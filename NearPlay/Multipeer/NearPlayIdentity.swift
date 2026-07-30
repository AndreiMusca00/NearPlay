import Foundation
import MultipeerConnectivity

enum NearPlayIdentity {
    private static let playerIDKey = "nearplay_player_id"
    private static let archivedPeerIDKey = "nearplay_archived_peer_id"

    static var playerID: String {
        if let existingID = UserDefaults.standard.string(forKey: playerIDKey),
           !existingID.isEmpty {
            return existingID
        }

        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: playerIDKey)
        return newID
    }

    static var peerID: MCPeerID {
        if let archivedData = UserDefaults.standard.data(forKey: archivedPeerIDKey),
           let savedPeerID = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: MCPeerID.self,
                from: archivedData
           ) {
            return savedPeerID
        }

        let newPeerID = MCPeerID(
            displayName: "NearPlay-\(playerID)"
        )

        if let archivedData = try? NSKeyedArchiver.archivedData(
            withRootObject: newPeerID,
            requiringSecureCoding: true
        ) {
            UserDefaults.standard.set(
                archivedData,
                forKey: archivedPeerIDKey
            )
        }

        return newPeerID
    }
}
