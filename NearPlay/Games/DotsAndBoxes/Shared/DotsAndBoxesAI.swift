import Foundation

enum DotsAndBoxesAI {
    static func chooseEdge(state: DotsAndBoxesGameState, difficulty: GameAIDifficulty) -> DotsAndBoxesEdge? {
        let available = DotsAndBoxesGame.allEdges.filter { !state.edges.contains($0) }
        guard !available.isEmpty else { return nil }
        if difficulty == .easy { return available.randomElement() }

        let scoring = available.filter { edge in
            adjacentBoxes(to: edge).contains { box in
                let filled = DotsAndBoxesGame.edges(forBox: box).filter(state.edges.contains).count
                return filled == 3
            }
        }
        if let move = scoring.randomElement() { return move }

        let safe = available.filter { edge in
            !adjacentBoxes(to: edge).contains { box in
                DotsAndBoxesGame.edges(forBox: box).filter(state.edges.contains).count == 2
            }
        }
        if difficulty == .hard, let move = safe.randomElement() { return move }
        return (safe.isEmpty ? available : safe).randomElement()
    }

    private static func adjacentBoxes(to edge: DotsAndBoxesEdge) -> [Int] {
        (0..<DotsAndBoxesGame.boxCount).filter { DotsAndBoxesGame.edges(forBox: $0).contains(edge) }
    }
}
