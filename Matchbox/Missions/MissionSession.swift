import SwiftUI
import Observation

/// Runs one short session: a handful of missions, one at a time, then a finish.
@MainActor
@Observable
final class MissionSession {
    enum Phase: Equatable { case ready, playing, celebrating, finished }

    static let missionsPerSession = 5
    static let hintDelay: Duration = .seconds(8)

    private(set) var phase: Phase = .ready
    private(set) var missions: [Mission] = []
    private(set) var index = 0
    private(set) var progress: Double = 0
    private(set) var earned: [String] = []
    var showHint = false

    let profile: TrackpadProfile
    let book: StickerBook
    private let catalogSize: Int
    private var advanceTask: Task<Void, Never>?

    init(profile: TrackpadProfile, book: StickerBook) {
        self.profile = profile
        self.book = book
        catalogSize = MissionCatalog.all(for: profile, emojis: []).count
    }

    var current: Mission? {
        missions.indices.contains(index) ? missions[index] : nil
    }

    func start() {
        let catalog = MissionCatalog.all(for: profile, emojis: MissionCatalog.emojiPool.shuffled())
        guard !catalog.isEmpty else { return }
        let start = book.nextMissionIndex % catalog.count
        missions = (0..<min(Self.missionsPerSession, catalog.count)).map { catalog[(start + $0) % catalog.count] }
        index = 0
        progress = 0
        earned = []
        showHint = false
        phase = .playing
    }

    func handle(_ gesture: GestureKind) {
        guard phase == .playing, let mission = current else { return }
        let credit = mission.goal.credit(for: gesture)
        guard credit > 0 else { return }
        progress = min(1, progress + credit)
        if progress >= 1 { complete() }
    }

    /// Normalized one-finger travel, in trackpad widths.
    func pointerMoved(by distance: CGFloat) {
        guard phase == .playing, current?.goal == .moveArrow else { return }
        progress = min(1, progress + Double(distance) / 2.0)
        if progress >= 1 { complete() }
    }

    private func complete() {
        guard let mission = current else { return }
        phase = .celebrating
        showHint = false
        earned.append(mission.emoji)
        book.add(mission.emoji)
        Sounds.play(.success)
        advanceTask?.cancel()
        advanceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            self?.advance()
        }
    }

    private func advance() {
        index += 1
        progress = 0
        showHint = false
        if index >= missions.count {
            book.advanceMissionIndex(by: missions.count, catalogSize: catalogSize)
            book.finishedSession()
            phase = .finished
            Sounds.play(.finish)
        } else {
            phase = .playing
        }
    }
}
