import Foundation

/// Build-time configuration surfaced through Info.plist keys defined in `project.yml`.
enum AppConfig {
    private static func info(_ key: String) -> String? {
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String
        return (value?.isEmpty ?? true) ? nil : value
    }

    static var displayName: String {
        info("CFBundleDisplayName") ?? "LyricLive"
    }

    static var version: String {
        let short = info("CFBundleShortVersionString") ?? "1.0"
        let build = info("CFBundleVersion") ?? "1"
        return "\(short) (\(build))"
    }

    // MARK: StoreKit

    /// Placeholder product identifiers. Create matching products in App Store Connect
    /// (or edit `App/Resources/LyricLive.storekit` for local testing).
    static var productIDPrefix: String {
        info("LLProductPrefix") ?? "com.example.lyriclive.pro"
    }

    static var monthlyProductID: String { productIDPrefix + ".monthly" }
    static var yearlyProductID: String { productIDPrefix + ".yearly" }
    static var lifetimeProductID: String { productIDPrefix + ".lifetime" }

    static var allProductIDs: [String] {
        [yearlyProductID, monthlyProductID, lifetimeProductID]
    }

    // MARK: Spotify

    /// Set `SPOTIFY_CLIENT_ID` in `project.yml`. Register the redirect URI below in the Spotify dashboard.
    static var spotifyClientID: String {
        info("LLSpotifyClientID") ?? ""
    }

    static var isSpotifyConfigured: Bool {
        let id = spotifyClientID
        return !id.isEmpty && !id.hasPrefix("YOUR_")
    }

    static var urlScheme: String {
        info("LLURLScheme") ?? "lyriclive"
    }

    static var spotifyRedirectURL: URL {
        URL(string: "\(urlScheme)://spotify-login-callback")!
    }

    // MARK: Links

    static let privacyURL = URL(string: "https://example.com/lyriclive/privacy")!
    static let termsURL = URL(string: "https://example.com/lyriclive/terms")!
    static let supportEmail = "support@example.com"
}
