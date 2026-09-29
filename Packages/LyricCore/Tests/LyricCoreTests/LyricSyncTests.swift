import XCTest
@testable import LyricCore

final class LyricSyncTests: XCTestCase {
    private func lines(_ times: [Double]) -> [LyricLine] {
        times.enumerated().map { LyricLine(id: $0.offset, time: $0.element, text: "L\($0.offset)") }
    }

    func testIndexBeforeFirstLineIsNil() {
        let engine = LyricSyncEngine(lines: lines([5, 10, 15]))
        XCTAssertNil(engine.index(at: 0))
        XCTAssertNil(engine.index(at: 4.99))
    }

    func testIndexAtBoundariesAndBetween() {
        let engine = LyricSyncEngine(lines: lines([5, 10, 15]))
        XCTAssertEqual(engine.index(at: 5), 0)
        XCTAssertEqual(engine.index(at: 9.99), 0)
        XCTAssertEqual(engine.index(at: 10), 1)
        XCTAssertEqual(engine.index(at: 14), 1)
        XCTAssertEqual(engine.index(at: 15), 2)
        XCTAssertEqual(engine.index(at: 9999), 2)
    }

    func testEmptyLines() {
        let engine = LyricSyncEngine(lines: [])
        XCTAssertNil(engine.index(at: 3))
        XCTAssertEqual(engine.state(at: 3), SyncState(currentIndex: nil, lineProgress: 0, nextChangePosition: nil))
        XCTAssertTrue(engine.window(around: nil, before: 1, after: 2).isEmpty)
    }

    func testPositiveOffsetShowsLinesEarlier() {
        let engine = LyricSyncEngine(lines: lines([10, 20]), offset: 1.5)
        XCTAssertNil(engine.index(at: 8.4))
        XCTAssertEqual(engine.index(at: 8.5), 0)
        XCTAssertEqual(engine.state(at: 9).nextChangePosition!, 18.5, accuracy: 0.0001)
    }

    func testNegativeOffsetShowsLinesLater() {
        let engine = LyricSyncEngine(lines: lines([10, 20]), offset: -2)
        XCTAssertNil(engine.index(at: 11.9))
        XCTAssertEqual(engine.index(at: 12), 0)
    }

    func testStateProgressAndNextChange() {
        let engine = LyricSyncEngine(lines: lines([10, 20]))
        let state = engine.state(at: 15)
        XCTAssertEqual(state.currentIndex, 0)
        XCTAssertEqual(state.lineProgress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(state.nextChangePosition, 20)
    }

    func testStateBeforeFirstLineReportsWhenItStarts() {
        let engine = LyricSyncEngine(lines: lines([10, 20]))
        let state = engine.state(at: 2)
        XCTAssertNil(state.currentIndex)
        XCTAssertEqual(state.nextChangePosition, 10)
    }

    func testLastLineUsesDurationOrDefault() {
        let withDuration = LyricSyncEngine(lines: lines([10, 20]), duration: 40)
        XCTAssertEqual(withDuration.state(at: 30).lineProgress, 0.5, accuracy: 0.0001)
        XCTAssertNil(withDuration.state(at: 30).nextChangePosition)

        let withoutDuration = LyricSyncEngine(lines: lines([10, 20]))
        XCTAssertEqual(withoutDuration.state(at: 22.5).lineProgress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(withoutDuration.state(at: 100).lineProgress, 1, accuracy: 0.0001)
    }

    func testSeekPositionLandsInsideLine() {
        let engine = LyricSyncEngine(lines: lines([10, 20]), offset: 1)
        let seek = engine.seekPosition(forLine: 1)!
        XCTAssertEqual(engine.index(at: seek), 1)
        XCTAssertNil(engine.seekPosition(forLine: 5))
    }

    func testSeekPositionNeverNegative() {
        let engine = LyricSyncEngine(lines: lines([0.5]), offset: 3)
        XCTAssertGreaterThanOrEqual(engine.seekPosition(forLine: 0)!, 0)
    }

    func testWindow() {
        let engine = LyricSyncEngine(lines: lines([1, 2, 3, 4, 5, 6]))
        XCTAssertEqual(engine.window(around: 3, before: 1, after: 2).map(\.id), [2, 3, 4, 5])
        XCTAssertEqual(engine.window(around: 0, before: 2, after: 1).map(\.id), [0, 1])
        XCTAssertEqual(engine.window(around: 5, before: 0, after: 3).map(\.id), [5])
        XCTAssertEqual(engine.window(around: nil, before: 1, after: 2).map(\.id), [0, 1])
    }

    func testUnsyncedDocumentsNeverSync() {
        let doc = LRCParser.parsePlain("a\nb\nc")
        let engine = LyricSyncEngine(document: doc)
        XCTAssertNil(engine.index(at: 10))
    }

    func testBinarySearchMatchesLinearScanOnRandomData() {
        var generator = SystemRandomNumberGenerator()
        let times = (0..<200).map { _ in Double.random(in: 0...300, using: &generator) }.sorted()
        let engine = LyricSyncEngine(lines: lines(times), offset: 0.7)
        for _ in 0..<500 {
            let position = Double.random(in: -5...310, using: &generator)
            let expected = times.lastIndex { $0 <= position + 0.7 }
            XCTAssertEqual(engine.index(at: position), expected)
        }
    }
}

final class PlaybackClockTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    func testAdvancesWhilePlaying() {
        let clock = PlaybackClock(anchorPosition: 10, anchorDate: t0, rate: 1)
        XCTAssertEqual(clock.position(at: t0.addingTimeInterval(2.5)), 12.5, accuracy: 0.0001)
        XCTAssertTrue(clock.isPlaying)
    }

    func testFrozenWhilePaused() {
        let clock = PlaybackClock(anchorPosition: 10, anchorDate: t0, rate: 0)
        XCTAssertEqual(clock.position(at: t0.addingTimeInterval(30)), 10, accuracy: 0.0001)
        XCTAssertFalse(clock.isPlaying)
    }

    func testClampsToDurationAndZero() {
        let clock = PlaybackClock(anchorPosition: 90, anchorDate: t0, rate: 1, duration: 100)
        XCTAssertEqual(clock.position(at: t0.addingTimeInterval(50)), 100, accuracy: 0.0001)
        XCTAssertEqual(clock.position(at: t0.addingTimeInterval(-50)), 90, accuracy: 0.0001)
    }

    func testPauseResumeAndSeek() {
        let playing = PlaybackClock(anchorPosition: 0, anchorDate: t0, rate: 1)
        let paused = playing.paused(at: t0.addingTimeInterval(5))
        XCTAssertEqual(paused.position(at: t0.addingTimeInterval(60)), 5, accuracy: 0.0001)
        let resumed = paused.resumed(at: t0.addingTimeInterval(60))
        XCTAssertEqual(resumed.position(at: t0.addingTimeInterval(62)), 7, accuracy: 0.0001)
        let sought = resumed.seeking(to: 40, at: t0.addingTimeInterval(62))
        XCTAssertEqual(sought.position(at: t0.addingTimeInterval(63)), 41, accuracy: 0.0001)
    }

    func testDateForPosition() {
        let clock = PlaybackClock(anchorPosition: 10, anchorDate: t0, rate: 1)
        XCTAssertEqual(clock.date(forPosition: 15), t0.addingTimeInterval(5))
        XCTAssertNil(PlaybackClock(anchorPosition: 10, anchorDate: t0, rate: 0).date(forPosition: 15))
    }

    func testEquivalence() {
        let a = PlaybackClock(anchorPosition: 10, anchorDate: t0, rate: 1)
        let b = PlaybackClock(anchorPosition: 10.2, anchorDate: t0, rate: 1)
        let c = PlaybackClock(anchorPosition: 12, anchorDate: t0, rate: 1)
        XCTAssertTrue(a.isEquivalent(to: b, at: t0))
        XCTAssertFalse(a.isEquivalent(to: c, at: t0))
        XCTAssertFalse(a.isEquivalent(to: a.paused(at: t0), at: t0))
    }
}
