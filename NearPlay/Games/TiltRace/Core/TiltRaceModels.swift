import Foundation

struct TiltRaceMatchState: Codable, Equatable, Sendable {
    var progress: [String: Int]
    var roundID: UUID
    var startsAt: Date
    var trackSeed: Int
    var winnerPlayerID: String?

    func progress(for playerID: String) -> Int {
        progress[playerID, default: 0]
    }
}

struct TiltRaceStartPayload: Codable, Equatable {
    let sessionID: String
    let playerOneID: String
    let playerOneName: String
    let playerTwoID: String
    let playerTwoName: String
    let initialState: TiltRaceMatchState
}

struct TiltRaceProgressPayload: Codable, Equatable {
    let sessionID: String
    let roundID: UUID
    let eventID: UUID
    let playerID: String
    let gateIndex: Int
}

struct TiltRaceStatePayload: Codable, Equatable {
    let sessionID: String
    let state: TiltRaceMatchState
}

struct TiltRaceCheckpoint: Identifiable, Equatable {
    let id: Int
    let x: Double
    let y: Double
}

enum TiltRaceGame {
    static let gateCount = 10

    static func checkpoints(for seed: Int) -> [TiltRaceCheckpoint] {
        var generator = TiltRaceSeededGenerator(seed: seed)
        var result: [TiltRaceCheckpoint] = []
        var previous = (x: 0.5, y: 0.91)

        for index in 0..<gateCount {
            var selected = (x: 0.5, y: 0.5)

            for attempt in 0..<80 {
                let candidate = (
                    x: 0.11 + generator.nextUnit() * 0.78,
                    y: 0.08 + generator.nextUnit() * 0.78
                )
                let distanceFromPrevious = distance(candidate, previous)
                let nearestExisting = result.map {
                    distance(candidate, (x: $0.x, y: $0.y))
                }.min() ?? 1

                selected = candidate
                if distanceFromPrevious >= 0.42,
                   nearestExisting >= 0.15 {
                    break
                }

                if attempt == 79 {
                    let moveLeft = previous.x >= 0.5
                    selected.x = moveLeft
                        ? 0.11 + generator.nextUnit() * 0.20
                        : 0.69 + generator.nextUnit() * 0.20
                    selected.y = 0.08 + generator.nextUnit() * 0.78
                }
            }

            result.append(.init(id: index, x: selected.x, y: selected.y))
            previous = selected
        }

        return result
    }

    static func makeInitialState(
        playerOneID: String,
        playerTwoID: String,
        startsAt: Date = Date().addingTimeInterval(3.2)
    ) -> TiltRaceMatchState {
        TiltRaceMatchState(
            progress: [playerOneID: 0, playerTwoID: 0],
            roundID: UUID(),
            startsAt: startsAt,
            trackSeed: Int.random(in: 1...2_000_000_000),
            winnerPlayerID: nil
        )
    }

    private static func distance(
        _ first: (x: Double, y: Double),
        _ second: (x: Double, y: Double)
    ) -> Double {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return sqrt(dx * dx + dy * dy)
    }
}

private struct TiltRaceSeededGenerator {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(max(seed, 1))
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
