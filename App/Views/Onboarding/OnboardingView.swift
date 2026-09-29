import SwiftUI

/// First-run flow: welcome, Apple Music access, microphone for Shazam, notifications and Live Activities.
struct OnboardingView: View {
    var isReplay = false

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var permissions: PermissionsManager
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0
    private let lastPage = 3

    var body: some View {
        ZStack {
            AppBackdrop()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") { finish() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .opacity(page == lastPage ? 0 : 1)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                TabView(selection: $page) {
                    welcomePage.tag(0)
                    musicPage.tag(1)
                    microphonePage.tag(2)
                    notificationsPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0...lastPage, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Color.white : Color.white.opacity(0.3))
                            .frame(width: index == page ? 22 : 8, height: 8)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
                .padding(.bottom, 18)
            }
        }
        .foregroundStyle(.white)
        .interactiveDismissDisabled(!isReplay)
        .task { await permissions.refresh() }
    }

    // MARK: Pages

    private var welcomePage: some View {
        OnboardingPage(
            symbol: "text.quote",
            title: "Lyrics that follow the music",
            message: "Time-synced lyrics for whatever you're playing, on your Lock Screen, Dynamic Island, widgets and in the car.",
            bullets: [
                ("character.bubble", "Translate lyrics on your device"),
                ("lock.iphone", "Live lyrics on the Lock Screen"),
                ("square.grid.2x2", "Home Screen and Lock Screen widgets"),
                ("car", "Lyrics in CarPlay"),
            ]
        ) {
            Button("Get started") { withAnimation { page = 1 } }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var musicPage: some View {
        OnboardingPage(
            symbol: "music.note",
            title: "Connect your music",
            message: "Allow access to Apple Music so we can see which song is playing. Spotify can be connected later from the Home tab.",
            bullets: []
        ) {
            VStack(spacing: 12) {
                switch permissions.appleMusic {
                case .granted:
                    Label("Apple Music connected", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                case .notDetermined:
                    Button("Allow Apple Music") {
                        Task {
                            await model.requestAppleMusicAccess()
                            withAnimation { page = 2 }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                case .denied:
                    Button("Open Settings") { openSettings() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                Button("Continue") { withAnimation { page = 2 } }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var microphonePage: some View {
        OnboardingPage(
            symbol: "waveform",
            title: "Identify songs anywhere",
            message: "Shazam mode listens through the microphone to recognize music playing nearby, from any app, a video or a speaker. Audio is only used to find a match.",
            bullets: []
        ) {
            VStack(spacing: 12) {
                switch permissions.microphone {
                case .granted:
                    Label("Microphone allowed", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                case .notDetermined:
                    Button("Allow microphone") {
                        Task {
                            await permissions.requestMicrophone()
                            withAnimation { page = 3 }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                case .denied:
                    Button("Open Settings") { openSettings() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                Button("Not now") { withAnimation { page = 3 } }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var notificationsPage: some View {
        OnboardingPage(
            symbol: "lock.iphone",
            title: "Lyrics on your Lock Screen",
            message: "Live Activities show the current line under the clock and in the Dynamic Island. Turn on notifications so iOS allows them.",
            bullets: []
        ) {
            VStack(spacing: 12) {
                if !permissions.liveActivitiesEnabled {
                    Text("Live Activities are turned off for this app in Settings.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
                if permissions.notifications == .notDetermined {
                    Button("Allow notifications") {
                        Task { await permissions.requestNotifications() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else if permissions.notifications == .denied || !permissions.liveActivitiesEnabled {
                    Button("Open Settings") { openSettings() }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Label("All set", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                Button(isReplay ? "Done" : "Start listening") { finish(showPaywall: !isReplay) }
                    .buttonStyle(permissions.notifications == .notDetermined ? AnyButtonStyle(SecondaryButtonStyle()) : AnyButtonStyle(PrimaryButtonStyle()))
            }
        }
    }

    // MARK: Actions

    private func finish(showPaywall: Bool = false) {
        settings.hasCompletedOnboarding = true
        model.start()
        dismiss()
        if showPaywall && !model.isPro {
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                model.paywallReason = .general
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

private struct OnboardingPage<Actions: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let bullets: [(String, LocalizedStringKey)]
    @ViewBuilder var actions: () -> Actions

    init(
        symbol: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        bullets: [(String, LocalizedStringKey)],
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.bullets = bullets
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 10)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Brand.violet, Brand.pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 116, height: 116)
                    .shadow(color: Brand.pink.opacity(0.4), radius: 24, y: 10)
                Image(systemName: symbol)
                    .font(.system(size: 48, weight: .semibold))
            }
            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)

            if !bullets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                        HStack(spacing: 14) {
                            Image(systemName: bullet.0)
                                .frame(width: 30)
                                .foregroundStyle(Brand.pink)
                            Text(bullet.1).font(.subheadline.weight(.medium))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            }

            Spacer(minLength: 10)
            actions()
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 28)
    }
}

/// Type-erased ButtonStyle so a button can switch emphasis at runtime.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        make(configuration)
    }
}
