import SwiftUI

@main
struct LyricLiveApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(model.settings)
                .environmentObject(model.store)
                .environmentObject(model.favorites)
                .environmentObject(model.permissions)
                .tint(Brand.pink)
                .preferredColorScheme(.dark)
                .onOpenURL { model.handle(url: $0) }
                .task { model.start() }
                .onChange(of: scenePhase) { _, phase in
                    model.handleScenePhase(phase)
                }
        }
    }
}
