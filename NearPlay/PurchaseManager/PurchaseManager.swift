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
        
        // Ascultăm permanent modificările venite de la StoreKit.
        transactionUpdatesTask = Task { [weak self] in
            
            for await result in Transaction.updates {
                
                guard let self else {
                    return
                }
                
                await self.handleTransactionUpdate(result)
            }
        }
        
        // La pornirea aplicației verificăm ce cumpărături
        // deține deja utilizatorul și încărcăm produsele.
        Task { [weak self] in
            
            guard let self else {
                return
            }
            
            await self.refreshEntitlements()
            
            await self.loadProducts()
            
            self.isInitialStoreReady = true
        }
    }
    
    // MARK: - Unlock
    
    func isUnlocked(_ game: Game) -> Bool {
        
        // Dacă jocul nu are productID, este gratuit.
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
            
            let products = try await Product.products(
                for: productIDs
            )
            
            productsByID = Dictionary(
                uniqueKeysWithValues: products.map {
                    ($0.id, $0)
                }
            )
            
        } catch {
            
            // Dacă App Store nu răspunde momentan,
            // păstrăm produsele deja încărcate.
            print(
                "Failed to load StoreKit products:",
                error.localizedDescription
            )
        }
    }
    
    // MARK: - Purchase
    
    func purchase(
        _ game: Game
    ) async throws -> PurchaseOutcome {
        
        // Jocurile fără productID sunt gratuite.
        guard let productID = game.productID else {
            return .purchased
        }
        
        // Dacă deja îl deținem, nu mai încercăm
        // să pornim o nouă achiziție.
        if purchasedProductIDs.contains(productID) {
            return .purchased
        }
        
        let product: Product
        
        // Folosim produsul din cache dacă există.
        if let cachedProduct = productsByID[productID] {
            
            product = cachedProduct
            
        } else {
            
            // Dacă nu este încă în cache,
            // îl cerem direct de la StoreKit.
            let fetchedProducts = try await Product.products(
                for: [productID]
            )
            
            guard let fetchedProduct = fetchedProducts.first else {
                throw PurchaseManagerError.productUnavailable
            }
            
            productsByID[productID] = fetchedProduct
            
            product = fetchedProduct
        }
        
        // Pornim flow-ul Apple de purchase.
        let result = try await product.purchase()
        
        switch result {
            
        case .success(let verificationResult):
            
            // Acceptăm numai tranzacții verificate.
            guard case .verified(let transaction) = verificationResult else {
                throw PurchaseManagerError.failedVerification
            }
            
            // IMPORTANT:
            //
            // StoreKit tocmai ne-a confirmat tranzacția.
            // Deblocăm imediat jocul în sesiunea curentă.
            purchasedProductIDs.insert(
                transaction.productID
            )
            
            // Finalizăm tranzacția după ce am acordat accesul.
            await transaction.finish()
            
            // NU apelăm refreshEntitlements() aici.
            //
            // Pe device fizic StoreKit poate avea un mic delay
            // până când transaction.currentEntitlements reflectă
            // tranzacția nouă.
            //
            // Dacă am reconstrui setul imediat, jocul s-ar putea
            // bloca din nou la câteva momente după cumpărare.
            
            return .purchased
            
        case .pending:
            
            return .pending
            
        case .userCancelled:
            
            return .cancelled
            
        @unknown default:
            
            return .cancelled
        }
    }
    
    // MARK: - Refresh Entitlements
    
    func refreshEntitlements() async {
        
        var currentProductIDs: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            
            guard case .verified(let transaction) = result else {
                continue
            }
            
            // Dacă Apple a revocat/refundat produsul,
            // nu trebuie să rămână unlocked.
            guard transaction.revocationDate == nil else {
                continue
            }
            
            currentProductIDs.insert(
                transaction.productID
            )
        }
        
        purchasedProductIDs = currentProductIDs
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async throws {
        
        // Solicităm explicit sincronizarea cu App Store.
        try await AppStore.sync()
        
        // După sync verificăm entitlement-urile reale.
        await refreshEntitlements()
        
        // Reîncărcăm și produsele / prețurile.
        await loadProducts()
    }
    
    // MARK: - Initial Store Preparation
    
    /// Folosit de loading screen.
    ///
    /// Așteaptă verificarea inițială StoreKit,
    /// dar nu ține aplicația blocată mai mult
    /// de aproximativ două secunde.
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
        
        guard case .verified(let transaction) = result else {
            return
        }
        
        if transaction.revocationDate == nil {
            
            // Purchase / entitlement valid.
            purchasedProductIDs.insert(
                transaction.productID
            )
            
        } else {
            
            // Refund / revocation.
            purchasedProductIDs.remove(
                transaction.productID
            )
        }
        
        await transaction.finish()
        
        // IMPORTANT:
        // Nu facem refreshEntitlements() imediat aici.
        // Transaction.updates tocmai ne-a oferit starea
        // verificată pe care trebuie să o aplicăm.
    }
}
