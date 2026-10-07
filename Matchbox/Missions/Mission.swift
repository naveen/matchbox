import Foundation

/// What a mission is waiting for.
enum MissionGoal: Equatable {
    case moveArrow
    case tap
    case click
    case doubleTap
    case doubleClick
    case hold
    case drag
    case scroll(GestureKind.Direction)
    case secondaryClick
    case pinch(open: Bool)
    case rotate(clockwise: Bool)
    case forceClick

    /// How much of the mission a single recognised gesture is worth (0...1).
    /// Discrete gestures finish in one go; continuous ones need a few events.
    func credit(for gesture: GestureKind) -> Double {
        switch (self, gesture) {
        case (.tap, .tap): 1
        case (.click, .click): 1
        case (.doubleTap, .doubleTap), (.doubleTap, .doubleClick): 1
        case (.doubleClick, .doubleClick), (.doubleClick, .doubleTap): 1
        case (.hold, .holding): 1
        case (.drag, .dragging): 0.1
        case (.scroll(let want), .scroll(let got)) where want == got: 1.0 / 12
        case (.secondaryClick, .secondaryTap), (.secondaryClick, .secondaryClick): 1
        case (.pinch(let want), .pinch(let got)) where want == got: 1.0 / 8
        case (.rotate(let want), .rotate(let got)) where want == got: 1.0 / 8
        case (.forceClick, .forceClick): 1
        default: 0
        }
    }
}

struct Mission: Identifiable, Equatable {
    let id: String
    let goal: MissionGoal
    /// Big text the child reads. Contains the emoji.
    let prompt: String
    /// Shown after a while if nothing has happened. Also contains the emoji.
    let hint: String
    let symbol: String
    /// The toy for this mission and the sticker earned on completion.
    let emoji: String
}

/// Builds the ordered list of missions that are possible on this Mac, worded
/// for how this Mac is set up.
enum MissionCatalog {
    static let emojiPool = [
        "🐶", "🐱", "🦊", "🐸", "🐼", "🦁", "🐵", "🐨", "🦖", "🐙", "🦋", "🐧",
        "🚗", "🚀", "🚁", "🚂", "⛵", "🛸",
        "🍕", "🍩", "🍓", "🍪", "🍉", "🧁",
        "⚽", "🎈", "🪁", "🎸", "🌈", "⭐", "🎁", "🦄",
    ]

    /// All missions in difficulty order, using `emojis` in turn.
    static func all(for profile: TrackpadProfile, emojis: [String]) -> [Mission] {
        var pick = emojis.makeIterator()
        func next() -> String { pick.next() ?? "⭐" }
        var missions: [Mission] = []

        do {
            let e = next()
            missions.append(Mission(
                id: "move", goal: .moveArrow,
                prompt: "Slide one finger around to wake up the \(e)",
                hint: "Just glide one finger on the trackpad. Don't press.",
                symbol: "cursorarrow.motionlines", emoji: e))
        }

        if profile.tapToClick {
            let e = next()
            missions.append(Mission(
                id: "tap", goal: .tap,
                prompt: "Tap the trackpad lightly to boop the \(e)",
                hint: "A quick, light tap with one finger. No pressing down!",
                symbol: "hand.tap.fill", emoji: e))
        }

        do {
            let e = next()
            missions.append(Mission(
                id: "click", goal: .click,
                prompt: "Press the trackpad down until it clicks to poke the \(e)",
                hint: "Push down with one finger until you feel the click.",
                symbol: "cursorarrow.click", emoji: e))
        }

        do {
            let e = next()
            missions.append(profile.tapToClick
                ? Mission(id: "doubleTap", goal: .doubleTap,
                          prompt: "Tap twice, quick as a bunny, to wake the \(e)",
                          hint: "Tap-tap! Two light taps, fast.",
                          symbol: "hand.tap.fill", emoji: e)
                : Mission(id: "doubleClick", goal: .doubleClick,
                          prompt: "Click twice, quick as a bunny, to wake the \(e)",
                          hint: "Click-click! Two clicks, fast.",
                          symbol: "cursorarrow.click.2", emoji: e))
        }

        do {
            let e = next()
            missions.append(Mission(
                id: "hold", goal: .hold,
                prompt: "Press down and keep holding to squeeze the \(e)",
                hint: "Push down and don't let go. Count to two!",
                symbol: "hand.point.up.left.fill", emoji: e))
        }

        do {
            let e = next()
            missions.append(Mission(
                id: "drag", goal: .drag,
                prompt: profile.threeFingerDrag
                    ? "Slide three fingers to drag the \(e) around"
                    : "Press down, keep pressing, and slide to drag the \(e)",
                hint: profile.threeFingerDrag
                    ? "Three fingers together, then glide."
                    : "Push down like a click, but keep pushing while you slide.",
                symbol: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", emoji: e))
        }

        do {
            let e = next()
            let fingers = profile.fingerDirection(toMoveContent: .up)
            missions.append(Mission(
                id: "scrollUp", goal: .scroll(fingers),
                prompt: "Slide two fingers \(fingers.rawValue) to lift the \(e) into the sky",
                hint: "Two fingers side by side, sliding \(fingers.rawValue) together.",
                symbol: "arrow.up", emoji: e))
        }

        do {
            let e = next()
            let fingers = profile.fingerDirection(toMoveContent: .down)
            missions.append(Mission(
                id: "scrollDown", goal: .scroll(fingers),
                prompt: "Slide two fingers \(fingers.rawValue) to bring the \(e) back down",
                hint: "Two fingers side by side, sliding \(fingers.rawValue) together.",
                symbol: "arrow.down", emoji: e))
        }

        if profile.secondaryClick != .off {
            let e = next()
            let (prompt, hint): (String, String) = switch profile.secondaryClick {
                case .twoFingers where profile.tapToClick:
                    ("Tap with two fingers to open the \(e)'s secret menu", "Two fingers, one light tap, at the same time.")
                case .twoFingers:
                    ("Click with two fingers to open the \(e)'s secret menu", "Two fingers on the trackpad, then press down.")
                case .bottomRightCorner:
                    ("Click in the bottom right corner to open the \(e)'s secret menu", "Press down in the bottom right corner.")
                case .bottomLeftCorner:
                    ("Click in the bottom left corner to open the \(e)'s secret menu", "Press down in the bottom left corner.")
                case .off:
                    ("", "")
            }
            missions.append(Mission(id: "secondary", goal: .secondaryClick, prompt: prompt, hint: hint,
                                    symbol: "cursorarrow.click.2", emoji: e))
        }

        if profile.pinch {
            let e1 = next()
            missions.append(Mission(
                id: "pinchOpen", goal: .pinch(open: true),
                prompt: "Spread two fingers apart to make the \(e1) grow",
                hint: "Start with two fingers together, then slide them apart.",
                symbol: "arrow.up.left.and.arrow.down.right", emoji: e1))
            let e2 = next()
            missions.append(Mission(
                id: "pinchClose", goal: .pinch(open: false),
                prompt: "Pinch two fingers together to shrink the \(e2)",
                hint: "Start with two fingers apart, then slide them together.",
                symbol: "arrow.down.right.and.arrow.up.left", emoji: e2))
        }

        if profile.rotate {
            let e = next()
            missions.append(Mission(
                id: "rotate", goal: .rotate(clockwise: true),
                prompt: "Twist two fingers to the right to spin the \(e)",
                hint: "Like turning a doorknob: two fingers, twist clockwise.",
                symbol: "arrow.clockwise", emoji: e))
        }

        if profile.forceClick {
            let e = next()
            missions.append(Mission(
                id: "force", goal: .forceClick,
                prompt: "Press, then press even HARDER, to launch the \(e)",
                hint: "Click… and keep pushing until you feel a second, deeper click.",
                symbol: "burst.fill", emoji: e))
        }

        return missions
    }
}
