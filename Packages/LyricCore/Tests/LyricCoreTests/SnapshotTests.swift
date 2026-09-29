import XCTest
@testable import LyricCore

final class NowPlayingSnapshotTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 2_000_000)

    private func snapshot(playing: Bool = true, position: Double = 0, offset: Double = 0) -> NowPlayingSnapshot {
        let lines = [
            LyricLine(id: 0, time: 5, text: "A"),
            LyricLine(id: 1, time: 10, text: "B"),
            LyricLine(id: 2, time: 15, text: "C"),
            LyricLine(id: 3, time: 20, text: "D"),
        ]
        return NowPlayingSnapshot(
            track: TrackInfo(title: "T", artist: "Ar", duration: 30, source: .demo),
            clock: PlaybackClock(anchorPosition: position, anchorDate: t0, rate: playing ? 1 : 0, duration: 30),
            lines: lines,
            isSynced: true,
            translations: ["a", "b", "", "d"],
            offset: offset
        )
    }

    func testWindowAroundCurrentLine() {
        let window = snapshot(position: 11).window(at: t0, before: 1, after: 2)
        XCTAssertEqual(window.current, .init(text: "B", translation: "b"))
        XCTAssertEqual(window.previous.map(\.text), ["A"])
        XCTAssertEqual(window.upcoming.map(\.text), ["C", "D"])
        XCTAssertNil(window.upcoming[0].translation, "empty translations are dropped")
        XCTAssertEqual(window.currentIndex, 1)
        XCTAssertEqual(window.progress, 0.2, accuracy: 0.0001)
    }

    func testWindowBeforeFirstLine() {
        let window = snapshot(position: 1).window(at: t0, before: 1, after: 2)
        XCTAssertNil(window.current)
        XCTAssertTrue(window.previous.isEmpty)
        XCTAssertEqual(window.upcoming.map(\.text), ["A", "B"])
    }

    func testWindowAtEnd() {
        let window = snapshot(position: 29).window(at: t0, before: 1, after: 2)
        XCTAssertEqual(window.current?.text, "D")
        XCTAssertTrue(window.upcoming.isEmpty)
    }

    func testWindowAdvancesWithClock() {
        let s = snapshot(position: 9)
        XCTAssertEqual(s.window(at: t0).current?.text, "A")
        XCTAssertEqual(s.window(at: t0.addingTimeInterval(1.5)).current?.text, "B")
    }

    func testUnsyncedSnapshotHasNoWindow() {
        var s = snapshot(position: 11)
        s.isSynced = false
        XCTAssertNil(s.window(at: t0).current)
        XCTAssertTrue(s.changeDates(from: t0).count == 1)
    }

    func testChangeDatesFollowLineBoundaries() {
        let dates = snapshot(position: 11).changeDates(from: t0)
        XCTAssertEqual(dates, [t0, t0.addingTimeInterval(4), t0.addingTimeInterval(9)])
    }

    func testChangeDatesBeforeFirstLine() {
        let dates = snapshot(position: 0).changeDates(from: t0)
        XCTAssertEqual(dates.map { $0.timeIntervalSince(t0) }, [0, 5, 10, 15, 20])
    }

    func testChangeDatesRespectOffset() {
        let dates = snapshot(position: 0, offset: 1).changeDates(from: t0)
        XCTAssertEqual(dates.map { $0.timeIntervalSince(t0) }, [0, 4, 9, 14, 19])
    }

    func testChangeDatesEmptyWhenPaused() {
        XCTAssertEqual(snapshot(playing: false, position: 11).changeDates(from: t0), [t0])
    }

    func testChangeDatesLimit() {
        XCTAssertEqual(snapshot(position: 0).changeDates(from: t0, limit: 3).count, 3)
    }

    func testCodableRoundTrip() throws {
        let original = snapshot(position: 3)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NowPlayingSnapshot.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
