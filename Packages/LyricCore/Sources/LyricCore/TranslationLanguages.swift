import Foundation

public struct TranslationLanguage: Identifiable, Hashable, Codable, Sendable {
    /// BCP-47 identifier understood by `Locale.Language(identifier:)`, e.g. `zh-Hant`.
    public let code: String

    public var id: String { code }

    public init(code: String) {
        self.code = code
    }

    /// Name of the language written in `locale`. English UI shows "Spanish", "Korean", and so on.
    public func displayName(in locale: Locale = .current) -> String {
        locale.localizedString(forIdentifier: code) ?? code
    }

    /// Name of the language in its own language, e.g. "日本語".
    public var nativeName: String {
        Locale(identifier: code).localizedString(forIdentifier: code) ?? code
    }
}

public enum TranslationLanguages {
    /// Targets offered by Apple's on-device Translation framework (iOS 18).
    /// English is the default. The languages an English-speaking listener most often meets come next.
    /// Traditional Chinese is available, but it is not pinned to the top.
    public static let all: [TranslationLanguage] = [
        "en", "es", "ko", "ja", "fr", "pt-BR", "de", "it",
        "zh-Hans", "zh-Hant", "ru", "ar", "hi", "id", "th", "vi", "tr", "nl", "pl", "uk",
    ].map(TranslationLanguage.init(code:))

    public static let fallbackCode = "en"

    /// New installs translate foreign lyrics into English. `locale` and `preferred` are accepted so call sites
    /// can still pass the device language, and they do not change the default.
    public static func defaultTarget(for locale: Locale = .current, preferred: [String] = Locale.preferredLanguages) -> String {
        _ = locale
        _ = preferred
        return fallbackCode
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
