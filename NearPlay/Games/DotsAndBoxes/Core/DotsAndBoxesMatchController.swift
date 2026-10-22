import SwiftUI
import Combine

@MainActor
final class DotsAndBoxesMatchController: ObservableObject {
    let playerOneID: String
    let playerTwoID: String
    @Published private(set) var state: DotsAndBoxesGameState
    @Published private(set) var animationID = UUID()
    private var game: DotsAndBoxesGame

    init(playerOneID: String, playerTwoID: String, initialState: DotsAndBoxesGameState) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID
        game = DotsAndBoxesGame(playerOneID: playerOneID, playerTwoID: playerTwoID, state: initialState)
        state = initialState
    }

    @discardableResult
    func play(edge: DotsAndBoxesEdge, by playerID: String, turnID: UUID? = nil) -> DotsAndBoxesMoveResult {
        let result = game.play(edge: edge, by: playerID, turnID: turnID ?? game.state.turnID)
        state = game.state
        if result.didPlaceEdge { animationID = UUID() }
        return result
    }

    func reset(startingPlayerID: String) {
        game.reset(startingPlayerID: startingPlayerID)
        state = game.state
        animationID = UUID()
    }

    func applyRemoteState(_ newState: DotsAndBoxesGameState) {
        game.applyRemoteState(newState)
        state = game.state
        animationID = UUID()
    }
}
