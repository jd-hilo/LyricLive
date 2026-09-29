import LyricCore
import StoreKit
import SwiftUI

/// StoreKit 2 paywall: yearly (best value), monthly and lifetime.
struct PaywallView: View {
    var reason: PaywallReason = .general

    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedID: String = AppConfig.yearlyProductID
    @State private var message: LocalizedStringKey?

    private struct FeatureRow: Identifiable {
        let id: String
        let symbol: String
        let title: LocalizedStringKey
        let feature: ProFeature?
    }

    private let features: [FeatureRow] = [
        .init(id: "live", symbol: "lock.iphone", title: "Live Activity and Dynamic Island lyrics", feature: .liveActivity),
        .init(id: "widgets", symbol: "square.grid.2x2", title: "Medium, large and Now Playing widgets", feature: .largeWidgets),
        .init(id: "carplay", symbol: "car", title: "Lyrics in CarPlay", feature: .carPlay),
        .init(id: "translate", symbol: "character.bubble", title: "Unlimited on-device translation", feature: .translation),
        .init(id: "sources", symbol: "waveform.badge.magnifyingglass", title: "Spotify and Shazam mode", feature: .spotify),
        .init(id: "share", symbol: "square.and.arrow.up", title: "Share cards without watermark", feature: .shareCardsNoWatermark),
        .init(id: "looks", symbol: "paintpalette", title: "Artwork backgrounds and font styles", feature: .premiumBackgrounds),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#2A1670"), Color(hex: "#0C0B1E")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    header
                    featureList
                    plans
                    purchaseButton
                    footer
                }
                .padding(.horizontal, 22)
                .padding(.top, 54)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.14), in: Circle())
                    }
                    .accessibilityLabel(Text("Close"))
                }
                .padding(16)
                Spacer()
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onChange(of: store.isPro) { _, isPro in
            if isPro { dismiss() }
        }
        .onChange(of: store.loadState) { _, _ in
            if store.product(id: selectedID) == nil, let first = store.products.first {
                selectedID = first.id
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Brand.violet, Brand.pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                    .shadow(color: Brand.pink.opacity(0.45), radius: 22, y: 8)
                Image(systemName: "sparkles").font(.system(size: 36, weight: .semibold))
            }
            Text("\(AppConfig.displayName) Pro")
                .font(.system(size: 32, weight: .bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
    }

    private var subtitle: LocalizedStringKey {
        switch reason {
        case .general: return "Lyrics on every screen you use."
        case .feature(.liveActivity): return "Unlock Lock Screen and Dynamic Island lyrics."
        case .feature(.carPlay): return "Unlock lyrics in CarPlay."
        case .feature(.translation): return "You've used today's free translations. Go Pro for unlimited."
        case .feature(.spotify): return "Unlock Spotify."
        case .feature(.shazam): return "Unlock Shazam mode."
        case .feature(.largeWidgets): return "Unlock every widget size."
        case .feature(.shareCardsNoWatermark): return "Unlock all share card styles without a watermark."
        case .feature(.premiumBackgrounds): return "Unlock artwork backgrounds and font styles."
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(features) { row in
                HStack(spacing: 14) {
                    Image(systemName: row.symbol)
                        .frame(width: 28)
                        .foregroundStyle(Brand.pink)
                    Text(row.title).font(.subheadline.weight(.medium))
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(.green)
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var plans: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView().tint(.white).padding(.vertical, 30)
        case .failed(let error):
            VStack(spacing: 12) {
                Text("Couldn't load prices").font(.headline)
                Text(error).font(.footnote).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                Button("Try again") { Task { await store.loadProducts() } }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.vertical, 12)
        case .loaded:
            VStack(spacing: 10) {
                ForEach(store.products, id: \.id) { product in
                    planCard(product)
                }
            }
        }
    }

    private func planCard(_ product: Product) -> some View {
        let isSelected = product.id == selectedID
        return Button {
            selectedID = product.id
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Brand.pink : .white.opacity(0.5))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(planTitle(product)).font(.headline)
                        if product.id == AppConfig.yearlyProductID {
                            Text(bestValueLabel)
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Brand.pink, in: Capsule())
                        }
                    }
                    Text(planSubtitle(product)).font(.footnote).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text(product.displayPrice).font(.headline)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.16 : 0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Brand.pink : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func planTitle(_ product: Product) -> LocalizedStringKey {
        switch product.id {
        case AppConfig.yearlyProductID: return "Yearly"
        case AppConfig.monthlyProductID: return "Monthly"
        default: return "Lifetime"
        }
    }

    private var bestValueLabel: LocalizedStringKey {
        if let percent = store.yearlySavingsPercent { return "SAVE \(percent)%" }
        return "BEST VALUE"
    }

    private func planSubtitle(_ product: Product) -> LocalizedStringKey {
        switch product.id {
        case AppConfig.yearlyProductID: return "Renews every year. Cancel anytime."
        case AppConfig.monthlyProductID: return "Renews every month. Cancel anytime."
        default: return "One payment, yours forever."
        }
    }

    private var purchaseButton: some View {
        VStack(spacing: 10) {
            Button {
                guard let product = store.product(id: selectedID) else { return }
                Task {
                    switch await store.purchase(product) {
                    case .success: message = nil
                    case .cancelled: message = nil
                    case .pending: message = "Your purchase is waiting for approval."
                    case .failed: message = "The purchase didn't go through. Please try again."
                    }
                }
            } label: {
                Group {
                    if store.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continue")
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(store.product(id: selectedID) == nil || store.isPurchasing)

            if let message {
                Text(message).font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button("Restore purchases") {
                Task {
                    switch await store.restore() {
                    case .success: message = nil
                    default: message = "No previous purchases were found."
                    }
                }
            }
            .font(.subheadline.weight(.semibold))

            HStack(spacing: 18) {
                Link("Terms of use", destination: AppConfig.termsURL)
                Link("Privacy policy", destination: AppConfig.privacyURL)
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.7))

            Text("Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple ID. Manage or cancel in your App Store account settings. Lifetime is a one-time purchase.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
    }
}

extension StoreManager {
    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }
}
