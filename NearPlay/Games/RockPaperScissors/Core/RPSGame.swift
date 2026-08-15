import Foundation

struct RPSGame: Sendable {
    let playerOneID: String
    let playerTwoID: String

    private(set) var state: RPSGameState

    init(
        playerOneID: String,
        playerTwoID: String,
        state: RPSGameState
    ) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID
        self.state = state
    }

    static func makeInitialState() -> RPSGameState {
        RPSGameState(
            roundID: UUID(),
            playerOneChoice: nil,
            playerTwoChoice: nil,
            winnerPlayerID: nil,
            isDraw: false
        )
    }

    mutating func applyRemoteState(
        _ newState: RPSGameState
    ) {
        state = newState
    }

    mutating func reset() {
        state = Self.makeInitialState()
    }

    @discardableResult
    mutating func choose(
        _ choice: RPSChoice,
        by playerID: String,
        roundID: UUID
    ) -> RPSMoveResult {
        guard !state.isFinished,
              state.roundID == roundID,
              playerID == playerOneID ||
              playerID == playerTwoID else {
            return .ignored
        }

        if playerID == playerOneID {
            guard state.playerOneChoice == nil else {
                return .alreadyChosen
            }

            state.playerOneChoice = choice
        } else {
            guard state.playerTwoChoice == nil else {
                return .alreadyChosen
            }

            state.playerTwoChoice = choice
        }

        return evaluateIfReady()
    }

    func choice(
        for playerID: String
    ) -> RPSChoice? {
        state.choice(
            for: playerID,
            playerOneID: playerOneID,
            playerTwoID: playerTwoID
        )
    }

    private mutating func evaluateIfReady() -> RPSMoveResult {
        guard let playerOneChoice =
                state.playerOneChoice,
              let playerTwoChoice =
                state.playerTwoChoice else {
            return .stored
        }

        if playerOneChoice == playerTwoChoice {
            state.isDraw = true
            state.winnerPlayerID = nil
            return .completed
        }

        if playerOneChoice.beats(playerTwoChoice) {
            state.winnerPlayerID = playerOneID
        } else {
            state.winnerPlayerID = playerTwoID
        }

        state.isDraw = false
        return .completed
    }
}
