//
//  BattleshipModels.swift
//  NearPlay
//

import Foundation

enum BattleshipOrientation: String, Codable, CaseIterable {
    case horizontal
    case vertical

    mutating func toggle() {
        self = self == .horizontal
            ? .vertical
            : .horizontal
    }
}

struct BattleshipCoordinate: Codable, Hashable, Identifiable {
    let row: Int
    let column: Int

    var id: String {
        "\(row)-\(column)"
    }
}

struct BattleshipShipDefinition: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let length: Int

    static let standardFleet: [BattleshipShipDefinition] = [
        .init(id: "carrier", name: "Carrier", length: 4),
        .init(id: "cruiser_a", name: "Cruiser", length: 3),
        .init(id: "cruiser_b", name: "Cruiser", length: 3),
        .init(id: "patrol_a", name: "Patrol", length: 2),
        .init(id: "patrol_b", name: "Patrol", length: 2)
    ]
}

struct BattleshipPlacedShip: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let length: Int
    var origin: BattleshipCoordinate
    var orientation: BattleshipOrientation
    var hits: Set<BattleshipCoordinate>

    var occupiedCoordinates: [BattleshipCoordinate] {
        (0..<length).map { offset in
            switch orientation {
            case .horizontal:
                return BattleshipCoordinate(
                    row: origin.row,
                    column: origin.column + offset
                )

            case .vertical:
                return BattleshipCoordinate(
                    row: origin.row + offset,
                    column: origin.column
                )
            }
        }
    }

    var isSunk: Bool {
        Set(occupiedCoordinates).isSubset(of: hits)
    }
}

enum BattleshipCellMark: String, Codable, Hashable {
    case miss
    case hit
    case sunk
}

enum BattleshipAttackOutcome: String, Codable, Hashable {
    case miss
    case hit
    case sunk
    case gameOver
}

enum BattleshipPhase: String, Codable {
    case placement
    case waiting
    case battle
    case finished
}

struct BattleshipLocalBoard: Codable, Equatable {
    var ships: [BattleshipPlacedShip] = []
    var misses: Set<BattleshipCoordinate> = []

    var allShipsPlaced: Bool {
        ships.count == BattleshipShipDefinition.standardFleet.count
    }

    var remainingShips: Int {
        ships.filter { !$0.isSunk }.count
    }

    var allShipsSunk: Bool {
        allShipsPlaced && ships.allSatisfy(\.isSunk)
    }

    func ship(at coordinate: BattleshipCoordinate) -> BattleshipPlacedShip? {
        ships.first {
            $0.occupiedCoordinates.contains(coordinate)
        }
    }

    func mark(at coordinate: BattleshipCoordinate) -> BattleshipCellMark? {
        if misses.contains(coordinate) {
            return .miss
        }

        guard let ship = ship(at: coordinate),
              ship.hits.contains(coordinate) else {
            return nil
        }

        return ship.isSunk ? .sunk : .hit
    }
}

struct BattleshipOpponentBoard: Codable, Equatable {
    var marks: [BattleshipCoordinate: BattleshipCellMark] = [:]
    var remainingShips: Int =
        BattleshipShipDefinition.standardFleet.count
}

enum BattleshipPlacementError: Error, Equatable {
    case outsideBoard
    case overlap
    case alreadyPlaced
    case gameLocked
}
