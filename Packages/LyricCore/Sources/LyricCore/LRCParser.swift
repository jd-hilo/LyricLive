import Foundation

/// Parser for the LRC time-synced lyric format, including the common extensions:
/// - several timestamps on one line (`[00:12.00][01:05.50]Chorus`)
/// - `mm:ss`, `mm:ss.x`, `mm:ss.xx`, `mm:ss.xxx` and `mm:ss:xx` stamps
/// - ID tags (`[ti:]`, `[ar:]`, `[al:]`, `[by:]`, `[length:]`, `[offset:]` ...)
/// - enhanced per-word tags (`<00:01.20>word`), which are stripped
public enum LRCParser {
    public struct Options: Sendable {
        /// Honour the `[offset:+/-ms]` tag. Per the LRC convention a positive offset makes lyrics appear sooner.
        public var applyOffsetTag: Bool
        /// Keep empty timestamped lines as instrumental gaps.
        public var keepGaps: Bool

        public init(applyOffsetTag: Bool = true, keepGaps: Bool = true) {
            self.applyOffsetTag = applyOffsetTag
            self.keepGaps = keepGaps
        }
    }

    private static let metadataKeys: Set<String> = [
        "ti", "ar", "al", "au", "by", "re", "tool", "ve", "length", "offset", "la", "lang", "id", "hash",
    ]

    /// Parses `text` as LRC. If no timestamps are found the input is treated as plain lyrics.
    public static func parse(
        _ text: String,
        origin: LyricsOrigin = .lrclibSynced,
        options: Options = Options()
    ) -> LyricsDocument {
        var entries: [(time: TimeInterval, order: Int, text: String)] = []
        var metadata: [String: String] = [:]
        var order = 0

        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        for rawLine in normalized.split(separator: "\n", omittingEmptySubsequences: true) {
            let parsed = parseLine(rawLine)
            for (key, value) in parsed.metadata where metadata[key] == nil {
                metadata[key] = value
            }
            guard !parsed.times.isEmpty else { continue }
            if parsed.text.isEmpty && !options.keepGaps { continue }
            for time in parsed.times {
                entries.append((time, order, parsed.text))
                order += 1
            }
        }

        guard !entries.isEmpty else {
            return parsePlain(text, origin: origin == .lrclibSynced ? .lrclibPlain : origin, metadata: metadata)
        }

        var offset: TimeInterval = 0
        if options.applyOffsetTag, let raw = metadata["offset"], let ms = Double(raw.trimmingCharacters(in: .whitespaces)) {
            offset = ms / 1000
        }

        entries.sort { lhs, rhs in
            lhs.time == rhs.time ? lhs.order < rhs.order : lhs.time < rhs.time
        }

        var lines: [LyricLine] = []
        lines.reserveCapacity(entries.count)
        for entry in entries {
            let shifted = max(0, entry.time - offset)
            // Two consecutive gaps add nothing.
            if entry.text.isEmpty, let last = lines.last, last.isGap { continue }
            lines.append(LyricLine(id: lines.count, time: shifted, text: entry.text))
        }

        return LyricsDocument(lines: lines, isSynced: true, origin: origin, metadata: metadata)
    }

    /// Plain (unsynced) lyrics. Blank lines become stanza gaps, but never lead, trail or repeat.
    public static func parsePlain(
        _ text: String,
        origin: LyricsOrigin = .lrclibPlain,
        metadata: [String: String] = [:]
    ) -> LyricsDocument {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var lines: [LyricLine] = []
        for raw in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if let last = lines.last, !last.isGap {
                    lines.append(LyricLine(id: lines.count, time: 0, text: ""))
                }
            } else if !isMetadataOnly(trimmed) {
                lines.append(LyricLine(id: lines.count, time: 0, text: trimmed))
            }
        }
        while let last = lines.last, last.isGap { lines.removeLast() }
        return LyricsDocument(lines: lines, isSynced: false, origin: origin, metadata: metadata)
    }

    // MARK: - Line parsing

    struct ParsedLine {
        var times: [TimeInterval] = []
        var metadata: [(String, String)] = []
        var text: String = ""
    }

    static func parseLine(_ raw: Substring) -> ParsedLine {
        var result = ParsedLine()
        var rest = Substring(raw.trimmingCharacters(in: .whitespaces))

        while rest.first == "[", let close = rest.firstIndex(of: "]") {
            let inner = rest[rest.index(after: rest.startIndex)..<close]
            if let time = parseTimestamp(inner) {
                result.times.append(time)
            } else if let colon = inner.firstIndex(of: ":") {
                let key = inner[inner.startIndex..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                guard metadataKeys.contains(key) else { break }
                let value = inner[inner.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                result.metadata.append((key, value))
            } else {
                break
            }
            rest = rest[rest.index(after: close)...]
        }

        result.text = stripWordTags(String(rest)).trimmingCharacters(in: .whitespaces)
        return result
    }

    /// Accepts `mm:ss`, `mm:ss.f{1,3}` and `mm:ss:f{1,3}`.
    static func parseTimestamp<S: StringProtocol>(_ inner: S) -> TimeInterval? {
        let parts = inner.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3 else { return nil }
        guard let minutes = digits(parts[0]).flatMap({ Double($0) }) else { return nil }

        var seconds: Double
        var fraction: Double = 0

        if parts.count == 3 {
            guard let whole = digits(parts[1]).flatMap({ Double($0) }),
                  let fractionDigits = digits(parts[2]) else { return nil }
            seconds = whole
            fraction = Double("0.\(fractionDigits)") ?? 0
        } else {
            let secondsPart = parts[1]
            if let dot = secondsPart.firstIndex(of: ".") {
                guard let whole = digits(secondsPart[secondsPart.startIndex..<dot]).flatMap({ Double($0) }),
                      let fractionDigits = digits(secondsPart[secondsPart.index(after: dot)...]) else { return nil }
                seconds = whole
                fraction = Double("0.\(fractionDigits)") ?? 0
            } else {
                guard let whole = digits(secondsPart).flatMap({ Double($0) }) else { return nil }
                seconds = whole
            }
        }
        return minutes * 60 + seconds + fraction
    }

    private static func digits<S: StringProtocol>(_ s: S) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return trimmed
    }

    /// Removes enhanced-LRC `<mm:ss.xx>` word tags.
    static func stripWordTags(_ text: String) -> String {
        guard text.contains("<") else { return text }
        var output = ""
        var index = text.startIndex
        var removedAny = false
        while index < text.endIndex {
            let char = text[index]
            if char == "<", let close = text[index...].firstIndex(of: ">"),
               parseTimestamp(text[text.index(after: index)..<close]) != nil {
                index = text.index(after: close)
                removedAny = true
                continue
            }
            output.append(char)
            index = text.index(after: index)
        }
        guard removedAny else { return text }
        return output.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }

    private static func isMetadataOnly(_ line: String) -> Bool {
        guard line.hasPrefix("["), line.hasSuffix("]"), let colon = line.firstIndex(of: ":") else { return false }
        let key = line[line.index(after: line.startIndex)..<colon].lowercased()
        return metadataKeys.contains(key)
    }
}
