import SwiftUI
import Observation

/// Everything the child has earned, saved on this Mac.
@MainActor
@Observable
final class StickerBook {
    private static let stickersKey = "stickers"
    private static let nextMissionKey = "nextMissionIndex"
    private static let sessionsKey = "sessionsFinished"

    private(set) var stickers: [String]
    /// Where the next session starts in the mission catalog, so each session
    /// moves on to new gestures and eventually wraps around.
    private(set) var nextMissionIndex: Int
    private(set) var sessionsFinished: Int

    init() {
        let defaults = UserDefaults.standard
        stickers = defaults.stringArray(forKey: Self.stickersKey) ?? []
        nextMissionIndex = defaults.integer(forKey: Self.nextMissionKey)
        sessionsFinished = defaults.integer(forKey: Self.sessionsKey)
    }

    func add(_ sticker: String) {
        stickers.append(sticker)
        UserDefaults.standard.set(stickers, forKey: Self.stickersKey)
    }

    func advanceMissionIndex(by count: Int, catalogSize: Int) {
        guard catalogSize > 0 else { return }
        nextMissionIndex = (nextMissionIndex + count) % catalogSize
        UserDefaults.standard.set(nextMissionIndex, forKey: Self.nextMissionKey)
    }

    func finishedSession() {
        sessionsFinished += 1
        UserDefaults.standard.set(sessionsFinished, forKey: Self.sessionsKey)
    }
}
