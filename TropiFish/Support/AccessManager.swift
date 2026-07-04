import Foundation
import StoreKit
import SwiftUI

/// Owns the app's paid-access state for the free-trial → one-time-unlock model
/// (see [[tropifish-appstore]] pricing). The app is free to download; every
/// keeper gets a 14-day full-feature trial, after which the value actions
/// (logging, stock, trends) are gated behind a single non-consumable purchase.
///
/// The trial window is enforced here (StoreKit has no trial concept for
/// non-subscription IAP): we stamp a start date on first launch and compare.
/// Purchase/restore use StoreKit 2; `Transaction.currentEntitlements` is the
/// source of truth for whether the unlock has been bought.
@MainActor
final class AccessManager: ObservableObject {
    /// True once the non-consumable unlock is owned.
    @Published private(set) var isUnlocked = false
    /// The loaded product, for its localised price. Nil until StoreKit responds.
    @Published private(set) var product: Product?
    /// Drives the app-wide paywall sheet.
    @Published var isShowingPaywall = false
    @Published private(set) var purchaseState: PurchaseState = .idle

    enum PurchaseState: Equatable {
        case idle, working
        case failed(String)
    }

    private var updatesTask: Task<Void, Never>?
    /// Cached trial start (Keychain-backed via `TrialStore` so a reinstall can't
    /// reset it). Resolved once at init.
    private(set) var trialStartDate: Date

    init() {
        // Keychain is the source of truth: survives delete/reinstall, so the
        // 14-day trial can't be farmed by reinstalling.
        trialStartDate = TrialStore.resolveStart()
        #if DEBUG
        applyDebugOverrides()
        #endif
        updatesTask = listenForTransactions()
        Task { await refresh() }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Trial window

    var trialEndDate: Date {
        Calendar.current.date(byAdding: .day, value: AppInfo.trialLengthDays, to: trialStartDate) ?? trialStartDate
    }

    /// Whole days left in the trial (0 once expired).
    var trialDaysRemaining: Int {
        let comps = Calendar.current.dateComponents([.day], from: Date(), to: trialEndDate)
        return max(0, (comps.day ?? 0) + (trialEndDate > Date() ? 1 : 0))
    }

    var isTrialActive: Bool { !isUnlocked && Date() < trialEndDate }
    var isTrialExpired: Bool { !isUnlocked && Date() >= trialEndDate }

    /// The gate every value action checks.
    var hasFullAccess: Bool { isUnlocked || isTrialActive }

    /// Run `action` if the user has access; otherwise surface the paywall.
    func attempt(_ action: () -> Void) {
        if hasFullAccess {
            action()
        } else {
            Haptics.warning()
            isShowingPaywall = true
        }
    }

    // MARK: - StoreKit

    var displayPrice: String { product?.displayPrice ?? AppInfo.unlockPriceFallback }

    func refresh() async {
        await loadProduct()
        await updateEntitlement()
    }

    private func loadProduct() async {
        product = try? await Product.products(for: [AppInfo.unlockProductID]).first
    }

    /// Re-derive `isUnlocked` from the user's current entitlements. Only ever
    /// flips to `true` (a non-consumable, once owned, stays owned).
    func updateEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == AppInfo.unlockProductID,
               transaction.revocationDate == nil {
                isUnlocked = true
                return
            }
        }
    }

    func purchase() async {
        guard let product else { purchaseState = .failed("The App Store is unavailable right now. Please try again."); return }
        purchaseState = .working
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    isUnlocked = true
                    purchaseState = .idle
                    isShowingPaywall = false
                    Haptics.success()
                } else {
                    purchaseState = .failed("That purchase couldn't be verified.")
                }
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func restore() async {
        purchaseState = .working
        do {
            try await AppStore.sync()
            await updateEntitlement()
            purchaseState = .idle
            if isUnlocked {
                isShowingPaywall = false
                Haptics.success()
            } else {
                purchaseState = .failed("No previous purchase was found on this Apple Account.")
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.updateEntitlement()
                }
            }
        }
    }

    #if DEBUG
    /// QA overrides so the trial/paywall states can be reached headlessly,
    /// mirroring the `-openTank=` deep-link convention.
    private func applyDebugOverrides() {
        let args = ProcessInfo.processInfo.arguments
        func setStart(daysAgo: Int) {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            TrialStore.saveStart(date)
            trialStartDate = date
        }
        if args.contains("-freshTrial")  { setStart(daysAgo: 0) }
        if args.contains("-endingTrial") { setStart(daysAgo: AppInfo.trialLengthDays - 2) }
        if args.contains("-expireTrial") { setStart(daysAgo: AppInfo.trialLengthDays + 1) }
        if args.contains("-unlockFull")  { isUnlocked = true }
    }
    #endif
}
