import LyricCore
import SwiftUI

extension PlaybackSource {
    var symbolName: String {
        switch self {
        case .appleMusic: return "music.note"
        case .spotify: return "dot.radiowaves.left.and.right"
        case .shazam: return "waveform.badge.magnifyingglass"
        case .demo: return "sparkles"
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        case .shazam: return "Shazam"
        case .demo: return "Demo"
        }
    }
}

struct SourceBadge: View {
    let source: PlaybackSource

    var body: some View {
        Label {
            Text(source.titleKey)
        } icon: {
            Image(systemName: source.symbolName)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.14), in: Capsule())
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(LinearGradient(colors: [Brand.violet, Brand.pink], startPoint: .leading, endPoint: .trailing), in: Capsule())
            .foregroundStyle(.white)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Brand.pink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.white.opacity(configuration.isPressed ? 0.22 : 0.14), in: Capsule())
    }
}

/// Persistent bar showing the current song, above the tab bar (see screenshot 2 of the reference listing).
struct MiniPlayerBar: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        if let track = model.track {
            HStack(spacing: 12) {
                ArtworkThumb(image: model.artwork, cornerRadius: 8)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Button {
                    favorites.toggleFavorite(track)
                } label: {
                    Image(systemName: favorites.isFavorite(track) ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundStyle(favorites.isFavorite(track) ? Brand.pink : .white)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel(Text("Favorite"))
                Button {
                    model.togglePlayPause()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel(Text(model.isPlaying ? "Pause" : "Play"))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    LinearGradient(colors: gradientColors(fromHex: model.palette.map(\.hex)).prefix(2).map { $0.opacity(0.35) },
                                   startPoint: .leading, endPoint: .trailing)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
            .onTapGesture { model.isLyricsPresented = true }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

extension View {
    /// Reserves room for, and shows, the mini player above the tab bar.
    func miniPlayerInset() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            MiniPlayerBar()
        }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.6))
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

/// Background used behind all tabs.
struct AppBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [Color(hex: "#1A1442"), Color(hex: "#0C0B1E")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
