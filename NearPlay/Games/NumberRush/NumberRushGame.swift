//
//  NumberRushGame.swift
//  NearPlay
//

import Foundation

struct NumberRushGameState: Codable, Equatable {
    var shuffledNumbers: [Int]
    var targetNumber: Int
    var scores: [String: Int]

    var activePlayerID: String
    var turnID: UUID
    var turnStartedAt: Date
    var turnDuration: TimeInterval

    var isFinished: Bool

    var deadline: Date {
        turnStartedAt.addingTimeInterval(turnDuration)
    }

    var completedNumbers: Set<Int> {
        guard targetNumber > 1 else {
            return []
        }

        return Set(1..<targetNumber)
    }
}

enum NumberRushSelectionOutcome: Equatable {
    case ignored
    case correct(number: Int)
    case wrong(number: Int)
    case finished(number: Int)
}

struct NumberRushGame {
    let playerOneID: String
    let playerTwoID: String
    let baseTurnDuration: TimeInterval

    private(set) var state: NumberRushGameState

    init(
        playerOneID: String,
        playerTwoID: String,
        shuffledNumbers: [Int],
        startingPlayerID: String,
        baseTurnDuration: TimeInterval = 5,
        now: Date = Date()
    ) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID
        self.baseTurnDuration = baseTurnDuration

        self.state = NumberRushGameState(
            shuffledNumbers: shuffledNumbers,
            targetNumber: 1,
            scores: [
                playerOneID: 0,
                playerTwoID: 0
            ],
            activePlayerID: startingPlayerID,
            turnID: UUID(),
            turnStartedAt: now,
            turnDuration: baseTurnDuration,
            isFinished: false
        )
    }

    init(
        playerOneID: String,
        playerTwoID: String,
        baseTurnDuration: TimeInterval,
        state: NumberRushGameState
    ) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID
        self.baseTurnDuration = baseTurnDuration
        self.state = state
    }

    mutating func applyRemoteState(
        _ newState: NumberRushGameState
    ) {
        state = newState
    }

    mutating func select(
        number: Int,
        by playerID: String,
        turnID: UUID,
        now: Date = Date()
    ) -> NumberRushSelectionOutcome {
        guard !state.isFinished,
              playerID == state.activePlayerID,
              turnID == state.turnID,
              now < state.deadline else {
            return .ignored
        }

        guard number == state.targetNumber else {
            switchTurn(now: now)
            return .wrong(number: number)
        }

        state.scores[playerID, default: 0] += 1

        let selectedTarget = state.targetNumber
        state.targetNumber += 1

        if selectedTarget >= 100 {
            state.isFinished = true
            return .finished(number: selectedTarget)
        }

        // Jucătorul păstrează tura și primește o secundă în plus
        // peste timpul care îi mai rămânea în momentul alegerii.
        let remaining = max(
            state.deadline.timeIntervalSince(now),
            0
        )

        state.turnStartedAt = now
        state.turnDuration = remaining + 1

        return .correct(number: selectedTarget)
    }

    mutating func expireTurn(
        expectedTurnID: UUID,
        now: Date = Date()
    ) -> Bool {
        guard !state.isFinished,
              state.turnID == expectedTurnID,
              now >= state.deadline else {
            return false
        }

        switchTurn(now: now)
        return true
    }

    mutating func reset(
        shuffledNumbers: [Int],
        startingPlayerID: String,
        now: Date = Date()
    ) {
        state = NumberRushGameState(
            shuffledNumbers: shuffledNumbers,
            targetNumber: 1,
            scores: [
                playerOneID: 0,
                playerTwoID: 0
            ],
            activePlayerID: startingPlayerID,
            turnID: UUID(),
            turnStartedAt: now,
            turnDuration: baseTurnDuration,
            isFinished: false
        )
    }

    private mutating func switchTurn(
        now: Date
    ) {
        state.activePlayerID =
            state.activePlayerID == playerOneID
            ? playerTwoID
            : playerOneID

        state.turnID = UUID()
        state.turnStartedAt = now
        state.turnDuration = baseTurnDuration
    }
}
