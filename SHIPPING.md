# Shipping LyricLive

Everything that can be done in the repo is done. These are the steps that need J.D.'s logins, in order.

## Values

| What | Value |
|---|---|
| Team ID | `N8SACG5845` (Hilo LLC; taken from `DEVELOPMENT_TEAM` in jd-hilo/PetWidget's `Petmoji.xcodeproj`) |
| App bundle ID | `com.hilollc.lyriclive` |
| Widget extension bundle ID | `com.hilollc.lyriclive.widgets` |
| App Group | `group.com.hilollc.lyriclive` |
| URL scheme | `lyriclive` |
| Monthly subscription | `com.hilollc.lyriclive.pro.monthly`, 1 month, US$2.99 |
| Yearly subscription | `com.hilollc.lyriclive.pro.yearly`, 1 year, US$6.99 |
| Lifetime (non-consumable) | `com.hilollc.lyriclive.pro.lifetime`, US$9.99 |
| Subscription group | `LyricLive Pro` |
| Spotify redirect URI | `lyriclive://spotify-login-callback` |
| Support URL | https://jd-hilo.github.io/LyricLive/ |
| Privacy policy URL | https://jd-hilo.github.io/LyricLive/privacy.html |
| Terms of use URL | https://jd-hilo.github.io/LyricLive/terms.html |
| Support email | jd@hilo.media |

All of these are set in one place: the “Configure here” block in `project.yml` (plus the matching IDs in `App/Resources/LyricLive.storekit` and the URLs in `App/Config/AppConfig.swift`).

## 1. Apple Developer (developer.apple.com → Certificates, Identifiers & Profiles)

1. Membership details: confirm the Team ID is `N8SACG5845`. If it differs, change `DEVELOPMENT_TEAM` in `project.yml`.
2. Identifiers → + → App Groups → Description `LyricLive`, Identifier `group.com.hilollc.lyriclive`.
3. Identifiers → + → App IDs → App → Description `LyricLive`, Bundle ID (Explicit) `com.hilollc.lyriclive`.
   - Capabilities: App Groups (Configure → `group.com.hilollc.lyriclive`), In-App Purchase (on by default).
   - App Services tab: MusicKit, ShazamKit.
4. Identifiers → + → App IDs → App → Description `LyricLive Widgets`, Bundle ID (Explicit) `com.hilollc.lyriclive.widgets`.
   - Capabilities: App Groups (Configure → `group.com.hilollc.lyriclive`).
5. CarPlay (optional, can wait until after 1.0): request the CarPlay Audio entitlement at https://developer.apple.com/contact/carplay/ for `com.hilollc.lyriclive`. Apple grants CarPlay Audio to apps that play audio, and LyricLive controls other apps rather than playing audio itself, so approval is not guaranteed. Once granted, set the app target's `CODE_SIGN_ENTITLEMENTS` to `Config/App-CarPlay.entitlements` in `project.yml` and use a provisioning profile that includes the CarPlay entitlement.
6. On the Mac: Xcode → Settings → Accounts → sign in with the Apple ID on team `N8SACG5845`. Then `brew install xcodegen && xcodegen generate && open LyricLive.xcodeproj`. Signing is Automatic.

## 2. App Store Connect (appstoreconnect.apple.com)

1. Business → Agreements: the Paid Apps agreement, tax, and banking must be Active (they may already be, from Petmoji).
2. Apps → + → New App: Platform iOS, Name `LyricLive` (if that name is taken, try `LyricLive: Synced Lyrics`), Primary Language English (U.S.), Bundle ID `com.hilollc.lyriclive`, SKU `lyriclive-ios`, User Access Full.
3. Monetization → Subscriptions → create group `LyricLive Pro` (group display name `LyricLive Pro`), then add:
   - Reference name `Yearly`, Product ID `com.hilollc.lyriclive.pro.yearly`, Duration 1 year, Price US$6.99. Display name `LyricLive Pro Yearly`, description `Unlock every feature. Renews yearly.`
   - Reference name `Monthly`, Product ID `com.hilollc.lyriclive.pro.monthly`, Duration 1 month, Price US$2.99. Display name `LyricLive Pro Monthly`, description `Unlock every feature. Renews monthly.`
   - Each needs a review screenshot of the paywall.
4. Monetization → In-App Purchases → + → Non-Consumable: Reference name `Lifetime`, Product ID `com.hilollc.lyriclive.pro.lifetime`, Price US$9.99, Display name `LyricLive Lifetime`, description `Unlock every feature with one payment.` Add a paywall screenshot.
5. App Information: Category Music (secondary Entertainment). Privacy Policy URL `https://jd-hilo.github.io/LyricLive/privacy.html`. Content Rights: the app shows third-party content (lyrics from LRCLIB); answer truthfully.
6. App Privacy: Privacy Policy URL as above. Data collection: “No, we do not collect data from this app.” (The app has no accounts, analytics or servers; see `docs/privacy.html` and the privacy manifests.)
7. Age rating questionnaire: lyrics can contain profanity, so answer the profanity question accordingly.
8. Version 1.0 page: Support URL `https://jd-hilo.github.io/LyricLive/`, Copyright `2026 Hilo LLC`. Put the terms link in the description (`Terms of Use: https://jd-hilo.github.io/LyricLive/terms.html`), which with the Standard EULA satisfies the subscription-terms requirement. Add the three in-app purchases to the version under “In-App Purchases and Subscriptions”.
9. Encryption: `ITSAppUsesNonExemptEncryption` is already `false` in Info.plist; no export documents needed.
10. Users and Access → Sandbox → add a sandbox tester to test purchases on device.
11. Review notes: “Home → Play demo song drives every lyrics surface without a music account. Apple Music detection needs media library permission. Spotify is not enabled in this version. CarPlay is not enabled in this version.”

## 3. Spotify for Developers (developer.spotify.com/dashboard) — optional

Since February 2026, new Spotify apps start in Development Mode: the owner must have Spotify Premium, and only 5 allowlisted Spotify users can connect. The App Remote SDK is covered by this limit. Extended Quota Mode is only open to established organizations. Until Spotify grants extended access, keep `SPOTIFY_CLIENT_ID` unset for the public release. The app then shows “Spotify isn't available in this version yet.” Also consider removing Spotify from the paywall and onboarding copy for 1.0.

To set it up for testing:

1. Create app: Name `LyricLive`, Description `Time-synced lyrics for the song you are playing.`, Website `https://jd-hilo.github.io/LyricLive/`, Redirect URI `lyriclive://spotify-login-callback`, APIs used: iOS SDK. Accept the terms.
2. Settings → iOS: Bundle ID `com.hilollc.lyriclive`.
3. User Management: add up to 5 tester Spotify accounts.
4. Copy the Client ID into `SPOTIFY_CLIENT_ID` in `project.yml` (it is not a secret) and run `xcodegen generate`.
