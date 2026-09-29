import LyricCore
import SwiftUI

enum ShareCardStyle: String, CaseIterable, Identifiable {
    case artwork, midnight, sunrise, paper

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .artwork: return "Artwork"
        case .midnight: return "Midnight"
        case .sunrise: return "Sunrise"
        case .paper: return "Paper"
        }
    }

    var requiresPro: Bool { self != .artwork }
}

enum ShareCardAspect: String, CaseIterable, Identifiable {
    case square, story

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .square: return CGSize(width: 360, height: 360)
        case .story: return CGSize(width: 360, height: 640)
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .square: return "Square"
        case .story: return "Story"
        }
    }
}

/// The image that gets shared. Rendered off-screen with `ImageRenderer`, so it must not depend on the environment.
struct ShareCardView: View {
    let title: String
    let artist: String
    let lines: [String]
    let translations: [String]
    let artwork: UIImage?
    let paletteHex: [String]
    let style: ShareCardStyle
    let aspect: ShareCardAspect
    let watermark: String?

    private var colors: [Color] { gradientColors(fromHex: paletteHex) }

    private var foreground: Color { style == .paper ? Color(hex: "#1B1B22") : .white }

    var body: some View {
        ZStack {
            background
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(line)
                                .font(.system(size: fontSize, weight: .bold))
                            if index < translations.count, !translations[index].isEmpty {
                                Text(translations[index])
                                    .font(.system(size: fontSize * 0.62, weight: .semibold))
                                    .opacity(0.72)
                            }
                        }
                    }
                }
                .foregroundStyle(foreground)
                .minimumScaleFactor(0.6)

                Spacer(minLength: 16)

                HStack(spacing: 10) {
                    ArtworkThumb(image: artwork, cornerRadius: 8)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 14, weight: .bold)).lineLimit(1)
                        Text(artist).font(.system(size: 12)).opacity(0.7).lineLimit(1)
                    }
                    .foregroundStyle(foreground)
                    Spacer()
                    if let watermark {
                        Text(watermark)
                            .font(.system(size: 10, weight: .semibold))
                            .opacity(0.6)
                            .foregroundStyle(foreground)
                    }
                }
            }
            .padding(26)
        }
        .frame(width: aspect.size.width, height: aspect.size.height)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    private var fontSize: CGFloat {
        let count = max(lines.count, 1)
        let base: CGFloat = aspect == .square ? 30 : 34
        return max(18, base - CGFloat(count - 1) * 2.5)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .artwork:
            ZStack {
                (colors.first ?? Brand.violet)
                LinearGradient(colors: colors.map { $0.opacity(0.85) }, startPoint: .topLeading, endPoint: .bottomTrailing)
                if let artwork {
                    Image(uiImage: artwork).resizable().scaledToFill().blur(radius: 40).opacity(0.45)
                }
                Color.black.opacity(0.28)
            }
        case .midnight:
            LinearGradient(colors: [Color(hex: "#1A1442"), Color(hex: "#0C0B1E")], startPoint: .top, endPoint: .bottom)
        case .sunrise:
            LinearGradient(colors: [Color(hex: "#5B3DF5"), Color(hex: "#FF4F8B"), Color(hex: "#FFA84D")], startPoint: .bottomLeading, endPoint: .topTrailing)
        case .paper:
            Color(hex: "#F5F1E8")
        }
    }
}

/// Pick lines, style and format, then share the rendered card.
struct ShareLyricsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<Int> = []
    @State private var style: ShareCardStyle = .artwork
    @State private var aspect: ShareCardAspect = .square
    @State private var rendered: UIImage?

    private let maxLines = 6

    private var lines: [LyricLine] {
        model.document?.lines.filter { !$0.isGap } ?? []
    }

    private var selectedLines: [LyricLine] {
        lines.filter { selected.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                preview
                    .padding(.vertical, 12)

                Picker("Style", selection: Binding(
                    get: { style },
                    set: { newValue in
                        if newValue.requiresPro && !store.isPro {
                            dismiss()
                            model.requirePro(.shareCardsNoWatermark, after: 0.5)
                        } else {
                            style = newValue
                        }
                    }
                )) {
                    ForEach(ShareCardStyle.allCases) { Text($0.titleKey).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Picker("Format", selection: $aspect) {
                    ForEach(ShareCardAspect.allCases) { Text($0.titleKey).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                Text("Select up to \(maxLines) lines")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)

                List(lines) { line in
                    Button {
                        toggle(line.id)
                    } label: {
                        HStack {
                            Image(systemName: selected.contains(line.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(line.id) ? Brand.pink : .secondary)
                            Text(line.text).foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Share lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if let rendered {
                        ShareLink(
                            item: Image(uiImage: rendered),
                            preview: SharePreview(model.track?.title ?? "Lyrics", image: Image(uiImage: rendered))
                        ) {
                            Text("Share")
                        }
                    } else {
                        Text("Share").foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear(perform: preselect)
            .onChange(of: selected) { _, _ in render() }
            .onChange(of: style) { _, _ in render() }
            .onChange(of: aspect) { _, _ in render() }
        }
    }

    private var card: ShareCardView {
        let chosen = selectedLines
        let translations: [String] = chosen.map { line in
            guard let all = model.translations, all.indices.contains(line.id) else { return "" }
            return all[line.id]
        }
        return ShareCardView(
            title: model.track?.title ?? "",
            artist: model.track?.artist ?? "",
            lines: chosen.map(\.text),
            translations: model.settings.showTranslation ? translations : [],
            artwork: model.artwork,
            paletteHex: model.palette.map(\.hex),
            style: style,
            aspect: aspect,
            watermark: store.isPro ? nil : AppConfig.displayName
        )
    }

    private var preview: some View {
        card
            .scaleEffect(previewScale)
            .frame(width: aspect.size.width * previewScale, height: aspect.size.height * previewScale)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    private var previewScale: CGFloat {
        aspect == .square ? 0.62 : 0.4
    }

    private func toggle(_ id: Int) {
        if selected.contains(id) {
            selected.remove(id)
        } else if selected.count < maxLines {
            selected.insert(id)
        }
    }

    private func preselect() {
        if selected.isEmpty {
            if let current = model.currentIndex, lines.contains(where: { $0.id == current }) {
                selected = [current]
            } else if let first = lines.first {
                selected = [first.id]
            }
        }
        render()
    }

    private func render() {
        guard !selected.isEmpty else {
            rendered = nil
            return
        }
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        rendered = renderer.uiImage
    }
}
