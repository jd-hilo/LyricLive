import Foundation

/// An original song, written for this project, that lets the app run without any music service:
/// Simulator, SwiftUI previews, App Review and screenshots.
public enum DemoContent {
    public static let track = TrackInfo(
        title: "Midnight Signal",
        artist: "LyricLive Demo",
        album: "Demo Sessions",
        duration: 96,
        source: .demo,
        externalID: "demo-midnight-signal"
    )

    public static let lrc = """
    [ti:Midnight Signal]
    [ar:LyricLive Demo]
    [al:Demo Sessions]
    [00:00.00]
    [00:04.00]City lights are humming low
    [00:08.50]Every window keeps a glow
    [00:13.00]I'm following the radio
    [00:17.50]Wherever the night wants to go
    [00:22.00]
    [00:24.00]Oh, midnight signal, carry me
    [00:28.50]Over rooftops, over sea
    [00:33.00]Every word a little spark
    [00:37.50]Writing sunrise on the dark
    [00:42.00]
    [00:44.00]Static turns to harmony
    [00:48.50]Strangers sing in unison
    [00:53.00]Nobody here is on their own
    [00:57.50]When the whole town sings along
    [01:02.00]
    [01:04.00]Oh, midnight signal, carry me
    [01:08.50]Over rooftops, over sea
    [01:13.00]Every word a little spark
    [01:17.50]Writing sunrise on the dark
    [01:22.00]Writing sunrise on the dark
    [01:28.00]
    """

    /// Traditional Chinese translation, one entry per line of `document.lines`.
    public static var translationsZhHant: [String] {
        let map: [String: String] = [
            "City lights are humming low": "城市的燈光輕輕哼唱",
            "Every window keeps a glow": "每一扇窗都留著微光",
            "I'm following the radio": "我跟著收音機的訊號",
            "Wherever the night wants to go": "去往夜晚想去的地方",
            "Oh, midnight signal, carry me": "噢，午夜的訊號，帶我走吧",
            "Over rooftops, over sea": "越過屋頂，越過海洋",
            "Every word a little spark": "每個字都是一點火花",
            "Writing sunrise on the dark": "在黑暗中寫下日出",
            "Static turns to harmony": "雜音化作和聲",
            "Strangers sing in unison": "陌生人齊聲歌唱",
            "Nobody here is on their own": "這裡沒有人孤單",
            "When the whole town sings along": "當整座城市一起合唱",
        ]
        return document.lines.map { map[$0.text] ?? "" }
    }

    public static var document: LyricsDocument {
        var document = LRCParser.parse(lrc, origin: .bundled)
        document.fetchedAt = Date(timeIntervalSince1970: 0)
        return document
    }
}
