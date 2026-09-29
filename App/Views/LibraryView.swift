import LyricCore
import SwiftUI

struct LibraryView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case favorites, recent
        var id: String { rawValue }
    }

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var favorites: FavoritesStore

    @State private var tab: Tab = .favorites
    @State private var selected: TrackInfo?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackdrop()
                VStack(spacing: 0) {
                    Picker("Library", selection: $tab) {
                        Text("Favorites").tag(Tab.favorites)
                        Text("Recent").tag(Tab.recent)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)

                    content
                }
            }
            .navigationTitle("Library")
            .toolbar {
                if tab == .recent, !favorites.history.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear", role: .destructive) { favorites.clearHistory() }
                    }
                }
            }
            .sheet(item: $selected) { track in
                SavedLyricsView(track: track)
            }
        }
        .miniPlayerInset()
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .favorites:
            if favorites.favorites.isEmpty {
                Spacer()
                EmptyStateView(symbol: "heart", title: "No favorites yet", message: "Tap the heart on the player to keep a song here.")
                Spacer()
            } else {
                list(favorites.favorites)
            }
        case .recent:
            if favorites.history.isEmpty {
                Spacer()
                EmptyStateView(symbol: "clock", title: "Nothing here yet", message: "Songs you play show up here.")
                Spacer()
            } else {
                list(favorites.history.map(\.track))
            }
        }
    }

    private func list(_ tracks: [TrackInfo]) -> some View {
        List {
            ForEach(tracks) { track in
                Button {
                    selected = track
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: track.source.symbolName)
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title).font(.body.weight(.semibold)).lineLimit(1)
                            Text(track.artist).font(.subheadline).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                        }
                        Spacer()
                        if favorites.isFavorite(track) {
                            Image(systemName: "heart.fill").foregroundStyle(Brand.pink)
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.06))
                .swipeActions {
                    Button {
                        favorites.toggleFavorite(track)
                    } label: {
                        Label("Favorite", systemImage: favorites.isFavorite(track) ? "heart.slash" : "heart")
                    }
                    .tint(Brand.pink)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

/// Read-only lyrics of a saved song.
struct SavedLyricsView: View {
    let track: TrackInfo

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var result: LyricsResult?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch result {
                    case nil:
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    case .found(let document):
                        ForEach(document.lines) { line in
                            Text(line.isGap ? " " : line.text)
                                .font(.system(size: 20, weight: .semibold))
                        }
                    case .instrumental:
                        EmptyStateView(symbol: "pianokeys", title: "Instrumental", message: "This song has no lyrics.")
                    case .notFound:
                        EmptyStateView(symbol: "text.magnifyingglass", title: "No lyrics found", message: "We couldn't find lyrics for this song.")
                    case .failed:
                        EmptyStateView(symbol: "wifi.exclamationmark", title: "Couldn't load lyrics", message: "Check your connection and try again.")
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(track.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { result = await model.lyrics(for: track) }
        }
    }
}
