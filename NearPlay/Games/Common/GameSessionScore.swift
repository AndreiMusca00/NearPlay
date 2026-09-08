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

    mutating func record(
        localResult: GameRoundResult,
        roundNumber: Int
    ) {
        let outcome: GameSessionRoundOutcome

        switch localResult {
        case .win:
            outcome = .firstPlayerWin
        case .loss:
            outcome = .secondPlayerWin
        case .draw:
            outcome = .draw
        }

        record(
            outcome,
            roundNumber: roundNumber
        )
    }

    var totalRounds: Int {
        firstPlayerWins + secondPlayerWins + draws
    }
}
