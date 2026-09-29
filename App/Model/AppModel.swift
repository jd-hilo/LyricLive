import Combine
import Foundation
import LyricCore
import SwiftUI
import UIKit
import WidgetKit

enum LyricsLoadState: Equatable {
    case idle
    case loading
    case ready
    case instrumental
    case notFound
    case failed(String)
}

enum TranslationStatus: Equatable {
    case idle
    case working
    case ready
    case quotaReached
    case sameLanguage
    case unavailable(String)
    case failed(String)
}

enum PaywallReason: Identifiable, Equatable {
    case general
    case feature(ProFeature)

    var id: String {
        switch self {
        case .general: return "general"
        case .feature(let feature): return feature.rawValue
        }
    }
}

/// Central coordinator: follows the active music source, resolves lyrics and translations, keeps the current line
/// up to date, and publishes state to the Live Activity, widgets and CarPlay.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let settings: AppSettings
    let store: StoreManager
    let favorites: FavoritesStore
    let permissions: PermissionsManager

    // MARK: Published state

    @Published private(set) var track: TrackInfo?
    @Published private(set) var clock: PlaybackClock = .stopped
    @Published private(set) var document: LyricsDocument?
    @Published private(set) var lyricsState: LyricsLoadState = .idle
    @Published private(set) var translations: [String]?
    @Published private(set) var translationStatus: TranslationStatus = .idle
    @Published private(set) var translationJob: TranslationJob?
    @Published private(set) var artwork: UIImage?
    @Published private(set) var palette: [RGBColor] = PaletteExtractor.fallback
    @Published private(set) var currentIndex: Int?
    @Published private(set) var activeSource: PlaybackSource?
    @Published private(set) var sourceStatus: [PlaybackSource: SourceStatus] = [:]

    @Published var isLyricsPresented = false
    @Published var paywallReason: PaywallReason?

    // MARK: Private

    private let cache: FileLyricsCache
    private let repository: LyricsRepository
    private let liveActivity = LiveActivityManager()
    private let keepAlive = BackgroundKeepAlive()
    private var sources: [PlaybackSource: NowPlayingSource] = [:]
    private var runningSources: Set<PlaybackSource> = []
    private var cancellables: Set<AnyCancellable> = []

    private var lyricsTask: Task<Void, Never>?
    private var scheduleTask: Task<Void, Never>?
    private var widgetReloadTask: Task<Void, Never>?
    private var artworkToken = 0
    private var lastAppliedSettings: AppliedSettings?

    private struct AppliedSettings: Equatable {
        var showTranslation: Bool
        var language: String
        var offset: TimeInterval
        var appleMusic: Bool
        var spotify: Bool
        var liveActivity: Bool
        var keepAlive: Bool
        var isPro: Bool
    }

    // MARK: Init

    init(
        settings: AppSettings = AppSettings(),
        store: StoreManager = StoreManager(),
        favorites: FavoritesStore = FavoritesStore(),
        permissions: PermissionsManager = PermissionsManager()
    ) {
        self.settings = settings
        self.store = store
        self.favorites = favorites
        self.permissions = permissions

        let cacheDirectory = AppGroup.containerURL.appendingPathComponent("LyricsCache", isDirectory: true)
        cache = FileLyricsCache(directory: cacheDirectory)
        repository = LyricsRepository(cache: cache)

        let appleMusic = AppleMusicSource()
        let spotify = SpotifySource()
        let shazam = ShazamSource()
        let demo = DemoSource()
        for source in [appleMusic, spotify, shazam, demo] as [NowPlayingSource] {
            register(source)
        }

        PlaybackCommandBus.shared.handler = { [weak self] command in
            self?.perform(command)
        }

        settings.objectWillChange
            .merge(with: store.objectWillChange)
            .sink { [weak self] _ in
                Task { @MainActor in self?.settingsDidChange() }
            }
            .store(in: &cancellables)

        lastAppliedSettings = currentAppliedSettings()
    }

    private func register(_ source: NowPlayingSource) {
        source.onUpdate = { [weak self, kind = source.kind] update in
            self?.receive(update, from: kind)
        }
        source.onStatusChange = { [weak self, kind = source.kind] status in
            self?.sourceStatus[kind] = status
        }
        sources[source.kind] = source
        sourceStatus[source.kind] = source.status
    }

    // MARK: Derived

    var isPro: Bool { store.isPro }

    var offset: TimeInterval { settings.effectiveOffset(for: track?.key) }

    var trackOffsetMs: Int {
        get { track.map { settings.offsetMs(for: $0.key) } ?? 0 }
        set {
            guard let track else { return }
            settings.setOffsetMs(newValue, for: track.key)
        }
    }

    var syncEngine: LyricSyncEngine {
        guard let document else { return LyricSyncEngine(lines: []) }
        return LyricSyncEngine(document: document, offset: offset, duration: track?.duration)
    }

    var canSeek: Bool {
        guard let activeSource else { return false }
        return sources[activeSource]?.canSeek ?? false
    }

    var isPlaying: Bool { clock.isPlaying }

    var window: LyricWindow {
        makeSnapshot().window(at: Date(), before: 1, after: 3)
    }

    var isShazamListening: Bool { sourceStatus[.shazam] == .listening }

    // MARK: Lifecycle

    func start() {
        reconcileSources()
        Task { await permissions.refresh() }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            (sources[.spotify] as? SpotifySource)?.sceneDidBecomeActive()
            if settings.appleMusicEnabled { sources[.appleMusic]?.start() }
            Task { await permissions.refresh() }
            if track != nil { publish(.playback) }
        case .background:
            (sources[.spotify] as? SpotifySource)?.sceneWillResignActive()
        default:
            break
        }
    }

    func handle(url: URL) {
        if url.host == "spotify-login-callback" {
            (sources[.spotify] as? SpotifySource)?.handleOpenURL(url)
        } else if url.host == "lyrics" {
            isLyricsPresented = true
        }
    }

    // MARK: Sources

    func requestAppleMusicAccess() async {
        if let source = sources[.appleMusic] as? AppleMusicSource {
            await source.requestAccess()
            runningSources.insert(.appleMusic)
        }
        await permissions.refresh()
    }

    func connectSpotify() {
        guard requirePro(.spotify) else { return }
        settings.spotifyEnabled = true
        (sources[.spotify] as? SpotifySource)?.authorize()
        runningSources.insert(.spotify)
    }

    func startShazam() async {
        guard requirePro(.shazam) else { return }
        if permissions.microphone == .notDetermined {
            await permissions.requestMicrophone()
        }
        guard permissions.microphone == .granted else {
            sourceStatus[.shazam] = .unavailable(String(localized: "Microphone access is turned off in Settings."))
            return
        }
        sources[.shazam]?.start()
        runningSources.insert(.shazam)
    }

    func stopShazam() {
        sources[.shazam]?.stop()
        runningSources.remove(.shazam)
        if activeSource == .shazam { clearTrack() }
    }

    func restartShazam() {
        (sources[.shazam] as? ShazamSource)?.listenAgain()
    }

    func startDemo() {
        sources[.demo]?.start()
        runningSources.insert(.demo)
    }

    func stopDemo() {
        sources[.demo]?.stop()
        runningSources.remove(.demo)
        if activeSource == .demo { clearTrack() }
    }

    var isDemoRunning: Bool { runningSources.contains(.demo) }

    /// Starts or stops the automatic sources (Apple Music, Spotify) to match settings.
    func reconcileSources() {
        let wanted: [PlaybackSource: Bool] = [
            .appleMusic: settings.appleMusicEnabled,
            .spotify: settings.spotifyEnabled && isPro,
        ]
        for (kind, shouldRun) in wanted {
            guard let source = sources[kind] else { continue }
            if shouldRun, !runningSources.contains(kind) {
                source.start()
                runningSources.insert(kind)
            } else if !shouldRun, runningSources.contains(kind) {
                source.stop()
                runningSources.remove(kind)
                if activeSource == kind { clearTrack() }
            }
        }
    }

    private func receive(_ update: SourceUpdate, from kind: PlaybackSource) {
        guard activeSource == nil || activeSource == kind || update.isPlaying || !clock.isPlaying else { return }

        guard let newTrack = update.track, !newTrack.title.isEmpty else {
            if activeSource == kind { clearTrack() }
            return
        }

        let trackChanged = track?.key != newTrack.key
        let newClock = PlaybackClock(
            anchorPosition: update.position,
            anchorDate: update.timestamp,
            rate: update.isPlaying ? 1 : 0,
            duration: newTrack.duration
        )
        let unchanged = !trackChanged
            && update.artwork == nil
            && activeSource == kind
            && clock.isEquivalent(to: newClock, at: update.timestamp, tolerance: 0.4)
        if unchanged { return }

        activeSource = kind
        track = newTrack
        clock = newClock

        if let image = update.artwork {
            setArtwork(image)
        } else if trackChanged {
            setArtwork(nil)
        }

        if trackChanged {
            favorites.recordPlay(newTrack)
            loadLyrics(for: newTrack)
        }

        scheduleLineUpdates()
        publish(.playback)
    }

    private func clearTrack() {
        lyricsTask?.cancel()
        scheduleTask?.cancel()
        track = nil
        clock = .stopped
        document = nil
        translations = nil
        translationJob = nil
        translationStatus = .idle
        lyricsState = .idle
        currentIndex = nil
        activeSource = nil
        setArtwork(nil)
        publish(.playback)
    }

    // MARK: Playback control

    func perform(_ command: PlaybackCommand) {
        switch command {
        case .togglePlayPause: togglePlayPause()
        case .next: skipNext()
        case .previous: skipPrevious()
        case .toggleTranslation: settings.showTranslation.toggle()
        }
    }

    private var activeSourceObject: NowPlayingSource? {
        activeSource.flatMap { sources[$0] }
    }

    func togglePlayPause() {
        activeSourceObject?.togglePlayPause()
    }

    func skipNext() {
        activeSourceObject?.skipNext()
    }

    func skipPrevious() {
        activeSourceObject?.skipPrevious()
    }

    func seek(to position: TimeInterval) {
        guard canSeek else { return }
        let clamped = min(max(0, position), track?.duration ?? position)
        activeSourceObject?.seek(to: clamped)
        clock = clock.seeking(to: clamped)
        scheduleLineUpdates()
        publish(.playback)
    }

    func seek(toLine index: Int) {
        guard canSeek, let position = syncEngine.seekPosition(forLine: index) else { return }
        seek(to: position)
    }

    // MARK: Lyrics

    private func loadLyrics(for track: TrackInfo) {
        lyricsTask?.cancel()
        document = nil
        translations = nil
        translationJob = nil
        translationStatus = .idle
        currentIndex = nil

        if track.source == .demo {
            document = DemoContent.document
            lyricsState = .ready
            afterLyricsLoaded()
            return
        }

        lyricsState = .loading
        lyricsTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.repository.lyrics(for: track)
            guard !Task.isCancelled, self.track?.key == track.key else { return }
            self.apply(result)
        }
    }

    func retryLyrics() {
        guard let track else { return }
        lyricsTask?.cancel()
        lyricsState = .loading
        lyricsTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.repository.lyrics(for: track, forceRefresh: true)
            guard !Task.isCancelled, self.track?.key == track.key else { return }
            self.apply(result)
        }
    }

    private func apply(_ result: LyricsResult) {
        switch result {
        case .found(let found):
            document = found
            lyricsState = .ready
        case .instrumental:
            document = nil
            lyricsState = .instrumental
        case .notFound:
            document = nil
            lyricsState = .notFound
        case .failed(let message):
            document = nil
            lyricsState = .failed(message)
        }
        afterLyricsLoaded()
    }

    private func afterLyricsLoaded() {
        scheduleLineUpdates()
        refreshTranslation()
        publish(.playback)
    }

    func searchLyrics(query: String) async -> [LRCLibRecord] {
        (try? await repository.search(query: query)) ?? []
    }

    func adoptLyrics(_ record: LRCLibRecord) async {
        guard let track else { return }
        let result = await repository.adopt(record: record, for: track)
        guard self.track?.key == track.key else { return }
        apply(result)
    }

    /// Cached-or-fetched lyrics for a track that is not playing (Library tab).
    func lyrics(for savedTrack: TrackInfo) async -> LyricsResult {
        if savedTrack.source == .demo { return .found(DemoContent.document) }
        return await repository.lyrics(for: savedTrack)
    }

    func clearLyricsCache() {
        cache.removeAll()
    }

    var cacheSizeBytes: Int { cache.sizeOnDisk() }

    // MARK: Translation

    func refreshTranslation() {
        translationJob = nil

        guard settings.showTranslation else {
            translations = nil
            translationStatus = .idle
            publish(.playback)
            return
        }
        guard let track, let document, document.isSynced, !document.lines.isEmpty else {
            translations = nil
            translationStatus = .idle
            return
        }

        let target = settings.translationLanguage
        let lines = document.lines.map(\.text)

        if let cached = cache.translations(forKey: track.key, language: target), cached.count == lines.count {
            translations = cached
            translationStatus = .ready
            publish(.playback)
            return
        }

        if track.source == .demo, TranslationLanguages.isSameLanguage(target, "en") {
            let bundled = DemoContent.translationsEn
            translations = bundled
            translationStatus = .ready
            publish(.playback)
            return
        }

        let source = LanguageDetector.dominantLanguage(of: lines)
        if let source, TranslationLanguages.isSameLanguage(source, target) {
            translations = nil
            translationStatus = .sameLanguage
            return
        }

        guard #available(iOS 18.0, *) else {
            translations = nil
            translationStatus = .unavailable(String(localized: "On-device translation needs iOS 18 or later."))
            return
        }

        if !isPro && settings.translationQuota.remaining(limit: ProPolicy.freeTranslationsPerDay) == 0 {
            translations = nil
            translationStatus = .quotaReached
            return
        }

        translations = nil
        translationStatus = .working
        translationJob = TranslationJob(trackKey: track.key, lines: lines, source: source, target: target)
    }

    func finishTranslation(_ job: TranslationJob, results: [String]) {
        guard translationJob?.id == job.id, track?.key == job.trackKey else { return }
        translationJob = nil
        translations = results
        translationStatus = .ready
        cache.storeTranslations(results, forKey: job.trackKey, language: job.target)
        if !isPro {
            var quota = settings.translationQuota
            quota.consume(limit: ProPolicy.freeTranslationsPerDay)
            settings.translationQuota = quota
        }
        publish(.playback)
    }

    func failTranslation(_ job: TranslationJob, message: String) {
        guard translationJob?.id == job.id else { return }
        translationJob = nil
        translations = nil
        translationStatus = .failed(message)
    }

    var translationsRemainingToday: Int {
        isPro ? .max : settings.translationQuota.remaining(limit: ProPolicy.freeTranslationsPerDay)
    }

    // MARK: Artwork

    private func setArtwork(_ image: UIImage?) {
        artwork = image
        artworkToken += 1
        if let image {
            palette = ArtworkProcessor.palette(from: image)
            SharedStore.writeArtwork(ArtworkProcessor.sharedJPEG(from: image))
        } else {
            palette = PaletteExtractor.fallback
            SharedStore.writeArtwork(nil)
        }
    }

    // MARK: Line scheduling

    /// Keeps `currentIndex` in step with playback by sleeping until the next line boundary.
    private func scheduleLineUpdates() {
        scheduleTask?.cancel()
        scheduleTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let delay = self.tickLine() else { return }
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    /// Updates `currentIndex`. Returns seconds until the next change, or nil when nothing else is scheduled.
    private func tickLine() -> TimeInterval? {
        guard let document, document.isSynced, track != nil else {
            if currentIndex != nil { currentIndex = nil }
            return nil
        }
        let position = clock.position()
        let state = syncEngine.state(at: position)
        if state.currentIndex != currentIndex {
            currentIndex = state.currentIndex
            publish(.line)
        }
        guard clock.isPlaying, let next = state.nextChangePosition else { return nil }
        return max(0.03, next - position + 0.01)
    }

    // MARK: Settings reactions

    private func currentAppliedSettings() -> AppliedSettings {
        AppliedSettings(
            showTranslation: settings.showTranslation,
            language: settings.translationLanguage,
            offset: offset,
            appleMusic: settings.appleMusicEnabled,
            spotify: settings.spotifyEnabled,
            liveActivity: settings.liveActivityEnabled,
            keepAlive: settings.keepAliveInBackground,
            isPro: isPro
        )
    }

    private func settingsDidChange() {
        let applied = currentAppliedSettings()
        guard let previous = lastAppliedSettings, previous != applied else { return }
        lastAppliedSettings = applied

        if previous.appleMusic != applied.appleMusic || previous.spotify != applied.spotify || previous.isPro != applied.isPro {
            reconcileSources()
        }
        if previous.showTranslation != applied.showTranslation || previous.language != applied.language {
            refreshTranslation()
            if applied.showTranslation, translationStatus == .quotaReached {
                paywallReason = .feature(.translation)
            }
        }
        if previous.offset != applied.offset {
            scheduleLineUpdates()
            publish(.playback)
        }
        if previous.liveActivity != applied.liveActivity || previous.keepAlive != applied.keepAlive || previous.isPro != applied.isPro {
            publish(.playback)
        }
    }

    // MARK: Pro gating

    /// Returns true if the feature is available. Otherwise presents the paywall and returns false.
    @discardableResult
    func requirePro(_ feature: ProFeature) -> Bool {
        if ProPolicy.isAllowed(feature, isPro: isPro) { return true }
        paywallReason = .feature(feature)
        return false
    }

    /// Same as `requirePro(_:)`, but waits so a sheet that is being dismissed has time to go away first.
    func requirePro(_ feature: ProFeature, after delay: TimeInterval) {
        guard !ProPolicy.isAllowed(feature, isPro: isPro) else { return }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            requirePro(feature)
        }
    }

    // MARK: Publishing

    enum PublishReason {
        /// The highlighted line moved.
        case line
        /// Track, play state, seek, lyrics, translations or settings changed.
        case playback
    }

    func makeSnapshot() -> NowPlayingSnapshot {
        NowPlayingSnapshot(
            track: track,
            clock: clock,
            lines: document?.lines ?? [],
            isSynced: document?.isSynced ?? false,
            translations: settings.showTranslation ? translations : nil,
            offset: offset,
            paletteHex: palette.map(\.hex),
            isPro: isPro
        )
    }

    private func publish(_ reason: PublishReason) {
        NotificationCenter.default.post(name: .lyricStateDidChange, object: nil)
        updateLiveActivity()
        updateKeepAlive()

        if reason == .playback {
            SharedStore.write(makeSnapshot())
            scheduleWidgetReload()
        }
    }

    private func scheduleWidgetReload() {
        widgetReloadTask?.cancel()
        widgetReloadTask = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func updateLiveActivity() {
        guard let track, settings.liveActivityEnabled, isPro else {
            if liveActivity.isRunning { liveActivity.end() }
            return
        }
        let now = Date()
        let snapshot = makeSnapshot()
        let window = snapshot.window(at: now, before: 1, after: 1)
        let state = LyricActivityAttributes.ContentState(
            title: track.title,
            artist: track.artist,
            previousLine: window.previous.last?.text.nilIfEmpty,
            currentLine: window.current?.text.nilIfEmpty,
            currentTranslation: window.current?.translation,
            nextLine: window.upcoming.first?.text.nilIfEmpty,
            nextTranslation: window.upcoming.first?.translation,
            isPlaying: clock.isPlaying,
            position: clock.position(at: now),
            duration: track.duration ?? 0,
            updatedAt: now,
            paletteHex: palette.map(\.hex),
            artworkToken: artworkToken,
            showsTranslation: settings.showTranslation
        )
        liveActivity.show(state)
    }

    private func updateKeepAlive() {
        if settings.keepAliveInBackground, track != nil, clock.isPlaying {
            keepAlive.start()
        } else if keepAlive.isActive {
            keepAlive.stop()
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
