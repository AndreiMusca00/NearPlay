//
//  ConnectFourMatchController.swift
//  NearPlay
//

import SwiftUI
import Combine

final class ConnectFourMatchController: ObservableObject {
    let playerOneID: String
    let playerTwoID: String

    @Published
    private(set) var state: ConnectFourGameState

    @Published
    private(set) var animationID = UUID()

    private var game: ConnectFourGame

    init(
        playerOneID: String,
        playerTwoID: String,
        initialState: ConnectFourGameState
    ) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID

        let game = ConnectFourGame(
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            state: initialState
        )

        self.game = game
        self.state = game.state
    }

    @discardableResult
    func play(
        column: Int,
        by playerID: String,
        turnID: UUID? = nil
    ) -> ConnectFourMoveResult {
        let previousLastMove = game.state.lastMove

        let result = game.play(
            column: column,
            by: playerID,
            turnID: turnID ?? game.state.turnID
        )

        state = game.state

        if result.didPlaceDisc,
           game.state.lastMove != previousLastMove {
            animationID = UUID()
        }

        return result
    }

    func applyRemoteState(
        _ newState: ConnectFourGameState,
        animateLastMove: Bool
    ) {
        let previousLastMove = game.state.lastMove

        game.applyRemoteState(newState)
        state = game.state

        if animateLastMove,
           newState.lastMove != nil,
           newState.lastMove != previousLastMove {
            animationID = UUID()
        }
    }

    func reset(
        startingPlayerID: String
    ) {
        game.reset(
            startingPlayerID: startingPlayerID
        )

        state = game.state
        animationID = UUID()
    }

    func disc(
        for playerID: String
    ) -> ConnectFourDisc? {
        game.disc(for: playerID)
    }
}
