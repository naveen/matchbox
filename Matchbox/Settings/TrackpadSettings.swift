import Foundation

/// One row on the Grown-ups screen: what a gesture is currently mapped to.
struct TrackpadSetting: Identifiable, Hashable {
    enum Section: String, CaseIterable, Identifiable {
        case pointAndClick = "Point & Click"
        case scrollAndZoom = "Scroll & Zoom"
        case moreGestures = "More Gestures"
        case accessibility = "Accessibility"
        var id: String { rawValue }
    }

    let id: String
    let section: Section
    let title: String
    let symbol: String
    /// Current mapping in plain words, e.g. "Click or tap with two fingers".
    let value: String
    let isOn: Bool
    /// What the child should know, e.g. "Tap lightly with one finger to click."
    let hint: String
}

/// Reads the logged-in user's trackpad preferences straight from the same
/// defaults domains System Settings writes to. Read-only on purpose: changing
/// these is a grown-up job in System Settings, and Matchbox never writes them.
///
/// Requires the app to be un-sandboxed.
struct TrackpadSettingsReader {
    private let builtIn = UserDefaults(suiteName: "com.apple.AppleMultitouchTrackpad")
    private let bluetooth = UserDefaults(suiteName: "com.apple.driver.AppleBluetoothMultitouch.trackpad")
    private let dock = UserDefaults(suiteName: "com.apple.dock")
    private let global = UserDefaults.standard

    /// Integer value from the built-in trackpad domain, falling back to an
    /// external Bluetooth trackpad if the built-in one has no opinion.
    func int(_ key: String) -> Int? {
        if let value = builtIn?.object(forKey: key) as? NSNumber { return value.intValue }
        if let value = bluetooth?.object(forKey: key) as? NSNumber { return value.intValue }
        return nil
    }

    func globalBool(_ key: String) -> Bool? {
        (global.object(forKey: key) as? NSNumber)?.boolValue
    }

    private func globalDouble(_ key: String) -> Double? {
        (global.object(forKey: key) as? NSNumber)?.doubleValue
    }

    func read() -> [TrackpadSetting] {
        var rows: [TrackpadSetting] = []

        // MARK: Point & Click

        let tapToClick = int("Clicking") == 1
        rows.append(.init(
            id: "tapToClick", section: .pointAndClick, title: "Tap to click", symbol: "hand.tap.fill",
            value: tapToClick ? "On" : "Off", isOn: tapToClick,
            hint: tapToClick ? "A light tap with one finger works like a click."
                             : "Tapping does nothing. Press the trackpad down to click."
        ))

        let rightClick = int("TrackpadRightClick") == 1
        let corner = int("TrackpadCornerSecondaryClick") ?? 0
        let secondary: (String, Bool) = switch (rightClick, corner) {
            case (_, 1): ("Click in the bottom right corner", true)
            case (_, 2): ("Click in the bottom left corner", true)
            case (true, _): (tapToClick ? "Click or tap with two fingers" : "Click with two fingers", true)
            default: ("Off", false)
        }
        rows.append(.init(
            id: "secondaryClick", section: .pointAndClick, title: "Secondary click", symbol: "cursorarrow.click.2",
            value: secondary.0, isOn: secondary.1,
            hint: "Opens the little menu of extra choices (a “right click”)."
        ))

        let speed = globalDouble("com.apple.trackpad.scaling") ?? 0.875
        let speedLabel: String = switch speed {
            case ..<0.5: "Slow"
            case ..<1.25: "Medium"
            case ..<2.0: "Fast"
            default: "Very fast"
        }
        rows.append(.init(
            id: "trackingSpeed", section: .pointAndClick, title: "Tracking speed", symbol: "hare.fill",
            value: speedLabel, isOn: true,
            hint: "How far the arrow moves when your finger moves."
        ))

        let firmness = int("FirstClickThreshold") ?? 1
        let firmnessLabel = ["Light", "Medium", "Firm"][min(max(firmness, 0), 2)]
        rows.append(.init(
            id: "clickFirmness", section: .pointAndClick, title: "Click", symbol: "arrow.down.to.line",
            value: firmnessLabel, isOn: true,
            hint: "How hard you need to press before it counts as a click."
        ))

        // The driver key is authoritative. The global mirror key
        // (com.apple.trackpad.forceClick) can be stale and disagree with it.
        let forceClick: Bool = if let suppressed = int("ForceSuppressed") {
            suppressed != 1
        } else {
            globalBool("com.apple.trackpad.forceClick") ?? true
        }
        rows.append(.init(
            id: "forceClick", section: .pointAndClick, title: "Force Click and haptic feedback", symbol: "burst.fill",
            value: forceClick ? "On" : "Off", isOn: forceClick,
            hint: forceClick ? "Press, then press even harder for a second, deeper click."
                             : "Pressing harder does nothing extra."
        ))

        let lookUp = int("TrackpadThreeFingerTapGesture") ?? 0
        let lookUpValue: (String, Bool) = switch lookUp {
            case 2: ("Tap with three fingers", true)
            default: forceClick ? ("Force click with one finger", true) : ("Off", false)
        }
        rows.append(.init(
            id: "lookUp", section: .pointAndClick, title: "Look up & data detectors", symbol: "text.magnifyingglass",
            value: lookUpValue.0, isOn: lookUpValue.1,
            hint: "Shows the meaning of a word you point at."
        ))

        let silent = int("ActuateDetents") == 0
        rows.append(.init(
            id: "silentClicking", section: .pointAndClick, title: "Silent clicking", symbol: "speaker.slash.fill",
            value: silent ? "On" : "Off", isOn: silent,
            hint: silent ? "Clicks are quiet." : "Clicks make a click sound and a little buzz."
        ))

        // MARK: Scroll & Zoom

        let natural = globalBool("com.apple.swipescrolldirection") ?? true
        rows.append(.init(
            id: "naturalScrolling", section: .scrollAndZoom, title: "Natural scrolling", symbol: "arrow.up.and.down",
            value: natural ? "On" : "Off", isOn: natural,
            hint: natural ? "Slide two fingers up and the page moves up, like pushing paper."
                          : "Slide two fingers up and the page moves down, like an old mouse wheel."
        ))

        let pinch = int("TrackpadPinch") == 1
        rows.append(.init(
            id: "pinchZoom", section: .scrollAndZoom, title: "Zoom in or out", symbol: "arrow.up.left.and.arrow.down.right",
            value: pinch ? "Pinch with two fingers" : "Off", isOn: pinch,
            hint: "Spread two fingers apart to make things bigger, pinch them to make things smaller."
        ))

        let smartZoom = int("TrackpadTwoFingerDoubleTapGesture") == 1
        rows.append(.init(
            id: "smartZoom", section: .scrollAndZoom, title: "Smart zoom", symbol: "plus.magnifyingglass",
            value: smartZoom ? "Double-tap with two fingers" : "Off", isOn: smartZoom,
            hint: "Two quick taps with two fingers zooms in on what you are looking at."
        ))

        let rotate = int("TrackpadRotate") == 1
        rows.append(.init(
            id: "rotate", section: .scrollAndZoom, title: "Rotate", symbol: "arrow.clockwise",
            value: rotate ? "Rotate with two fingers" : "Off", isOn: rotate,
            hint: "Twist two fingers like turning a dial to spin a picture."
        ))

        // MARK: More Gestures

        let threeHoriz = int("TrackpadThreeFingerHorizSwipeGesture") ?? 0
        let fourHoriz = int("TrackpadFourFingerHorizSwipeGesture") ?? 0
        let twoFingerPages = globalBool("AppleEnableSwipeNavigateWithScrolls") ?? true
        let pages: (String, Bool) = switch (twoFingerPages, threeHoriz == 1) {
            case (true, true): ("Scroll with two or swipe with three fingers", true)
            case (true, false): ("Scroll left or right with two fingers", true)
            case (false, true): ("Swipe with three fingers", true)
            default: ("Off", false)
        }
        rows.append(.init(
            id: "swipePages", section: .moreGestures, title: "Swipe between pages", symbol: "book.pages.fill",
            value: pages.0, isOn: pages.1,
            hint: "Goes back or forward, like turning pages in a book."
        ))

        let fullScreen: (String, Bool) = switch (threeHoriz, fourHoriz) {
            case (2, _): ("Swipe left or right with three fingers", true)
            case (_, 2): ("Swipe left or right with four fingers", true)
            default: ("Off", false)
        }
        rows.append(.init(
            id: "swipeFullScreen", section: .moreGestures, title: "Swipe between full-screen apps", symbol: "rectangle.on.rectangle",
            value: fullScreen.0, isOn: fullScreen.1,
            hint: "Slides sideways to the next full-screen app or desktop."
        ))

        let notificationCenter = int("TrackpadTwoFingerFromRightEdgeSwipeGesture") == 3
        rows.append(.init(
            id: "notificationCenter", section: .moreGestures, title: "Notification Center", symbol: "bell.fill",
            value: notificationCenter ? "Swipe left from the right edge with two fingers" : "Off", isOn: notificationCenter,
            hint: "Start with two fingers off the right edge and slide in to see notifications."
        ))

        let threeVert = int("TrackpadThreeFingerVertSwipeGesture") ?? 0
        let fourVert = int("TrackpadFourFingerVertSwipeGesture") ?? 0
        let missionControl: (String, Bool) = switch (threeVert, fourVert) {
            case (2, _): ("Swipe up with three fingers", true)
            case (_, 2): ("Swipe up with four fingers", true)
            default: ("Off", false)
        }
        rows.append(.init(
            id: "missionControl", section: .moreGestures, title: "Mission Control", symbol: "square.grid.3x3.fill",
            value: missionControl.0, isOn: missionControl.1,
            hint: "Shows every open window at once."
        ))

        let appExpose = (dock?.object(forKey: "showAppExposeGestureEnabled") as? NSNumber)?.boolValue ?? false
        let exposeFingers = threeVert == 2 ? "three" : "four"
        rows.append(.init(
            id: "appExpose", section: .moreGestures, title: "App Exposé", symbol: "square.stack.fill",
            value: appExpose && missionControl.1 ? "Swipe down with \(exposeFingers) fingers" : "Off", isOn: appExpose && missionControl.1,
            hint: "Shows all the windows of the app you are using."
        ))

        let launchpad = int("TrackpadFourFingerPinchGesture") == 2 || int("TrackpadFiveFingerPinchGesture") == 2
        rows.append(.init(
            id: "launchpad", section: .moreGestures, title: "Launchpad & Show Desktop", symbol: "square.grid.4x3.fill",
            value: launchpad ? "Pinch or spread with thumb and three fingers" : "Off", isOn: launchpad,
            hint: "Pinch to see all your apps. Spread to hide everything and see the desktop."
        ))

        // MARK: Accessibility

        let threeFingerDrag = int("TrackpadThreeFingerDrag") == 1
        rows.append(.init(
            id: "threeFingerDrag", section: .accessibility, title: "Three-finger drag", symbol: "hand.draw.fill",
            value: threeFingerDrag ? "On" : "Off", isOn: threeFingerDrag,
            hint: threeFingerDrag ? "Slide three fingers to drag things without pressing."
                                  : "To drag, press down and keep pressing while you slide."
        ))

        let dragging = int("Dragging") == 1
        let dragLock = int("DragLock") == 1
        let dragValue: (String, Bool) = switch (dragging, dragLock) {
            case (_, true): ("With drag lock", true)
            case (true, _): ("Without drag lock", true)
            default: ("Off", false)
        }
        rows.append(.init(
            id: "dragging", section: .accessibility, title: "Dragging style", symbol: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left",
            value: dragValue.0, isOn: dragValue.1,
            hint: "Double-tap and hold to pick something up and drag it."
        ))

        return rows
    }
}

// MARK: - Profile

/// The handful of settings that change how missions are worded and which
/// ones are possible. Read once at launch; the whole app adapts to it.
struct TrackpadProfile: Equatable {
    enum SecondaryClick: Equatable {
        case off
        case twoFingers
        case bottomRightCorner
        case bottomLeftCorner
    }

    var tapToClick = true
    var naturalScrolling = true
    var secondaryClick: SecondaryClick = .twoFingers
    var forceClick = true
    var pinch = true
    var rotate = true
    var threeFingerDrag = false

    /// Which way fingers must slide so the content moves in `contentDirection`.
    func fingerDirection(toMoveContent contentDirection: GestureKind.Direction) -> GestureKind.Direction {
        // Natural: content follows the fingers. Traditional: it goes the other way.
        guard !naturalScrolling else { return contentDirection }
        switch contentDirection {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }
}

extension TrackpadSettingsReader {
    func profile() -> TrackpadProfile {
        var profile = TrackpadProfile()
        profile.tapToClick = int("Clicking") == 1
        profile.naturalScrolling = globalBool("com.apple.swipescrolldirection") ?? true

        let rightClick = int("TrackpadRightClick") == 1
        switch (rightClick, int("TrackpadCornerSecondaryClick") ?? 0) {
        case (_, 1): profile.secondaryClick = .bottomRightCorner
        case (_, 2): profile.secondaryClick = .bottomLeftCorner
        case (true, _): profile.secondaryClick = .twoFingers
        default: profile.secondaryClick = .off
        }

        if let suppressed = int("ForceSuppressed") {
            profile.forceClick = suppressed != 1
        } else {
            profile.forceClick = globalBool("com.apple.trackpad.forceClick") ?? true
        }
        profile.pinch = int("TrackpadPinch") == 1
        profile.rotate = int("TrackpadRotate") == 1
        profile.threeFingerDrag = int("TrackpadThreeFingerDrag") == 1
        return profile
    }
}
