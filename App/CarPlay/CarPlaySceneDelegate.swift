import CarPlay
import LyricCore
import UIKit

/// CarPlay scene entry point. Requires the `com.apple.developer.carplay-audio` entitlement granted by Apple
/// (see README), otherwise CarPlay never connects this scene.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        Task { @MainActor in
            CarPlayLyricsController.shared.connect(interfaceController)
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        Task { @MainActor in
            CarPlayLyricsController.shared.disconnect()
        }
    }
}

/// Builds the CarPlay UI. Audio-category CarPlay apps are limited to list, grid and now-playing templates, so lyrics
/// are shown as a list whose rows advance with the song: previous line, the current line (with its translation as
/// detail text) and the next lines.
@MainActor
final class CarPlayLyricsController {
    static let shared = CarPlayLyricsController()

    private var interfaceController: CPInterfaceController?
    private var lyricsTemplate: CPListTemplate?
    private var controlsTemplate: CPListTemplate?
    private var observer: NSObjectProtocol?
    private var lastRenderedKey = ""

    private var model: AppModel { AppModel.shared }

    func connect(_ interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController

        let lyrics = CPListTemplate(title: String(localized: "Lyrics"), sections: buildLyricsSections())
        lyrics.tabTitle = String(localized: "Lyrics")
        lyrics.tabImage = UIImage(systemName: "text.quote")
        lyricsTemplate = lyrics

        let controls = CPListTemplate(title: String(localized: "Controls"), sections: buildControlSections())
        controls.tabTitle = String(localized: "Controls")
        controls.tabImage = UIImage(systemName: "playpause.fill")
        controlsTemplate = controls

        let tabBar = CPTabBarTemplate(templates: [lyrics, controls])
        interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)

        observer = NotificationCenter.default.addObserver(forName: .lyricStateDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func disconnect() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        interfaceController = nil
        lyricsTemplate = nil
        controlsTemplate = nil
    }

    private func refresh() {
        let window = model.window
        let key = "\(model.track?.key ?? "-")|\(model.currentIndex ?? -1)|\(model.isPlaying)|\(window.current?.translation ?? "")|\(model.isPro)"
        guard key != lastRenderedKey else { return }
        lastRenderedKey = key
        lyricsTemplate?.updateSections(buildLyricsSections())
        controlsTemplate?.updateSections(buildControlSections())
    }

    // MARK: Lyrics tab

    private func buildLyricsSections() -> [CPListSection] {
        guard model.isPro else {
            let item = CPListItem(
                text: String(localized: "LyricLive Pro required"),
                detailText: String(localized: "Open LyricLive on your iPhone to unlock CarPlay lyrics.")
            )
            return [CPListSection(items: [item])]
        }
        guard let track = model.track else {
            let item = CPListItem(
                text: String(localized: "Nothing playing"),
                detailText: String(localized: "Start a song in Apple Music or Spotify.")
            )
            return [CPListSection(items: [item])]
        }

        let window = model.window
        var items: [CPListItem] = []

        if let previous = window.previous.last, !previous.isGap {
            items.append(listItem(previous, isCurrent: false))
        }
        if let current = window.current {
            items.append(listItem(current, isCurrent: true))
        } else if model.lyricsState == .loading {
            items.append(CPListItem(text: String(localized: "Finding lyrics…"), detailText: nil))
        } else if model.document?.isSynced != true {
            items.append(CPListItem(text: String(localized: "No synced lyrics for this song"), detailText: nil))
        } else {
            items.append(CPListItem(text: "♪", detailText: nil))
        }
        for upcoming in window.upcoming.prefix(3) where !upcoming.isGap {
            items.append(listItem(upcoming, isCurrent: false))
        }

        return [CPListSection(items: items, header: "\(track.title) · \(track.artist)", sectionIndexTitle: nil)]
    }

    private func listItem(_ entry: LyricWindow.Entry, isCurrent: Bool) -> CPListItem {
        let item = CPListItem(text: entry.text, detailText: entry.translation)
        item.isPlaying = isCurrent
        return item
    }

    // MARK: Controls tab

    private func buildControlSections() -> [CPListSection] {
        func row(_ title: String, _ symbol: String, _ command: PlaybackCommand) -> CPListItem {
            let item = CPListItem(text: title, detailText: nil, image: UIImage(systemName: symbol))
            item.handler = { _, completion in
                Task { @MainActor in
                    PlaybackCommandBus.shared.send(command)
                    completion()
                }
            }
            return item
        }
        let playTitle = model.isPlaying ? String(localized: "Pause") : String(localized: "Play")
        let translationTitle = model.settings.showTranslation
            ? String(localized: "Hide translation")
            : String(localized: "Show translation")
        return [CPListSection(items: [
            row(playTitle, model.isPlaying ? "pause.fill" : "play.fill", .togglePlayPause),
            row(String(localized: "Next song"), "forward.fill", .next),
            row(String(localized: "Previous song"), "backward.fill", .previous),
            row(translationTitle, "character.bubble", .toggleTranslation),
        ])]
    }
}
