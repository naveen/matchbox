import SwiftUI
import Observation

/// One finger currently resting on the trackpad, in normalized trackpad
/// coordinates (0...1 on both axes, origin at the bottom-left, as AppKit reports).
struct Finger: Identifiable, Equatable {
    let id: Int
    var x: CGFloat
    var y: CGFloat
}

/// The kinds of things Matchbox can recognise on the trackpad. Missions will
/// eventually be expressed in terms of these.
enum GestureKind: Equatable {
    case tap
    case click
    case doubleTap
    case doubleClick
    case secondaryTap
    case secondaryClick
    case holding
    case dragging
    case forceClick
    case scroll(Direction)
    case pinch(open: Bool)
    case rotate(clockwise: Bool)
    case swipe(Direction)
    case smartZoom
    case lookUp

    enum Direction: String { case up, down, left, right }
}

/// A single line in the "what I saw" log shown next to the play area.
struct SeenEvent: Identifiable, Equatable {
    let id: Int
    let text: String
    let symbol: String
}

/// Everything the play area needs to draw. Written to by `TouchCanvasView`
/// (AppKit) and read by SwiftUI.
@MainActor
@Observable
final class TouchState {
    /// Fingers currently touching the trackpad.
    var fingers: [Finger] = []
    /// Width divided by height of the physical trackpad, so the mirror can match its shape.
    var trackpadAspect: CGFloat = 1.55
    /// 0...1 while pressing down (force-touch trackpads report this continuously).
    var pressure: Double = 0
    /// 0 = not pressed, 1 = normal click, 2 = force click.
    var pressureStage: Int = 0
    /// True between mouse down and mouse up.
    var isPressed = false

    /// Big text shown to the child.
    var headline: String = "Touch the trackpad!"
    var headlineSymbol: String = "hand.point.up.left.fill"
    /// The last thing recognised, for the toy to react to.
    var lastGesture: GestureKind?
    /// Bumps every time something is recognised so views can key animations off it.
    var gestureSerial: Int = 0

    /// Where the toy currently is, driven by scrolling (in points, clamped by the view).
    var toyOffset: CGSize = .zero
    var toyScale: CGFloat = 1
    var toyRotation: Angle = .zero

    /// Recent recognised events, newest first.
    var recent: [SeenEvent] = []

    /// True while the pointer is over the play area. Trackpad events only
    /// reach the app while it is, so views can nudge the child back.
    var pointerInside = true
    /// Accumulated one-finger travel, in trackpad widths. Bumped continuously.
    var pointerTravel: CGFloat = 0

    private var nextEventID = 0

    func fingerCountChanged(_ count: Int) {
        guard !isPressed else { return }
        switch count {
        case 0:
            headline = "Touch the trackpad!"
            headlineSymbol = "hand.point.up.left.fill"
        case 1:
            headline = "One finger"
            headlineSymbol = "1.circle.fill"
        case 2:
            headline = "Two fingers"
            headlineSymbol = "2.circle.fill"
        case 3:
            headline = "Three fingers"
            headlineSymbol = "3.circle.fill"
        case 4:
            headline = "Four fingers"
            headlineSymbol = "4.circle.fill"
        default:
            headline = "\(count) fingers!"
            headlineSymbol = "hand.raised.fingers.spread.fill"
        }
    }

    func recognised(_ gesture: GestureKind) {
        lastGesture = gesture
        gestureSerial += 1

        let (text, symbol) = describe(gesture)
        headline = text
        headlineSymbol = symbol

        switch gesture {
        case .click, .tap:
            toyScale = max(0.4, toyScale * 0.9)
        case .doubleClick, .doubleTap:
            toyScale = min(3, toyScale * 1.25)
        case .forceClick:
            toyScale = 1
            toyOffset = .zero
            toyRotation = .zero
        default:
            break
        }

        // Continuous gestures fire many times per second; only log a new line
        // when the description actually changes.
        if recent.first?.text != text {
            nextEventID += 1
            recent.insert(SeenEvent(id: nextEventID, text: text, symbol: symbol), at: 0)
            if recent.count > 8 { recent.removeLast(recent.count - 8) }
        }
    }

    private func describe(_ gesture: GestureKind) -> (String, String) {
        switch gesture {
        case .tap: ("Tap!", "hand.tap.fill")
        case .click: ("Click!", "cursorarrow.click")
        case .doubleTap: ("Double tap!", "hand.tap.fill")
        case .doubleClick: ("Double click!", "cursorarrow.click.2")
        case .secondaryTap: ("Two-finger tap!", "hand.tap.fill")
        case .secondaryClick: ("Two-finger click!", "cursorarrow.click.2")
        case .holding: ("Holding…", "hand.point.up.left.fill")
        case .dragging: ("Dragging!", "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
        case .forceClick: ("FORCE CLICK!", "burst.fill")
        case .scroll(let direction): ("Scrolling \(direction.rawValue)", arrow(direction))
        case .pinch(let open): (open ? "Pinch open (bigger!)" : "Pinch closed (smaller!)", open ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
        case .rotate(let clockwise): (clockwise ? "Rotating right" : "Rotating left", clockwise ? "arrow.clockwise" : "arrow.counterclockwise")
        case .swipe(let direction): ("Swipe \(direction.rawValue)!", arrow(direction))
        case .smartZoom: ("Smart zoom!", "plus.magnifyingglass")
        case .lookUp: ("Look up!", "text.magnifyingglass")
        }
    }

    private func arrow(_ direction: GestureKind.Direction) -> String {
        switch direction {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .left: "arrow.left"
        case .right: "arrow.right"
        }
    }
}
