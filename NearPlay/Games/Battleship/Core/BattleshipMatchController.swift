import Foundation
import Combine

@MainActor
final class BattleshipMatchController: ObservableObject {
    @Published
    private(set) var game: BattleshipGame

    init(game: BattleshipGame = BattleshipGame()) {
        self.game = game
    }

    var ownBoard: BattleshipLocalBoard {
        game.ownBoard
    }

    var opponentBoard: BattleshipOpponentBoard {
        game.opponentBoard
    }

    var phase: BattleshipPhase {
        game.phase
    }

    var activePlayerID: String? {
        game.activePlayerID
    }

    var turnID: UUID? {
        game.turnID
    }

    var localReady: Bool {
        game.localReady
    }

    var opponentReady: Bool {
        game.opponentReady
    }

    var winnerPlayerID: String? {
        game.winnerPlayerID
    }

    @discardableResult
    func placeOrMoveShip(
        definition: BattleshipShipDefinition,
        preferredOrigin: BattleshipCoordinate,
        orientation: BattleshipOrientation
    ) -> Bool {
        game.placeOrMoveShip(
            definition: definition,
            preferredOrigin: preferredOrigin,
            orientation: orientation
        )
    }

    @discardableResult
    func rotateShipAutomatically(
        id: String
    ) -> Bool {
        game.rotateShipAutomatically(id: id)
    }

    @discardableResult
    func randomizeFleet() -> Bool {
        game.randomizeFleet()
    }

    func markLocalReady() {
        game.markLocalReady()
    }

    func markOpponentReady() {
        game.markOpponentReady()
    }

    func beginBattle(
        startingPlayerID: String,
        turnID: UUID
    ) {
        game.beginBattle(
            startingPlayerID: startingPlayerID,
            turnID: turnID
        )
    }

    func receiveAttack(
        at coordinate: BattleshipCoordinate
    ) -> (
        outcome: BattleshipAttackOutcome,
        sunkShipID: String?
    )? {
        game.receiveAttack(at: coordinate)
    }

    func applyAttackResult(
        coordinate: BattleshipCoordinate,
        outcome: BattleshipAttackOutcome,
        sunkCoordinates: [BattleshipCoordinate],
        defenderRemainingShips: Int,
        nextPlayerID: String,
        nextTurnID: UUID,
        winnerPlayerID: String?
    ) {
        game.applyAttackResult(
            coordinate: coordinate,
            outcome: outcome,
            sunkCoordinates: sunkCoordinates,
            defenderRemainingShips: defenderRemainingShips,
            nextPlayerID: nextPlayerID,
            nextTurnID: nextTurnID,
            winnerPlayerID: winnerPlayerID
        )
    }

    func applyDefendedAttack(
        nextPlayerID: String,
        nextTurnID: UUID,
        winnerPlayerID: String?
    ) {
        game.applyDefendedAttack(
            nextPlayerID: nextPlayerID,
            nextTurnID: nextTurnID,
            winnerPlayerID: winnerPlayerID
        )
    }

    func resetForRematch() {
        game.resetForRematch()
    }
}
