import LyricCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var permissions: PermissionsManager

    @State private var restoreMessage: LocalizedStringKey?
    @State private var cacheSize = 0
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            Form {
                proSection
                lyricsSection
                translationSection
                timingSection
                sourcesSection
                liveActivitySection
                dataSection
                aboutSection
                #if DEBUG
                debugSection
                #endif
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(AppBackdrop())
            .onAppear { cacheSize = model.cacheSizeBytes }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(isReplay: true)
            }
        }
        .miniPlayerInset()
    }

    // MARK: Sections

    private var proSection: some View {
        Section {
            if store.isPro {
                Label {
                    Text("\(AppConfig.displayName) Pro is active")
                } icon: {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Brand.pink)
                }
                Button("Manage subscription") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                Button {
                    model.paywallReason = .general
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Upgrade to Pro").font(.headline)
                            Text("Live Activity, all widgets, CarPlay, Spotify, Shazam and more.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
            }
            Button("Restore purchases") {
                Task {
                    let outcome = await store.restore()
                    switch outcome {
                    case .success: restoreMessage = "Purchases restored."
                    default: restoreMessage = "No previous purchases were found."
                    }
                }
            }
            if let restoreMessage {
                Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var lyricsSection: some View {
        Section("Lyrics") {
            LyricAppearanceControls()
            Button("Reset appearance") { settings.resetLooks() }
        }
    }

    private var translationSection: some View {
        Section {
            Toggle("Show translation", isOn: $settings.showTranslation)
            Picker("Translate to", selection: $settings.translationLanguage) {
                ForEach(TranslationLanguages.all) { language in
                    Text("\(language.displayName()) (\(language.code))").tag(language.code)
                }
            }
            if !store.isPro {
                Text("\(model.translationsRemainingToday) free translations left today")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Translation")
        } footer: {
            Text("Songs in other languages translate into English on your iPhone (iOS 18 or later). You can pick another language below. Language packs download the first time you use them.")
        }
    }

    private var timingSection: some View {
        Section {
            Stepper(value: $settings.globalOffsetMs, in: -5000...5000, step: 100) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Global lyric offset")
                    Text(String(format: "%+.1f s", Double(settings.globalOffsetMs) / 1000))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Timing")
        } footer: {
            Text("Positive values show lyrics earlier. You can also adjust a single song from the lyrics screen.")
        }
    }

    private var sourcesSection: some View {
        Section("Sources") {
            Toggle(isOn: $settings.appleMusicEnabled) {
                Label("Apple Music", systemImage: PlaybackSource.appleMusic.symbolName)
            }
            Toggle(isOn: Binding(
                get: { settings.spotifyEnabled && store.isPro },
                set: { newValue in
                    if newValue, !model.requirePro(.spotify) { return }
                    settings.spotifyEnabled = newValue
                }
            )) {
                HStack { Label("Spotify", systemImage: PlaybackSource.spotify.symbolName); if !store.isPro { ProBadge() } }
            }
            Toggle(isOn: $settings.shazamEnabled) {
                HStack { Label("Shazam mode", systemImage: PlaybackSource.shazam.symbolName); if !store.isPro { ProBadge() } }
            }
            permissionRow("Apple Music access", status: permissions.appleMusic)
            permissionRow("Microphone access", status: permissions.microphone)
        }
    }

    private func permissionRow(_ title: LocalizedStringKey, status: PermissionStatus) -> some View {
        HStack {
            Text(title)
            Spacer()
            switch status {
            case .granted: Text("On").foregroundStyle(.green)
            case .denied:
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            case .notDetermined: Text("Not asked").foregroundStyle(.secondary)
            }
        }
    }

    private var liveActivitySection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings.liveActivityEnabled && store.isPro },
                set: { newValue in
                    if newValue, !model.requirePro(.liveActivity) { return }
                    settings.liveActivityEnabled = newValue
                }
            )) {
                HStack { Text("Lock Screen & Dynamic Island"); if !store.isPro { ProBadge() } }
            }
            Toggle("Keep lyrics updating in the background", isOn: $settings.keepAliveInBackground)
        } header: {
            Text("Live Activity")
        } footer: {
            Text("iOS suspends apps shortly after you leave them. This option plays inaudible audio, mixed with your music, so the Lock Screen lyrics keep advancing. It uses a little more battery.")
        }
    }

    private var dataSection: some View {
        Section("Data") {
            HStack {
                Text("Lyrics cache")
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: Int64(cacheSize), countStyle: .file))
                    .foregroundStyle(.secondary)
            }
            Button("Clear lyrics cache", role: .destructive) {
                model.clearLyricsCache()
                cacheSize = model.cacheSizeBytes
            }
            Button("Show welcome tour again") { showOnboarding = true }
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(AppConfig.version).foregroundStyle(.secondary)
            }
            Link("Privacy policy", destination: AppConfig.privacyURL)
            Link("Terms of use", destination: AppConfig.termsURL)
            Link("Contact support", destination: URL(string: "mailto:\(AppConfig.supportEmail)")!)
        } header: {
            Text("About")
        } footer: {
            Text("Lyrics are provided by LRCLIB, a community-run database. Translation happens on your device. \(AppConfig.displayName) has no accounts and no analytics.")
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section("Debug") {
            Toggle("Unlock Pro (debug only)", isOn: $store.debugProOverride)
        }
    }
    #endif
}
