import XCTest
@testable import LyricCore

final class TrackKeyTests: XCTestCase {
    func testCleanTitleRemovesNoise() {
        XCTAssertEqual(TrackKey.cleanTitle("Song (feat. Someone)"), "Song")
        XCTAssertEqual(TrackKey.cleanTitle("Song [Remastered 2011]"), "Song")
        XCTAssertEqual(TrackKey.cleanTitle("Song - Remastered 2011"), "Song")
        XCTAssertEqual(TrackKey.cleanTitle("Song - Radio Edit"), "Song")
        XCTAssertEqual(TrackKey.cleanTitle("Song (Deluxe Version)"), "Song")
        XCTAssertEqual(TrackKey.cleanTitle("Song ft. Someone"), "Song")
        XCTAssertEqual(TrackKey.cleanTitle("Song (Part 2)"), "Song (Part 2)", "meaningful brackets survive")
        XCTAssertEqual(TrackKey.cleanTitle("  Spaced   Out  "), "Spaced Out")
    }

    func testCleanArtistKeepsPrimaryArtist() {
        XCTAssertEqual(TrackKey.cleanArtist("A & B"), "A")
        XCTAssertEqual(TrackKey.cleanArtist("A, B"), "A")
        XCTAssertEqual(TrackKey.cleanArtist("A feat. B"), "A")
        XCTAssertEqual(TrackKey.cleanArtist("Solo"), "Solo")
    }

    func testKeyIsCaseAccentAndNoiseInsensitive() {
        let a = TrackKey.make(title: "Café del Mar (Remastered)", artist: "DJ Ünal & Friends")
        let b = TrackKey.make(title: "cafe del mar", artist: "dj unal")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, TrackKey.make(title: "Other", artist: "dj unal"))
    }

    func testKeyHandlesCJK() {
        XCTAssertEqual(TrackKey.make(title: "今夜的滋味", artist: "朴树"), TrackKey.make(title: "今夜的滋味 ", artist: "朴树"))
        XCTAssertFalse(TrackKey.make(title: "今夜的滋味", artist: "朴树").hasPrefix("|"))
    }

    func testTrackInfoKeyIgnoresSourceAndDuration() {
        let a = TrackInfo(title: "X", artist: "Y", duration: 10, source: .appleMusic)
        let b = TrackInfo(title: "X", artist: "Y", duration: 99, source: .spotify)
        XCTAssertEqual(a.key, b.key)
    }
}

final class FileLyricsCacheTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("lyriccore-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func testRoundTripAndPersistenceAcrossInstances() {
        let doc = LRCParser.parse("[00:01.00]Hello\n[00:02.00]世界")
        FileLyricsCache(directory: directory).store(doc, forKey: "a|b")
        let reloaded = FileLyricsCache(directory: directory).document(forKey: "a|b")
        XCTAssertEqual(reloaded?.lines, doc.lines)
        XCTAssertNil(FileLyricsCache(directory: directory).document(forKey: "other"))
    }

    func testTranslationsAreKeyedByLanguage() {
        let cache = FileLyricsCache(directory: directory)
        cache.storeTranslations(["你好"], forKey: "k", language: "zh-Hant")
        cache.storeTranslations(["こんにちは"], forKey: "k", language: "ja")
        XCTAssertEqual(cache.translations(forKey: "k", language: "zh-Hant"), ["你好"])
        XCTAssertEqual(cache.translations(forKey: "k", language: "ja"), ["こんにちは"])
        XCTAssertNil(cache.translations(forKey: "k", language: "ko"))
    }

    func testRemoveDeletesLyricsAndTranslationsForKeyOnly() {
        let cache = FileLyricsCache(directory: directory)
        cache.store(LRCParser.parse("[00:01.00]a"), forKey: "k1")
        cache.store(LRCParser.parse("[00:01.00]b"), forKey: "k2")
        cache.storeTranslations(["x"], forKey: "k1", language: "ja")
        cache.remove(forKey: "k1")
        XCTAssertNil(cache.document(forKey: "k1"))
        XCTAssertNil(cache.translations(forKey: "k1", language: "ja"))
        XCTAssertNotNil(cache.document(forKey: "k2"))
    }

    func testRemoveAllAndSize() {
        let cache = FileLyricsCache(directory: directory)
        cache.store(LRCParser.parse("[00:01.00]a"), forKey: "k1")
        XCTAssertGreaterThan(cache.sizeOnDisk(), 0)
        cache.removeAll()
        XCTAssertEqual(cache.sizeOnDisk(), 0)
    }

    func testCorruptFileIsTreatedAsMiss() throws {
        let cache = FileLyricsCache(directory: directory)
        cache.store(LRCParser.parse("[00:01.00]a"), forKey: "k")
        let file = try XCTUnwrap(FileManager.default.contentsOfDirectory(atPath: directory.path).first)
        try Data("garbage".utf8).write(to: directory.appendingPathComponent(file))
        XCTAssertNil(cache.document(forKey: "k"))
    }
}

final class TranslationLanguagesTests: XCTestCase {
    func testChineseVariants() {
        XCTAssertEqual(TranslationLanguages.match(identifier: "zh-Hant-TW"), "zh-Hant")
        XCTAssertEqual(TranslationLanguages.match(identifier: "zh_TW"), "zh-Hant")
        XCTAssertEqual(TranslationLanguages.match(identifier: "zh-HK"), "zh-Hant")
        XCTAssertEqual(TranslationLanguages.match(identifier: "zh-Hant"), "zh-Hant")
        XCTAssertEqual(TranslationLanguages.match(identifier: "zh-Hans-CN"), "zh-Hans")
        XCTAssertEqual(TranslationLanguages.match(identifier: "zh-CN"), "zh-Hans")
    }

    func testOtherLanguages() {
        XCTAssertEqual(TranslationLanguages.match(identifier: "en-US"), "en")
        XCTAssertEqual(TranslationLanguages.match(identifier: "pt-PT"), "pt-BR")
        XCTAssertEqual(TranslationLanguages.match(identifier: "ja-JP"), "ja")
        XCTAssertNil(TranslationLanguages.match(identifier: "xx-YY"))
    }

    func testDefaultTargetUsesFirstSupportedPreferredLanguage() {
        XCTAssertEqual(TranslationLanguages.defaultTarget(preferred: ["zh-Hant-TW", "en-US"]), "zh-Hant")
        XCTAssertEqual(TranslationLanguages.defaultTarget(preferred: ["xx", "fr-FR"]), "fr")
        XCTAssertEqual(TranslationLanguages.defaultTarget(for: Locale(identifier: "xx"), preferred: ["xx"]), "en")
    }

    func testTraditionalChineseIsListedFirst() {
        XCTAssertEqual(TranslationLanguages.all.first?.code, "zh-Hant")
        XCTAssertEqual(Set(TranslationLanguages.all.map(\.code)).count, TranslationLanguages.all.count)
    }

    func testSameLanguage() {
        XCTAssertTrue(TranslationLanguages.isSameLanguage("en-GB", "en"))
        XCTAssertTrue(TranslationLanguages.isSameLanguage("zh-TW", "zh-Hant"))
        XCTAssertFalse(TranslationLanguages.isSameLanguage("zh-Hant", "zh-Hans"))
        XCTAssertFalse(TranslationLanguages.isSameLanguage("ja", "ko"))
    }
}

final class PaletteExtractorTests: XCTestCase {
    private func image(_ colors: [(r: UInt8, g: UInt8, b: UInt8)], width: Int = 40, height: Int = 40) -> [UInt8] {
        var bytes: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width {
                let c = colors[(x * colors.count / width + (y * 0)) % colors.count]
                bytes += [c.r, c.g, c.b, 255]
            }
        }
        return bytes
    }

    func testFindsDominantDistinctColours() {
        let pixels = image([(230, 40, 40), (30, 60, 220), (240, 240, 240)])
        let palette = PaletteExtractor.extract(rgba: pixels, width: 40, height: 40, count: 2)
        XCTAssertEqual(palette.count, 2)
        let hues = palette.map { $0.hsb.hue }
        XCTAssertTrue(hues.contains { abs($0 - 0) < 0.05 || abs($0 - 1) < 0.05 }, "red present")
        XCTAssertTrue(hues.contains { abs($0 - 0.65) < 0.06 }, "blue present")
    }

    func testAlwaysReturnsRequestedCount() {
        let mono = image([(100, 100, 100)])
        XCTAssertEqual(PaletteExtractor.extract(rgba: mono, width: 40, height: 40, count: 4).count, 4)
    }

    func testInvalidInputFallsBack() {
        XCTAssertEqual(PaletteExtractor.extract(rgba: [], width: 0, height: 0), PaletteExtractor.fallback)
        XCTAssertEqual(PaletteExtractor.extract(rgba: [1, 2], width: 10, height: 10), PaletteExtractor.fallback)
    }

    func testTransparentPixelsAreIgnored() {
        let clear = [UInt8](repeating: 0, count: 10 * 10 * 4)
        XCTAssertEqual(PaletteExtractor.extract(rgba: clear, width: 10, height: 10), PaletteExtractor.fallback)
    }

    func testHexRoundTripAndHSB() {
        let color = RGBColor(hex: "#FF8000")!
        XCTAssertEqual(color.hex, "#FF8000")
        let back = RGBColor.fromHSB(hue: color.hsb.hue, saturation: color.hsb.saturation, brightness: color.hsb.brightness)
        XCTAssertEqual(back.hex, "#FF8000")
        XCTAssertNil(RGBColor(hex: "nope"))
        XCTAssertEqual(RGBColor(hex: "12B5CB")?.hex, "#12B5CB")
    }
}

final class ProPolicyTests: XCTestCase {
    func testFreeTierRestrictions() {
        XCTAssertFalse(ProPolicy.isAllowed(.liveActivity, isPro: false))
        XCTAssertFalse(ProPolicy.isAllowed(.carPlay, isPro: false))
        XCTAssertFalse(ProPolicy.isAllowed(.spotify, isPro: false))
        XCTAssertFalse(ProPolicy.isAllowed(.shazam, isPro: false))
        XCTAssertTrue(ProPolicy.isAllowed(.translation, isPro: false), "quota-limited, not blocked outright")
    }

    func testProUnlocksEverything() {
        for feature in ProFeature.allCases {
            XCTAssertTrue(ProPolicy.isAllowed(feature, isPro: true))
        }
    }

    func testDailyQuota() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day1 = Date(timeIntervalSince1970: 1_800_000_000)
        let day2 = day1.addingTimeInterval(86_400)

        var quota = DailyQuota()
        XCTAssertEqual(quota.remaining(limit: 3, on: day1, calendar: calendar), 3)
        XCTAssertTrue(quota.consume(limit: 3, on: day1, calendar: calendar))
        XCTAssertTrue(quota.consume(limit: 3, on: day1, calendar: calendar))
        XCTAssertTrue(quota.consume(limit: 3, on: day1, calendar: calendar))
        XCTAssertFalse(quota.consume(limit: 3, on: day1, calendar: calendar))
        XCTAssertEqual(quota.remaining(limit: 3, on: day1, calendar: calendar), 0)
        XCTAssertEqual(quota.remaining(limit: 3, on: day2, calendar: calendar), 3, "resets next day")
        XCTAssertTrue(quota.consume(limit: 3, on: day2, calendar: calendar))
        XCTAssertEqual(quota.used, 1)
    }
}

final class TimeFormatTests: XCTestCase {
    func testClock() {
        XCTAssertEqual(TimeFormat.clock(0), "0:00")
        XCTAssertEqual(TimeFormat.clock(11.9), "0:11")
        XCTAssertEqual(TimeFormat.clock(187), "3:07")
        XCTAssertEqual(TimeFormat.clock(3723), "1:02:03")
        XCTAssertEqual(TimeFormat.clock(-5), "0:00")
        XCTAssertEqual(TimeFormat.clock(.nan), "0:00")
    }

    func testRemaining() {
        XCTAssertEqual(TimeFormat.remaining(position: 11, duration: 179), "-2:48")
        XCTAssertEqual(TimeFormat.remaining(position: 200, duration: 179), "-0:00")
    }
}
