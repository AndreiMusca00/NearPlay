import Foundation

struct TapFrenzyTarget: Identifiable, Equatable {
    let number: Int
    let x: Double
    let y: Double

    var id: Int { number }
}

struct TapFrenzyRunResult: Codable, Equatable, Sendable {
    let score: Int
    let completedSequences: Int
    let mistakes: Int
    let totalSequenceTime: TimeInterval
}

struct TapFrenzyPlayerProgress: Codable, Equatable, Sendable {
    var score = 0
    var completedSequences = 0
    var mistakes = 0
    var expectedNumber = 1
    var totalSequenceTime: TimeInterval = 0
    var isFinished = false

    var result: TapFrenzyRunResult {
        TapFrenzyRunResult(
            score: score,
            completedSequences: completedSequences,
            mistakes: mistakes,
            totalSequenceTime: totalSequenceTime
        )
    }
}

struct TapFrenzyMatchState: Codable, Equatable, Sendable {
    var roundID: UUID
    var startsAt: Date
    var targetSeed: Int
    var progress: [String: TapFrenzyPlayerProgress]
    var winnerPlayerID: String?
    var isDraw: Bool

    func progress(for playerID: String) -> TapFrenzyPlayerProgress {
        progress[playerID] ?? TapFrenzyPlayerProgress()
    }

    var isFinished: Bool {
        winnerPlayerID != nil || isDraw
    }
}

struct TapFrenzyStartPayload: Codable, Equatable {
    let sessionID: String
    let playerOneID: String
    let playerOneName: String
    let playerTwoID: String
    let playerTwoName: String
    let initialState: TapFrenzyMatchState
}

struct TapFrenzyProgressPayload: Codable, Equatable {
    let sessionID: String
    let roundID: UUID
    let eventID: UUID
    let playerID: String
    let progress: TapFrenzyPlayerProgress
}

struct TapFrenzyStatePayload: Codable, Equatable {
    let sessionID: String
    let state: TapFrenzyMatchState
}

enum TapFrenzyGame {
    static let runDuration: TimeInterval = 60
    static let targetCount = 5
    static let mistakePenalty = 2

    static func targetSize(after completedSequences: Int) -> Double {
        max(43, 68 - Double(completedSequences) * 2.2)
    }

    static func relocationInterval(after completedSequences: Int) -> TimeInterval {
        max(0.82, 2.25 - Double(completedSequences) * 0.10)
    }

    static func speedBonus(for executionTime: TimeInterval) -> Int {
        max(0, 10 - Int(executionTime * 1.8))
    }

    static func makeInitialState(
        playerOneID: String,
        playerTwoID: String,
        startsAt: Date = Date().addingTimeInterval(3.2)
    ) -> TapFrenzyMatchState {
        TapFrenzyMatchState(
            roundID: UUID(),
            startsAt: startsAt,
            targetSeed: Int.random(in: 1...2_000_000_000),
            progress: [
                playerOneID: TapFrenzyPlayerProgress(),
                playerTwoID: TapFrenzyPlayerProgress()
            ],
            winnerPlayerID: nil,
            isDraw: false
        )
    }

    static func winner(
        firstPlayerID: String,
        first: TapFrenzyRunResult,
        secondPlayerID: String,
        second: TapFrenzyRunResult
    ) -> String? {
        if first.score != second.score {
            return first.score > second.score
                ? firstPlayerID
                : secondPlayerID
        }
        if first.completedSequences != second.completedSequences {
            return first.completedSequences > second.completedSequences
                ? firstPlayerID
                : secondPlayerID
        }
        if first.mistakes != second.mistakes {
            return first.mistakes < second.mistakes
                ? firstPlayerID
                : secondPlayerID
        }
        if abs(first.totalSequenceTime - second.totalSequenceTime) >= 0.01 {
            return first.totalSequenceTime < second.totalSequenceTime
                ? firstPlayerID
                : secondPlayerID
        }
        return nil
    }

    static func targets(
        seed: Int,
        sequence: Int,
        relocation: Int
    ) -> [TapFrenzyTarget] {
        let mixedSeed = UInt64(max(seed, 1))
            ^ (UInt64(sequence + 1) &* 0x9E3779B97F4A7C15)
            ^ (UInt64(relocation + 1) &* 0xBF58476D1CE4E5B9)
        var generator = TapFrenzySeededGenerator(seed: mixedSeed)
        var positions: [(x: Double, y: Double)] = []

        for _ in 0..<targetCount {
            var selected = (x: 0.5, y: 0.5)

            for attempt in 0..<100 {
                let candidate = (
                    x: 0.12 + generator.nextUnit() * 0.76,
                    y: 0.12 + generator.nextUnit() * 0.76
                )
                selected = candidate

                let nearest = positions.map { position in
                    let dx = position.x - candidate.x
                    let dy = position.y - candidate.y
                    return sqrt(dx * dx + dy * dy)
                }.min() ?? 1

                if nearest >= 0.21 || attempt == 99 {
                    break
                }
            }

            positions.append(selected)
        }

        return positions.enumerated().map { index, position in
            TapFrenzyTarget(
                number: index + 1,
                x: position.x,
                y: position.y
            )
        }
    }
}

private struct TapFrenzySeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = max(seed, 1)
    }

    mutating func nextUnit() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        return Double(value >> 11) / Double(1 << 53)
    }
}
