import XCTest
@testable import Matchbox

final class MissionCatalogTests: XCTestCase {
    func testDefaultProfileIncludesEveryGesture() {
        let missions = MissionCatalog.all(for: TrackpadProfile(), emojis: MissionCatalog.emojiPool)
        let ids = missions.map(\.id)
        XCTAssertEqual(ids, ["move", "tap", "click", "doubleTap", "hold", "drag", "scrollUp", "scrollDown",
                             "secondary", "pinchOpen", "pinchClose", "rotate", "force"])
    }

    func testTapMissionsDisappearWhenTapToClickIsOff() {
        var profile = TrackpadProfile()
        profile.tapToClick = false
        let ids = MissionCatalog.all(for: profile, emojis: MissionCatalog.emojiPool).map(\.id)
        XCTAssertFalse(ids.contains("tap"))
        XCTAssertTrue(ids.contains("doubleClick"))
        XCTAssertFalse(ids.contains("doubleTap"))
    }

    func testDisabledGesturesAreSkipped() {
        var profile = TrackpadProfile()
        profile.pinch = false
        profile.rotate = false
        profile.forceClick = false
        profile.secondaryClick = .off
        let ids = MissionCatalog.all(for: profile, emojis: MissionCatalog.emojiPool).map(\.id)
        XCTAssertEqual(ids, ["move", "tap", "click", "doubleTap", "hold", "drag", "scrollUp", "scrollDown"])
    }

    func testScrollDirectionFollowsNaturalScrolling() {
        var natural = TrackpadProfile()
        natural.naturalScrolling = true
        XCTAssertEqual(natural.fingerDirection(toMoveContent: .up), .up)

        var traditional = TrackpadProfile()
        traditional.naturalScrolling = false
        XCTAssertEqual(traditional.fingerDirection(toMoveContent: .up), .down)

        let mission = MissionCatalog.all(for: traditional, emojis: MissionCatalog.emojiPool).first { $0.id == "scrollUp" }
        XCTAssertEqual(mission?.goal, .scroll(.down))
        XCTAssertTrue(mission?.prompt.contains("two fingers down") ?? false)
    }

    func testEveryPromptContainsItsEmoji() {
        for mission in MissionCatalog.all(for: TrackpadProfile(), emojis: MissionCatalog.emojiPool) {
            XCTAssertTrue(mission.prompt.contains(mission.emoji), mission.id)
        }
    }

    func testCredit() {
        XCTAssertEqual(MissionGoal.tap.credit(for: .tap), 1)
        XCTAssertEqual(MissionGoal.tap.credit(for: .click), 0, "tap mission teaches the difference, so a press doesn't count")
        XCTAssertEqual(MissionGoal.doubleTap.credit(for: .doubleClick), 1, "double is lenient")
        XCTAssertEqual(MissionGoal.secondaryClick.credit(for: .secondaryTap), 1)
        XCTAssertEqual(MissionGoal.scroll(.up).credit(for: .scroll(.down)), 0)
        XCTAssertGreaterThan(MissionGoal.scroll(.up).credit(for: .scroll(.up)), 0)
        XCTAssertLessThan(MissionGoal.scroll(.up).credit(for: .scroll(.up)), 1)
    }
}

@MainActor
final class MissionSessionTests: XCTestCase {
    // Note: runs against the real app defaults domain on this machine and clears saved stickers.
    override func setUp() {
        for key in ["stickers", "nextMissionIndex", "sessionsFinished"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func testSessionRunsFiveMissionsAndAwardsStickers() async throws {
        let book = StickerBook()
        let session = MissionSession(profile: TrackpadProfile(), book: book)
        session.start()
        XCTAssertEqual(session.phase, .playing)
        XCTAssertEqual(session.missions.count, 5)
        XCTAssertEqual(session.missions.map(\.id), ["move", "tap", "click", "doubleTap", "hold"])

        session.pointerMoved(by: 2.0)
        XCTAssertEqual(session.phase, .celebrating)
        XCTAssertEqual(session.earned, [session.missions[0].emoji])
        XCTAssertEqual(book.stickers.count, 1)

        try await Task.sleep(for: .seconds(2.5))
        XCTAssertEqual(session.phase, .playing)
        XCTAssertEqual(session.index, 1)

        session.handle(.click)
        XCTAssertEqual(session.phase, .playing, "a press doesn't finish the tap mission")
        session.handle(.tap)
        XCTAssertEqual(session.phase, .celebrating)
    }

    func testNextSessionStartsWhereTheLastOneEnded() {
        let book = StickerBook()
        book.advanceMissionIndex(by: 5, catalogSize: 13)
        let session = MissionSession(profile: TrackpadProfile(), book: book)
        session.start()
        XCTAssertEqual(session.missions.map(\.id), ["drag", "scrollUp", "scrollDown", "secondary", "pinchOpen"])

        book.advanceMissionIndex(by: 5, catalogSize: 13)
        session.start()
        XCTAssertEqual(session.missions.map(\.id), ["pinchClose", "rotate", "force", "move", "tap"], "wraps around")
    }
}
