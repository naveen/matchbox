import AppKit
import SwiftUI

/// A transparent AppKit view that sits over the play area and listens to every
/// kind of trackpad input AppKit exposes: raw finger touches, clicks, pressure,
/// scrolling, pinching, rotating, swiping, smart zoom and look up.
///
/// AppKit routes indirect (trackpad) touches to the view under the pointer, so
/// this view must cover the whole play area for the finger mirror to work.
final class TouchCanvasView: NSView {
    var state: TouchState

    private var sawPhysicalClick = false
    private var mouseDownPoint: NSPoint = .zero
    private var isHolding = false
    private var isDragging = false
    private var holdTask: Task<Void, Never>?
    private var lastFingerPositions: [Int: CGPoint] = [:]
    private var trackingArea: NSTrackingArea?

    init(state: TouchState) {
        self.state = state
        super.init(frame: .zero)
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not supported") }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { state.pointerInside = true }
    override func mouseExited(with event: NSEvent) { state.pointerInside = false }

    // MARK: Raw finger touches

    override func touchesBegan(with event: NSEvent) { updateFingers(event) }
    override func touchesMoved(with event: NSEvent) { updateFingers(event) }
    override func touchesEnded(with event: NSEvent) { updateFingers(event) }

    override func touchesCancelled(with event: NSEvent) {
        // The system took the gesture over (Mission Control, Launchpad, …).
        state.fingers = []
        state.fingerCountChanged(0)
    }

    private func updateFingers(_ event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        if let any = touches.first, any.deviceSize.height > 0 {
            state.trackpadAspect = any.deviceSize.width / any.deviceSize.height
        }
        let previousCount = state.fingers.count
        state.fingers = touches
            .map { Finger(id: $0.identity.hash, x: $0.normalizedPosition.x, y: $0.normalizedPosition.y) }
            .sorted { $0.id < $1.id }
        if state.fingers.count != previousCount {
            state.fingerCountChanged(state.fingers.count)
        }

        // Accumulate how far a lone, unpressed finger has glided.
        var positions: [Int: CGPoint] = [:]
        for finger in state.fingers { positions[finger.id] = CGPoint(x: finger.x, y: finger.y) }
        if state.fingers.count == 1, !state.isPressed,
           let finger = state.fingers.first, let previous = lastFingerPositions[finger.id] {
            state.pointerTravel += hypot(finger.x - previous.x, finger.y - previous.y)
        }
        lastFingerPositions = positions
    }

    // MARK: Clicks, taps, holds and drags

    override func mouseDown(with event: NSEvent) {
        beginPress(at: event.locationInWindow)
    }

    override func mouseDragged(with event: NSEvent) {
        let distance = hypot(event.locationInWindow.x - mouseDownPoint.x,
                             event.locationInWindow.y - mouseDownPoint.y)
        if distance > 12 {
            isDragging = true
            holdTask?.cancel()
            state.recognised(.dragging)
        }
    }

    override func mouseUp(with event: NSEvent) {
        endPress()
        guard !isDragging, !isHolding else {
            resetPress()
            return
        }
        switch (event.clickCount, sawPhysicalClick) {
        case (2..., true): state.recognised(.doubleClick)
        case (2..., false): state.recognised(.doubleTap)
        case (_, true): state.recognised(.click)
        case (_, false): state.recognised(.tap)
        }
        resetPress()
    }

    override func rightMouseDown(with event: NSEvent) {
        beginPress(at: event.locationInWindow)
    }

    override func rightMouseUp(with event: NSEvent) {
        endPress()
        state.recognised(sawPhysicalClick ? .secondaryClick : .secondaryTap)
        resetPress()
    }

    private func beginPress(at point: NSPoint) {
        mouseDownPoint = point
        state.isPressed = true
        holdTask?.cancel()
        holdTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let self, self.state.isPressed, !self.isDragging else { return }
            self.isHolding = true
            self.state.recognised(.holding)
        }
    }

    private func endPress() {
        holdTask?.cancel()
        state.isPressed = false
        state.pressure = 0
        state.pressureStage = 0
    }

    private func resetPress() {
        sawPhysicalClick = false
        isHolding = false
        isDragging = false
        state.fingerCountChanged(state.fingers.count)
    }

    // MARK: Pressure (force click)

    override func pressureChange(with event: NSEvent) {
        // Tap-to-click never produces pressure events, so seeing any stage at
        // all tells us the trackpad was physically pressed.
        if event.stage >= 1 { sawPhysicalClick = true }
        state.pressure = Double(event.pressure)
        if event.stage == 2, state.pressureStage < 2 {
            holdTask?.cancel()
            state.recognised(.forceClick)
        }
        state.pressureStage = event.stage
    }

    // MARK: Scroll, pinch, rotate, swipe

    override func scrollWheel(with event: NSEvent) {
        guard event.phase != [] || event.momentumPhase != [] else {
            // A physical mouse wheel; still let the toy move.
            return
        }
        guard event.momentumPhase == [] else { return }

        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY
        guard abs(dx) + abs(dy) > 0.5 else { return }

        // Report the direction the *fingers* moved, which is what the child feels.
        let inverted = event.isDirectionInvertedFromDevice
        let fingerDX = inverted ? -dx : dx
        let fingerDY = inverted ? -dy : dy

        let direction: GestureKind.Direction
        if abs(fingerDY) >= abs(fingerDX) {
            direction = fingerDY > 0 ? .up : .down
        } else {
            direction = fingerDX > 0 ? .right : .left
        }
        state.toyOffset.width += fingerDX
        state.toyOffset.height -= fingerDY
        state.recognised(.scroll(direction))
    }

    override func magnify(with event: NSEvent) {
        guard event.phase == .changed else { return }
        state.toyScale = min(3, max(0.4, state.toyScale * (1 + event.magnification)))
        state.recognised(.pinch(open: event.magnification > 0))
    }

    override func rotate(with event: NSEvent) {
        // AppKit reports counter-clockwise rotation as positive degrees.
        state.toyRotation -= .degrees(Double(event.rotation))
        state.recognised(.rotate(clockwise: event.rotation < 0))
    }

    override func swipe(with event: NSEvent) {
        // Only delivered when "Swipe between pages" is set to three fingers.
        if event.deltaX > 0 { state.recognised(.swipe(.left)) }
        else if event.deltaX < 0 { state.recognised(.swipe(.right)) }
        else if event.deltaY > 0 { state.recognised(.swipe(.up)) }
        else if event.deltaY < 0 { state.recognised(.swipe(.down)) }
    }

    override func smartMagnify(with event: NSEvent) {
        state.toyScale = state.toyScale > 1.5 ? 1 : 2
        state.recognised(.smartZoom)
    }

    override func quickLook(with event: NSEvent) {
        state.recognised(.lookUp)
    }
}

struct TouchCanvas: NSViewRepresentable {
    let state: TouchState

    func makeNSView(context: Context) -> TouchCanvasView {
        TouchCanvasView(state: state)
    }

    func updateNSView(_ view: TouchCanvasView, context: Context) {
        view.state = state
    }
}
