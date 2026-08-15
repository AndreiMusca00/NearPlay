import SwiftUI
import Combine

final class RPSMatchController: ObservableObject {
    let playerOneID: String
    let playerTwoID: String

    @Published
    private(set) var state: RPSGameState

    @Published
    private(set) var animationID = UUID()

    private var game: RPSGame

    init(
        playerOneID: String,
        playerTwoID: String,
        initialState: RPSGameState
    ) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID

        let game = RPSGame(
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            state: initialState
        )

        self.game = game
        self.state = game.state
    }

    @discardableResult
    func choose(
        _ choice: RPSChoice,
        by playerID: String,
        roundID: UUID? = nil
    ) -> RPSMoveResult {
        let previousState = game.state

        let result = game.choose(
            choice,
            by: playerID,
            roundID: roundID ?? game.state.roundID
        )

        state = game.state

        if result.didStoreChoice,
           previousState != game.state {
            animationID = UUID()
        }

        return result
    }

    func applyRemoteState(
        _ newState: RPSGameState,
        animate: Bool
    ) {
        let previousState = game.state

        game.applyRemoteState(newState)
        state = game.state

        if animate,
           previousState != newState {
            animationID = UUID()
        }
    }

    func reset() {
        game.reset()
        state = game.state
        animationID = UUID()
    }

    func choice(
        for playerID: String
    ) -> RPSChoice? {
        game.choice(for: playerID)
    }
}
