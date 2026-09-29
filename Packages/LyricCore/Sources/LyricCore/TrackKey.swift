import Foundation

/// Normalisation helpers so "Song (Remastered 2011)" and "SONG" hit the same cache entry and the same
/// LRCLIB record.
public enum TrackKey {
    private static let noiseKeywords =
        "feat|ft\\.?|featuring|with|remaster(?:ed)?|version|edit|mix|deluxe|mono|stereo|bonus|explicit|clean|from"

    private static let bracketNoise = try! NSRegularExpression(
        pattern: "\\s*[\\(\\[][^\\)\\]]*\\b(?:\(noiseKeywords))\\b[^\\)\\]]*[\\)\\]]",
        options: [.caseInsensitive]
    )

    private static let dashSuffixNoise = try! NSRegularExpression(
        pattern: "\\s+[-–—]\\s+[^-–—]*\\b(?:remaster(?:ed)?|version|edit|mix|mono|stereo|deluxe|bonus)\\b.*$",
        options: [.caseInsensitive]
    )

    private static let featSuffix = try! NSRegularExpression(
        pattern: "\\s+(?:feat\\.?|ft\\.?|featuring)\\s+.*$",
        options: [.caseInsensitive]
    )

    /// Human readable clean title (case preserved). Removes "(feat. X)", "[Remastered]" and
    /// " - Remastered 2011" style noise.
    public static func cleanTitle(_ title: String) -> String {
        var result = title
        result = replace(bracketNoise, in: result)
        result = replace(dashSuffixNoise, in: result)
        result = replace(featSuffix, in: result)
        return collapse(result)
    }

    /// Primary artist only: "A & B", "A, B", "A feat. B" all become "A".
    public static func cleanArtist(_ artist: String) -> String {
        var result = replace(featSuffix, in: artist)
        for separator in [" & ", ", ", " x ", " × ", " and ", " ; ", "; "] {
            if let range = result.range(of: separator, options: .caseInsensitive) {
                result = String(result[result.startIndex..<range.lowerBound])
            }
        }
        return collapse(result)
    }

    public static func normalize(_ string: String) -> String {
        let folded = string.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
        let scalars = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return collapse(String(scalars))
    }

    public static func make(title: String, artist: String) -> String {
        "\(normalize(cleanArtist(artist)))|\(normalize(cleanTitle(title)))"
    }

    private static func replace(_ regex: NSRegularExpression, in string: String) -> String {
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(in: string, options: [], range: range, withTemplate: "")
    }

    private static func collapse(_ string: String) -> String {
        string
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
