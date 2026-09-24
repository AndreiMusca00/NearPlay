import Foundation

struct BackgammonAI {
    static func chooseMove(
        from moves: [BackgammonMove],
        state: BackgammonGameState,
        player: BackgammonPlayer,
        difficulty: GameAIDifficulty
    ) -> BackgammonMove? {
        guard !moves.isEmpty else {
            return nil
        }

        switch difficulty {
        case .easy:
            return moves.randomElement()

        case .medium:
            return moves.max {
                score(
                    $0,
                    state: state,
                    player: player,
                    advanced: false
                ) < score(
                    $1,
                    state: state,
                    player: player,
                    advanced: false
                )
            }

        case .hard:
            return moves.max {
                score(
                    $0,
                    state: state,
                    player: player,
                    advanced: true
                ) < score(
                    $1,
                    state: state,
                    player: player,
                    advanced: true
                )
            }
        }
    }

    private static func score(
        _ move: BackgammonMove,
        state: BackgammonGameState,
        player: BackgammonPlayer,
        advanced: Bool
    ) -> Int {
        var value = 0

        if move.destination == nil {
            value += 120
        }

        if move.source == nil {
            value += 70
        }

        if let destination = move.destination {
            let point = state.points[destination]

            if point.owner == player.opponent,
               point.count == 1 {
                value += advanced ? 95 : 70
            }

            if point.owner == player,
               point.count == 1 {
                value += advanced ? 45 : 25
            }

            let progress = player == .playerOne
                ? 23 - destination
                : destination

            value += progress
        }

        if advanced,
           let source = move.source,
           state.points[source].count == 2 {
            // Avoid breaking a made point unless the move is otherwise valuable.
            value -= 25
        }

        value += move.die
        return value
    }
}
