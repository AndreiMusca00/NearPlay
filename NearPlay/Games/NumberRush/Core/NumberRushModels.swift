import Foundation

struct NumberRushGameState: Codable, Equatable, Sendable {
    var shuffledNumbers: [Int]
    var targetNumber: Int
    var scores: [String: Int]
    var claimedNumberOwners: [Int: String] = [:]

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

extension NumberRushGameState {
    private enum CodingKeys: String, CodingKey {
        case shuffledNumbers
        case targetNumber
        case scores
        case claimedNumberOwners
        case activePlayerID
        case turnID
        case turnStartedAt
        case turnDuration
        case isFinished
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        shuffledNumbers = try container.decode(
            [Int].self,
            forKey: .shuffledNumbers
        )
        targetNumber = try container.decode(
            Int.self,
            forKey: .targetNumber
        )
        scores = try container.decode(
            [String: Int].self,
            forKey: .scores
        )
        claimedNumberOwners = try container.decodeIfPresent(
            [Int: String].self,
            forKey: .claimedNumberOwners
        ) ?? [:]
        activePlayerID = try container.decode(
            String.self,
            forKey: .activePlayerID
        )
        turnID = try container.decode(
            UUID.self,
            forKey: .turnID
        )
        turnStartedAt = try container.decode(
            Date.self,
            forKey: .turnStartedAt
        )
        turnDuration = try container.decode(
            TimeInterval.self,
            forKey: .turnDuration
        )
        isFinished = try container.decode(
            Bool.self,
            forKey: .isFinished
        )
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
