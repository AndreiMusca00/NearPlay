import Foundation

enum DotsAndBoxesOrientation: String, Codable, Hashable, Sendable {
    case horizontal
    case vertical
}

struct DotsAndBoxesEdge: Codable, Hashable, Sendable {
    let orientation: DotsAndBoxesOrientation
    let row: Int
    let column: Int
}

struct DotsAndBoxesGameState: Codable, Equatable, Sendable {
    var edges: [DotsAndBoxesEdge]
    var edgeOwners: [String]
    var boxOwners: [String?]
    var activePlayerID: String
    var turnID: UUID
    var lastEdge: DotsAndBoxesEdge?
    var lastCompletedBoxes: [Int]
    var winnerPlayerID: String?
    var isDraw: Bool

    var isFinished: Bool { winnerPlayerID != nil || isDraw }

    func owner(of edge: DotsAndBoxesEdge) -> String? {
        guard let index = edges.firstIndex(of: edge), edgeOwners.indices.contains(index) else { return nil }
        return edgeOwners[index]
    }

    func score(for playerID: String) -> Int {
        boxOwners.reduce(0) { $0 + ($1 == playerID ? 1 : 0) }
    }
}

enum DotsAndBoxesMoveResult: Equatable, Sendable {
    case ignored
    case occupied
    case placed(DotsAndBoxesEdge)
    case scored(DotsAndBoxesEdge, boxes: [Int])
    case finished(DotsAndBoxesEdge, boxes: [Int])

    var didPlaceEdge: Bool {
        switch self {
        case .placed, .scored, .finished: true
        case .ignored, .occupied: false
        }
    }
}
