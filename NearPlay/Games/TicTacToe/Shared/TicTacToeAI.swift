import Foundation

enum TicTacToeAI {
    static func chooseIndex(
        state: TicTacToeGameState,
        playerOneID: String,
        playerTwoID: String,
        computerPlayerID: String,
        difficulty: GameAIDifficulty
    ) -> Int? {
        guard !state.isFinished,
              state.activePlayerID == computerPlayerID else {
            return nil
        }

        switch difficulty {
        case .easy:
            return state.availableIndexes.randomElement()

        case .medium:
            return mediumMove(
                state: state,
                playerOneID: playerOneID,
                playerTwoID: playerTwoID,
                computerPlayerID: computerPlayerID
            )

        case .hard:
            return hardMove(
                state: state,
                playerOneID: playerOneID,
                playerTwoID: playerTwoID,
                computerPlayerID: computerPlayerID
            )
        }
    }

    private static func mediumMove(
        state: TicTacToeGameState,
        playerOneID: String,
        playerTwoID: String,
        computerPlayerID: String
    ) -> Int? {
        let opponentID =
            computerPlayerID == playerOneID
            ? playerTwoID
            : playerOneID

        if let winningMove = immediateWinningIndex(
            state: state,
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            playerID: computerPlayerID
        ) {
            return winningMove
        }

        if let blockMove = immediateWinningIndex(
            state: state,
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            playerID: opponentID
        ) {
            return blockMove
        }

        if state.availableIndexes.contains(4) {
            return 4
        }

        let preferredIndexes = [
            0, 2, 6, 8, 1, 3, 5, 7
        ]

        return preferredIndexes.first {
            state.availableIndexes.contains($0)
        }
    }

    private static func hardMove(
        state: TicTacToeGameState,
        playerOneID: String,
        playerTwoID: String,
        computerPlayerID: String
    ) -> Int? {
        var bestScore = Int.min
        var bestIndex: Int?

        for index in orderedAvailableIndexes(state.availableIndexes) {
            guard let nextState = simulatedState(
                state: state,
                index: index,
                playerOneID: playerOneID,
                playerTwoID: playerTwoID,
                playerID: computerPlayerID
            ) else {
                continue
            }

            let score = minimax(
                state: nextState,
                playerOneID: playerOneID,
                playerTwoID: playerTwoID,
                maximizingPlayerID: computerPlayerID,
                depth: 0,
                isMaximizing: false
            )

            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        return bestIndex ??
            mediumMove(
                state: state,
                playerOneID: playerOneID,
                playerTwoID: playerTwoID,
                computerPlayerID: computerPlayerID
            )
    }

    private static func minimax(
        state: TicTacToeGameState,
        playerOneID: String,
        playerTwoID: String,
        maximizingPlayerID: String,
        depth: Int,
        isMaximizing: Bool
    ) -> Int {
        if let winnerID = state.winnerPlayerID {
            return winnerID == maximizingPlayerID
                ? 10 - depth
                : depth - 10
        }

        if state.isDraw {
            return 0
        }

        let activePlayerID = state.activePlayerID

        if isMaximizing {
            var bestScore = Int.min

            for index in orderedAvailableIndexes(state.availableIndexes) {
                guard let nextState = simulatedState(
                    state: state,
                    index: index,
                    playerOneID: playerOneID,
                    playerTwoID: playerTwoID,
                    playerID: activePlayerID
                ) else {
                    continue
                }

                bestScore = max(
                    bestScore,
                    minimax(
                        state: nextState,
                        playerOneID: playerOneID,
                        playerTwoID: playerTwoID,
                        maximizingPlayerID: maximizingPlayerID,
                        depth: depth + 1,
                        isMaximizing: false
                    )
                )
            }

            return bestScore
        }

        var bestScore = Int.max

        for index in orderedAvailableIndexes(state.availableIndexes) {
            guard let nextState = simulatedState(
                state: state,
                index: index,
                playerOneID: playerOneID,
                playerTwoID: playerTwoID,
                playerID: activePlayerID
            ) else {
                continue
            }

            bestScore = min(
                bestScore,
                minimax(
                    state: nextState,
                    playerOneID: playerOneID,
                    playerTwoID: playerTwoID,
                    maximizingPlayerID: maximizingPlayerID,
                    depth: depth + 1,
                    isMaximizing: true
                )
            )
        }

        return bestScore
    }

    private static func immediateWinningIndex(
        state: TicTacToeGameState,
        playerOneID: String,
        playerTwoID: String,
        playerID: String
    ) -> Int? {
        for index in orderedAvailableIndexes(state.availableIndexes) {
            guard let nextState = simulatedState(
                state: state,
                index: index,
                playerOneID: playerOneID,
                playerTwoID: playerTwoID,
                playerID: playerID
            ) else {
                continue
            }

            if nextState.winnerPlayerID == playerID {
                return index
            }
        }

        return nil
    }

    private static func simulatedState(
        state: TicTacToeGameState,
        index: Int,
        playerOneID: String,
        playerTwoID: String,
        playerID: String
    ) -> TicTacToeGameState? {
        var game = TicTacToeGame(
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            state: state
        )

        let result = game.play(
            index: index,
            by: playerID,
            turnID: state.turnID
        )

        guard result.didPlaceMark else {
            return nil
        }

        return game.state
    }

    private static func orderedAvailableIndexes(
        _ indexes: [Int]
    ) -> [Int] {
        let preferred = [
            4, 0, 2, 6, 8, 1, 3, 5, 7
        ]

        return preferred.filter {
            indexes.contains($0)
        }
    }
}
