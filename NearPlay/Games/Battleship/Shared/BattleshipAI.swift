import Foundation

struct BattleshipAIProfile: Equatable {
    let minThinkDelay: TimeInterval
    let maxThinkDelay: TimeInterval
    let smartTargetChance: Double
    let usesParityHunt: Bool

    func thinkDelay() -> TimeInterval {
        TimeInterval.random(
            in: minThinkDelay...maxThinkDelay
        )
    }
}

extension GameAIDifficulty {
    var battleshipProfile: BattleshipAIProfile {
        switch self {
        case .easy:
            return BattleshipAIProfile(
                minThinkDelay: 1.35,
                maxThinkDelay: 2.55,
                smartTargetChance: 0.25,
                usesParityHunt: false
            )

        case .medium:
            return BattleshipAIProfile(
                minThinkDelay: 0.85,
                maxThinkDelay: 1.55,
                smartTargetChance: 0.68,
                usesParityHunt: false
            )

        case .hard:
            return BattleshipAIProfile(
                minThinkDelay: 0.45,
                maxThinkDelay: 0.95,
                smartTargetChance: 0.94,
                usesParityHunt: true
            )
        }
    }
}

enum BattleshipAI {
    static func makeFleet() -> BattleshipLocalBoard {
        var game = BattleshipGame()

        if game.randomizeFleet() {
            return game.ownBoard
        }

        return fallbackFleet()
    }

    static func chooseAttackCoordinate(
        opponentBoard: BattleshipOpponentBoard,
        difficulty: GameAIDifficulty
    ) -> BattleshipCoordinate? {
        let profile = difficulty.battleshipProfile
        let available = availableCoordinates(
            opponentBoard: opponentBoard
        )

        guard !available.isEmpty else {
            return nil
        }

        let shouldPlaySmart =
            Double.random(in: 0...1) <=
            profile.smartTargetChance

        if shouldPlaySmart,
           let target = smartTarget(
            opponentBoard: opponentBoard,
            available: available,
            usesParityHunt: profile.usesParityHunt
           ) {
            return target
        }

        return available.randomElement()
    }

    private static func smartTarget(
        opponentBoard: BattleshipOpponentBoard,
        available: [BattleshipCoordinate],
        usesParityHunt: Bool
    ) -> BattleshipCoordinate? {
        let unresolvedHits =
            opponentBoard
            .marks
            .filter { $0.value == .hit }
            .map(\.key)

        if let target = lineContinuationTarget(
            hits: unresolvedHits,
            available: available
        ) {
            return target
        }

        if let target = neighborTarget(
            hits: unresolvedHits,
            available: available
        ) {
            return target
        }

        if usesParityHunt {
            let parityTargets =
                available.filter {
                    ($0.row + $0.column).isMultiple(of: 2)
                }

            if let target = parityTargets.randomElement() {
                return target
            }
        }

        return nil
    }

    private static func lineContinuationTarget(
        hits: [BattleshipCoordinate],
        available: [BattleshipCoordinate]
    ) -> BattleshipCoordinate? {
        guard hits.count >= 2 else {
            return nil
        }

        let availableSet = Set(available)
        let rows = Dictionary(
            grouping: hits,
            by: { $0.row }
        )

        for rowHits in rows.values where rowHits.count >= 2 {
            let sorted = rowHits.sorted {
                $0.column < $1.column
            }

            if let left = sorted.first,
               let right = sorted.last {
                let candidates = [
                    BattleshipCoordinate(
                        row: left.row,
                        column: left.column - 1
                    ),
                    BattleshipCoordinate(
                        row: right.row,
                        column: right.column + 1
                    )
                ]

                if let target = candidates.first(
                    where: {
                        BattleshipGame.isInsideBoard($0) &&
                        availableSet.contains($0)
                    }
                ) {
                    return target
                }
            }
        }

        let columns = Dictionary(
            grouping: hits,
            by: { $0.column }
        )

        for columnHits in columns.values where columnHits.count >= 2 {
            let sorted = columnHits.sorted {
                $0.row < $1.row
            }

            if let top = sorted.first,
               let bottom = sorted.last {
                let candidates = [
                    BattleshipCoordinate(
                        row: top.row - 1,
                        column: top.column
                    ),
                    BattleshipCoordinate(
                        row: bottom.row + 1,
                        column: bottom.column
                    )
                ]

                if let target = candidates.first(
                    where: {
                        BattleshipGame.isInsideBoard($0) &&
                        availableSet.contains($0)
                    }
                ) {
                    return target
                }
            }
        }

        return nil
    }

    private static func neighborTarget(
        hits: [BattleshipCoordinate],
        available: [BattleshipCoordinate]
    ) -> BattleshipCoordinate? {
        guard !hits.isEmpty else {
            return nil
        }

        let availableSet = Set(available)
        let candidates =
            hits
            .flatMap(neighbors)
            .filter {
                BattleshipGame.isInsideBoard($0) &&
                availableSet.contains($0)
            }

        return candidates.randomElement()
    }

    private static func neighbors(
        of coordinate: BattleshipCoordinate
    ) -> [BattleshipCoordinate] {
        [
            BattleshipCoordinate(
                row: coordinate.row - 1,
                column: coordinate.column
            ),
            BattleshipCoordinate(
                row: coordinate.row + 1,
                column: coordinate.column
            ),
            BattleshipCoordinate(
                row: coordinate.row,
                column: coordinate.column - 1
            ),
            BattleshipCoordinate(
                row: coordinate.row,
                column: coordinate.column + 1
            )
        ]
    }

    private static func availableCoordinates(
        opponentBoard: BattleshipOpponentBoard
    ) -> [BattleshipCoordinate] {
        (0..<BattleshipGame.boardSize)
            .flatMap { row in
                (0..<BattleshipGame.boardSize).map {
                    column in

                    BattleshipCoordinate(
                        row: row,
                        column: column
                    )
                }
            }
            .filter {
                opponentBoard.marks[$0] == nil
            }
    }

    private static func fallbackFleet() -> BattleshipLocalBoard {
        var board = BattleshipLocalBoard()

        board.ships = [
            BattleshipPlacedShip(
                id: "carrier",
                name: "Carrier",
                length: 4,
                origin: BattleshipCoordinate(row: 0, column: 0),
                orientation: .horizontal,
                hits: []
            ),
            BattleshipPlacedShip(
                id: "cruiser_a",
                name: "Cruiser",
                length: 3,
                origin: BattleshipCoordinate(row: 2, column: 0),
                orientation: .horizontal,
                hits: []
            ),
            BattleshipPlacedShip(
                id: "cruiser_b",
                name: "Cruiser",
                length: 3,
                origin: BattleshipCoordinate(row: 4, column: 0),
                orientation: .horizontal,
                hits: []
            ),
            BattleshipPlacedShip(
                id: "patrol_a",
                name: "Patrol",
                length: 2,
                origin: BattleshipCoordinate(row: 6, column: 0),
                orientation: .horizontal,
                hits: []
            ),
            BattleshipPlacedShip(
                id: "patrol_b",
                name: "Patrol",
                length: 2,
                origin: BattleshipCoordinate(row: 6, column: 3),
                orientation: .horizontal,
                hits: []
            )
        ]

        return board
    }
}
