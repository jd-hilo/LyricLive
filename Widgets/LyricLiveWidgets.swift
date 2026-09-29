import SwiftUI
import WidgetKit

@main
struct LyricLiveWidgets: WidgetBundle {
    var body: some Widget {
        LyricWidget()
        NowPlayingWidget()
        LyricLiveActivity()
    }
}
