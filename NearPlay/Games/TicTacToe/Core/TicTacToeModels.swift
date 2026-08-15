import Foundation

enum TicTacToeMark: String, Codable, Equatable, Hashable, Sendable {
    case x
    case o

    var opposite: TicTacToeMark {
        self == .x ? .o : .x
    }

    var title: String {
        switch self {
        case .x:
            return "X"
        case .o:
            return "O"
        }
    }

    var systemName: String {
        switch self {
        case .x:
            return "xmark"
        case .o:
            return "circle"
        }
    }
}

struct TicTacToeGameState: Codable, Equatable, Sendable {
    var board: [TicTacToeMark?]

    var activePlayerID: String
    var turnID: UUID

    var lastMoveIndex: Int?
    var winnerPlayerID: String?
    var winningIndexes: [Int]
    var isDraw: Bool

    var isFinished: Bool {
        winnerPlayerID != nil || isDraw
    }

    var availableIndexes: [Int] {
        board.indices.filter { board[$0] == nil }
    }

    func mark(at index: Int) -> TicTacToeMark? {
        guard Self.isValidIndex(index) else {
            return nil
        }

        return board[index]
    }

    func isCellEmpty(_ index: Int) -> Bool {
        guard Self.isValidIndex(index) else {
            return false
        }

        return board[index] == nil
    }

    static func isValidIndex(_ index: Int) -> Bool {
        index >= 0 && index < 9
    }
}

enum TicTacToeMoveResult: Equatable, Sendable {
    case ignored
    case occupied
    case placed(Int)
    case won(Int)
    case draw(Int)

    var didPlaceMark: Bool {
        switch self {
        case .placed, .won, .draw:
            return true
        case .ignored, .occupied:
            return false
        }
    }
}
