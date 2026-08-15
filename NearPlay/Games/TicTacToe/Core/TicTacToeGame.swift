import Foundation

struct TicTacToeGame: Sendable {
    static let cellCount = 9

    let playerOneID: String
    let playerTwoID: String

    private(set) var state: TicTacToeGameState

    init(
        playerOneID: String,
        playerTwoID: String,
        state: TicTacToeGameState
    ) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID
        self.state = state
    }

    static func makeInitialState(
        startingPlayerID: String
    ) -> TicTacToeGameState {
        TicTacToeGameState(
            board: Array(repeating: nil, count: cellCount),
            activePlayerID: startingPlayerID,
            turnID: UUID(),
            lastMoveIndex: nil,
            winnerPlayerID: nil,
            winningIndexes: [],
            isDraw: false
        )
    }

    mutating func applyRemoteState(
        _ newState: TicTacToeGameState
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
        index: Int,
        by playerID: String,
        turnID: UUID
    ) -> TicTacToeMoveResult {
        guard !state.isFinished,
              playerID == state.activePlayerID,
              turnID == state.turnID,
              TicTacToeGameState.isValidIndex(index),
              let mark = mark(for: playerID) else {
            return .ignored
        }

        guard state.board[index] == nil else {
            return .occupied
        }

        state.board[index] = mark
        state.lastMoveIndex = index

        let winningLine = winningIndexes(for: mark)

        if !winningLine.isEmpty {
            state.winnerPlayerID = playerID
            state.winningIndexes = winningLine
            return .won(index)
        }

        if state.board.allSatisfy({ $0 != nil }) {
            state.isDraw = true
            return .draw(index)
        }

        state.activePlayerID =
            playerID == playerOneID
            ? playerTwoID
            : playerOneID

        state.turnID = UUID()

        return .placed(index)
    }

    func mark(
        for playerID: String
    ) -> TicTacToeMark? {
        if playerID == playerOneID {
            return .x
        }

        if playerID == playerTwoID {
            return .o
        }

        return nil
    }

    private func winningIndexes(
        for mark: TicTacToeMark
    ) -> [Int] {
        let combinations = [
            [0, 1, 2],
            [3, 4, 5],
            [6, 7, 8],
            [0, 3, 6],
            [1, 4, 7],
            [2, 5, 8],
            [0, 4, 8],
            [2, 4, 6]
        ]

        for combination in combinations {
            if combination.allSatisfy({ state.board[$0] == mark }) {
                return combination
            }
        }

        return []
    }
}
