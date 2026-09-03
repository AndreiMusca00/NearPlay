import SwiftUI
import UIKit

private enum BattleshipLocalPhase {
    case placingPlayerOne
    case placingPlayerTwo
    case battle
    case finished
}

struct BattleshipLocalView: View {
    let game: Game

    @Environment(\.dismiss)
    private var dismiss

    @AppStorage(PlayerProfile.nameKey)
    private var playerName: String = ""

    @State private var playerOneGame = BattleshipGame()
    @State private var playerTwoGame = BattleshipGame()

    @State private var localPhase: BattleshipLocalPhase = .placingPlayerOne
    @State private var activePlayerID = Self.playerOneID
    @State private var roundNumber = 0
    @State private var sessionScore = GameSessionScore()

    @State private var pendingAttack = false
    @State private var showQuitConfirmation = false
    @State private var showResultOverlay = false

    @State private var feedbackText: String?
    @State private var feedbackTone: BattleshipFeedbackTone = .neutral

    private static let playerOneID =
        "battleship_local_player_one"

    private static let playerTwoID =
        "battleship_local_player_two"

    var body: some View {
        ZStack {
            BattleshipTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                GeometryReader { geometry in
                    Group {
                        switch localPhase {
                        case .placingPlayerOne, .placingPlayerTwo:
                            BattleshipPlacementView(
                                ownBoard: placementGame.ownBoard,
                                localReady: placementGame.localReady,
                                opponentReady: opponentGameForPlacement.localReady,
                                onShipDropped: placeOrMoveShip,
                                onPlacedShipTap: rotatePlacedShip,
                                onRandomize: randomizeFleet,
                                onReady: markReady
                            )

                        case .battle, .finished:
                            BattleshipBattleView(
                                ownBoard: activeGame.ownBoard,
                                opponentBoard: activeGame.opponentBoard,
                                isLocalTurn: localPhase == .battle,
                                localPlayerName: activePlayerName,
                                opponentName: inactivePlayerName,
                                pendingAttack: pendingAttack,
                                onAttack: resolveLocalAttack
                            )
                        }
                    }
                    .frame(
                        width: max(geometry.size.width - 28, 0),
                        height: max(geometry.size.height - 10, 0),
                        alignment: .top
                    )
                    .offset(x: 14)
                }
            }

            if let feedbackText {
                feedbackBanner(
                    feedbackText,
                    tone: feedbackTone
                )
                .transition(
                    .move(edge: .top)
                    .combined(with: .opacity)
                )
                .zIndex(8)
            }

            if localPhase == .finished &&
                showResultOverlay {
                SimpleGameResultOverlay(
                    title: resultTitle,
                    subtitle: resultSubtitle,
                    symbolName: resultSymbol,
                    accentColor: resultColor,
                    buttonGradient: BattleshipTheme.primaryGradient,
                    cardBackground: BattleshipTheme.cardBackground,
                    usesGradientBorder: true,
                    firstPlayerName: playerOneName,
                    secondPlayerName: "Guest",
                    sessionScore: sessionScore,
                    firstPlayerColor: BattleshipTheme.cyan,
                    secondPlayerColor: BattleshipTheme.purple,
                    onPlayAgain: playAgain,
                    onQuit: {
                        dismiss()
                    }
                )
                .zIndex(10)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .alert(
            "Quit game?",
            isPresented: $showQuitConfirmation
        ) {
            Button(
                "Quit Game",
                role: .destructive
            ) {
                dismiss()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "The current local battle will be discarded."
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                showQuitConfirmation = true
            } label: {
                Image(systemName: "chevron.left")
                    .font(
                        .system(
                            size: 20,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.055))
                    }
                    .overlay {
                        Circle()
                            .stroke(
                                Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 3) {
                Text(game.title)
                    .font(
                        .system(
                            size: 23,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)

                Text(headerSubtitle)
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(headerColor)
                    .lineLimit(1)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.055))
                    .frame(width: 46, height: 46)

                Circle()
                    .stroke(
                        Color.white.opacity(0.12),
                        lineWidth: 1
                    )
                    .frame(width: 46, height: 46)

                Image(systemName: "person.2.fill")
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        BattleshipTheme.primaryGradient
                    )
            }
        }
    }

    private var headerSubtitle: String {
        switch localPhase {
        case .placingPlayerOne:
            return "\(playerOneName): deploy your fleet"
        case .placingPlayerTwo:
            return "Guest: deploy your fleet"
        case .battle:
            return "\(activePlayerName)'s turn"
        case .finished:
            return "Battle complete"
        }
    }

    private var headerColor: Color {
        activePlayerID == Self.playerOneID
        ? BattleshipTheme.cyan
        : BattleshipTheme.purple
    }

    // MARK: - Placement

    private func placeOrMoveShip(
        _ definition: BattleshipShipDefinition,
        at coordinate: BattleshipCoordinate
    ) {
        let placed: Bool

        if placementPlayerID == Self.playerOneID {
            let orientation =
                playerOneGame
                .placedShip(id: definition.id)?
                .orientation ?? .horizontal

            placed = playerOneGame.placeOrMoveShip(
                definition: definition,
                preferredOrigin: coordinate,
                orientation: orientation
            )
        } else {
            let orientation =
                playerTwoGame
                .placedShip(id: definition.id)?
                .orientation ?? .horizontal

            placed = playerTwoGame.placeOrMoveShip(
                definition: definition,
                preferredOrigin: coordinate,
                orientation: orientation
            )
        }

        if placed {
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred()
        } else {
            UINotificationFeedbackGenerator()
                .notificationOccurred(.error)
        }
    }

    private func rotatePlacedShip(
        _ shipID: String
    ) {
        let rotated: Bool

        if placementPlayerID == Self.playerOneID {
            rotated = playerOneGame
                .rotateShipAutomatically(id: shipID)
        } else {
            rotated = playerTwoGame
                .rotateShipAutomatically(id: shipID)
        }

        if rotated {
            UIImpactFeedbackGenerator(style: .light)
                .impactOccurred()
        } else {
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)
        }
    }

    private func randomizeFleet() {
        let didRandomize: Bool

        if placementPlayerID == Self.playerOneID {
            didRandomize = playerOneGame.randomizeFleet()
        } else {
            didRandomize = playerTwoGame.randomizeFleet()
        }

        if didRandomize {
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred()
        } else {
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)
        }
    }

    private func markReady() {
        switch localPhase {
        case .placingPlayerOne:
            guard playerOneGame.ownBoard.allShipsPlaced else {
                return
            }

            playerOneGame.markLocalReady()
            playerTwoGame.markOpponentReady()

            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)

            withAnimation(
                .spring(
                    response: 0.38,
                    dampingFraction: 0.84
                )
            ) {
                localPhase = .placingPlayerTwo
                activePlayerID = Self.playerTwoID
            }

            showFeedback(
                "Pass the iPhone to Guest",
                tone: .neutral
            )

        case .placingPlayerTwo:
            guard playerTwoGame.ownBoard.allShipsPlaced else {
                return
            }

            playerTwoGame.markLocalReady()
            playerOneGame.markOpponentReady()

            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)

            beginBattle()

        default:
            break
        }
    }

    private func beginBattle() {
        let startingPlayerID =
            roundNumber.isMultiple(of: 2)
            ? Self.playerOneID
            : Self.playerTwoID

        let turnID = UUID()

        playerOneGame.beginBattle(
            startingPlayerID: startingPlayerID,
            turnID: turnID
        )

        playerTwoGame.beginBattle(
            startingPlayerID: startingPlayerID,
            turnID: turnID
        )

        withAnimation(
            .spring(
                response: 0.42,
                dampingFraction: 0.84
            )
        ) {
            activePlayerID = startingPlayerID
            localPhase = .battle
        }

    }

    // MARK: - Battle

    private func resolveLocalAttack(
        _ coordinate: BattleshipCoordinate
    ) {
        guard localPhase == .battle,
              !pendingAttack,
              activeGame
                .opponentBoard
                .marks[coordinate] == nil else {
            return
        }

        pendingAttack = true

        let attackerID = activePlayerID
        let defenderID =
            attackerID == Self.playerOneID
            ? Self.playerTwoID
            : Self.playerOneID

        var attackerGame = gameForPlayer(attackerID)
        var defenderGame = gameForPlayer(defenderID)

        guard let result =
                defenderGame.receiveAttack(
                    at: coordinate
                ) else {
            pendingAttack = false
            return
        }

        let sunkCoordinates =
            sunkCoordinatesForLastHit(
                result: result,
                defenderGame: defenderGame
            )

        let winnerID =
            result.outcome == .gameOver
            ? attackerID
            : nil

        let nextTurnID = UUID()

        attackerGame.applyAttackResult(
            coordinate: coordinate,
            outcome: result.outcome,
            sunkCoordinates: sunkCoordinates,
            defenderRemainingShips:
                defenderGame.ownBoard.remainingShips,
            nextPlayerID: defenderID,
            nextTurnID: nextTurnID,
            winnerPlayerID: winnerID
        )

        defenderGame.applyDefendedAttack(
            nextPlayerID: defenderID,
            nextTurnID: nextTurnID,
            winnerPlayerID: winnerID
        )

        assign(
            attackerGame,
            to: attackerID
        )

        assign(
            defenderGame,
            to: defenderID
        )

        pendingAttack = false

        if result.outcome == .gameOver {
            finishBattle(winnerID: attackerID)
        } else {
            withAnimation(
                .spring(
                    response: 0.34,
                    dampingFraction: 0.84
                )
            ) {
                activePlayerID = defenderID
            }
        }
    }

    private func finishBattle(
        winnerID: String
    ) {
        sessionScore.record(
            winnerID == Self.playerOneID
            ? .firstPlayerWin
            : .secondPlayerWin,
            roundNumber: roundNumber
        )

        activePlayerID = winnerID

        withAnimation(.easeOut(duration: 0.20)) {
            localPhase = .finished
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.85
        ) {
            withAnimation(
                .spring(
                    response: 0.38,
                    dampingFraction: 0.84
                )
            ) {
                showResultOverlay = true
            }
        }
    }

    private func playAgain() {
        roundNumber += 1

        playerOneGame = BattleshipGame()
        playerTwoGame = BattleshipGame()
        activePlayerID = Self.playerOneID
        localPhase = .placingPlayerOne
        pendingAttack = false
        showResultOverlay = false
        feedbackText = nil
    }

    // MARK: - Feedback

    private func showFeedback(
        _ text: String,
        tone: BattleshipFeedbackTone
    ) {
        feedbackText = text
        feedbackTone = tone

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1.15
        ) {
            withAnimation(.easeOut(duration: 0.18)) {
                if feedbackText == text {
                    feedbackText = nil
                }
            }
        }
    }

    private func feedbackBanner(
        _ text: String,
        tone: BattleshipFeedbackTone
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: tone.iconName)
                .font(.system(size: 17, weight: .bold))

            Text(text)
                .font(
                    .system(
                        size: 15,
                        weight: .bold,
                        design: .rounded
                    )
                )
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(height: 48)
        .background {
            Capsule()
                .fill(tone.color.opacity(0.88))
        }
        .overlay {
            Capsule()
                .stroke(
                    Color.white.opacity(0.26),
                    lineWidth: 1
                )
        }
        .shadow(
            color: tone.color.opacity(0.42),
            radius: 12
        )
        .frame(
            maxHeight: .infinity,
            alignment: .top
        )
        .padding(.top, 74)
    }

    // MARK: - Computed

    private var placementPlayerID: String {
        localPhase == .placingPlayerOne
        ? Self.playerOneID
        : Self.playerTwoID
    }

    private var placementGame: BattleshipGame {
        gameForPlayer(placementPlayerID)
    }

    private var opponentGameForPlacement: BattleshipGame {
        placementPlayerID == Self.playerOneID
        ? playerTwoGame
        : playerOneGame
    }

    private var activeGame: BattleshipGame {
        gameForPlayer(activePlayerID)
    }

    private var playerOneName: String {
        let trimmed = playerName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return trimmed.isEmpty ? "Player 1" : trimmed
    }

    private var activePlayerName: String {
        playerName(for: activePlayerID)
    }

    private var inactivePlayerName: String {
        let otherID =
            activePlayerID == Self.playerOneID
            ? Self.playerTwoID
            : Self.playerOneID

        return playerName(for: otherID)
    }

    private var winnerID: String? {
        playerOneGame.winnerPlayerID ??
        playerTwoGame.winnerPlayerID
    }

    private var resultTitle: String {
        "\(playerName(for: winnerID ?? Self.playerOneID)) Wins!"
    }

    private var resultSubtitle: String {
        "\(playerName(for: winnerID ?? Self.playerOneID)) sank every enemy ship."
    }

    private var resultSymbol: String {
        "crown.fill"
    }

    private var resultColor: Color {
        winnerID == Self.playerOneID
        ? BattleshipTheme.cyan
        : BattleshipTheme.purple
    }

    private func playerName(
        for playerID: String
    ) -> String {
        playerID == Self.playerOneID
        ? playerOneName
        : "Guest"
    }

    private func gameForPlayer(
        _ playerID: String
    ) -> BattleshipGame {
        playerID == Self.playerOneID
        ? playerOneGame
        : playerTwoGame
    }

    private func assign(
        _ game: BattleshipGame,
        to playerID: String
    ) {
        if playerID == Self.playerOneID {
            playerOneGame = game
        } else {
            playerTwoGame = game
        }
    }

    private func sunkCoordinatesForLastHit(
        result: (
            outcome: BattleshipAttackOutcome,
            sunkShipID: String?
        ),
        defenderGame: BattleshipGame
    ) -> [BattleshipCoordinate] {
        guard let sunkShipID = result.sunkShipID,
              let sunkShip =
                defenderGame
                .ownBoard
                .ships
                .first(
                    where: {
                        $0.id == sunkShipID
                    }
                ) else {
            return []
        }

        return sunkShip.occupiedCoordinates
    }
}
