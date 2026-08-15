import Foundation

struct NumberRushGameState: Codable, Equatable, Sendable {
    var shuffledNumbers: [Int]
    var targetNumber: Int
    var scores: [String: Int]

    var activePlayerID: String
    var turnID: UUID
    var turnStartedAt: Date
    var turnDuration: TimeInterval

    var isFinished: Bool

    var deadline: Date {
        turnStartedAt.addingTimeInterval(turnDuration)
    }

    var completedNumbers: Set<Int> {
        guard targetNumber > 1 else {
            return []
        }

        return Set(1..<targetNumber)
    }

    var availableNumbers: [Int] {
        shuffledNumbers.filter {
            !completedNumbers.contains($0)
        }
    }
}

enum NumberRushSelectionOutcome: Equatable, Sendable {
    case ignored
    case correct(number: Int)
    case wrong(number: Int)
    case finished(number: Int)

    var didChangeState: Bool {
        switch self {
        case .correct, .wrong, .finished:
            return true
        case .ignored:
            return false
        }
    }

    var didScore: Bool {
        switch self {
        case .correct, .finished:
            return true
        case .ignored, .wrong:
            return false
        }
    }
}

struct NumberRushPlayerPresentation: Identifiable, Equatable {
    let id: String
    let name: String
    let inactiveBadge: String
}

enum NumberRushFeedbackTone {
    case neutral
    case success
    case danger

    var iconName: String {
        switch self {
        case .neutral:
            return "clock.fill"
        case .success:
            return "checkmark.circle.fill"
        case .danger:
            return "xmark.octagon.fill"
        }
    }
}

struct NumberRushFeedbackMessage: Equatable {
    let text: String
    let tone: NumberRushFeedbackTone
}
