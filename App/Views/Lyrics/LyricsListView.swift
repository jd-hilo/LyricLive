import LyricCore
import SwiftUI

struct LyricStyle {
    let scale: Double
    let design: Font.Design
    let alignment: LyricAlignment

    @MainActor
    init(settings: AppSettings, isPro: Bool) {
        scale = settings.fontScale
        design = (settings.fontStyle.requiresPro && !isPro ? LyricFontStyle.system : settings.fontStyle).design
        alignment = settings.alignment
    }

    func lineFont(large: Bool) -> Font {
        .system(size: (large ? 38 : 34) * scale, weight: .bold, design: design)
    }

    func translationFont(large: Bool) -> Font {
        .system(size: (large ? 22 : 20) * scale, weight: .semibold, design: design)
    }
}

/// One lyric line plus its optional translation.
struct LyricLineView: View {
    let line: LyricLine
    let translation: String?
    let distance: Int?
    let isCurrent: Bool
    let style: LyricStyle
    var large = false

    private var opacity: Double {
        guard let distance else { return 0.9 }
        if isCurrent { return 1 }
        return max(0.22, 0.5 - Double(distance - 1) * 0.08)
    }

    private var blur: CGFloat {
        guard let distance, !isCurrent else { return 0 }
        return min(CGFloat(distance - 1), 3) * 0.7
    }

    var body: some View {
        VStack(alignment: style.alignment.horizontal, spacing: 6) {
            if line.isGap {
                Text("♪")
                    .font(style.lineFont(large: large))
            } else {
                Text(line.text)
                    .font(style.lineFont(large: large))
            }
            if let translation, !translation.isEmpty, !line.isGap {
                Text(translation)
                    .font(style.translationFont(large: large))
                    .opacity(isCurrent ? 0.72 : 0.9)
            }
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(style.alignment.text)
        .frame(maxWidth: .infinity, alignment: style.alignment.frame)
        .scaleEffect(isCurrent || distance == nil ? 1 : 0.94, anchor: style.alignment.unit)
        .opacity(opacity)
        .blur(radius: blur)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: isCurrent)
        .contentShape(Rectangle())
    }
}

/// Auto-scrolling synced lyrics. Tap a line to seek; dragging pauses auto-scroll for a few seconds.
struct LyricsListView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: StoreManager

    var large = false

    @State private var isUserScrolling = false
    @State private var resumeTask: Task<Void, Never>?

    private let scrollAnchor = UnitPoint(x: 0.5, y: 0.32)

    var body: some View {
        let style = LyricStyle(settings: settings, isPro: store.isPro)
        Group {
            switch model.lyricsState {
            case .idle:
                EmptyStateView(symbol: "music.note", title: "Nothing playing", message: "Start a song and its lyrics will appear here.")
            case .loading:
                VStack(spacing: 14) {
                    ProgressView().tint(.white)
                    Text("Finding lyrics…").font(.subheadline).foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .instrumental:
                EmptyStateView(symbol: "pianokeys", title: "Instrumental", message: "This song has no lyrics.")
            case .notFound:
                VStack(spacing: 16) {
                    EmptyStateView(symbol: "text.magnifyingglass", title: "No lyrics found", message: "We couldn't find lyrics for this song.")
                    Button("Try again") { model.retryLyrics() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .frame(maxHeight: .infinity)
            case .failed:
                VStack(spacing: 16) {
                    EmptyStateView(symbol: "wifi.exclamationmark", title: "Couldn't load lyrics", message: "Check your connection and try again.")
                    Button("Try again") { model.retryLyrics() }
                        .buttonStyle(SecondaryButtonStyle())
                }
                .frame(maxHeight: .infinity)
            case .ready:
                if let document = model.document {
                    lyricsScroll(document: document, style: style)
                }
            }
        }
    }

    @ViewBuilder
    private func lyricsScroll(document: LyricsDocument, style: LyricStyle) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if !document.isSynced {
                        Label("These lyrics aren't time-synced.", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: style.alignment.frame)
                    }
                    ForEach(document.lines) { line in
                        LyricLineView(
                            line: line,
                            translation: translation(for: line.id),
                            distance: distance(of: line.id, synced: document.isSynced),
                            isCurrent: document.isSynced && model.currentIndex == line.id,
                            style: style,
                            large: large
                        )
                        .id(line.id)
                        .onTapGesture {
                            if document.isSynced { model.seek(toLine: line.id) }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 80)
                .padding(.bottom, 260)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 6).onChanged { _ in userDidScroll() }
            )
            .onChange(of: model.currentIndex) { _, index in
                guard let index, !isUserScrolling, document.isSynced else { return }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) {
                    proxy.scrollTo(index, anchor: scrollAnchor)
                }
            }
            .onAppear {
                if let index = model.currentIndex, document.isSynced {
                    proxy.scrollTo(index, anchor: scrollAnchor)
                }
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.08),
                        .init(color: .black, location: 0.92),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private func translation(for index: Int) -> String? {
        guard settings.showTranslation, let translations = model.translations, translations.indices.contains(index) else { return nil }
        return translations[index]
    }

    private func distance(of index: Int, synced: Bool) -> Int? {
        guard synced else { return nil }
        guard let current = model.currentIndex else { return index + 1 }
        return abs(index - current)
    }

    private func userDidScroll() {
        isUserScrolling = true
        resumeTask?.cancel()
        resumeTask = Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            isUserScrolling = false
        }
    }
}
