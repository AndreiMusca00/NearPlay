import Foundation
import UIKit

/// Persistent identity owned by NearPlay itself.
///
/// This file intentionally knows nothing about MultipeerConnectivity,
/// CoreBluetooth, Bonjour, or any future transport.
enum NearPlayIdentity {
    private static let playerIDKey = "nearplay_player_id"
    private static let deviceIDKey = "nearplay_identity_device_id"

    /// Swift initializes static stored properties exactly once, atomically.
    /// This prevents two callers from generating different IDs during launch.
    static let playerID: String = {
        let defaults = UserDefaults.standard
        let currentDeviceID = UIDevice.current.identifierForVendor?.uuidString
        let storedDeviceID = defaults.string(forKey: deviceIDKey)

        if let existingID = defaults.string(forKey: playerIDKey),
           !existingID.isEmpty,
           currentDeviceID == nil || storedDeviceID == currentDeviceID {
            return existingID
        }

        let newID = UUID().uuidString
        defaults.set(newID, forKey: playerIDKey)
        defaults.set(currentDeviceID, forKey: deviceIDKey)
        return newID
    }()
}
