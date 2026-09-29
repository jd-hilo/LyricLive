import LyricCore
import SwiftUI

/// Full-screen synced lyrics: artwork-tinted animated background, large bold current line, dimmed neighbours,
/// optional translation under each line, transport controls and a language menu.
struct LyricsScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(\.dismiss) private var dismiss

    @State private var showOptions = false
    @State private var showShare = false
    @State private var showSearch = false

    var body: some View {
        GeometryReader { proxy in
            let landscape = proxy.size.width > proxy.size.height
            ZStack {
                LyricBackground()
                if landscape {
                    landscapeLayout(height: proxy.size.height)
                } else {
                    portraitLayout
                }
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showOptions) {
            LyricOptionsSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShare) {
            ShareLyricsView()
        }
        .sheet(isPresented: $showSearch) {
            LyricSearchView()
        }
        .sheet(item: paywallBinding) { reason in
            PaywallView(reason: reason)
        }
    }

    private var paywallBinding: Binding<PaywallReason?> {
        Binding(
            get: { (showOptions || showShare || showSearch) ? nil : model.paywallReason },
            set: { model.paywallReason = $0 }
        )
    }

    // MARK: Layouts

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            HStack {
                closeButton
                Spacer()
                moreMenu
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            LyricsListView()
            bottomCard
        }
    }

    private func landscapeLayout(height: CGFloat) -> some View {
        HStack(spacing: 24) {
            VStack(spacing: 20) {
                ArtworkThumb(image: model.artwork, cornerRadius: 16)
                    .frame(width: min(height * 0.5, 200), height: min(height * 0.5, 200))
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                VStack(spacing: 2) {
                    Text(model.track?.title ?? "").font(.headline).lineLimit(1)
                    Text(model.track?.artist ?? "").font(.subheadline).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                }
                TransportControls(compact: true)
                HStack(spacing: 28) {
                    translationMenu
                    Button { showOptions = true } label: { Image(systemName: "slider.horizontal.3") }
                }
                .font(.system(size: 20))
            }
            .frame(width: 240)
            .padding(.leading, 40)
            .overlay(alignment: .topLeading) { closeButton.padding(.leading, 20).padding(.top, 8) }

            LyricsListView(large: true)
        }
    }

    // MARK: Pieces

    /// Bottom identity bar from the full-screen lyrics screenshot: artwork, title, artist, heart.
    private var nowPlayingIdentity: some View {
        HStack(spacing: 12) {
            ArtworkThumb(image: model.artwork, cornerRadius: 8)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.track?.title ?? "")
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                Text(model.track?.artist ?? "")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let track = model.track {
                Button {
                    favorites.toggleFavorite(track)
                } label: {
                    Image(systemName: favorites.isFavorite(track) ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundStyle(favorites.isFavorite(track) ? Brand.pink : .white)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel(Text("Favorite"))
            }
        }
    }

    private var bottomCard: some View {
        VStack(spacing: 6) {
            ProgressScrubber()
            nowPlayingIdentity
            bottomBar
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    private var moreMenu: some View {
        Menu {
            if let track = model.track {
                Button {
                    favorites.toggleFavorite(track)
                } label: {
                    Label(favorites.isFavorite(track) ? "Remove from favorites" : "Add to favorites",
                          systemImage: favorites.isFavorite(track) ? "heart.slash" : "heart")
                }
            }
            Button { showOptions = true } label: { Label("Lyric options", systemImage: "slider.horizontal.3") }
            Button { showSearch = true } label: { Label("Find other lyrics", systemImage: "magnifyingglass") }
            Button { showShare = true } label: { Label("Share lyrics", systemImage: "square.and.arrow.up") }
                .disabled(model.document == nil)
            Divider()
            Button { dismiss() } label: { Label("Close", systemImage: "xmark") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.14), in: Circle())
        }
        .accessibilityLabel(Text("More"))
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.14), in: Circle())
        }
        .accessibilityLabel(Text("Close"))
    }

    private var bottomBar: some View {
        HStack {
            translationMenu
                .frame(width: 60, alignment: .leading)
            Spacer()
            TransportControls()
            Spacer()
            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 20, weight: .medium))
            }
            .frame(width: 60, alignment: .trailing)
            .accessibilityLabel(Text("Find other lyrics"))
        }
    }

    private var translationMenu: some View {
        Menu {
            Toggle(isOn: $settings.showTranslation) {
                Label("Show translation", systemImage: "character.bubble")
            }
            Picker("Translate to", selection: $settings.translationLanguage) {
                ForEach(TranslationLanguages.all) { language in
                    Text("\(language.nativeName) (\(language.code))").tag(language.code)
                }
            }
            if !store.isPro {
                Text("\(model.translationsRemainingToday) free translations left today")
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: settings.showTranslation ? "character.bubble.fill" : "character.bubble")
                    .font(.system(size: 22, weight: .medium))
                if model.translationStatus == .working {
                    ProgressView().controlSize(.mini).tint(.white).offset(x: 10, y: -8)
                }
            }
        }
        .accessibilityLabel(Text("Translation"))
    }
}

/// Offset, font, alignment and background controls.
struct LyricOptionsSheet: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Timing") {
                    Stepper(value: Binding(get: { model.trackOffsetMs }, set: { model.trackOffsetMs = $0 }), in: -10_000...10_000, step: 100) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Offset for this song")
                            Text(offsetLabel(model.trackOffsetMs)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("Positive values show lyrics earlier, negative values later.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Appearance") {
                    LyricAppearanceControls()
                }

                if let status = statusMessage {
                    Section("Translation") { Text(status).font(.footnote) }
                }
            }
            .navigationTitle("Lyric options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func offsetLabel(_ ms: Int) -> String {
        let seconds = Double(ms) / 1000
        return String(format: "%+.1f s", seconds)
    }

    private var statusMessage: LocalizedStringKey? {
        switch model.translationStatus {
        case .sameLanguage: return "The lyrics are already in the selected language."
        case .quotaReached: return "You've used today's free translations."
        case .unavailable: return "On-device translation needs iOS 18 or later."
        case .failed: return "Translation failed. Make sure the language pack is downloaded."
        default: return nil
        }
    }
}

/// Font size / style / alignment / background pickers, shared by the sheet and Settings.
struct LyricAppearanceControls: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "textformat.size.smaller")
                Slider(value: $settings.fontScale, in: 0.75...1.6, step: 0.05)
                Image(systemName: "textformat.size.larger")
            }
            Text("Font size").font(.caption).foregroundStyle(.secondary)
        }

        Picker("Alignment", selection: $settings.alignment) {
            ForEach(LyricAlignment.allCases) { alignment in
                Image(systemName: alignment.symbol).tag(alignment)
            }
        }
        .pickerStyle(.segmented)

        Picker("Font style", selection: Binding(
            get: { settings.fontStyle },
            set: { newValue in
                if newValue.requiresPro && !store.isPro {
                    dismiss()
                    model.requirePro(.premiumBackgrounds, after: 0.5)
                } else {
                    settings.fontStyle = newValue
                }
            }
        )) {
            ForEach(LyricFontStyle.allCases) { style in
                Text(style.titleKey).tag(style)
            }
        }

        Picker("Background", selection: Binding(
            get: { settings.backgroundStyle },
            set: { newValue in
                if newValue.requiresPro && !store.isPro {
                    dismiss()
                    model.requirePro(.premiumBackgrounds, after: 0.5)
                } else {
                    settings.backgroundStyle = newValue
                }
            }
        )) {
            ForEach(LyricBackgroundStyle.allCases) { style in
                Text(style.titleKey).tag(style)
            }
        }
    }
}

/// Manual lyric search against LRCLIB, for songs whose automatic match is wrong or missing.
struct LyricSearchView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [LRCLibRecord] = []
    @State private var isSearching = false
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if hasSearched && results.isEmpty {
                    Text("No results").foregroundStyle(.secondary)
                }
                ForEach(results, id: \.id) { record in
                    Button {
                        Task {
                            await model.adoptLyrics(record)
                            dismiss()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.trackName ?? "").font(.headline)
                            HStack {
                                Text([record.artistName, record.albumName].compactMap { $0 }.joined(separator: " · "))
                                Spacer()
                                if record.hasSyncedLyrics {
                                    Label("Synced", systemImage: "checkmark.circle.fill").labelStyle(.titleAndIcon)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("Plain")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Find other lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Song and artist"))
            .onSubmit(of: .search) { runSearch() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear {
                if query.isEmpty, let track = model.track {
                    query = "\(track.title) \(track.artist)"
                    runSearch()
                }
            }
        }
    }

    private func runSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        Task {
            results = await model.searchLyrics(query: trimmed)
            isSearching = false
            hasSearched = true
        }
    }
}
