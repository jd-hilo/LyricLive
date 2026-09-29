# LyricsFlow: Dynamic Lyrics — research & product spec

Reference material only. Scraped 2026-09-29 from the public iTunes Search/Lookup API, the App Store web
pages, the RSS review feeds, competitor listings and their marketing sites. Downloaded screenshots live
next to this file (`research/lyricsflow/`, `research/dynamic-lyrics/`, `research/lyricflow-translate/`)
and raw API payloads are in `research/raw/`. **Nothing from this folder is bundled in the app.**

Our clone is called **LyricLive** (placeholder, see README for renaming).

**Audience.** LyricLive targets English-speaking listeners, US storefront first. English is the development language and the default translation target (foreign lyrics are translated into English). The language list leads with Spanish, Korean, Japanese, French, Portuguese, German, and Italian. Traditional Chinese remains an optional app localization (`zh-Hant.lproj`) and a picker choice, not the assumed user. The TW/HK facts below describe the reference listing that was scraped. They are not LyricLive's market.

---

## 1. Target app: what we scraped

| Field | Value |
|---|---|
| Name | **LyricsFlow: Dynamic Lyrics** (US/MY) / **LyricsFlow: 靈動歌詞** (TW/HK) |
| App Store ID | `6779954248` (found via `search?term=LyricsFlow&country=tw&entity=software`) |
| Developer | Kexin Li (`id1613010571`), site `https://lyricsflow.org` (behind Cloudflare, not scrapeable) |
| Bundle ID | `li.kexin.lyrics` |
| Category | Music (primary), Entertainment (secondary) |
| Released | 2026-09-22 |
| Current version | 1.1.0 (released 2026-09-29) |
| Min OS | iOS 18.2 (iPhone, iPad, iPod touch; Apple Vision listed) |
| Size | ~41 MB |
| Price | Free with in-app purchases |
| Age rating | 4+ |
| Languages | AR, EN, FR, DE, ID, IT, JA, KO, PT, RU, ZH-Hans, ZH-Hant, ES, TH, VI |
| Rating | 4.9 (TW, 8 ratings), 5.0 (US, 1 rating) at time of scrape |
| Screenshots | 7 iPhone 6.7" (1290x2796), no iPad set. All downloaded: `research/lyricsflow/{tw,us}_iphone_NN.jpg` |
| Icon | `research/lyricsflow/icon_512.jpg` — red vertical gradient rounded square, three centred white rounded bars (long / short / medium) |

### Description (zh-Hant, verbatim from the TW listing)

> 在鎖定畫面、動態島和 CarPlay 螢幕上，隨時查看歌詞。
> LyricsFlow 將即時同步歌詞帶到你日常使用的畫面，讓你直接在主畫面控制播放，並透過歌詞翻譯，理解不同語言的歌曲。
> • 歌詞翻譯 — 透過其他語言歌曲的歌詞翻譯，讀懂音樂中的字句。
> • 鎖定畫面與動態島 — 無須返回 App，即可查看即時歌詞。
> • CarPlay 歌詞 — 透過 CarPlay，在車載螢幕上查看歌詞。
> • 主畫面小工具 — 直接在主畫面查看歌詞並控制播放。
> • 歌詞浮動視窗 — 使用其他 App 時，仍可透過浮動視窗查看歌詞。

English listing (US): "Dynamic Lyrics" title, same five feature bullets (Lyrics Translation, Lock Screen & Dynamic
Island, CarPlay Lyrics, Home Screen Widgets, Floating Lyrics window).

### What's New (1.1.0)

- New **Now Playing widget**: album art on the Home Screen plus playback control.
- New **extra-large lyrics widget** for iOS 27 (`systemExtraLarge` on iPhone).
- New **font styles** for lyric display.
- Fixed a text-editing issue on iOS 18 and other bugs.

### Subscription / paywall

Three IAPs, one subscription group plus a non-consumable:

| Product | US | TW |
|---|---|---|
| LyricsFlow Premium Yearly (auto-renewing) | $6.99 | NT$150 |
| LyricsFlow Premium Monthly (auto-renewing) | $2.99 | NT$30 |
| LyricsFlow Lifetime (one-off) | $9.99 | NT$220 |

Structure: monthly + yearly + lifetime, with the yearly plan the cheap "best value" option (yearly ≈ 2.3 months of
monthly). Their sibling app Dynamic-Lyrics has the same shape ($1.49 / $4.99 / $9.99 lifetime).

### Privacy label

- **Data Linked to You:** Purchases.
- **Data Not Linked to You:** Usage Data.
- No tracking.

### Reviews

Only one written review existed at scrape time (US, 5 stars): praises lyric sync accuracy and that *CarPlay
lyrics deliberately do not sync while the phone is unlocked, for driving safety*. No TW/HK/MY reviews yet.
Competitor reviews (Dynamic-Lyrics, ~9k ratings, 4.3–4.7) are the more informative source, see §3.

### Chart position

The tracker screenshot shows #16 in its chart with top storefronts TW, HK, MY.

---

## 2. Screen-by-screen breakdown (from the 7 App Store screenshots)

Reference frame: 1290x2796 px = 393x852 pt @3x. Measurements below are estimates in points.

Marketing frame (all): promo headline at top in a large bold CJK sans (~44pt) over a themed backdrop, phone mockup
below. Headline copy: `車載歌詞`, `歌詞翻譯`, `鎖定螢幕歌詞`, `動態島歌詞`, `桌面小工具`, `橫向模式`, `车载小工具`.

### 2.1 Full-screen lyrics ("歌詞翻譯", screenshot 2)  → `LyricsScreen`

- **Background:** heavily blurred (~80–100pt radius) multi-colour gradient derived from the album art:
  orange `#F28C38`, teal `#2FA8A0`, deep blue `#1E3F8F`, dark red. Animated slowly (blobs drift over ~20 s).
  A ~25–35 % black overlay keeps white text AA-contrast.
- **Header:** small artwork thumbnail (44x44, radius 8) left, title (17pt semibold) over artist (13pt, 60 % white);
  trailing "…" menu (options, offset, share, search). Grabber pill centred (36x5, 30 % white).
- **Lyrics list:** left aligned, horizontal padding 28pt.
  - Current line: 34pt **bold**, white 100 %.
  - Translation under each line: 20pt semibold, white 70 % (current) / 35 % (inactive).
  - Inactive lines: same font, white 30–40 % opacity, slight blur growing with distance (0–2pt), scale 0.94–1.0.
  - Vertical gap between line groups: ~26pt. Current line anchored ~35 % from the top of the list.
  - Scrolls with a spring (response ≈ 0.55 s, damping 0.85). User drag pauses auto-scroll for ~3 s.
- **Bottom bar:** persistent "now playing" mini-bar (also shown on Home): artwork 44x44 r8, title 16pt bold, artist 13pt 65 %
  white, heart button trailing. Screen 4 of the competitor adds a bottom control row: translate toggle (left),
  prev / play-pause (~64pt white circle) / next (centre), search (right).
- **Landscape ("橫向模式", screenshot 6):** two columns. Left ≈40 %: square artwork (≈ 180pt, r16) centred vertically,
  three transport buttons underneath. Right ≈60 %: same lyric list, left aligned, current line ~38pt bold.
  Background: dark ambient blur of the art (dark red / orange / black).
- **Language picker (competitor, screen 7):** dark translucent popover, header "Translate to: 中文 (zh) ⌄", scrollable
  list with language name + ISO code, hairline dividers.

### 2.2 Lock Screen Live Activity ("鎖定螢幕歌詞", screenshot 3)  → `LyricLockScreenView`

- Sits under the iOS clock; frosted material card, corner radius ≈ 24pt, padding 16pt, max height ≈ 160pt.
- Header row: artwork 44x44 r8, title 15pt bold white, artist 13pt 60 % white, small waveform glyph trailing.
- Progress: 4pt capsule, white on 25 % white, elapsed `0:11` left / remaining `-2:48` right (11pt monospaced digits).
- Controls: back / play-pause / forward (SF Symbols `backward.fill`, `pause.fill`, `forward.fill`, ~24pt), white.
- Lyric block (lower, secondary rounded glass): current line 17pt bold white, translation 13pt 70 % white, next line 15pt 40 % white.
  Previous line above at 35 %. Centre aligned.
- Their actual screenshot stacks this under iOS' own Now Playing widget; ours merges header, controls and lyrics into one
  Live Activity because we cannot rely on the system player being present.

### 2.3 Dynamic Island ("動態島歌詞", screenshot 4)  → `DynamicIsland`

- **Expanded:** black. Centre stack: previous line (dim, 13pt, 40 %), **current line (bold 20pt white)** with translation (14pt white 75 %),
  next line dim. Bottom row: previous / play-pause / next. Trailing/leading: artwork thumb and animated bars.
- **Compact:** leading = current lyric (1 line, truncates with "…"), trailing = 22x22 artwork. **Minimal:** artwork only.

### 2.4 CarPlay ("車載歌詞" / "车载小工具", screenshots 1 and 7)

- Dashboard split screen: map left, media widget right. Widget: artwork left, pause + skip on the right, lyric block below:
  current line bold white, adjacent lines grey 40 %.
- Full CarPlay app view: two columns. Left: artwork, title `N.I.G.H.T`, heart / play / skip. Right: three centred lyric lines
  (above/below dim & smaller, current bold & larger).
- Ratings badge "4.9 Worldwide Rating" with laurels is marketing only.
- Reviews on the sibling app: CarPlay lyrics fight other apps for the now-playing slot; refresh problems on iOS 27; users
  appreciate that lyrics stop syncing while the phone is unlocked (safety).

### 2.5 Home Screen widgets ("桌面小工具", screenshot 5)  → `LyricWidget`, `NowPlayingWidget`

- **Medium:** dark translucent charcoal card. Left ~65 %: header (music note glyph, title white, artist grey 11pt), lyric block
  current line 17pt bold white (2 lines max), next line dim 55 %. Right ~35 %: vinyl record (black disc with grooves) sticking out
  of the right edge, circular crop of artwork at the centre (~60 % of disc diameter).
- **Large:** header row with vinyl partly cropped in the top-left, title 15pt bold + artist 12pt grey. Body: 4–5 centred lyric lines with
  progressive opacity (past 30 %, current 100 % **extra-bold ~26pt**, future 55 % then 35 %).
- **Small (screenshot 4 of the store, iOS home):** cropped vinyl on top, two lines of lyrics bottom ("Climb on every rung" / dim continuation).
- 1.1.0 additions: Now Playing widget (artwork + controls), extra-large lyric widget, font styles.
- Dynamic-Lyrics adds a multi-line variant with a control footer and a vinyl-record variant with title/artist on top.

### 2.6 Other surfaces seen on competitors

- **Floating lyrics window ("懸浮歌詞")**: pill-shaped 90 %-width dark glass window over other apps, primary line bold white,
  translation light grey below, implemented with Picture-in-Picture tricks. Not achievable as a system overlay on iOS; we
  document this as a gap.
- **StandBy:** black background, left column vinyl artwork + title + controls, right column large centred lyrics.
- **Translation setup:** language list with ISO codes; separate "lyric separator" style in LyricFlow.
- **Shazam mode:** identify music playing anywhere (Dynamic-Lyrics, Lyricflow), lyrics start at the matched offset.
- **Share cards:** styled square image with selected lyric lines and artwork.

---

## 3. Competitors (how they implement the same features)

### 3.1 Dynamic-Lyrics / 靈動歌詞 (`6476125287`, 云冰 谭, musiclyrics.cn, bundle `com.bing.lyrics`)

- iOS 17+, 8,985 ratings, 4.3 (US) / 4.7 (TW). Released 2024-04-08, v2.0.5. iPhone + iPad + Mac.
- Pricing US: Year $4.99, Month $1.49, Lifetime $9.99. TW: NT$120 / NT$30 / NT$150 lifetime.
  A one-star review complains the lifetime price was later replaced by a yearly plan (trust risk when changing structure).
- Sources: Apple Music, Spotify (custom Spotify developer app authorization: users paste their own client ID after a
  tutorial; reviewers report the new Spotify flow broke it), **Shazam mode**, local music.
- Surfaces: lock screen (Live Activity), Dynamic Island, widgets + StandBy, floating window, full-screen lyrics
  with bilingual display, lyric translation (many languages, ISO-coded list), share cards, CarPlay lyrics + CarPlay widget.
- Privacy label: Data Not Linked to You (Diagnostics, Usage Data). No tracking.
- Known pain points from reviews (informs our design): Live Activity closes on its own / has to be re-started each session; lyrics stop updating when
  the music app is swiped away; CarPlay lyrics compete with other apps; no refresh feedback (their widgets need a refresh button);
  lyrics missing for some tracks; wish for Apple Watch lyrics; "long transition to next song".
- Site claims: "StandBy: automatically shows large-screen lyrics when device lies flat", "CarPlay lyrics on home screen,
  navigation and karaoke", "Note: CarPlay lyrics are only for passengers".

### 3.2 LyricFlow — Translate Music (`6757671982`, Ömer Aslan, bundle `com.omeraslan.LyricFlow`)

- iOS 17+, v1.1.0 (2026-03-02 release; earlier 1.0.3 on Apr 6 in the web listing). No ratings yet.
- Pricing US: Weekly $1.99, Yearly $29.99, Lifetime $39.99 (TW: NT$60 / NT$990 / NT$1,290). Weekly subscription paywall pattern.
- Privacy label: Linked (Contact Info, Identifiers, Usage, Diagnostics) and used to track — heavier than the others.
- Features: connect Apple Music (Spotify in the CN listing), line-by-line synced lyrics, one-tap translation, home/lock widgets,
  Live Activity + Dynamic Island with **transport buttons in the activity header row and a big current line with the
  translation underneath in smaller dimmed text**, CarPlay scrolling lyrics, in-app song search, sharing lyrics.
- 1.1.0 redesign: "Home" experience with favorite lyrics that "stay with you", search feature, sharing.
- Screens: full-screen lyric view with `X` close (top right), artwork+song name (top left), left aligned 30–34pt bold current lyric, dim/blurred
  upcoming lines, progress scrubber with `0:00 / 3:29`, bottom bar = translate toggle · transport (large filled play) · search.

### 3.3 Takeaways applied to our design

1. Adopt the Apple-Music-lyrics look for the main lyric screen: left aligned, big bold, opacity+blur falloff, artwork-derived animated background.
2. Live Activity: one card with header (artwork, title, artist, transport), progress, and lyric block (current + translation + next).
3. Widgets with the vinyl motif; medium and large are the hero sizes; accessory (lock screen) variants for the current line.
4. Solve competitors' top complaints: explicit refresh action, keep-alive option, a Shazam fallback, caching so replays never re-fetch.
5. Three-tier IAP (monthly, yearly, lifetime) with a highlighted yearly plan, restore purchases, clear renewal copy.
6. Privacy: no accounts, no analytics; only StoreKit purchase state. Lyrics come from LRCLIB (no key).

---

## 4. Product requirements for LyricLive (our clone)

### Core flows

1. **First launch → onboarding** (4 steps): welcome → connect music (Apple Music permission; Spotify optional) → microphone for Shazam →
   notifications / Live Activities → optional paywall.
2. **Home tab**: source status card (Apple Music / Spotify / Shazam / Demo), "Now Playing" summary with a "Open lyrics" action, feature shortcuts
   (Live Activity toggle, widgets guide, CarPlay note), Shazam listen button. Persistent mini player bar above the tab bar.
3. **Lyrics screen** (full-screen cover): as §2.1. Tap a line to seek (Apple Music, Spotify). Menu: offset ±, translation language, share, search another lyric.
4. **Library tab**: favorites (heart) and recently played, tap → cached lyrics screen.
5. **Settings**: font size, alignment, background style, translation (on/off; target defaults to English), lyric offset, sources, Live Activity, background keep-alive, Pro status.
6. **Paywall** (StoreKit 2): monthly, yearly (best value), lifetime; restore; legal links. Gate: see below.
7. **Share card**: choose lines, style, aspect → render image → share sheet.

### Pro gating (modelled on their "premium unlocks everything, free is basic")

| Feature | Free | Pro |
|---|---|---|
| Apple Music now-playing + synced lyrics in app | yes | yes |
| Small home widget, lock-screen accessory widgets | yes | yes |
| Lyric offset, font size, alignment | yes | yes |
| Translation | 3 songs / day | unlimited |
| Live Activity / Dynamic Island | no | yes |
| Medium / large / extra-large widgets, Now Playing widget | no | yes |
| CarPlay lyrics | no | yes |
| Spotify source, Shazam mode | no | yes |
| Share cards | watermarked | no watermark, all styles |
| Animated artwork gradient / custom fonts | basic gradient | all |

(The real gating of the original could not be observed without installing it; the above is a plausible structure derived from
the listing copy and the competitors' pricing.)

### Technical surface

- iOS 17.0+, SwiftUI, Observation, ActivityKit, WidgetKit, App Intents, CarPlay, MusicKit, MediaPlayer, ShazamKit,
  Translation (iOS 18+; graceful fallback on 17), StoreKit 2. Only optional third-party SDK: Spotify iOS SDK (App Remote).
- Lyrics data: LRCLIB (`GET https://lrclib.net/api/get?track_name&artist_name&album_name&duration`, fallback `GET /api/search?q=`).
  Response fields: `syncedLyrics` (LRC), `plainLyrics`, `instrumental`, `duration`. Cached on disk by normalized artist/title/duration.
- Shared state between app, widgets, Live Activity: App Group container (`group.<bundle>.shared`) with a JSON snapshot + artwork file.

---

## 5. Known limits vs the original

- **Floating lyrics window:** iOS has no third-party system overlay. The original uses Picture-in-Picture tricks; not implemented.
- **Running while the music app is foreground:** an app cannot read Apple Music state from the background unless something keeps it alive.
  We provide an opt-in silent-audio keep-alive (README explains the App Review risk).
- **CarPlay:** needs Apple's `com.apple.developer.carplay-audio` entitlement (or another category) granted per developer account.
  Audio apps can only use list / now-playing templates, so our "lyrics" screen is a list template updated per line, not free-form UI.
- **Spotify:** App Remote requires the user to install Spotify and you to register a client ID and redirect URI.
- **Lyrics quality:** LRCLIB coverage is community sourced; the original likely uses a paid or scraped multi-source provider.
- **Artwork of the original app / Apple, Spotify, Shazam logos:** not reproduced. Source pills use SF Symbols and text.
