import Foundation

struct RPSStartPayload: Codable, Equatable {
    let sessionID: String

    let playerOneID: String
    let playerOneName: String

    let playerTwoID: String
    let playerTwoName: String

    let initialState: RPSGameState
}

struct RPSChoicePayload: Codable, Equatable {
    let sessionID: String
    let playerID: String
    let choice: RPSChoice
    let roundID: UUID
}

struct RPSStatePayload: Codable, Equatable {
    let sessionID: String
    let roundNumber: Int
    let state: RPSGameState
}
