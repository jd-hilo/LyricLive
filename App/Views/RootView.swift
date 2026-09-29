import SwiftUI

struct RootView: View {
    enum Tab: Hashable {
        case home, library, settings
    }

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings

    @State private var tab: Tab = .home

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)
            LibraryView()
                .tabItem { Label("Library", systemImage: "heart.text.square.fill") }
                .tag(Tab.library)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: model.track?.key)
        .fullScreenCover(isPresented: $model.isLyricsPresented) {
            LyricsScreen()
        }
        .sheet(item: rootPaywallBinding) { reason in
            PaywallView(reason: reason)
        }
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView()
        }
        .background {
            if #available(iOS 18.0, *) {
                TranslationHostView()
            }
        }
    }

    /// The paywall is presented by the lyrics screen when it is open, otherwise from here, so two presentations never collide.
    private var rootPaywallBinding: Binding<PaywallReason?> {
        Binding(
            get: { model.isLyricsPresented ? nil : model.paywallReason },
            set: { model.paywallReason = $0 }
        )
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !settings.hasCompletedOnboarding },
            set: { newValue in
                if !newValue { settings.hasCompletedOnboarding = true }
            }
        )
    }
}
