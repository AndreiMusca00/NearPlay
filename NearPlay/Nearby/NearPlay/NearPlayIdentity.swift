import Foundation

/// Persistent identity owned by NearPlay itself.
///
/// This file intentionally knows nothing about MultipeerConnectivity,
/// CoreBluetooth, Bonjour, or any future transport.
enum NearPlayIdentity {
    private static let playerIDKey = "nearplay_player_id"

    static var playerID: String {
        if let existingID = UserDefaults.standard.string(
            forKey: playerIDKey
        ), !existingID.isEmpty {
            return existingID
        }

        let newID = UUID().uuidString
        UserDefaults.standard.set(
            newID,
            forKey: playerIDKey
        )
        return newID
    }
}
