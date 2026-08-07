//
//  ConnectFourAI.swift
//  NearPlay
//

import Foundation

enum ConnectFourAI {
    static func chooseColumn(
        state: ConnectFourGameState,
        playerOneID: String,
        playerTwoID: String,
        computerPlayerID: String,
        difficulty: ConnectFourDifficulty
    ) -> Int? {
        guard !state.isFinished,
              state.activePlayerID ==
                computerPlayerID else {
            return nil
        }

        switch difficulty {
        case .easy:
            return state.availableColumns.randomElement()

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
        state: ConnectFourGameState,
        playerOneID: String,
        playerTwoID: String,
        computerPlayerID: String
    ) -> Int? {
        let opponentID =
            computerPlayerID == playerOneID
            ? playerTwoID
            : playerOneID

        if let winning = immediateWinningColumn(
            state: state,
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            playerID: computerPlayerID
        ) {
            return winning
        }

        if let block = immediateWinningColumn(
            state: state,
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            playerID: opponentID
        ) {
            return block
        }

        let preferredColumns = [
            3, 2, 4, 1, 5, 0, 6
        ]

        return preferredColumns.first {
            state.availableColumns.contains($0)
        }
    }

    private static func hardMove(
        state: ConnectFourGameState,
        playerOneID: String,
        playerTwoID: String,
        computerPlayerID: String
    ) -> Int? {
        if let tactical = mediumMove(
            state: state,
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            computerPlayerID: computerPlayerID
        ),
        let immediate = simulatedState(
            state: state,
            column: tactical,
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            playerID: computerPlayerID
        ),
        immediate.winnerPlayerID ==
            computerPlayerID {
            return tactical
        }

        var bestScore = Int.min
        var bestColumn: Int?

        let orderedColumns = orderedAvailableColumns(
            state.availableColumns
        )

        for column in orderedColumns {
            guard let nextState = simulatedState(
                state: state,
                column: column,
                playerOneID: playerOneID,
                playerTwoID: playerTwoID,
                playerID: computerPlayerID
            ) else {
                continue
            }

            let score = minimax(
                state: nextState,
                depth: 5,
                alpha: Int.min / 2,
                beta: Int.max / 2,
                maximizingPlayerID:
                    computerPlayerID,
                playerOneID: playerOneID,
                playerTwoID: playerTwoID
            )

            if score > bestScore {
                bestScore = score
                bestColumn = column
            }
        }

        return bestColumn ??
            mediumMove(
                state: state,
                playerOneID: playerOneID,
                playerTwoID: playerTwoID,
                computerPlayerID: computerPlayerID
            )
    }

    private static func minimax(
        state: ConnectFourGameState,
        depth: Int,
        alpha: Int,
        beta: Int,
        maximizingPlayerID: String,
        playerOneID: String,
        playerTwoID: String
    ) -> Int {
        if let winner = state.winnerPlayerID {
            return winner == maximizingPlayerID
                ? 1_000_000 + depth
                : -1_000_000 - depth
        }

        if state.isDraw {
            return 0
        }

        if depth == 0 {
            return evaluate(
                state: state,
                maximizingPlayerID:
                    maximizingPlayerID,
                playerOneID: playerOneID,
                playerTwoID: playerTwoID
            )
        }

        let isMaximizing =
            state.activePlayerID ==
            maximizingPlayerID

        var localAlpha = alpha
        var localBeta = beta

        if isMaximizing {
            var value = Int.min / 2

            for column in orderedAvailableColumns(
                state.availableColumns
            ) {
                guard let nextState = simulatedState(
                    state: state,
                    column: column,
                    playerOneID: playerOneID,
                    playerTwoID: playerTwoID,
                    playerID:
                        state.activePlayerID
                ) else {
                    continue
                }

                value = max(
                    value,
                    minimax(
                        state: nextState,
                        depth: depth - 1,
                        alpha: localAlpha,
                        beta: localBeta,
                        maximizingPlayerID:
                            maximizingPlayerID,
                        playerOneID: playerOneID,
                        playerTwoID: playerTwoID
                    )
                )

                localAlpha = max(
                    localAlpha,
                    value
                )

                if localAlpha >= localBeta {
                    break
                }
            }

            return value
        }

        var value = Int.max / 2

        for column in orderedAvailableColumns(
            state.availableColumns
        ) {
            guard let nextState = simulatedState(
                state: state,
                column: column,
                playerOneID: playerOneID,
                playerTwoID: playerTwoID,
                playerID:
                    state.activePlayerID
            ) else {
                continue
            }

            value = min(
                value,
                minimax(
                    state: nextState,
                    depth: depth - 1,
                    alpha: localAlpha,
                    beta: localBeta,
                    maximizingPlayerID:
                        maximizingPlayerID,
                    playerOneID: playerOneID,
                    playerTwoID: playerTwoID
                )
            )

            localBeta = min(
                localBeta,
                value
            )

            if localAlpha >= localBeta {
                break
            }
        }

        return value
    }

    private static func evaluate(
        state: ConnectFourGameState,
        maximizingPlayerID: String,
        playerOneID: String,
        playerTwoID: String
    ) -> Int {
        let maximizingDisc =
            maximizingPlayerID == playerOneID
            ? ConnectFourDisc.playerOne
            : ConnectFourDisc.playerTwo

        let minimizingDisc =
            maximizingDisc == .playerOne
            ? ConnectFourDisc.playerTwo
            : ConnectFourDisc.playerOne

        var score = 0

        for row in 0..<ConnectFourGame.rows {
            if state.disc(
                row: row,
                column: 3
            ) == maximizingDisc {
                score += 7
            }
        }

        let windows = allWindows()

        for window in windows {
            let discs = window.map {
                state.disc(
                    row: $0.row,
                    column: $0.column
                )
            }

            score += windowScore(
                discs: discs,
                maximizingDisc: maximizingDisc,
                minimizingDisc: minimizingDisc
            )
        }

        return score
    }

    private static func windowScore(
        discs: [ConnectFourDisc?],
        maximizingDisc: ConnectFourDisc,
        minimizingDisc: ConnectFourDisc
    ) -> Int {
        let maximizingCount =
            discs.filter {
                $0 == maximizingDisc
            }
            .count

        let minimizingCount =
            discs.filter {
                $0 == minimizingDisc
            }
            .count

        let emptyCount =
            discs.filter {
                $0 == nil
            }
            .count

        if maximizingCount == 4 {
            return 100_000
        }

        if maximizingCount == 3 &&
            emptyCount == 1 {
            return 120
        }

        if maximizingCount == 2 &&
            emptyCount == 2 {
            return 18
        }

        if minimizingCount == 3 &&
            emptyCount == 1 {
            return -145
        }

        if minimizingCount == 2 &&
            emptyCount == 2 {
            return -15
        }

        return 0
    }

    private static func immediateWinningColumn(
        state: ConnectFourGameState,
        playerOneID: String,
        playerTwoID: String,
        playerID: String
    ) -> Int? {
        for column in orderedAvailableColumns(
            state.availableColumns
        ) {
            var adjustedState = state
            adjustedState.activePlayerID = playerID
            adjustedState.turnID = UUID()

            guard let result = simulatedState(
                state: adjustedState,
                column: column,
                playerOneID: playerOneID,
                playerTwoID: playerTwoID,
                playerID: playerID
            ) else {
                continue
            }

            if result.winnerPlayerID == playerID {
                return column
            }
        }

        return nil
    }

    private static func simulatedState(
        state: ConnectFourGameState,
        column: Int,
        playerOneID: String,
        playerTwoID: String,
        playerID: String
    ) -> ConnectFourGameState? {
        var game = ConnectFourGame(
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            state: state
        )

        let result = game.play(
            column: column,
            by: playerID,
            turnID: state.turnID
        )

        switch result {
        case .placed, .won, .draw:
            return game.state
        case .ignored, .columnFull:
            return nil
        }
    }

    private static func orderedAvailableColumns(
        _ columns: [Int]
    ) -> [Int] {
        let priority = [3, 2, 4, 1, 5, 0, 6]

        return priority.filter {
            columns.contains($0)
        }
    }

    private static func allWindows()
        -> [[ConnectFourCoordinate]] {
        var windows: [[ConnectFourCoordinate]] = []

        for row in 0..<ConnectFourGame.rows {
            for column in 0...(ConnectFourGame.columns - 4) {
                windows.append(
                    (0..<4).map {
                        ConnectFourCoordinate(
                            row: row,
                            column: column + $0
                        )
                    }
                )
            }
        }

        for column in 0..<ConnectFourGame.columns {
            for row in 0...(ConnectFourGame.rows - 4) {
                windows.append(
                    (0..<4).map {
                        ConnectFourCoordinate(
                            row: row + $0,
                            column: column
                        )
                    }
                )
            }
        }

        for row in 0...(ConnectFourGame.rows - 4) {
            for column in 0...(ConnectFourGame.columns - 4) {
                windows.append(
                    (0..<4).map {
                        ConnectFourCoordinate(
                            row: row + $0,
                            column: column + $0
                        )
                    }
                )
            }
        }

        for row in 0...(ConnectFourGame.rows - 4) {
            for column in 3..<ConnectFourGame.columns {
                windows.append(
                    (0..<4).map {
                        ConnectFourCoordinate(
                            row: row + $0,
                            column: column - $0
                        )
                    }
                )
            }
        }

        return windows
    }
}
