import Foundation

struct TicTacToeStartPayload: Codable, Equatable {
    let sessionID: String

    let playerOneID: String
    let playerOneName: String

    let playerTwoID: String
    let playerTwoName: String

    let initialState: TicTacToeGameState
}

struct TicTacToeMovePayload: Codable, Equatable {
    let sessionID: String
    let playerID: String
    let index: Int
    let turnID: UUID
}

struct TicTacToeStatePayload: Codable, Equatable {
    let sessionID: String
    let roundNumber: Int
    let state: TicTacToeGameState
}
