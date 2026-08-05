//
//  BattleshipPayloads.swift
//  NearPlay
//

import Foundation

struct BattleshipStartPayload: Codable, Equatable {
    let sessionID: String

    let playerOneID: String
    let playerOneName: String

    let playerTwoID: String
    let playerTwoName: String

    let initialStartingPlayerID: String
}

struct BattleshipReadyPayload: Codable, Equatable {
    let sessionID: String
    let playerID: String
}

struct BattleshipBattleStartedPayload: Codable, Equatable {
    let sessionID: String
    let startingPlayerID: String
    let turnID: UUID
}

struct BattleshipAttackPayload: Codable, Equatable {
    let sessionID: String
    let attackerPlayerID: String
    let coordinate: BattleshipCoordinate
    let turnID: UUID
}

struct BattleshipAttackResultPayload: Codable, Equatable {
    let sessionID: String
    let attackerPlayerID: String
    let defenderPlayerID: String

    let coordinate: BattleshipCoordinate
    let outcome: BattleshipAttackOutcome
    let sunkCoordinates: [BattleshipCoordinate]
    let defenderRemainingShips: Int

    let nextPlayerID: String
    let nextTurnID: UUID
    let winnerPlayerID: String?
}
