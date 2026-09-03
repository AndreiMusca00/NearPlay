import Foundation

enum GameSessionRoundOutcome {
    case firstPlayerWin
    case secondPlayerWin
    case draw
}

struct GameSessionScore {
    private(set) var firstPlayerWins = 0
    private(set) var secondPlayerWins = 0
    private(set) var draws = 0

    private var recordedRounds: Set<Int> = []

    mutating func record(
        _ outcome: GameSessionRoundOutcome,
        roundNumber: Int
    ) {
        guard recordedRounds.insert(roundNumber).inserted else {
            return
        }

        switch outcome {
        case .firstPlayerWin:
            firstPlayerWins += 1

        case .secondPlayerWin:
            secondPlayerWins += 1

        case .draw:
            draws += 1
        }
    }

    var totalRounds: Int {
        firstPlayerWins + secondPlayerWins + draws
    }
}
