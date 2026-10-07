import AppKit

/// Built-in macOS sounds, so there are no audio assets to ship.
enum Sounds {
    enum Kind {
        case success, finish

        var systemName: String {
            switch self {
            case .success: "Glass"
            case .finish: "Hero"
            }
        }
    }

    static func play(_ kind: Kind) {
        NSSound(named: NSSound.Name(kind.systemName))?.play()
    }
}
