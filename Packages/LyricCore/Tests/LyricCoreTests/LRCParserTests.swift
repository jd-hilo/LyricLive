import XCTest
@testable import LyricCore

final class LRCParserTests: XCTestCase {
    func testParsesBasicSyncedLines() {
        let doc = LRCParser.parse("""
        [00:12.00]Hello
        [00:15.50]World
        """)
        XCTAssertTrue(doc.isSynced)
        XCTAssertEqual(doc.lines.map(\.text), ["Hello", "World"])
        XCTAssertEqual(doc.lines[0].time, 12.0, accuracy: 0.0001)
        XCTAssertEqual(doc.lines[1].time, 15.5, accuracy: 0.0001)
        XCTAssertEqual(doc.lines.map(\.id), [0, 1])
    }

    func testTimestampVariants() {
        XCTAssertEqual(LRCParser.parseTimestamp("01:02")!, 62, accuracy: 0.0001)
        XCTAssertEqual(LRCParser.parseTimestamp("01:02.5")!, 62.5, accuracy: 0.0001)
        XCTAssertEqual(LRCParser.parseTimestamp("01:02.50")!, 62.5, accuracy: 0.0001)
        XCTAssertEqual(LRCParser.parseTimestamp("01:02.567")!, 62.567, accuracy: 0.0001)
        XCTAssertEqual(LRCParser.parseTimestamp("01:02:25")!, 62.25, accuracy: 0.0001)
        XCTAssertEqual(LRCParser.parseTimestamp("120:00.00")!, 7200, accuracy: 0.0001)
        XCTAssertNil(LRCParser.parseTimestamp("ar:Someone"))
        XCTAssertNil(LRCParser.parseTimestamp("aa:bb"))
        XCTAssertNil(LRCParser.parseTimestamp("12"))
    }

    func testMultipleTimestampsPerLineAreExpandedAndSorted() {
        let doc = LRCParser.parse("""
        [00:30.00][01:10.00]Chorus
        [00:10.00]Verse
        """)
        XCTAssertEqual(doc.lines.map(\.text), ["Verse", "Chorus", "Chorus"])
        XCTAssertEqual(doc.lines.map(\.time), [10, 30, 70])
    }

    func testMetadataIsCollectedNotEmittedAsLines() {
        let doc = LRCParser.parse("""
        [ti:My Song]
        [ar:Some Artist]
        [al:Album]
        [by:someone]
        [00:01.00]First
        """)
        XCTAssertEqual(doc.metadata["ti"], "My Song")
        XCTAssertEqual(doc.metadata["ar"], "Some Artist")
        XCTAssertEqual(doc.metadata["al"], "Album")
        XCTAssertEqual(doc.lines.count, 1)
    }

    func testOffsetTagMakesLyricsAppearEarlier() {
        let doc = LRCParser.parse("""
        [offset:500]
        [00:10.00]Line
        """)
        XCTAssertEqual(doc.lines[0].time, 9.5, accuracy: 0.0001)

        let negative = LRCParser.parse("[offset:-250]\n[00:10.00]Line")
        XCTAssertEqual(negative.lines[0].time, 10.25, accuracy: 0.0001)

        let ignored = LRCParser.parse("[offset:500]\n[00:10.00]Line", options: .init(applyOffsetTag: false))
        XCTAssertEqual(ignored.lines[0].time, 10, accuracy: 0.0001)
    }

    func testOffsetNeverProducesNegativeTimes() {
        let doc = LRCParser.parse("[offset:5000]\n[00:01.00]Line")
        XCTAssertEqual(doc.lines[0].time, 0, accuracy: 0.0001)
    }

    func testEmptyTimestampedLinesBecomeSingleGaps() {
        let doc = LRCParser.parse("""
        [00:00.00]
        [00:05.00]Sing
        [00:09.00]
        [00:10.00]
        [00:15.00]Again
        """)
        XCTAssertEqual(doc.lines.map(\.text), ["", "Sing", "", "Again"])
        XCTAssertTrue(doc.lines[0].isGap)
    }

    func testGapsCanBeDropped() {
        let doc = LRCParser.parse("[00:00.00]\n[00:05.00]Sing", options: .init(keepGaps: false))
        XCTAssertEqual(doc.lines.map(\.text), ["Sing"])
    }

    func testEnhancedWordTagsAreStripped() {
        let doc = LRCParser.parse("[00:01.00]<00:01.00>Hello <00:01.50>big <00:02.00>world")
        XCTAssertEqual(doc.lines[0].text, "Hello big world")
    }

    func testAngleBracketsInLyricsAreKept() {
        let doc = LRCParser.parse("[00:01.00]I <3 you")
        XCTAssertEqual(doc.lines[0].text, "I <3 you")
    }

    func testBracketedSectionLabelsRemainText() {
        let doc = LRCParser.parse("[00:01.00][Chorus] la la")
        XCTAssertEqual(doc.lines[0].text, "[Chorus] la la")
        let label = LRCParser.parse("[00:01.00]x\n[Chorus]\n[00:05.00]y")
        XCTAssertEqual(label.lines.map(\.text), ["x", "y"])
    }

    func testHandlesWindowsLineEndingsAndWhitespace() {
        let doc = LRCParser.parse("[00:01.00]  spaced  \r\n[00:02.00]next\r\n")
        XCTAssertEqual(doc.lines.map(\.text), ["spaced", "next"])
    }

    func testStableOrderForEqualTimestamps() {
        let doc = LRCParser.parse("[00:05.00]a\n[00:05.00]b\n[00:05.00]c")
        XCTAssertEqual(doc.lines.map(\.text), ["a", "b", "c"])
    }

    func testUnicodeLyrics() {
        let doc = LRCParser.parse("[00:01.00]今夜的滋味\n[00:03.20]たまには違うものも")
        XCTAssertEqual(doc.lines.map(\.text), ["今夜的滋味", "たまには違うものも"])
    }

    func testRealLRCLibFormatWithSpaceAfterTimestamp() {
        let doc = LRCParser.parse("""
        [00:00.72] (Yeah, yeah, yeah, yeah)
        [00:05.77] Fever dream high in the quiet of the night
        [00:08.11] You know that I caught it (oh yeah, you're right, I want it)
        """)
        XCTAssertEqual(doc.lines.count, 3)
        XCTAssertEqual(doc.lines[0].text, "(Yeah, yeah, yeah, yeah)")
        XCTAssertEqual(doc.lines[2].time, 8.11, accuracy: 0.0001)
    }

    func testInputWithoutTimestampsFallsBackToPlain() {
        let doc = LRCParser.parse("Line one\nLine two\n\nLine three")
        XCTAssertFalse(doc.isSynced)
        XCTAssertEqual(doc.origin, .lrclibPlain)
        XCTAssertEqual(doc.lines.map(\.text), ["Line one", "Line two", "", "Line three"])
    }

    func testPlainLyricsTrimGapsAndMetadataLines() {
        let doc = LRCParser.parsePlain("\n\n[ar:Someone]\nOne\n\n\n\nTwo\n\n")
        XCTAssertEqual(doc.lines.map(\.text), ["One", "", "Two"])
    }

    func testEmptyInput() {
        XCTAssertTrue(LRCParser.parse("").isEmpty)
        XCTAssertTrue(LRCParser.parse("   \n  ").isEmpty)
    }

    func testDemoContentParsesAndHasTranslations() {
        let doc = DemoContent.document
        XCTAssertTrue(doc.isSynced)
        XCTAssertGreaterThan(doc.lines.count, 15)
        let translations = DemoContent.translationsZhHant
        XCTAssertEqual(translations.count, doc.lines.count)
        for (line, translation) in zip(doc.lines, translations) where !line.isGap {
            XCTAssertFalse(translation.isEmpty, "Missing translation for \(line.text)")
        }
        XCTAssertLessThan(doc.lines.last!.time, DemoContent.track.duration!)
    }
}
