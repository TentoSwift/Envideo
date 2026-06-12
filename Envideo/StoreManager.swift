import StoreKit
import Observation

@Observable
@MainActor
final class StoreManager {
    static let productID = "com.tento.envideo.pro"
    static let historyLimit = 3

    private(set) var isPurchased = false
    private(set) var isLoading = false

    init() {
        Task { await refresh() }
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
    }

    func refresh() async {
        for await result in Transaction.currentEntitlements {
            await handle(result)
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        try? await AppStore.sync()
        await refresh()
    }

    /// ProductView (.onInAppPurchaseCompletion) からの購入結果を処理する。
    /// ProductView の購入は Transaction.updates に流れないため、ここで即時反映する
    func handle(purchaseResult: Product.PurchaseResult) async {
        switch purchaseResult {
        case .success(let verification):
            await handle(verification)
        case .pending, .userCancelled:
            break
        @unknown default:
            break
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let tx) = result else { return }
        if tx.productID == Self.productID && tx.revocationDate == nil {
            isPurchased = true
        }
        await tx.finish()
    }
}
