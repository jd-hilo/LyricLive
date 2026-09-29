import Foundation
import StoreKit

enum PurchaseOutcome: Equatable {
    case success
    case cancelled
    case pending
    case failed(String)
}

/// StoreKit 2: one auto-renewing subscription group (monthly + yearly) and a non-consumable lifetime unlock.
/// Product identifiers are placeholders, see `AppConfig`.
@MainActor
final class StoreManager: ObservableObject {
    enum LoadState: Equatable {
        case idle, loading, loaded
        case failed(String)
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var hasPurchased: Bool
    @Published private(set) var isPurchasing = false

    #if DEBUG
    /// Lets the Pro gates be exercised without a StoreKit configuration.
    @Published var debugProOverride: Bool {
        didSet { UserDefaults.standard.set(debugProOverride, forKey: "debug.proOverride") }
    }
    #endif

    var isPro: Bool {
        #if DEBUG
        return hasPurchased || debugProOverride
        #else
        return hasPurchased
        #endif
    }

    private static let cacheKey = "store.hasPurchased"
    private var updatesTask: Task<Void, Never>?

    init() {
        hasPurchased = AppGroup.defaults.bool(forKey: Self.cacheKey)
        #if DEBUG
        debugProOverride = UserDefaults.standard.bool(forKey: "debug.proOverride")
        #endif
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { [weak self] in
            await self?.refreshEntitlements()
            await self?.loadProducts()
        }
    }

    // MARK: Products

    var monthly: Product? { products.first { $0.id == AppConfig.monthlyProductID } }
    var yearly: Product? { products.first { $0.id == AppConfig.yearlyProductID } }
    var lifetime: Product? { products.first { $0.id == AppConfig.lifetimeProductID } }

    /// How much cheaper the yearly plan is than twelve monthly payments, as a whole percentage.
    var yearlySavingsPercent: Int? {
        guard let monthly, let yearly, monthly.price > 0 else { return nil }
        let full = monthly.price * 12
        guard full > 0 else { return nil }
        let saved = (full - yearly.price) / full
        let percent = NSDecimalNumber(decimal: saved * 100).intValue
        return percent > 0 ? percent : nil
    }

    func loadProducts() async {
        loadState = .loading
        do {
            let loaded = try await Product.products(for: AppConfig.allProductIDs)
            products = AppConfig.allProductIDs.compactMap { id in loaded.first { $0.id == id } }
            loadState = products.isEmpty ? .failed(String(localized: "No purchase options are available right now.")) : .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: Purchasing

    func purchase(_ product: Product) async -> PurchaseOutcome {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    return .success
                case .unverified(_, let error):
                    return .failed(error.localizedDescription)
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Unknown purchase result")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restore() async -> PurchaseOutcome {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return hasPurchased ? .success : .failed(String(localized: "No previous purchases were found."))
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  AppConfig.allProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration < Date() { continue }
            owned = true
        }
        setPurchased(owned)
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = update else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    private func setPurchased(_ value: Bool) {
        hasPurchased = value
        AppGroup.defaults.set(value, forKey: Self.cacheKey)
    }
}
