//
//  ConnectFourModels.swift
//  NearPlay
//

import Foundation

enum ConnectFourDisc: String, Codable, Hashable, Sendable {
    case playerOne
    case playerTwo
}

struct ConnectFourCoordinate:
    Codable,
    Hashable,
    Identifiable,
    Sendable {

    let row: Int
    let column: Int

    var id: String {
        "\(row)-\(column)"
    }
}

struct ConnectFourGameState:
    Codable,
    Equatable,
    Sendable {

    var board: [ConnectFourDisc?]

    var activePlayerID: String
    var turnID: UUID

    var lastMove: ConnectFourCoordinate?
    var winnerPlayerID: String?
    var winningCoordinates: [ConnectFourCoordinate]
    var isDraw: Bool

    var isFinished: Bool {
        winnerPlayerID != nil || isDraw
    }

    var availableColumns: [Int] {
        (0..<ConnectFourGame.columns).filter {
            !isColumnFull($0)
        }
    }

    func disc(
        row: Int,
        column: Int
    ) -> ConnectFourDisc? {
        guard Self.isInsideBoard(
            row: row,
            column: column
        ) else {
            return nil
        }

        return board[
            Self.index(
                row: row,
                column: column
            )
        ]
    }

    func isColumnFull(
        _ column: Int
    ) -> Bool {
        guard column >= 0,
              column < ConnectFourGame.columns else {
            return true
        }

        return disc(row: 0, column: column) != nil
    }

    static func index(
        row: Int,
        column: Int
    ) -> Int {
        row * ConnectFourGame.columns + column
    }

    static func isInsideBoard(
        row: Int,
        column: Int
    ) -> Bool {
        row >= 0 &&
        row < ConnectFourGame.rows &&
        column >= 0 &&
        column < ConnectFourGame.columns
    }
}

enum ConnectFourMoveResult: Equatable, Sendable {
    case ignored
    case columnFull
    case placed(ConnectFourCoordinate)
    case won(ConnectFourCoordinate)
    case draw(ConnectFourCoordinate)

    var didPlaceDisc: Bool {
        switch self {
        case .placed, .won, .draw:
            return true
        case .ignored, .columnFull:
            return false
        }
    }
}
