import Foundation

/// Maps the single canonical 24-point board into the order shown to a viewer.
/// Game rules, moves, and network payloads always continue to use canonical
/// point indices.
enum BackgammonBoardPerspective: Equatable, Sendable {
    case samePhone
    case localPlayer(BackgammonPlayer)

    var viewerPlayer: BackgammonPlayer {
        switch self {
        case .samePhone:
            return .playerTwo
        case .localPlayer(let player):
            return player
        }
    }

    var opponentPlayer: BackgammonPlayer {
        viewerPlayer.opponent
    }

    var topLeft: [Int] {
        switch self {
        case .samePhone:
            return [0, 1, 2, 3, 4, 5]
        case .localPlayer(.playerOne):
            return [12, 13, 14, 15, 16, 17]
        case .localPlayer(.playerTwo):
            return [11, 10, 9, 8, 7, 6]
        }
    }

    var topRight: [Int] {
        switch self {
        case .samePhone:
            return [6, 7, 8, 9, 10, 11]
        case .localPlayer(.playerOne):
            return [18, 19, 20, 21, 22, 23]
        case .localPlayer(.playerTwo):
            return [5, 4, 3, 2, 1, 0]
        }
    }

    var bottomLeft: [Int] {
        switch self {
        case .samePhone:
            return [23, 22, 21, 20, 19, 18]
        case .localPlayer(.playerOne):
            return [11, 10, 9, 8, 7, 6]
        case .localPlayer(.playerTwo):
            return [12, 13, 14, 15, 16, 17]
        }
    }

    var bottomRight: [Int] {
        switch self {
        case .samePhone:
            return [17, 16, 15, 14, 13, 12]
        case .localPlayer(.playerOne):
            return [5, 4, 3, 2, 1, 0]
        case .localPlayer(.playerTwo):
            return [18, 19, 20, 21, 22, 23]
        }
    }

    func visualLocation(
        forCanonicalPoint index: Int
    ) -> (column: Int, isTop: Bool)? {
        if let position = topLeft.firstIndex(of: index) {
            return (position, true)
        }

        if let position = topRight.firstIndex(of: index) {
            return (position + 6, true)
        }

        if let position = bottomLeft.firstIndex(of: index) {
            return (position, false)
        }

        if let position = bottomRight.firstIndex(of: index) {
            return (position + 6, false)
        }

        return nil
    }

    func canonicalPoint(
        column: Int,
        isTop: Bool
    ) -> Int? {
        guard (0..<12).contains(column) else {
            return nil
        }

        let points: [Int]
        let position: Int

        if column < 6 {
            points = isTop ? topLeft : bottomLeft
            position = column
        } else {
            points = isTop ? topRight : bottomRight
            position = column - 6
        }

        return points[position]
    }
}
