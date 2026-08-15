import Foundation

enum RPSChoice:
    String,
    Codable,
    CaseIterable,
    Identifiable,
    Hashable,
    Sendable {

    case rock
    case paper
    case scissors

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .rock:
            return "Rock"
        case .paper:
            return "Paper"
        case .scissors:
            return "Scissors"
        }
    }

    var emoji: String {
        switch self {
        case .rock:
            return "🪨"
        case .paper:
            return "📄"
        case .scissors:
            return "✂️"
        }
    }

    var systemName: String {
        switch self {
        case .rock:
            return "circle.fill"
        case .paper:
            return "doc.fill"
        case .scissors:
            return "scissors"
        }
    }

    func beats(
        _ other: RPSChoice
    ) -> Bool {
        switch (self, other) {
        case (.rock, .scissors),
             (.paper, .rock),
             (.scissors, .paper):
            return true

        default:
            return false
        }
    }

    static func counter(
        for choice: RPSChoice
    ) -> RPSChoice {
        switch choice {
        case .rock:
            return .paper
        case .paper:
            return .scissors
        case .scissors:
            return .rock
        }
    }
}

struct RPSGameState:
    Codable,
    Equatable,
    Sendable {

    var roundID: UUID

    var playerOneChoice: RPSChoice?
    var playerTwoChoice: RPSChoice?

    var winnerPlayerID: String?
    var isDraw: Bool

    var isFinished: Bool {
        playerOneChoice != nil &&
        playerTwoChoice != nil
    }

    func choice(
        for playerID: String,
        playerOneID: String,
        playerTwoID: String
    ) -> RPSChoice? {
        if playerID == playerOneID {
            return playerOneChoice
        }

        if playerID == playerTwoID {
            return playerTwoChoice
        }

        return nil
    }

    var hasAnyChoice: Bool {
        playerOneChoice != nil ||
        playerTwoChoice != nil
    }
}

enum RPSMoveResult:
    Equatable,
    Sendable {

    case ignored
    case alreadyChosen
    case stored
    case completed

    var didStoreChoice: Bool {
        switch self {
        case .stored, .completed:
            return true
        case .ignored, .alreadyChosen:
            return false
        }
    }
}
