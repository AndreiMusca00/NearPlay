import SwiftUI
import Combine

final class TicTacToeMatchController: ObservableObject {
    let playerOneID: String
    let playerTwoID: String

    @Published
    private(set) var state: TicTacToeGameState

    @Published
    private(set) var animationID = UUID()

    private var game: TicTacToeGame

    init(
        playerOneID: String,
        playerTwoID: String,
        initialState: TicTacToeGameState
    ) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID

        let game = TicTacToeGame(
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            state: initialState
        )

        self.game = game
        self.state = game.state
    }

    @discardableResult
    func play(
        index: Int,
        by playerID: String,
        turnID: UUID? = nil
    ) -> TicTacToeMoveResult {
        let previousLastMove = game.state.lastMoveIndex

        let result = game.play(
            index: index,
            by: playerID,
            turnID: turnID ?? game.state.turnID
        )

        state = game.state

        if result.didPlaceMark,
           game.state.lastMoveIndex != previousLastMove {
            animationID = UUID()
        }

        return result
    }

    func applyRemoteState(
        _ newState: TicTacToeGameState,
        animateLastMove: Bool
    ) {
        let previousLastMove = game.state.lastMoveIndex

        game.applyRemoteState(newState)
        state = game.state

        if animateLastMove,
           newState.lastMoveIndex != nil,
           newState.lastMoveIndex != previousLastMove {
            animationID = UUID()
        }
    }

    func reset(
        startingPlayerID: String
    ) {
        game.reset(
            startingPlayerID: startingPlayerID
        )

        state = game.state
        animationID = UUID()
    }

    func mark(
        for playerID: String
    ) -> TicTacToeMark? {
        game.mark(for: playerID)
    }
}
