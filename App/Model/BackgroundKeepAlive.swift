import AVFoundation
import Foundation

/// Optional: plays inaudible audio (mixed with other apps) so iOS keeps the app running while the phone is locked,
/// which lets the Live Activity and CarPlay list keep advancing. Needs the `audio` background mode.
/// Apple may question this in App Review; it is opt-in and off by default.
@MainActor
final class BackgroundKeepAlive {
    private var player: AVAudioPlayer?
    private var interruptionObserver: NSObjectProtocol?

    var isActive: Bool { player?.isPlaying ?? false }

    func start() {
        guard player == nil else {
            if player?.isPlaying == false { player?.play() }
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(data: Self.silentWAV())
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            player = nil
            return
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor in
                guard let self, rawType == AVAudioSession.InterruptionType.ended.rawValue else { return }
                try? AVAudioSession.sharedInstance().setActive(true)
                self.player?.play()
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
            self.interruptionObserver = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// One second of 8 kHz mono 16-bit silence as an in-memory WAV file.
    private static func silentWAV() -> Data {
        let sampleRate: UInt32 = 8000
        let dataSize: UInt32 = sampleRate * 2
        var data = Data()
        func append(_ string: String) { data.append(contentsOf: Array(string.utf8)) }
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        append("RIFF"); append32(36 + dataSize); append("WAVE")
        append("fmt "); append32(16); append16(1); append16(1)
        append32(sampleRate); append32(sampleRate * 2); append16(2); append16(16)
        append("data"); append32(dataSize)
        data.append(Data(count: Int(dataSize)))
        return data
    }
}
