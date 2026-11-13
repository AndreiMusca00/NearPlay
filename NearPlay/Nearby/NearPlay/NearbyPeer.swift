//
//  NearbyPeer.swift
//  NearPlay
//
//  Created by Andrei Musca on 30/06/2026.
//

import Foundation

/// Represents a discovered or connected nearby peer.
/// Discovery uses a temporary BLE ID; connected peers use their NearPlay ID.
/// Names are presentation only and never identify a player.
struct NearbyPeer: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let gameID: String?
    let maxPlayers: Int?

    init(
        id: String,
        displayName: String,
        gameID: String? = nil,
        maxPlayers: Int? = nil
    ) {
        self.id = id
        self.displayName = PlayerProfile.displayName(for: displayName)
        self.gameID = gameID
        self.maxPlayers = maxPlayers
    }

    /// Scan responses can deliver the name after the initial discovery, and
    /// later advertisements can omit it again. Preserve the last known name.
    static func discovered(
        id: String,
        advertisedName: String?,
        previous: NearbyPeer?,
        gameID: String,
        maxPlayers: Int
    ) -> NearbyPeer {
        let name = PlayerProfile.normalizedName(advertisedName ?? "")
        let cachedName = previous.flatMap {
            $0.id == id && $0.gameID == gameID ? $0.displayName : nil
        }
        // Keep nameless discoveries distinguishable while waiting for a name.
        let fallback = "Guest \(id.suffix(4).uppercased())"
        return NearbyPeer(
            id: id,
            displayName: name.isEmpty ? (cachedName ?? fallback) : name,
            gameID: gameID,
            maxPlayers: maxPlayers
        )
    }
}
