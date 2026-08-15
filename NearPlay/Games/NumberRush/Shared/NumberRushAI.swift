import Foundation

struct NumberRushAIProfile: Sendable {
    let minThinkDelay: TimeInterval
    let maxThinkDelay: TimeInterval
    let mistakeChance: Double
    let timeoutChance: Double
    let fatigueAfterCorrectChoices: Int
    let fatigueDelayPerCorrectChoice: TimeInterval
}

struct NumberRushAIAction: Sendable {
    let selectedNumber: Int?
    let delay: TimeInterval

    var waitsForTimeout: Bool {
        selectedNumber == nil
    }
}

enum NumberRushAI {
    static func action(
        state: NumberRushGameState,
        difficulty: GameAIDifficulty,
        consecutiveCorrectChoices: Int,
        now: Date = Date()
    ) -> NumberRushAIAction? {
        guard !state.isFinished else {
            return nil
        }

        let profile = difficulty.numberRushAIProfile
        let fatigueCount = max(
            consecutiveCorrectChoices - profile.fatigueAfterCorrectChoices,
            0
        )

        let fatigueDelay =
            Double(fatigueCount) *
            profile.fatigueDelayPerCorrectChoice

        let baseDelay = Double.random(
            in: profile.minThinkDelay...profile.maxThinkDelay
        )

        let remaining = max(
            state.deadline.timeIntervalSince(now),
            0
        )

        if Double.random(in: 0...1) < profile.timeoutChance {
            return NumberRushAIAction(
                selectedNumber: nil,
                delay: remaining + 0.08
            )
        }

        let safeDelay = min(
            baseDelay + fatigueDelay,
            max(0.08, remaining * 0.82)
        )

        let adjustedMistakeChance = min(
            profile.mistakeChance + Double(fatigueCount) * 0.01,
            0.45
        )

        let shouldMistake =
            Double.random(in: 0...1) < adjustedMistakeChance

        let selectedNumber = shouldMistake
            ? plausibleWrongNumber(for: state)
            : state.targetNumber

        return NumberRushAIAction(
            selectedNumber: selectedNumber,
            delay: safeDelay
        )
    }

    private static func plausibleWrongNumber(
        for state: NumberRushGameState
    ) -> Int {
        let target = state.targetNumber

        let preferredOffsets = [
            1,
            -1,
            10,
            -10,
            2,
            -2,
            9,
            -9,
            11,
            -11
        ]

        let uncompletedNumbers = Set(
            state.shuffledNumbers.filter {
                !state.completedNumbers.contains($0) &&
                $0 != target
            }
        )

        for offset in preferredOffsets.shuffled() {
            let candidate = target + offset

            if uncompletedNumbers.contains(candidate) {
                return candidate
            }
        }

        return Array(uncompletedNumbers).randomElement() ??
            target
    }
}

extension GameAIDifficulty {
    var numberRushAIProfile: NumberRushAIProfile {
        switch self {
        case .easy:
            return NumberRushAIProfile(
                minThinkDelay: 1.8,
                maxThinkDelay: 3.2,
                mistakeChance: 0.30,
                timeoutChance: 0.12,
                fatigueAfterCorrectChoices: 2,
                fatigueDelayPerCorrectChoice: 0.12
            )

        case .medium:
            return NumberRushAIProfile(
                minThinkDelay: 0.9,
                maxThinkDelay: 1.7,
                mistakeChance: 0.12,
                timeoutChance: 0.03,
                fatigueAfterCorrectChoices: 5,
                fatigueDelayPerCorrectChoice: 0.06
            )

        case .hard:
            return NumberRushAIProfile(
                minThinkDelay: 0.35,
                maxThinkDelay: 0.85,
                mistakeChance: 0.03,
                timeoutChance: 0.00,
                fatigueAfterCorrectChoices: 8,
                fatigueDelayPerCorrectChoice: 0.035
            )
        }
    }
}
