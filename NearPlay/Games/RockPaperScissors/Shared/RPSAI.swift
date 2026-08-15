import Foundation

enum RPSAI {
    static func chooseChoice(
        difficulty: GameAIDifficulty,
        humanHistory: [RPSChoice]
    ) -> RPSChoice {
        switch difficulty {
        case .easy:
            return RPSChoice.allCases.randomElement() ?? .rock

        case .medium:
            if let lastChoice = humanHistory.last,
               Bool.random() {
                return RPSChoice.counter(for: lastChoice)
            }

            return RPSChoice.allCases.randomElement() ?? .rock

        case .hard:
            guard !humanHistory.isEmpty else {
                return RPSChoice.allCases.randomElement() ?? .rock
            }

            let grouped = Dictionary(
                grouping: humanHistory,
                by: { $0 }
            )

            let mostCommon =
                grouped
                .max { lhs, rhs in
                    lhs.value.count < rhs.value.count
                }?
                .key ?? humanHistory.last ?? .rock

            return RPSChoice.counter(for: mostCommon)
        }
    }
}
