//
//  NearbyPeer.swift
//  NearPlay
//
//  Created by Andrei Musca on 30/06/2026.
//

import Foundation

/// Represents a discovered or connected nearby peer.
struct NearbyPeer: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let gameID: String?
    let maxPlayers: Int?

    init(id: String, displayName: String, gameID: String? = nil, maxPlayers: Int? = nil) {
        self.id = id
        self.displayName = displayName
        self.gameID = gameID
        self.maxPlayers = maxPlayers
    }
}
