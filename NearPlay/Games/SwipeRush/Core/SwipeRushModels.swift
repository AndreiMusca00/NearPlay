import Foundation

enum SwipeRushDirection: String, Codable, CaseIterable, Sendable {
    case up
    case right
    case down
    case left

    var symbolName: String {
        switch self {
        case .up: "arrow.up"
        case .right: "arrow.right"
        case .down: "arrow.down"
        case .left: "arrow.left"
        }
    }

    var title: String { rawValue.uppercased() }

    static func from(translation: CGSize) -> SwipeRushDirection? {
        let minimumDistance: CGFloat = 24
        guard hypot(translation.width, translation.height) >= minimumDistance else {
            return nil
        }

        if abs(translation.width) > abs(translation.height) {
            return translation.width > 0 ? .right : .left
        }

        return translation.height > 0 ? .down : .up
    }
}

struct SwipeRushTarget: Identifiable, Equatable, Sendable {
    let index: Int
    let direction: SwipeRushDirection
    let x: Double
    let y: Double

    var id: Int { index }
}

struct SwipeRushRunResult: Codable, Equatable, Sendable {
    let score: Int
    let completedSwipes: Int
    let mistakes: Int
    let bestCombo: Int
    let totalReactionTime: TimeInterval
}

struct SwipeRushPlayerProgress: Codable, Equatable, Sendable {
    var score = 0
    var completedSwipes = 0
    var mistakes = 0
    var combo = 0
    var bestCombo = 0
    var challengeIndex = 0
    var totalReactionTime: TimeInterval = 0
    var isFinished = false

    var result: SwipeRushRunResult {
        SwipeRushRunResult(
            score: score,
            completedSwipes: completedSwipes,
            mistakes: mistakes,
            bestCombo: bestCombo,
            totalReactionTime: totalReactionTime
        )
    }
}

struct SwipeRushMatchState: Codable, Equatable, Sendable {
    var roundID: UUID
    var startsAt: Date
    var targetSeed: Int
    var progress: [String: SwipeRushPlayerProgress]
    var winnerPlayerID: String?
    var isDraw: Bool

    func progress(for playerID: String) -> SwipeRushPlayerProgress {
        progress[playerID] ?? SwipeRushPlayerProgress()
    }

    var isFinished: Bool { winnerPlayerID != nil || isDraw }
}

struct SwipeRushStartPayload: Codable, Equatable {
    let sessionID: String
    let playerOneID: String
    let playerOneName: String
    let playerTwoID: String
    let playerTwoName: String
    let initialState: SwipeRushMatchState
}

struct SwipeRushProgressPayload: Codable, Equatable {
    let sessionID: String
    let roundID: UUID
    let eventID: UUID
    let playerID: String
    let progress: SwipeRushPlayerProgress
}

struct SwipeRushStatePayload: Codable, Equatable {
    let sessionID: String
    let state: SwipeRushMatchState
}

enum SwipeRushGame {
    static let runDuration: TimeInterval = 60
    static let mistakePenalty = 3

    static func targetSize(after completedSwipes: Int) -> Double {
        max(76, 126 - Double(completedSwipes) * 0.9)
    }

    static func promptTimeLimit(after completedSwipes: Int) -> TimeInterval {
        max(0.68, 1.80 - Double(completedSwipes) * 0.022)
    }

    static func points(reactionTime: TimeInterval, combo: Int) -> Int {
        let speedBonus = max(0, 5 - Int(reactionTime * 3.2))
        let comboBonus = min(5, combo / 4)
        return 5 + speedBonus + comboBonus
    }

    static func makeInitialState(
        playerOneID: String,
        playerTwoID: String,
        startsAt: Date = Date().addingTimeInterval(3.2)
    ) -> SwipeRushMatchState {
        SwipeRushMatchState(
            roundID: UUID(),
            startsAt: startsAt,
            targetSeed: Int.random(in: 1...2_000_000_000),
            progress: [
                playerOneID: SwipeRushPlayerProgress(),
                playerTwoID: SwipeRushPlayerProgress()
            ],
            winnerPlayerID: nil,
            isDraw: false
        )
    }

    static func target(seed: Int, index: Int) -> SwipeRushTarget {
        let mixedSeed = UInt64(max(seed, 1))
            ^ (UInt64(index + 1) &* 0x9E3779B97F4A7C15)
        var generator = SwipeRushSeededGenerator(seed: mixedSeed)
        let directions = SwipeRushDirection.allCases
        let direction = directions[Int(generator.next() % UInt64(directions.count))]

        return SwipeRushTarget(
            index: index,
            direction: direction,
            x: 0.18 + generator.nextUnit() * 0.64,
            y: 0.18 + generator.nextUnit() * 0.64
        )
    }

    static func winner(
        firstPlayerID: String,
        first: SwipeRushRunResult,
        secondPlayerID: String,
        second: SwipeRushRunResult
    ) -> String? {
        if first.score != second.score {
            return first.score > second.score ? firstPlayerID : secondPlayerID
        }
        if first.completedSwipes != second.completedSwipes {
            return first.completedSwipes > second.completedSwipes ? firstPlayerID : secondPlayerID
        }
        if first.mistakes != second.mistakes {
            return first.mistakes < second.mistakes ? firstPlayerID : secondPlayerID
        }
        if first.bestCombo != second.bestCombo {
            return first.bestCombo > second.bestCombo ? firstPlayerID : secondPlayerID
        }
        if abs(first.totalReactionTime - second.totalReactionTime) >= 0.01 {
            return first.totalReactionTime < second.totalReactionTime ? firstPlayerID : secondPlayerID
        }
        return nil
    }
}

private struct SwipeRushSeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = max(seed, 1)
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
