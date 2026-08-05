import Foundation

struct BattleshipGame {
    static let boardSize = 8

    private(set) var ownBoard = BattleshipLocalBoard()
    private(set) var opponentBoard = BattleshipOpponentBoard()
    private(set) var phase: BattleshipPhase = .placement
    private(set) var activePlayerID: String?
    private(set) var turnID: UUID?
    private(set) var localReady = false
    private(set) var opponentReady = false
    private(set) var winnerPlayerID: String?

    mutating func placeOrMoveShip(
        definition: BattleshipShipDefinition,
        preferredOrigin: BattleshipCoordinate,
        orientation: BattleshipOrientation
    ) -> Bool {
        guard phase == .placement, !localReady else { return false }

        let previous = ownBoard.ships.first { $0.id == definition.id }
        ownBoard.ships.removeAll { $0.id == definition.id }

        guard let origin = nearestValidOrigin(
            for: definition,
            preferredOrigin: preferredOrigin,
            orientation: orientation
        ) else {
            if let previous { ownBoard.ships.append(previous) }
            return false
        }

        ownBoard.ships.append(
            BattleshipPlacedShip(
                id: definition.id,
                name: definition.name,
                length: definition.length,
                origin: origin,
                orientation: orientation,
                hits: previous?.hits ?? []
            )
        )
        sortShipsLikeFleet()
        return true
    }

    mutating func rotateShipAutomatically(id: String) -> Bool {
        guard let ship = ownBoard.ships.first(where: { $0.id == id }) else {
            return false
        }

        let definition = BattleshipShipDefinition(
            id: ship.id,
            name: ship.name,
            length: ship.length
        )

        let rotated: BattleshipOrientation =
            ship.orientation == .horizontal ? .vertical : .horizontal

        return placeOrMoveShip(
            definition: definition,
            preferredOrigin: ship.origin,
            orientation: rotated
        )
    }

    mutating func removeShip(id: String) {
        guard phase == .placement, !localReady else { return }
        ownBoard.ships.removeAll { $0.id == id }
    }

    func placedShip(id: String) -> BattleshipPlacedShip? {
        ownBoard.ships.first { $0.id == id }
    }

    private func nearestValidOrigin(
        for definition: BattleshipShipDefinition,
        preferredOrigin: BattleshipCoordinate,
        orientation: BattleshipOrientation
    ) -> BattleshipCoordinate? {
        allCoordinates
            .sorted {
                let a = distance($0, preferredOrigin)
                let b = distance($1, preferredOrigin)
                if a == b {
                    return $0.row == $1.row
                        ? $0.column < $1.column
                        : $0.row < $1.row
                }
                return a < b
            }
            .first {
                isValidPlacement(
                    definition: definition,
                    origin: $0,
                    orientation: orientation
                )
            }
    }

    private func isValidPlacement(
        definition: BattleshipShipDefinition,
        origin: BattleshipCoordinate,
        orientation: BattleshipOrientation
    ) -> Bool {
        let candidate = BattleshipPlacedShip(
            id: definition.id,
            name: definition.name,
            length: definition.length,
            origin: origin,
            orientation: orientation,
            hits: []
        )

        guard candidate.occupiedCoordinates.allSatisfy(Self.isInsideBoard) else {
            return false
        }

        let occupied = Set(ownBoard.ships.flatMap(\.occupiedCoordinates))
        return candidate.occupiedCoordinates.allSatisfy { !occupied.contains($0) }
    }

    private var allCoordinates: [BattleshipCoordinate] {
        (0..<Self.boardSize).flatMap { row in
            (0..<Self.boardSize).map { column in
                BattleshipCoordinate(row: row, column: column)
            }
        }
    }

    private func distance(
        _ a: BattleshipCoordinate,
        _ b: BattleshipCoordinate
    ) -> Int {
        abs(a.row - b.row) + abs(a.column - b.column)
    }

    private mutating func sortShipsLikeFleet() {
        let order = Dictionary(
            uniqueKeysWithValues: BattleshipShipDefinition.standardFleet
                .enumerated()
                .map { ($0.element.id, $0.offset) }
        )
        ownBoard.ships.sort {
            order[$0.id, default: 0] < order[$1.id, default: 0]
        }
    }

    mutating func markLocalReady() {
        guard ownBoard.allShipsPlaced else { return }
        localReady = true
        phase = .waiting
    }

    mutating func markOpponentReady() { opponentReady = true }

    mutating func beginBattle(startingPlayerID: String, turnID: UUID) {
        activePlayerID = startingPlayerID
        self.turnID = turnID
        phase = .battle
    }

    mutating func receiveAttack(
        at coordinate: BattleshipCoordinate
    ) -> (outcome: BattleshipAttackOutcome, sunkShipID: String?)? {
        guard phase == .battle,
              Self.isInsideBoard(coordinate),
              ownBoard.mark(at: coordinate) == nil else { return nil }

        guard let index = ownBoard.ships.firstIndex(where: {
            $0.occupiedCoordinates.contains(coordinate)
        }) else {
            ownBoard.misses.insert(coordinate)
            return (.miss, nil)
        }

        ownBoard.ships[index].hits.insert(coordinate)

        if ownBoard.allShipsSunk {
            return (.gameOver, ownBoard.ships[index].id)
        }
        if ownBoard.ships[index].isSunk {
            return (.sunk, ownBoard.ships[index].id)
        }
        return (.hit, nil)
    }

    mutating func applyAttackResult(
        coordinate: BattleshipCoordinate,
        outcome: BattleshipAttackOutcome,
        sunkCoordinates: [BattleshipCoordinate],
        defenderRemainingShips: Int,
        nextPlayerID: String,
        nextTurnID: UUID,
        winnerPlayerID: String?
    ) {
        switch outcome {
        case .miss: opponentBoard.marks[coordinate] = .miss
        case .hit: opponentBoard.marks[coordinate] = .hit
        case .sunk, .gameOver:
            for item in sunkCoordinates.isEmpty ? [coordinate] : sunkCoordinates {
                opponentBoard.marks[item] = .sunk
            }
        }

        opponentBoard.remainingShips = defenderRemainingShips
        activePlayerID = nextPlayerID
        turnID = nextTurnID

        if outcome == .gameOver {
            phase = .finished
            self.winnerPlayerID = winnerPlayerID
        }
    }

    mutating func applyDefendedAttack(
        nextPlayerID: String,
        nextTurnID: UUID,
        winnerPlayerID: String?
    ) {
        activePlayerID = nextPlayerID
        turnID = nextTurnID
        if let winnerPlayerID {
            phase = .finished
            self.winnerPlayerID = winnerPlayerID
        }
    }

    mutating func resetForRematch() {
        ownBoard = BattleshipLocalBoard()
        opponentBoard = BattleshipOpponentBoard()
        phase = .placement
        activePlayerID = nil
        turnID = nil
        localReady = false
        opponentReady = false
        winnerPlayerID = nil
    }

    static func isInsideBoard(_ coordinate: BattleshipCoordinate) -> Bool {
        coordinate.row >= 0 && coordinate.row < boardSize &&
        coordinate.column >= 0 && coordinate.column < boardSize
    }
}
