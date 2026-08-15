import SwiftUI
import Combine

final class NumberRushMatchController: ObservableObject {
    let playerOneID: String
    let playerTwoID: String

    @Published
    private(set) var state: NumberRushGameState

    @Published
    private(set) var animationID = UUID()

    private var game: NumberRushGame

    init(
        playerOneID: String,
        playerTwoID: String,
        shuffledNumbers: [Int],
        startingPlayerID: String,
        baseTurnDuration: TimeInterval = 5
    ) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID

        let game = NumberRushGame(
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            shuffledNumbers: shuffledNumbers,
            startingPlayerID: startingPlayerID,
            baseTurnDuration: baseTurnDuration
        )

        self.game = game
        self.state = game.state
    }

    init(
        playerOneID: String,
        playerTwoID: String,
        baseTurnDuration: TimeInterval,
        initialState: NumberRushGameState
    ) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID

        let game = NumberRushGame(
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            baseTurnDuration: baseTurnDuration,
            state: initialState
        )

        self.game = game
        self.state = game.state
    }

    @discardableResult
    func select(
        number: Int,
        by playerID: String,
        turnID: UUID? = nil
    ) -> NumberRushSelectionOutcome {
        let oldTargetNumber = game.state.targetNumber
        let oldActivePlayerID = game.state.activePlayerID

        let result = game.select(
            number: number,
            by: playerID,
            turnID: turnID ?? game.state.turnID
        )

        state = game.state

        if result.didChangeState,
           oldTargetNumber != game.state.targetNumber ||
            oldActivePlayerID != game.state.activePlayerID {
            animationID = UUID()
        }

        return result
    }

    @discardableResult
    func expireTurn(
        expectedTurnID: UUID
    ) -> Bool {
        let changed = game.expireTurn(
            expectedTurnID: expectedTurnID
        )

        if changed {
            state = game.state
            animationID = UUID()
        }

        return changed
    }

    func applyRemoteState(
        _ newState: NumberRushGameState,
        animate: Bool
    ) {
        let oldState = game.state

        game.applyRemoteState(newState)
        state = game.state

        if animate,
           oldState.targetNumber != newState.targetNumber ||
            oldState.activePlayerID != newState.activePlayerID ||
            oldState.isFinished != newState.isFinished {
            animationID = UUID()
        }
    }

    func reset(
        shuffledNumbers: [Int],
        startingPlayerID: String
    ) {
        game.reset(
            shuffledNumbers: shuffledNumbers,
            startingPlayerID: startingPlayerID
        )

        state = game.state
        animationID = UUID()
    }

    func opponentID(
        for playerID: String
    ) -> String {
        game.opponentID(for: playerID)
    }
}
