import Foundation

struct BackgammonStartPayload: Codable, Equatable {
    let sessionID: String

    let playerOneID: String
    let playerOneName: String

    let playerTwoID: String
    let playerTwoName: String

    let initialState: BackgammonGameState
}

enum BackgammonActionKind: String, Codable, Equatable {
    case roll
    case move
    case combinedMove
    case undo
    case commit
}

struct BackgammonActionPayload: Codable, Equatable {
    let sessionID: String
    let playerID: String
    let turnID: UUID
    let kind: BackgammonActionKind

    /// nil source means bar; nil destination means bear off.
    let source: Int?
    let destination: Int?
}

struct BackgammonStatePayload: Codable, Equatable {
    let sessionID: String
    let roundNumber: Int
    let state: BackgammonGameState
    let canUndo: Bool?

    init(
        sessionID: String,
        roundNumber: Int,
        state: BackgammonGameState,
        canUndo: Bool? = nil
    ) {
        self.sessionID = sessionID
        self.roundNumber = roundNumber
        self.state = state
        self.canUndo = canUndo
    }
}
