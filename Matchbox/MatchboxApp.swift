import SwiftUI

@main
struct MatchboxApp: App {
    /// Read once at launch. Missions are worded for, and limited to, what this
    /// Mac's trackpad is set up to do.
    private let profile = TrackpadSettingsReader().profile()

    var body: some Scene {
        WindowGroup {
            ContentView(initialRoom: LaunchOptions.room, profile: profile)
                .frame(minWidth: 900, minHeight: 620)
        }
        // A seven-year-old doesn't resize windows yet, so start big.
        .defaultSize(width: Self.launchSize.width, height: Self.launchSize.height)
        .defaultPosition(.center)

        // The grown-up screen lives under Matchbox > Settings (Cmd+,) so it
        // stays out of the child's way.
        Settings {
            GrownUpsView()
                .frame(minWidth: 1000, minHeight: 680)
        }
    }

    private static var launchSize: CGSize {
        let screen = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        return CGSize(width: screen.width - 40, height: screen.height - 40)
    }
}

/// Developer launch arguments:
///
///     Matchbox --room freeplay
enum LaunchOptions {
    private static func value(after flag: String) -> String? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    /// Which screen to open on. Defaults to Missions.
    static var room: Room {
        switch value(after: "--room")?.lowercased() {
        case "freeplay", "free-play": .freePlay
        case "stickers": .stickers
        default: .missions
        }
    }
}
