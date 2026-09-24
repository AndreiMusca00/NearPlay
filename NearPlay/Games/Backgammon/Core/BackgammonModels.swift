import Foundation

enum BackgammonPlayer: String, Codable, Hashable, Sendable {
    case playerOne
    case playerTwo

    var opponent: BackgammonPlayer {
        self == .playerOne ? .playerTwo : .playerOne
    }
}

struct BackgammonPoint: Codable, Equatable, Sendable {
    var owner: BackgammonPlayer?
    var count: Int

    static let empty = BackgammonPoint(owner: nil, count: 0)
}

/// `source == nil` means the move starts from the bar.
/// `destination == nil` means the checker is borne off.
struct BackgammonMove: Codable, Equatable, Hashable, Sendable {
    let source: Int?
    let destination: Int?
    let die: Int
}


/// A legal destination reachable by moving the same checker through one or
/// more dice during the current turn.
struct BackgammonMoveOption: Equatable, Hashable, Sendable {
    let source: Int?
    let destination: Int?
    let moves: [BackgammonMove]

    var diceUsed: [Int] {
        moves.map(\.die)
    }

    var moveCount: Int {
        moves.count
    }

    var totalPips: Int {
        moves.reduce(0) { partialResult, move in
            partialResult + move.die
        }
    }
}

struct BackgammonGameState: Codable, Equatable, Sendable {
    var points: [BackgammonPoint]

    var playerOneBar: Int
    var playerTwoBar: Int

    var playerOneBorneOff: Int
    var playerTwoBorneOff: Int

    var activePlayerID: String
    var turnID: UUID

    /// Dice rolled at the beginning of the current turn.
    /// Empty means the active player still needs to roll.
    var dice: [Int]

    /// Dice that are still available for moves this turn.
    /// Doubles are represented four times.
    var remainingDice: [Int]

    var lastMove: BackgammonMove?
    var winnerPlayerID: String?

    var isFinished: Bool {
        winnerPlayerID != nil
    }

    var hasRolled: Bool {
        !dice.isEmpty
    }

    /// Doubles use two visual passes: shade each die, then restore each die.
    /// Derived from remaining dice so Undo and multi-die moves stay in sync.
    func isDieShaded(at index: Int) -> Bool {
        guard dice.count == 2, dice.indices.contains(index) else { return false }
        if dice[0] == dice[1] {
            let used = max(0, min(4, 4 - remainingDice.count))
            return used > index && used < index + 3
        }
        return !remainingDice.contains(dice[index])
    }

    func barCount(for player: BackgammonPlayer) -> Int {
        player == .playerOne ? playerOneBar : playerTwoBar
    }

    func borneOffCount(for player: BackgammonPlayer) -> Int {
        player == .playerOne ? playerOneBorneOff : playerTwoBorneOff
    }
}

enum BackgammonRollResult: Equatable, Sendable {
    case ignored
    case rolled([Int])
    case noLegalMoves([Int])
}

enum BackgammonMoveResult: Equatable, Sendable {
    case ignored
    case moved(BackgammonMove, didHit: Bool)
    case turnEnded(BackgammonMove, didHit: Bool)
    case won(BackgammonMove)
}
