import Foundation

public struct TranslationLanguage: Identifiable, Hashable, Codable, Sendable {
    /// BCP-47 identifier understood by `Locale.Language(identifier:)`, e.g. `zh-Hant`.
    public let code: String

    public var id: String { code }

    public init(code: String) {
        self.code = code
    }

    /// Name of the language written in `locale`, e.g. "Chinese, Traditional" or "繁體中文".
    public func displayName(in locale: Locale = .current) -> String {
        locale.localizedString(forIdentifier: code) ?? code
    }

    /// Name of the language in its own language, e.g. "日本語".
    public var nativeName: String {
        Locale(identifier: code).localizedString(forIdentifier: code) ?? code
    }
}

public enum TranslationLanguages {
    /// Languages offered by Apple's on-device Translation framework (iOS 18). Traditional Chinese first.
    public static let all: [TranslationLanguage] = [
        "zh-Hant", "zh-Hans", "en", "ja", "ko", "es", "fr", "de", "it", "pt-BR", "ru", "ar", "hi",
        "id", "th", "vi", "tr", "nl", "pl", "uk",
    ].map(TranslationLanguage.init(code:))

    public static let fallbackCode = "en"

    /// Picks the translation target matching the device language. Traditional Chinese covers zh-Hant,
    /// zh-TW, zh-HK and zh-MO.
    public static func defaultTarget(for locale: Locale = .current, preferred: [String] = Locale.preferredLanguages) -> String {
        let identifiers = preferred.isEmpty ? [locale.identifier] : preferred
        for identifier in identifiers {
            if let match = match(identifier: identifier) { return match }
        }
        return match(identifier: locale.identifier) ?? fallbackCode
    }

    public static func match(identifier: String) -> String? {
        let parts = identifier.replacingOccurrences(of: "_", with: "-").split(separator: "-").map(String.init)
        guard let language = parts.first?.lowercased() else { return nil }

        if language == "zh" {
            let lowered = parts.map { $0.lowercased() }
            if lowered.contains("hant") || lowered.contains("tw") || lowered.contains("hk") || lowered.contains("mo") {
                return "zh-Hant"
            }
            return "zh-Hans"
        }
        if language == "pt" { return "pt-BR" }
        return all.first { $0.code.lowercased() == language }?.code
    }

    /// True when two identifiers name the same language, treating Chinese scripts as different languages.
    public static func isSameLanguage(_ lhs: String, _ rhs: String) -> Bool {
        guard let a = match(identifier: lhs) ?? primary(lhs), let b = match(identifier: rhs) ?? primary(rhs) else { return false }
        return a == b
    }

    private static func primary(_ identifier: String) -> String? {
        identifier.replacingOccurrences(of: "_", with: "-").split(separator: "-").first.map { String($0).lowercased() }
    }
}
