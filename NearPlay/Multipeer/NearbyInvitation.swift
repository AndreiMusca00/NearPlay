//
//  NearbyInvitation.swift
//  NearPlay
//
//  Created by Andrei Musca on 30/06/2026.
//

import Foundation

struct NearbyInvitation: Identifiable, Hashable, Codable {
    let id: UUID
    let fromPeer: NearbyPeer
    let gameID: String
    let playerName: String
    let maxPlayers: Int

    init(id: UUID = UUID(), fromPeer: NearbyPeer, gameID: String, playerName: String, maxPlayers: Int) {
        self.id = id
        self.fromPeer = fromPeer
        self.gameID = gameID
        self.playerName = playerName
        self.maxPlayers = maxPlayers
    }
}
