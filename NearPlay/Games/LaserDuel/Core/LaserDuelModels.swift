import Foundation

struct LaserDuelMatchState: Codable, Equatable, Sendable {
    var lives: [String: Int]
    var roundID: UUID
    var startsAt: Date
    var winnerPlayerID: String?

    func lives(for playerID: String) -> Int {
        lives[playerID, default: LaserDuelGame.startingLives]
    }

    var isFinished: Bool { winnerPlayerID != nil }
}

struct LaserDuelStartPayload: Codable, Equatable {
    let sessionID: String
    let playerOneID: String
    let playerOneName: String
    let playerTwoID: String
    let playerTwoName: String
    let initialState: LaserDuelMatchState
}

enum LaserDuelActionKind: String, Codable {
    case position
    case projectile
    case hit
}

struct LaserDuelActionPayload: Codable, Equatable {
    let sessionID: String
    let roundID: UUID
    let eventID: UUID
    let kind: LaserDuelActionKind
    let playerID: String
    let targetPlayerID: String?
    let x: Double?
}

struct LaserDuelStatePayload: Codable, Equatable {
    let sessionID: String
    let state: LaserDuelMatchState
}

struct LaserDuelProjectile: Identifiable, Equatable {
    let id: UUID
    var x: Double
    var y: Double
    let direction: Double
    let isIncoming: Bool
}

enum LaserDuelGame {
    static let startingLives = 3

    static func makeInitialState(
        playerOneID: String,
        playerTwoID: String,
        startsAt: Date = Date().addingTimeInterval(3.2)
    ) -> LaserDuelMatchState {
        LaserDuelMatchState(
            lives: [
                playerOneID: startingLives,
                playerTwoID: startingLives
            ],
            roundID: UUID(),
            startsAt: startsAt,
            winnerPlayerID: nil
        )
    }
}
