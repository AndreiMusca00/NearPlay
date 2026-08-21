//
//  PurchaseManager.swift
//  NearPlay
//

import Foundation
import StoreKit
import Combine

@MainActor
final class PurchaseManager: ObservableObject {
    enum PurchaseOutcome {
        case purchased
        case pending
        case cancelled
    }

    enum PurchaseManagerError: LocalizedError {
        case productUnavailable
        case failedVerification

        var errorDescription: String? {
            switch self {
            case .productUnavailable:
                return "This purchase is currently unavailable."
            case .failedVerification:
                return "The App Store transaction could not be verified."
            }
        }
    }

    @Published private(set) var productsByID: [String: Product] = [:]
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoadingProducts = false

    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handleTransactionUpdate(result)
            }
        }

        Task { [weak self] in
            guard let self else { return }
            await self.refreshEntitlements()
            await self.loadProducts()
        }
    }

    func isUnlocked(_ game: Game) -> Bool {
        guard let productID = game.productID else {
            return true
        }

        return purchasedProductIDs.contains(productID)
    }

    func product(for game: Game) -> Product? {
        guard let productID = game.productID else {
            return nil
        }

        return productsByID[productID]
    }

    func displayPrice(for game: Game) -> String? {
        product(for: game)?.displayPrice
    }

    var purchasedGameCount: Int {
        Game.all.reduce(into: 0) { count, game in
            guard let productID = game.productID else { return }

            if purchasedProductIDs.contains(productID) {
                count += 1
            }
        }
    }

    func loadProducts() async {
        let productIDs = Game.purchasableProductIDs

        guard !productIDs.isEmpty else {
            productsByID = [:]
            return
        }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: productIDs)
            productsByID = Dictionary(
                uniqueKeysWithValues: products.map { ($0.id, $0) }
            )
        } catch {
            // Keep the current cache if App Store product loading temporarily fails.
        }
    }

    func purchase(_ game: Game) async throws -> PurchaseOutcome {
        guard let productID = game.productID else {
            return .purchased
        }

        if purchasedProductIDs.contains(productID) {
            return .purchased
        }

        let product: Product

        if let cachedProduct = productsByID[productID] {
            product = cachedProduct
        } else {
            let fetchedProducts = try await Product.products(for: [productID])

            guard let fetchedProduct = fetchedProducts.first else {
                throw PurchaseManagerError.productUnavailable
            }

            productsByID[productID] = fetchedProduct
            product = fetchedProduct
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verificationResult):
            guard case .verified(let transaction) = verificationResult else {
                throw PurchaseManagerError.failedVerification
            }

            // Unlock first, then finish the transaction.
            purchasedProductIDs.insert(transaction.productID)
            await transaction.finish()
            await refreshEntitlements()

            return .purchased

        case .pending:
            return .pending

        case .userCancelled:
            return .cancelled

        @unknown default:
            return .cancelled
        }
    }

    func refreshEntitlements() async {
        var currentProductIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            guard transaction.revocationDate == nil else {
                continue
            }

            currentProductIDs.insert(transaction.productID)
        }

        purchasedProductIDs = currentProductIDs
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
        await loadProducts()
    }

    private func handleTransactionUpdate(
        _ result: VerificationResult<Transaction>
    ) async {
        guard case .verified(let transaction) = result else {
            return
        }

        if transaction.revocationDate == nil {
            purchasedProductIDs.insert(transaction.productID)
        } else {
            purchasedProductIDs.remove(transaction.productID)
        }

        await transaction.finish()
        await refreshEntitlements()
    }
}
