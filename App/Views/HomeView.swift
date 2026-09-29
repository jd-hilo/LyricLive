import LyricCore
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var permissions: PermissionsManager

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()
                ScrollView {
                    VStack(spacing: 22) {
                        nowPlayingCard
                        sourcesSection
                        featuresSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(AppConfig.displayName)
            .toolbar {
                if !store.isPro {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            model.paywallReason = .general
                        } label: {
                            Label("Go Pro", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
        .miniPlayerInset()
    }

    // MARK: Now playing

    @ViewBuilder
    private var nowPlayingCard: some View {
        if let track = model.track {
            Button {
                model.isLyricsPresented = true
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        ArtworkThumb(image: model.artwork, cornerRadius: 14)
                            .frame(width: 84, height: 84)
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                        VStack(alignment: .leading, spacing: 5) {
                            if let source = model.activeSource { SourceBadge(source: source) }
                            Text(track.title).font(.title3.weight(.bold)).lineLimit(2)
                            Text(track.artist).font(.subheadline).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    currentLyricPreview
                    HStack {
                        Text("Open lyrics")
                        Spacer()
                        Image(systemName: "chevron.up")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    ZStack {
                        LinearGradient(
                            colors: model.palette.map { Color($0).opacity(0.75) },
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        Color.black.opacity(0.3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 14) {
                Image(systemName: "text.quote")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Brand.pink)
                Text("Nothing playing")
                    .font(.title3.weight(.bold))
                Text("Play a song in Apple Music and the lyrics show up here, on your Lock Screen, and in widgets. The built-in demo is in Spanish, with an English translation.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                Button {
                    model.startDemo()
                } label: {
                    Label("Play demo song", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
            }
            .padding(22)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    @ViewBuilder
    private var currentLyricPreview: some View {
        switch model.lyricsState {
        case .loading:
            HStack(spacing: 8) {
                ProgressView().tint(.white).controlSize(.small)
                Text("Finding lyrics…").font(.subheadline).foregroundStyle(.white.opacity(0.75))
            }
        case .notFound, .failed:
            Text("No lyrics found").font(.subheadline).foregroundStyle(.white.opacity(0.75))
        case .instrumental:
            Text("Instrumental").font(.subheadline).foregroundStyle(.white.opacity(0.75))
        default:
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let window = model.window
                VStack(alignment: .leading, spacing: 3) {
                    Text(window.current?.text.isEmpty == false ? window.current?.text ?? "" : "♪")
                        .font(.system(size: 20, weight: .bold))
                        .lineLimit(2)
                    if let translation = window.current?.translation {
                        Text(translation).font(.subheadline).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Sources

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sources").font(.headline).padding(.horizontal, 4)
            VStack(spacing: 0) {
                sourceRow(
                    .appleMusic,
                    subtitle: appleMusicSubtitle,
                    trailing: appleMusicAction
                )
                divider
                sourceRow(.spotify, subtitle: spotifySubtitle, trailing: spotifyAction, isPro: true)
                divider
                sourceRow(.shazam, subtitle: shazamSubtitle, trailing: shazamAction, isPro: true)
                divider
                sourceRow(.demo, subtitle: LocalizedStringKey("Built-in song with synced lyrics"), trailing: demoAction)
            }
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var divider: some View {
        Divider().overlay(.white.opacity(0.1)).padding(.leading, 60)
    }

    private func sourceRow(_ source: PlaybackSource, subtitle: LocalizedStringKey, trailing: some View, isPro: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: source.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(source.titleKey).font(.body.weight(.semibold))
                    if isPro && !store.isPro { ProBadge() }
                }
                Text(subtitle).font(.footnote).foregroundStyle(.white.opacity(0.65)).lineLimit(2)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var appleMusicSubtitle: LocalizedStringKey {
        switch permissions.appleMusic {
        case .notDetermined: return "Allow access to follow what's playing."
        case .denied: return "Access is off. Enable it in Settings."
        case .granted:
            return model.sourceStatus[.appleMusic] == .connected ? "Connected. Play a song in the Music app." : "Ready"
        }
    }

    @ViewBuilder
    private var appleMusicAction: some View {
        switch permissions.appleMusic {
        case .notDetermined:
            Button("Allow") { Task { await model.requestAppleMusicAccess() } }
                .buttonStyle(SecondaryButtonStyle())
        case .denied:
            Button("Settings") { openSettings() }.buttonStyle(SecondaryButtonStyle())
        case .granted:
            Toggle("Apple Music", isOn: $settings.appleMusicEnabled).labelsHidden()
        }
    }

    private var spotifySubtitle: LocalizedStringKey {
        switch model.sourceStatus[.spotify] ?? .idle {
        case .connected: return "Connected to Spotify."
        case .connecting: return "Connecting…"
        case .needsPermission: return "Tap Connect to authorize in the Spotify app."
        case .unavailable: return AppConfig.isSpotifyConfigured ? "Couldn't connect. Open Spotify and try again." : "Add your Spotify client ID to enable this."
        default: return "Follow songs playing in Spotify."
        }
    }

    @ViewBuilder
    private var spotifyAction: some View {
        if model.sourceStatus[.spotify] == .connected {
            Toggle("Spotify", isOn: $settings.spotifyEnabled).labelsHidden()
        } else {
            Button("Connect") { model.connectSpotify() }.buttonStyle(SecondaryButtonStyle())
        }
    }

    private var shazamSubtitle: LocalizedStringKey {
        switch model.sourceStatus[.shazam] ?? .idle {
        case .listening: return "Listening for music nearby…"
        case .unavailable: return "Couldn't listen. Check microphone access."
        default: return "Identify any song playing around you."
        }
    }

    @ViewBuilder
    private var shazamAction: some View {
        if model.isShazamListening {
            Button("Stop") { model.stopShazam() }.buttonStyle(SecondaryButtonStyle())
        } else {
            Button("Listen") { Task { await model.startShazam() } }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    @ViewBuilder
    private var demoAction: some View {
        if model.isDemoRunning {
            Button("Stop") { model.stopDemo() }.buttonStyle(SecondaryButtonStyle())
        } else {
            Button("Play") { model.startDemo() }.buttonStyle(SecondaryButtonStyle())
        }
    }

    // MARK: Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lyrics everywhere").font(.headline).padding(.horizontal, 4)
            VStack(spacing: 0) {
                featureToggleRow(
                    symbol: "lock.iphone",
                    title: "Lock Screen & Dynamic Island",
                    subtitle: permissions.liveActivitiesEnabled ? "Live lyrics without opening the app." : "Live Activities are off in Settings.",
                    isPro: true
                ) {
                    Toggle("Live Activity", isOn: Binding(
                        get: { settings.liveActivityEnabled && store.isPro },
                        set: { newValue in
                            if newValue, !model.requirePro(.liveActivity) { return }
                            settings.liveActivityEnabled = newValue
                        }
                    ))
                    .labelsHidden()
                }
                divider
                featureToggleRow(
                    symbol: "square.grid.2x2",
                    title: "Widgets",
                    subtitle: "Long-press your Home Screen, tap + and add \(AppConfig.displayName).",
                    isPro: false
                ) { EmptyView() }
                divider
                featureToggleRow(
                    symbol: "car",
                    title: "CarPlay",
                    subtitle: "Lyrics appear in the CarPlay app list while you drive.",
                    isPro: true
                ) { EmptyView() }
            }
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func featureToggleRow<Trailing: View>(
        symbol: String,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        isPro: Bool,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.body.weight(.semibold))
                    if isPro && !store.isPro { ProBadge() }
                }
                Text(subtitle).font(.footnote).foregroundStyle(.white.opacity(0.65)).lineLimit(3)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
