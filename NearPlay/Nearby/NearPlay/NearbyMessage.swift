//
//  NearbyMessage.swift
//  NearPlay
//
//  Created by Andrei Musca on 30/06/2026.
//

import Foundation

enum NearbyMessageType: String, Codable {
    case lobbyUpdate
    case lobbyCountdown
    case gameStart
    case gameAction
    case gameState
    case rematch
    case playerJoined
    case playerLeft
    case endGame
    case custom
    case gameQuit
}

struct NearbyMessage: Codable, Identifiable, Hashable {
    let id: UUID
    let gameID: String
    let senderName: String
    let type: NearbyMessageType
    let payload: Data?
    let createdAt: Date
    /// Messages sharing this key may replace older queued messages that have
    /// not started transmitting yet. This is intended for live positions,
    /// where the newest value matters more than delivering every sample.
    let coalescingKey: String?

    init(
        id: UUID = UUID(),
        gameID: String,
        senderName: String,
        type: NearbyMessageType,
        payload: Data? = nil,
        createdAt: Date = Date(),
        coalescingKey: String? = nil
    ) {
        self.id = id
        self.gameID = gameID
        self.senderName = senderName
        self.type = type
        self.payload = payload
        self.createdAt = createdAt
        self.coalescingKey = coalescingKey
    }
}
