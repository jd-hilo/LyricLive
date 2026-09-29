# LyricLive

Time-synced lyrics for the song you are playing: full screen, Lock Screen, Dynamic Island, Home Screen widgets, and CarPlay. Translation runs on the device.

This is an independent app. It is not LyricsFlow. Research notes and the screenshots they were matched against are in `research/` (`SPEC.md`, `UI_PARITY.md`). Those images are not part of the app.

The app targets iOS 17 and later. It will not compile on Linux. The lyric engine in `Packages/LyricCore` does, and that is what `swift test` covers.

## Generate the Xcode project

[XcodeGen](https://github.com/yonaskolb/XcodeGen) is the source of truth. `project.yml` is checked in; the `.xcodeproj` is generated and not.

```bash
brew install xcodegen
# Optional, only if you want Spotify. See below.
xcodegen generate
open LyricLive.xcodeproj
```

Run the **LyricLive** scheme on an iPhone or simulator (iOS 17+). The scheme loads `App/Resources/LyricLive.storekit`, so the paywall works without App Store Connect.

To rename the app, edit the four values at the top of `settings.base` in `project.yml` (`APP_DISPLAY_NAME`, `APP_BUNDLE_ID_BASE`, `APP_URL_SCHEME`, `PRODUCT_ID_PREFIX`), then run `xcodegen generate` again.

## Capabilities and entitlements

Create the App ID for `com.example.lyriclive` (or whatever `APP_BUNDLE_ID_BASE` is) and a second App ID for the widget extension (`<base>.widgets`). Turn on:

| Capability | Where | Why |
|---|---|---|
| App Groups (`group.<bundle id>`) | App and widget extension | The app writes now-playing state and artwork; widgets and the Live Activity read them. Already in `Config/App.entitlements` and `Config/Widgets.entitlements`. |
| MusicKit | App ID, plus a MusicKit key if you call the catalog | Apple Music catalog lookup for Shazam matches (duration and album). Media library access is requested at runtime for the system music player. |
| ShazamKit | No extra entitlement on recent iOS; microphone usage string is in Info.plist | Identifying music playing nearby. |
| Live Activities / Frequent Updates | Info.plist keys `NSSupportsLiveActivities` and `NSSupportsLiveActivitiesFrequentUpdates` | Lock Screen and Dynamic Island. Also enable Live Activities for the app in Settings on device. |
| Background Modes → Audio | Info.plist `UIBackgroundModes: audio` | Optional “keep lyrics updating in the background” setting. Off by default. |
| In-App Purchase | App ID | StoreKit 2 products below. |
| CarPlay Audio | App ID, after Apple approves the entitlement | See below. Not included in the default entitlements file, because signing fails without the grant. |

Set `DEVELOPMENT_TEAM` in `project.yml` before you archive.

### CarPlay

CarPlay will not connect until Apple assigns your team the `com.apple.developer.carplay-audio` entitlement ([request it here](https://developer.apple.com/contact/carplay/)). After it is on the App ID:

1. Point the app target at the CarPlay file. In `project.yml`, change the app’s `CODE_SIGN_ENTITLEMENTS` from `Config/App.entitlements` to `Config/App-CarPlay.entitlements`.
2. Regenerate and install on a device. In the CarPlay simulator (I/O → External Displays → CarPlay) the app appears with a Lyrics tab and a Controls tab.

Audio apps may only use the system list, grid, and now-playing templates, so lyrics are a list that advances with the song rather than a free-form layout. `UI_PARITY.md` explains how that differs from the App Store marketing shots.

### StoreKit products

Create these in App Store Connect, in one subscription group plus a non-consumable. The identifiers must match `PRODUCT_ID_PREFIX`:

| Product | Id suffix | Reference price |
|---|---|---|
| Yearly, auto-renewable | `.yearly` | $6.99 |
| Monthly, auto-renewable | `.monthly` | $2.99 |
| Lifetime, non-consumable | `.lifetime` | $9.99 |

Local testing uses `App/Resources/LyricLive.storekit` with those same ids and prices. A debug-only “Unlock Pro” switch in Settings bypasses StoreKit.

Pro unlocks the Live Activity, medium / large / extra-large and Now Playing widgets, CarPlay, Spotify, Shazam, unlimited translation, unwatermarked share cards, and the artwork-blur background. Free includes in-app Apple Music lyrics, the small and Lock Screen widgets, and three translations a day.

### Spotify (optional)

The project compiles with or without the Spotify iOS SDK. `project.yml` depends on `https://github.com/spotify/ios-sdk` (5.0.1+). If you would rather not fetch it, delete the `SpotifyiOS` package entry and the app target’s package dependency; `SpotifySource` is wrapped in `#if canImport(SpotifyiOS)` and will say the SDK is not linked.

To turn it on:

1. Create an app at the [Spotify developer dashboard](https://developer.spotify.com/dashboard).
2. Add the redirect URI `<scheme>://spotify-login-callback` (default `lyriclive://spotify-login-callback`).
3. Set `SPOTIFY_CLIENT_ID` in `project.yml`.
4. Install Spotify on the device. App Remote controls the Spotify app; it does not stream audio itself.

### Lyrics source

[LRCLIB](https://lrclib.net/api) needs no key. The app calls `GET /api/get` with title, artist, album, and duration, then `GET /api/search` if that misses. Synced LRC is preferred, plain lyrics are the fallback, and results are cached as JSON in the App Group container. The user agent is set in `LRCLibClient`.

LyricLive is aimed at English-speaking listeners, with the US storefront first. English is the development language. Traditional Chinese (`zh-Hant`) ships as an optional localization and is not the default.

Translation uses Apple’s Translation framework (`translationTask` / `TranslationSession`) on iOS 18 and later. On iOS 17 the toggle explains that it needs 18. The default target is English, so lyrics in other languages are translated into English. The language picker lists English, then Spanish, Korean, Japanese, French, Portuguese, German, and Italian, with other languages after that. The built-in demo song is Spanish and includes a bundled English translation, so the feature works in the simulator with no network.

## Project layout

```
project.yml                  XcodeGen spec
App/                         SwiftUI app, sources, CarPlay scene, settings, paywall
Shared/                      App Group store, ActivityAttributes, App Intents (compiled into both targets)
Widgets/                     WidgetKit extension and the Live Activity
Packages/LyricCore/          Parser, sync, LRCLIB client, cache (no UIKit)
App/Resources/*.lproj        English (default) and optional Traditional Chinese strings
Config/*.entitlements        App Group, and the CarPlay variant
research/                    Scraped listing, SPEC.md, UI_PARITY.md, screenshots
```

## Tests

From macOS or Linux, with a Swift 5.9+ toolchain:

```bash
cd Packages/LyricCore
swift test
```

This covers the LRC parser (including a real LRCLIB timestamp shape), the sync engine and seek math, the playback clock, widget timeline dates, the LRCLIB client and cache, translation-language matching, the artwork palette, and the free-tier quota.

## Privacy

No account, no analytics. The only network calls are LRCLIB and, if you connect it, Spotify’s auth. Apple Music and the microphone are used on device. Purchases go through StoreKit. Privacy and terms URLs in `App/Config/AppConfig.swift` are placeholders (`example.com`); replace them before shipping.

## What still needs a device

Now-playing detection, Shazam, Live Activities, widgets, CarPlay, and StoreKit purchases can only be exercised on Apple hardware or the simulator. The demo song (Home → Play demo song) drives every lyrics surface without those services, including in the simulator.
