import Foundation

struct DotsAndBoxesGame: Sendable {
    static let dotCount = 5
    static let boxCount = (dotCount - 1) * (dotCount - 1)
    static let edgeCount = dotCount * (dotCount - 1) * 2

    let playerOneID: String
    let playerTwoID: String
    private(set) var state: DotsAndBoxesGameState

    init(playerOneID: String, playerTwoID: String, state: DotsAndBoxesGameState) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID
        self.state = state
    }

    static func makeInitialState(startingPlayerID: String) -> DotsAndBoxesGameState {
        DotsAndBoxesGameState(
            edges: [], edgeOwners: [], boxOwners: Array(repeating: nil, count: boxCount),
            activePlayerID: startingPlayerID, turnID: UUID(), lastEdge: nil,
            lastCompletedBoxes: [], winnerPlayerID: nil, isDraw: false
        )
    }

    static var allEdges: [DotsAndBoxesEdge] {
        var result: [DotsAndBoxesEdge] = []
        for row in 0..<dotCount {
            for column in 0..<(dotCount - 1) {
                result.append(.init(orientation: .horizontal, row: row, column: column))
            }
        }
        for row in 0..<(dotCount - 1) {
            for column in 0..<dotCount {
                result.append(.init(orientation: .vertical, row: row, column: column))
            }
        }
        return result
    }

    mutating func applyRemoteState(_ newState: DotsAndBoxesGameState) { state = newState }
    mutating func reset(startingPlayerID: String) { state = Self.makeInitialState(startingPlayerID: startingPlayerID) }

    @discardableResult
    mutating func play(edge: DotsAndBoxesEdge, by playerID: String, turnID: UUID) -> DotsAndBoxesMoveResult {
        guard !state.isFinished, playerID == state.activePlayerID,
              turnID == state.turnID, Self.isValid(edge) else { return .ignored }
        guard !state.edges.contains(edge) else { return .occupied }

        state.edges.append(edge)
        state.edgeOwners.append(playerID)
        state.lastEdge = edge
        let completed = newlyCompletedBoxes(touching: edge)
        state.lastCompletedBoxes = completed
        for index in completed { state.boxOwners[index] = playerID }

        if state.edges.count == Self.edgeCount {
            let one = state.score(for: playerOneID)
            let two = state.score(for: playerTwoID)
            if one == two { state.isDraw = true }
            else { state.winnerPlayerID = one > two ? playerOneID : playerTwoID }
            state.turnID = UUID()
            return .finished(edge, boxes: completed)
        }

        if completed.isEmpty {
            state.activePlayerID = playerID == playerOneID ? playerTwoID : playerOneID
        }
        state.turnID = UUID()
        return completed.isEmpty ? .placed(edge) : .scored(edge, boxes: completed)
    }

    static func isValid(_ edge: DotsAndBoxesEdge) -> Bool {
        switch edge.orientation {
        case .horizontal:
            return (0..<dotCount).contains(edge.row) && (0..<(dotCount - 1)).contains(edge.column)
        case .vertical:
            return (0..<(dotCount - 1)).contains(edge.row) && (0..<dotCount).contains(edge.column)
        }
    }

    static func edges(forBox index: Int) -> [DotsAndBoxesEdge] {
        let side = dotCount - 1
        let row = index / side
        let column = index % side
        return [
            .init(orientation: .horizontal, row: row, column: column),
            .init(orientation: .horizontal, row: row + 1, column: column),
            .init(orientation: .vertical, row: row, column: column),
            .init(orientation: .vertical, row: row, column: column + 1)
        ]
    }

    private func newlyCompletedBoxes(touching edge: DotsAndBoxesEdge) -> [Int] {
        let side = Self.dotCount - 1
        var candidates: [Int] = []
        switch edge.orientation {
        case .horizontal:
            if edge.row > 0 { candidates.append((edge.row - 1) * side + edge.column) }
            if edge.row < side { candidates.append(edge.row * side + edge.column) }
        case .vertical:
            if edge.column > 0 { candidates.append(edge.row * side + edge.column - 1) }
            if edge.column < side { candidates.append(edge.row * side + edge.column) }
        }
        return candidates.filter { index in
            state.boxOwners[index] == nil && Self.edges(forBox: index).allSatisfy(state.edges.contains)
        }
    }
}
