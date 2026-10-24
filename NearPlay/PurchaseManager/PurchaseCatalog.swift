import Foundation

/// Singura sursă de adevăr pentru produsele NearPlay din App Store Connect.
/// Product ID-urile nu trebuie schimbate după ce produsele sunt create.
enum PurchaseCatalog {
    static let numberRush = "com.nearplay.numberrush"
    static let dotsAndBoxes = "com.nearplay.dotsandboxes"
    static let ricochet = "com.nearplay.ricochet"
    static let tiltRace = "com.nearplay.tiltrace"
    static let laserDuel = "com.nearplay.laserduel"

    /// Produs Non-Consumable care deblochează toate jocurile premium actuale
    /// și toate jocurile premium adăugate în viitor.
    static let lifetimePass = "com.nearplay.allgames"

    static var allProductIDs: [String] {
        Array(
            Set(Game.purchasableProductIDs + [lifetimePass])
        )
        .sorted()
    }
}
