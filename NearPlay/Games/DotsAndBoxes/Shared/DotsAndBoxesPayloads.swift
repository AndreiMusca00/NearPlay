import Foundation

struct DotsAndBoxesStartPayload: Codable, Equatable {
    let sessionID: String
    let playerOneID: String
    let playerOneName: String
    let playerTwoID: String
    let playerTwoName: String
    let initialState: DotsAndBoxesGameState
}

struct DotsAndBoxesMovePayload: Codable, Equatable {
    let sessionID: String
    let playerID: String
    let edge: DotsAndBoxesEdge
    let turnID: UUID
}

struct DotsAndBoxesStatePayload: Codable, Equatable {
    let sessionID: String
    let roundNumber: Int
    let state: DotsAndBoxesGameState
}
