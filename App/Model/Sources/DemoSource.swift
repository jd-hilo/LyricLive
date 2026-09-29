import Foundation
import LyricCore
import UIKit

/// A built-in song with an original synced lyric sheet. Lets the whole app (widgets, Live Activity, CarPlay list,
/// share cards) be tried in the Simulator or by App Review without any music service.
@MainActor
final class DemoSource: NowPlayingSource {
    let kind: PlaybackSource = .demo
    var onUpdate: ((SourceUpdate) -> Void)?
    var onStatusChange: ((SourceStatus) -> Void)?
    var canSeek: Bool { true }

    private(set) var status: SourceStatus = .idle {
        didSet { if status != oldValue { onStatusChange?(status) } }
    }

    private var clock = PlaybackClock(anchorPosition: 0, anchorDate: Date(), rate: 0, duration: DemoContent.track.duration)
    private var loopTask: Task<Void, Never>?
    private lazy var artwork: UIImage = DemoArtwork.image()

    func start() {
        status = .connected
        clock = PlaybackClock(anchorPosition: 0, anchorDate: Date(), rate: 1, duration: DemoContent.track.duration)
        emit(withArtwork: true)
        scheduleWrap()
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        clock = clock.paused()
        status = .idle
    }

    func togglePlayPause() {
        let now = Date()
        clock = clock.isPlaying ? clock.paused(at: now) : clock.resumed(at: now)
        emit(withArtwork: false)
        scheduleWrap()
    }

    func skipNext() { restart() }
    func skipPrevious() { restart() }

    func seek(to time: TimeInterval) {
        clock = clock.seeking(to: time)
        emit(withArtwork: false)
        scheduleWrap()
    }

    private func restart() {
        clock = PlaybackClock(anchorPosition: 0, anchorDate: Date(), rate: 1, duration: DemoContent.track.duration)
        emit(withArtwork: false)
        scheduleWrap()
    }

    private func emit(withArtwork: Bool) {
        let now = Date()
        onUpdate?(SourceUpdate(
            track: DemoContent.track,
            isPlaying: clock.isPlaying,
            position: clock.position(at: now),
            artwork: withArtwork ? artwork : nil,
            timestamp: now
        ))
    }

    /// The demo loops when it reaches the end.
    private func scheduleWrap() {
        loopTask?.cancel()
        guard clock.isPlaying, let duration = clock.duration else { return }
        let remaining = max(0.1, duration - clock.position())
        loopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.restart()
        }
    }
}

/// Original artwork for the demo track, drawn in code.
enum DemoArtwork {
    static func image(size: CGFloat = 600) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let cg = context.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor(red: 0.18, green: 0.10, blue: 0.55, alpha: 1).cgColor,
                UIColor(red: 0.96, green: 0.30, blue: 0.55, alpha: 1).cgColor,
                UIColor(red: 1.00, green: 0.66, blue: 0.30, alpha: 1).cgColor,
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.6, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size, y: size), options: [])
            }

            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.16).cgColor)
            cg.setLineWidth(size * 0.012)
            for ring in 1...6 {
                let radius = size * 0.09 * CGFloat(ring)
                cg.strokeEllipse(in: CGRect(x: size * 0.5 - radius, y: size * 0.58 - radius, width: radius * 2, height: radius * 2))
            }

            let sun = size * 0.34
            cg.setFillColor(UIColor.white.withAlphaComponent(0.92).cgColor)
            cg.fillEllipse(in: CGRect(x: size * 0.5 - sun / 2, y: size * 0.34 - sun / 2, width: sun, height: sun))

            cg.setFillColor(UIColor(red: 0.12, green: 0.07, blue: 0.35, alpha: 0.85).cgColor)
            for bar in 0..<5 {
                let width = size * (0.62 - CGFloat(bar) * 0.09)
                let rect = CGRect(x: (size - width) / 2, y: size * 0.62 + CGFloat(bar) * size * 0.065, width: width, height: size * 0.035)
                cg.addPath(UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2).cgPath)
                cg.fillPath()
            }
        }
    }
}
