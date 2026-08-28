//
//  PurchaseManager.swift
//  NearPlay
//

import Foundation
import StoreKit
import Combine

@MainActor
final class PurchaseManager: ObservableObject {

    // MARK: - Purchase Outcome

    enum PurchaseOutcome {
        case purchased
        case pending
        case cancelled
    }

    // MARK: - Errors

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

    // MARK: - Published Properties

    @Published private(set) var productsByID: [String: Product] = [:]

    @Published private(set) var purchasedProductIDs: Set<String> = []

    @Published private(set) var isLoadingProducts = false

    @Published private(set) var isInitialStoreReady = false

    // MARK: - Private Properties

    private var transactionUpdatesTask: Task<Void, Never>?

    // MARK: - Init

    init() {

        // Ascultăm permanent tranzacțiile noi sau modificate
        // primite de la App Store.
        transactionUpdatesTask = Task { [weak self] in

            for await result in Transaction.updates {

                guard let self else {
                    return
                }

                await self.handleTransactionUpdate(result)
            }
        }

        // Pregătim StoreKit la pornirea aplicației.
        Task { [weak self] in

            guard let self else {
                return
            }

            await self.prepareStore()

            self.isInitialStoreReady = true
        }
    }

    // MARK: - Initial Store Preparation

    private func prepareStore() async {

        print("[StoreKit] Preparing store...")

        await loadProducts()

        await refreshEntitlements()

        // Fallback suplimentar pentru produsele Non-Consumable.
        await recoverLatestNonConsumablePurchases()

        print(
            "[StoreKit] Store ready. Purchased IDs:",
            purchasedProductIDs
        )
    }

    // MARK: - Unlock

    func isUnlocked(_ game: Game) -> Bool {

        // Joc fără Product ID = joc gratuit.
        guard let productID = game.productID else {
            return true
        }

        return purchasedProductIDs.contains(productID)
    }

    // MARK: - Product

    func product(for game: Game) -> Product? {

        guard let productID = game.productID else {
            return nil
        }

        return productsByID[productID]
    }

    // MARK: - Display Price

    func displayPrice(for game: Game) -> String? {
        product(for: game)?.displayPrice
    }

    // MARK: - Purchased Games Count

    var purchasedGameCount: Int {

        Game.all.reduce(into: 0) { count, game in

            guard let productID = game.productID else {
                return
            }

            if purchasedProductIDs.contains(productID) {
                count += 1
            }
        }
    }

    // MARK: - Load Products

    func loadProducts() async {

        let productIDs = Game.purchasableProductIDs

        guard !productIDs.isEmpty else {
            productsByID = [:]
            return
        }

        isLoadingProducts = true

        defer {
            isLoadingProducts = false
        }

        do {

            print(
                "[StoreKit] Loading products:",
                productIDs
            )

            let products = try await Product.products(
                for: productIDs
            )

            productsByID = Dictionary(
                uniqueKeysWithValues: products.map {
                    ($0.id, $0)
                }
            )

            print(
                "[StoreKit] Products returned:",
                products.map { $0.id }
            )

            if products.isEmpty {
                print(
                    "[StoreKit] WARNING: App Store returned no products."
                )
            }

        } catch {

            print(
                "[StoreKit] Failed to load products:",
                error.localizedDescription
            )
        }
    }

    // MARK: - Purchase

    func purchase(
        _ game: Game
    ) async throws -> PurchaseOutcome {

        guard let productID = game.productID else {
            return .purchased
        }

        // Dacă deja este cumpărat, nu pornim din nou
        // dialogul Apple.
        if purchasedProductIDs.contains(productID) {

            print(
                "[StoreKit] Product already owned:",
                productID
            )

            return .purchased
        }

        let product: Product

        // Folosim produsul deja încărcat dacă există.
        if let cachedProduct = productsByID[productID] {

            product = cachedProduct

        } else {

            print(
                "[StoreKit] Product not cached. Fetching:",
                productID
            )

            let fetchedProducts = try await Product.products(
                for: [productID]
            )

            guard let fetchedProduct = fetchedProducts.first else {

                print(
                    "[StoreKit] Product unavailable:",
                    productID
                )

                throw PurchaseManagerError.productUnavailable
            }

            productsByID[productID] = fetchedProduct

            product = fetchedProduct
        }

        print(
            "[StoreKit] Starting purchase:",
            product.id
        )

        // Acesta afișează dialogul SYSTEM Apple.
        let result = try await product.purchase()

        switch result {

        case .success(let verificationResult):

            guard case .verified(let transaction) = verificationResult else {

                print(
                    "[StoreKit] Purchase verification FAILED."
                )

                throw PurchaseManagerError.failedVerification
            }

            print(
                "[StoreKit] Purchase verified:",
                transaction.productID
            )

            print(
                "[StoreKit] Transaction ID:",
                transaction.id
            )
            print(
                "[StoreKit] Environment:",
                transaction.environment
            )

            // Deblocăm imediat produsul.
            purchasedProductIDs.insert(
                transaction.productID
            )

            // Confirmăm către Apple că produsul a fost livrat.
            await transaction.finish()

            print(
                "[StoreKit] Transaction finished."
            )

            return .purchased

        case .pending:

            print(
                "[StoreKit] Purchase pending:",
                productID
            )

            return .pending

        case .userCancelled:

            print(
                "[StoreKit] Purchase cancelled:",
                productID
            )

            return .cancelled

        @unknown default:

            print(
                "[StoreKit] Unknown purchase result:",
                productID
            )

            return .cancelled
        }
    }

    // MARK: - Current Entitlements

    func refreshEntitlements() async {

        print(
            "[StoreKit] Checking current entitlements..."
        )

        var currentProductIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {

            switch result {

            case .verified(let transaction):

                print(
                    "[StoreKit] Entitlement:",
                    transaction.productID
                )

                guard transaction.revocationDate == nil else {

                    print(
                        "[StoreKit] Revoked entitlement:",
                        transaction.productID
                    )

                    continue
                }

                guard Game.purchasableProductIDs.contains(
                    transaction.productID
                ) else {
                    continue
                }

                currentProductIDs.insert(
                    transaction.productID
                )

            case .unverified(let transaction, let error):

                print(
                    "[StoreKit] Unverified entitlement:",
                    transaction.productID,
                    error.localizedDescription
                )
            }
        }

        purchasedProductIDs = currentProductIDs

        print(
            "[StoreKit] Current entitlement IDs:",
            currentProductIDs
        )
    }

    // MARK: - Latest Transaction Fallback

    private func recoverLatestNonConsumablePurchases() async {

        print(
            "[StoreKit] Checking latest transactions..."
        )

        for productID in Game.purchasableProductIDs {

            // Fallback-ul acesta este destinat
            // produselor Non-Consumable.
            if let product = productsByID[productID],
               product.type != .nonConsumable {

                continue
            }

            guard let result = await Transaction.latest(
                for: productID
            ) else {

                print(
                    "[StoreKit] No transaction found for:",
                    productID
                )

                continue
            }

            switch result {

            case .verified(let transaction):

                print(
                    "[StoreKit] Latest verified transaction:",
                    transaction.productID
                )

                if transaction.revocationDate == nil {

                    purchasedProductIDs.insert(
                        transaction.productID
                    )

                    print(
                        "[StoreKit] Restored entitlement:",
                        transaction.productID
                    )

                } else {

                    purchasedProductIDs.remove(
                        transaction.productID
                    )

                    print(
                        "[StoreKit] Transaction revoked:",
                        transaction.productID
                    )
                }

            case .unverified(let transaction, let error):

                print(
                    "[StoreKit] Latest transaction unverified:",
                    transaction.productID,
                    error.localizedDescription
                )
            }
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async throws {

        print(
            "[StoreKit] ==============================="
        )

        print(
            "[StoreKit] RESTORE STARTED"
        )

        print(
            "[StoreKit] ==============================="
        )

        // IMPORTANT:
        // Acesta este dialogul SYSTEM Apple.
        // Apple poate cere autentificarea App Store / Sandbox.
        try await AppStore.sync()

        print(
            "[StoreKit] AppStore.sync() completed."
        )

        // Reîncărcăm produsele reale din App Store.
        await loadProducts()

        // Metoda principală recomandată pentru entitlement-uri.
        await refreshEntitlements()

        // Fallback pentru Non-Consumable:
        // verificăm și ultima tranzacție cunoscută de Apple.
        await recoverLatestNonConsumablePurchases()

        print(
            "[StoreKit] RESTORE FINISHED."
        )

        print(
            "[StoreKit] Purchased IDs after restore:",
            purchasedProductIDs
        )

        print(
            "[StoreKit] ==============================="
        )
    }

    // MARK: - Loading Screen Support

    func waitForInitialStorePreparation() async {

        if isInitialStoreReady {
            return
        }

        for _ in 0..<40 {

            if isInitialStoreReady {
                return
            }

            try? await Task.sleep(
                nanoseconds: 50_000_000
            )
        }
    }

    // MARK: - Transaction Updates

    private func handleTransactionUpdate(
        _ result: VerificationResult<Transaction>
    ) async {

        switch result {

        case .verified(let transaction):

            print(
                "[StoreKit] Transaction update:",
                transaction.productID
            )

            if transaction.revocationDate == nil {

                purchasedProductIDs.insert(
                    transaction.productID
                )

                print(
                    "[StoreKit] Transaction update unlocked:",
                    transaction.productID
                )

            } else {

                purchasedProductIDs.remove(
                    transaction.productID
                )

                print(
                    "[StoreKit] Transaction update revoked:",
                    transaction.productID
                )
            }

            await transaction.finish()

        case .unverified(let transaction, let error):

            print(
                "[StoreKit] Unverified transaction update:",
                transaction.productID,
                error.localizedDescription
            )
        }
    }
}
