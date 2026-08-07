//
//  ConnectFourGame.swift
//  NearPlay
//

import Foundation

struct ConnectFourGame: Sendable {
    static let rows = 6
    static let columns = 7

    let playerOneID: String
    let playerTwoID: String

    private(set) var state: ConnectFourGameState

    init(
        playerOneID: String,
        playerTwoID: String,
        state: ConnectFourGameState
    ) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID
        self.state = state
    }

    static func makeInitialState(
        startingPlayerID: String
    ) -> ConnectFourGameState {
        ConnectFourGameState(
            board: Array(
                repeating: nil,
                count: rows * columns
            ),
            activePlayerID: startingPlayerID,
            turnID: UUID(),
            lastMove: nil,
            winnerPlayerID: nil,
            winningCoordinates: [],
            isDraw: false
        )
    }

    mutating func applyRemoteState(
        _ newState: ConnectFourGameState
    ) {
        state = newState
    }

    mutating func reset(
        startingPlayerID: String
    ) {
        state = Self.makeInitialState(
            startingPlayerID: startingPlayerID
        )
    }

    @discardableResult
    mutating func play(
        column: Int,
        by playerID: String,
        turnID: UUID
    ) -> ConnectFourMoveResult {
        guard !state.isFinished,
              playerID == state.activePlayerID,
              turnID == state.turnID,
              column >= 0,
              column < Self.columns,
              let disc = disc(for: playerID) else {
            return .ignored
        }

        guard let row = availableRow(
            in: column
        ) else {
            return .columnFull
        }

        let coordinate = ConnectFourCoordinate(
            row: row,
            column: column
        )

        state.board[
            ConnectFourGameState.index(
                row: row,
                column: column
            )
        ] = disc

        state.lastMove = coordinate

        let winningLine = winningCoordinates(
            from: coordinate,
            disc: disc
        )

        if !winningLine.isEmpty {
            state.winnerPlayerID = playerID
            state.winningCoordinates = winningLine
            return .won(coordinate)
        }

        if state.board.allSatisfy({ $0 != nil }) {
            state.isDraw = true
            return .draw(coordinate)
        }

        state.activePlayerID =
            playerID == playerOneID
            ? playerTwoID
            : playerOneID

        state.turnID = UUID()
        return .placed(coordinate)
    }

    func disc(
        for playerID: String
    ) -> ConnectFourDisc? {
        if playerID == playerOneID {
            return .playerOne
        }

        if playerID == playerTwoID {
            return .playerTwo
        }

        return nil
    }

    private func availableRow(
        in column: Int
    ) -> Int? {
        stride(
            from: Self.rows - 1,
            through: 0,
            by: -1
        )
        .first {
            state.disc(
                row: $0,
                column: column
            ) == nil
        }
    }

    private func winningCoordinates(
        from coordinate: ConnectFourCoordinate,
        disc: ConnectFourDisc
    ) -> [ConnectFourCoordinate] {
        let directions = [
            (row: 0, column: 1),
            (row: 1, column: 0),
            (row: 1, column: 1),
            (row: 1, column: -1)
        ]

        for direction in directions {
            var negativeSide: [ConnectFourCoordinate] = []
            var positiveSide: [ConnectFourCoordinate] = []

            var row = coordinate.row - direction.row
            var column = coordinate.column - direction.column

            while ConnectFourGameState.isInsideBoard(
                row: row,
                column: column
            ),
            state.disc(
                row: row,
                column: column
            ) == disc {
                negativeSide.append(
                    ConnectFourCoordinate(
                        row: row,
                        column: column
                    )
                )

                row -= direction.row
                column -= direction.column
            }

            row = coordinate.row + direction.row
            column = coordinate.column + direction.column

            while ConnectFourGameState.isInsideBoard(
                row: row,
                column: column
            ),
            state.disc(
                row: row,
                column: column
            ) == disc {
                positiveSide.append(
                    ConnectFourCoordinate(
                        row: row,
                        column: column
                    )
                )

                row += direction.row
                column += direction.column
            }

            let line =
                negativeSide.reversed() +
                [coordinate] +
                positiveSide

            if line.count >= 4 {
                return Array(line)
            }
        }

        return []
    }
}
