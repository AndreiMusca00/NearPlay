import Foundation

struct RicochetMatchState: Codable, Equatable, Sendable {
    var lives: [String: Int]
    var serverPlayerID: String
    var roundID: UUID
    var isRoundActive: Bool
    var rally: Int
    var winnerPlayerID: String?

    func lives(for playerID: String) -> Int { lives[playerID, default: 3] }
    var isFinished: Bool { winnerPlayerID != nil }
}

struct RicochetBall: Equatable {
    var x: Double
    var y: Double
    var velocityX: Double
    var velocityY: Double
    var speed: Double
}

enum RicochetActionKind: String, Codable {
    case requestServe
    case projectileTransfer
    case lifeLost
}

struct RicochetStartPayload: Codable, Equatable {
    let sessionID: String
    let playerOneID: String
    let playerOneName: String
    let playerTwoID: String
    let playerTwoName: String
    let initialState: RicochetMatchState
}

struct RicochetActionPayload: Codable, Equatable {
    let sessionID: String
    let kind: RicochetActionKind
    let playerID: String
    let roundID: UUID
    let eventID: UUID
    let x: Double?
    let velocityX: Double?
    let speed: Double?
    let rally: Int?
}

struct RicochetStatePayload: Codable, Equatable {
    let sessionID: String
    let state: RicochetMatchState
}

struct RicochetResetPayload: Codable, Equatable {
    let sessionID: String
}

enum RicochetGame {
    static func makeInitialState(startingPlayerID: String) -> RicochetMatchState {
        RicochetMatchState(
            lives: [:], serverPlayerID: startingPlayerID, roundID: UUID(),
            isRoundActive: false, rally: 0, winnerPlayerID: nil
        )
    }
}
