import Foundation

/// An original song, written for this project, that lets the app run without any music service:
/// Simulator, SwiftUI previews, App Review and screenshots.
///
/// The lyrics are Spanish on purpose. LyricLive's default translation target is English, so the demo
/// shows a foreign-language song rendered into English without a network call.
public enum DemoContent {
    public static let track = TrackInfo(
        title: "Señal de Medianoche",
        artist: "LyricLive Demo",
        album: "Demo Sessions",
        duration: 96,
        source: .demo,
        externalID: "demo-midnight-signal"
    )

    public static let lrc = """
    [ti:Señal de Medianoche]
    [ar:LyricLive Demo]
    [al:Demo Sessions]
    [00:00.00]
    [00:04.00]Las luces de la ciudad susurran
    [00:08.50]Cada ventana guarda un brillo
    [00:13.00]Sigo la señal de la radio
    [00:17.50]Adondequiera que vaya la noche
    [00:22.00]
    [00:24.00]Oh, señal de medianoche, llévame
    [00:28.50]Sobre los techos y el mar
    [00:33.00]Cada palabra es una chispa
    [00:37.50]Escribo el amanecer en la oscuridad
    [00:42.00]
    [00:44.00]La estática se vuelve armonía
    [00:48.50]Desconocidos cantan a una voz
    [00:53.00]Aquí nadie está solo
    [00:57.50]Cuando la ciudad entera canta
    [01:02.00]
    [01:04.00]Oh, señal de medianoche, llévame
    [01:08.50]Sobre los techos y el mar
    [01:13.00]Cada palabra es una chispa
    [01:17.50]Escribo el amanecer en la oscuridad
    [01:22.00]Escribo el amanecer en la oscuridad
    [01:28.00]
    """

    /// English translation, one entry per line of `document.lines`. This is what US listeners see by default.
    public static var translationsEn: [String] {
        let map: [String: String] = [
            "Las luces de la ciudad susurran": "City lights are humming low",
            "Cada ventana guarda un brillo": "Every window keeps a glow",
            "Sigo la señal de la radio": "I'm following the radio",
            "Adondequiera que vaya la noche": "Wherever the night wants to go",
            "Oh, señal de medianoche, llévame": "Oh, midnight signal, carry me",
            "Sobre los techos y el mar": "Over rooftops, over the sea",
            "Cada palabra es una chispa": "Every word a little spark",
            "Escribo el amanecer en la oscuridad": "Writing sunrise on the dark",
            "La estática se vuelve armonía": "Static turns to harmony",
            "Desconocidos cantan a una voz": "Strangers sing in unison",
            "Aquí nadie está solo": "Nobody here is on their own",
            "Cuando la ciudad entera canta": "When the whole town sings along",
        ]
        return document.lines.map { map[$0.text] ?? "" }
    }

    public static var document: LyricsDocument {
        var document = LRCParser.parse(lrc, origin: .bundled)
        document.fetchedAt = Date(timeIntervalSince1970: 0)
        return document
    }
}
