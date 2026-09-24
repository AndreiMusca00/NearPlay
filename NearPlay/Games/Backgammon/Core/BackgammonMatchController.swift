import SwiftUI
import Combine

final class BackgammonMatchController: ObservableObject {
    let playerOneID: String
    let playerTwoID: String

    @Published
    private(set) var state: BackgammonGameState

    @Published
    private(set) var animationID = UUID()

    private var game: BackgammonGame
    private let manualTurnCommit: Bool
    private var moveHistory: [BackgammonGameState] = []

    @Published
    private(set) var canUndo = false

    init(
        playerOneID: String,
        playerTwoID: String,
        initialState: BackgammonGameState,
        manualTurnCommit: Bool = false
    ) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID

        let game = BackgammonGame(
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            state: initialState,
            manualTurnCommit: manualTurnCommit
        )

        self.manualTurnCommit = manualTurnCommit
        self.game = game
        self.state = game.state
    }

    func player(
        for playerID: String
    ) -> BackgammonPlayer? {
        game.player(for: playerID)
    }

    func legalMoves(
        for playerID: String
    ) -> [BackgammonMove] {
        game.legalMoves(for: playerID)
    }


    func moveOptions(
        for playerID: String
    ) -> [BackgammonMoveOption] {
        game.moveOptions(for: playerID)
    }

    @discardableResult
    func roll(
        by playerID: String,
        turnID: UUID,
        dieOne: Int = Int.random(in: 1...6),
        dieTwo: Int = Int.random(in: 1...6)
    ) -> BackgammonRollResult {
        let result = game.roll(
            dieOne: dieOne,
            dieTwo: dieTwo,
            by: playerID,
            turnID: turnID
        )

        state = game.state

        if result != .ignored {
            clearMoveHistory()
        }

        animationID = UUID()
        return result
    }

    @discardableResult
    func play(
        source: Int?,
        destination: Int?,
        by playerID: String,
        turnID: UUID,
        preferredDie: Int? = nil
    ) -> BackgammonMoveResult {
        let stateBeforeMove = game.state

        let result = game.play(
            source: source,
            destination: destination,
            by: playerID,
            turnID: turnID,
            preferredDie: preferredDie
        )

        state = game.state

        if result != .ignored {
            if state.isFinished {
                clearMoveHistory()
            } else if manualTurnCommit {
                moveHistory.append(stateBeforeMove)
                canUndo = true
            }

            animationID = UUID()
        }

        return result
    }

    /// A combined drag is validated in a copy and published as one action.
    /// Undo restores the entire drag, including dice and intermediate hits.
    @discardableResult
    func play(option: BackgammonMoveOption, by playerID: String, turnID: UUID) -> Bool {
        guard manualTurnCommit, state.turnID == turnID,
              game.moveOptions(for: playerID).contains(option) else { return false }
        let before = game.state
        var candidate = game
        for move in option.moves {
            let result = candidate.play(
                source: move.source, destination: move.destination,
                by: playerID, turnID: turnID, preferredDie: move.die
            )
            guard result != .ignored else { return false }
        }
        game = candidate
        state = game.state
        if state.isFinished {
            clearMoveHistory()
        } else {
            moveHistory.append(before)
            canUndo = true
        }
        animationID = UUID()
        return true
    }

    /// Automatically performs only moves that are unavoidable across every
    /// maximum-length legal turn sequence. Every automatic move is stored in
    /// the normal Same Phone undo history, so the player can still Undo it.
    @discardableResult
    func autoPlayForcedMoves(
        by playerID: String,
        turnID: UUID
    ) -> [BackgammonMove] {
        guard manualTurnCommit else {
            return []
        }

        var automaticMoves: [BackgammonMove] = []
        var safetyCounter = 0

        while safetyCounter < 4,
              state.activePlayerID == playerID,
              state.turnID == turnID,
              !state.isFinished,
              let forcedMove = game.forcedMove(for: playerID) {
            safetyCounter += 1

            let result = play(
                source: forcedMove.source,
                destination: forcedMove.destination,
                by: playerID,
                turnID: turnID,
                preferredDie: forcedMove.die
            )

            switch result {
            case .ignored:
                return automaticMoves

            case .moved(let move, _),
                 .turnEnded(let move, _),
                 .won(let move):
                automaticMoves.append(move)
            }
        }

        return automaticMoves
    }

    func nextForcedMove(for playerID: String) -> BackgammonMove? {
        guard manualTurnCommit, !state.isFinished else { return nil }
        return game.forcedMove(for: playerID)
    }

    func canCommitTurn(
        for playerID: String,
        turnID: UUID
    ) -> Bool {
        game.canCommitTurn(
            by: playerID,
            turnID: turnID
        )
    }

    @discardableResult
    func commitTurn(
        by playerID: String,
        turnID: UUID
    ) -> Bool {
        let didCommit = game.commitTurn(
            by: playerID,
            turnID: turnID
        )

        guard didCommit else {
            return false
        }

        state = game.state
        clearMoveHistory()
        animationID = UUID()
        return true
    }

    @discardableResult
    func undoLastMove() -> Bool {
        guard manualTurnCommit,
              !state.isFinished,
              let previousState = moveHistory.popLast() else {
            return false
        }

        game.applyRemoteState(previousState)
        state = game.state
        canUndo = !moveHistory.isEmpty
        animationID = UUID()
        return true
    }

    func applyRemoteState(
        _ newState: BackgammonGameState
    ) {
        game.applyRemoteState(newState)
        state = game.state
        clearMoveHistory()
        animationID = UUID()
    }

    func reset(
        startingPlayerID: String
    ) {
        game.reset(
            startingPlayerID: startingPlayerID
        )

        state = game.state
        clearMoveHistory()
        animationID = UUID()
    }

    private func clearMoveHistory() {
        moveHistory.removeAll()
        canUndo = false
    }
}
