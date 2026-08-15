import Foundation

struct NumberRushStartPayload: Codable, Equatable {
    let sessionID: String

    let playerOneID: String
    let playerOneName: String

    let playerTwoID: String
    let playerTwoName: String

    let shuffledNumbers: [Int]
    let startingPlayerID: String
    let turnDuration: TimeInterval
}

struct NumberRushSelectionPayload: Codable, Equatable {
    let sessionID: String
    let playerID: String
    let selectedNumber: Int
    let turnID: UUID
}

struct NumberRushStatePayload: Codable, Equatable {
    let sessionID: String
    let roundNumber: Int
    let state: NumberRushGameState
}
