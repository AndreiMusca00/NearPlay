//
//  ConnectFourPayloads.swift
//  NearPlay
//

import Foundation

struct ConnectFourStartPayload: Codable, Equatable {
    let sessionID: String

    let playerOneID: String
    let playerOneName: String

    let playerTwoID: String
    let playerTwoName: String

    let initialState: ConnectFourGameState
}

struct ConnectFourMovePayload: Codable, Equatable {
    let sessionID: String
    let playerID: String
    let column: Int
    let turnID: UUID
}

struct ConnectFourStatePayload: Codable, Equatable {
    let sessionID: String
    let roundNumber: Int
    let state: ConnectFourGameState
}
