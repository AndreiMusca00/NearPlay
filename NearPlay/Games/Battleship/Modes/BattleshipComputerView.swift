import SwiftUI
import UIKit

struct BattleshipComputerView: View {
    let game: Game
    let difficulty: GameAIDifficulty

    @Environment(\.dismiss)
    private var dismiss

    @State private var humanGame = BattleshipGame()
    @State private var computerGame = BattleshipGame()

    @State private var roundNumber = 0
    @State private var sessionScore = GameSessionScore()
    @State private var pendingAttack = false
    @State private var computerThinking = false
    @State private var showQuitConfirmation = false
    @State private var showResultOverlay = false
    @State private var computerTask: Task<Void, Never>?

    private static let humanID =
        "battleship_human"

    private static let computerID =
        "battleship_computer"

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
                        switch humanGame.phase {
                        case .placement, .waiting:
                            BattleshipPlacementView(
                                ownBoard: humanGame.ownBoard,
                                localReady: humanGame.localReady,
                                opponentReady: computerGame.localReady,
                                onShipDropped: placeOrMoveShip,
                                onPlacedShipTap: rotatePlacedShip,
                                onRandomize: randomizeFleet,
                                onReady: markReady
                            )

                        case .battle:
                            BattleshipBattleView(
                                ownBoard: humanGame.ownBoard,
                                opponentBoard:
                                    humanGame.opponentBoard,
                                isLocalTurn:
                                    isHumanTurn,
                                localPlayerName:
                                    "You",
                                opponentName:
                                    "Computer",
                                pendingAttack:
                                    pendingAttack ||
                                    computerThinking,
                                onAttack:
                                    resolveHumanAttack
                            )

                        case .finished:
                            BattleshipBattleView(
                                ownBoard: humanGame.ownBoard,
                                opponentBoard:
                                    humanGame.opponentBoard,
                                isLocalTurn: false,
                                localPlayerName: "You",
                                opponentName: "Computer",
                                pendingAttack: false,
                                onAttack: { _ in }
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

            if humanGame.phase == .finished &&
                showResultOverlay {
                SimpleGameResultOverlay(
                    title: resultTitle,
                    subtitle: resultSubtitle,
                    symbolName: resultSymbol,
                    accentColor: resultColor,
                    buttonGradient: BattleshipTheme.primaryGradient,
                    cardBackground: BattleshipTheme.cardBackground,
                    usesGradientBorder: true,
                    firstPlayerName: "You",
                    secondPlayerName: "Computer",
                    sessionScore: sessionScore,
                    firstPlayerColor: BattleshipTheme.cyan,
                    secondPlayerColor: BattleshipTheme.purple,
                    onPlayAgain: playAgain,
                    onQuit: {
                        computerTask?.cancel()
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
                computerTask?.cancel()
                dismiss()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "The current match against the computer will be discarded."
            )
        }
        .onDisappear {
            computerTask?.cancel()
            computerTask = nil
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

                Image(systemName: "cpu")
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
        switch humanGame.phase {
        case .placement:
            return "Deploy your fleet"
        case .waiting:
            return "Preparing computer fleet"
        case .battle:
            return isHumanTurn
            ? "Your turn"
            : "Computer is attacking"
        case .finished:
            return "Battle complete"
        }
    }

    private var headerColor: Color {
        isHumanTurn
        ? BattleshipTheme.cyan
        : BattleshipTheme.purple
    }

    // MARK: - Placement

    private func placeOrMoveShip(
        _ definition: BattleshipShipDefinition,
        at coordinate: BattleshipCoordinate
    ) {
        guard !humanGame.localReady else {
            return
        }

        let orientation =
            humanGame
            .placedShip(id: definition.id)?
            .orientation ?? .horizontal

        let placed = humanGame.placeOrMoveShip(
            definition: definition,
            preferredOrigin: coordinate,
            orientation: orientation
        )

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
        guard !humanGame.localReady else {
            return
        }

        let rotated =
            humanGame.rotateShipAutomatically(id: shipID)

        if rotated {
            UIImpactFeedbackGenerator(style: .light)
                .impactOccurred()
        } else {
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)
        }
    }

    private func randomizeFleet() {
        guard !humanGame.localReady else {
            return
        }

        if humanGame.randomizeFleet() {
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred()
        } else {
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)
        }
    }

    private func markReady() {
        guard humanGame.ownBoard.allShipsPlaced,
              !humanGame.localReady else {
            return
        }

        humanGame.markLocalReady()

        _ = computerGame.randomizeFleet()
        computerGame.markLocalReady()

        humanGame.markOpponentReady()
        computerGame.markOpponentReady()

        UINotificationFeedbackGenerator()
            .notificationOccurred(.success)

        beginBattle()
    }

    private func beginBattle() {
        let startingPlayerID =
            roundNumber.isMultiple(of: 2)
            ? Self.humanID
            : Self.computerID

        let turnID = UUID()

        humanGame.beginBattle(
            startingPlayerID: startingPlayerID,
            turnID: turnID
        )

        computerGame.beginBattle(
            startingPlayerID: startingPlayerID,
            turnID: turnID
        )


        if startingPlayerID == Self.computerID {
            scheduleComputerAttack()
        }
    }

    // MARK: - Human attack

    private func resolveHumanAttack(
        _ coordinate: BattleshipCoordinate
    ) {
        guard isHumanTurn,
              !pendingAttack,
              !computerThinking,
              humanGame
                .opponentBoard
                .marks[coordinate] == nil else {
            return
        }

        pendingAttack = true

        guard let result =
                computerGame.receiveAttack(
                    at: coordinate
                ) else {
            pendingAttack = false
            return
        }

        let sunkCoordinates =
            sunkCoordinatesForLastHit(
                result: result,
                defenderGame: computerGame
            )

        let winnerID =
            result.outcome == .gameOver
            ? Self.humanID
            : nil

        let nextTurnID = UUID()

        humanGame.applyAttackResult(
            coordinate: coordinate,
            outcome: result.outcome,
            sunkCoordinates: sunkCoordinates,
            defenderRemainingShips:
                computerGame.ownBoard.remainingShips,
            nextPlayerID: Self.computerID,
            nextTurnID: nextTurnID,
            winnerPlayerID: winnerID
        )

        computerGame.applyDefendedAttack(
            nextPlayerID: Self.computerID,
            nextTurnID: nextTurnID,
            winnerPlayerID: winnerID
        )

        pendingAttack = false

        if result.outcome == .gameOver {
            showResultAfterDelay()
        } else {
            scheduleComputerAttack()
        }
    }

    // MARK: - Computer attack

    private func scheduleComputerAttack() {
        computerTask?.cancel()

        guard computerGame.phase == .battle,
              computerGame.activePlayerID ==
                Self.computerID,
              !humanGame.ownBoard.allShipsSunk else {
            computerThinking = false
            return
        }

        computerThinking = true

        let opponentBoardSnapshot =
            computerGame.opponentBoard

        let difficultySnapshot = difficulty
        let delay =
            difficultySnapshot
            .battleshipProfile
            .thinkDelay()

        computerTask = Task {
            try? await Task.sleep(
                nanoseconds:
                    UInt64(delay * 1_000_000_000)
            )

            guard !Task.isCancelled else {
                return
            }

            let coordinate =
                BattleshipAI.chooseAttackCoordinate(
                    opponentBoard: opponentBoardSnapshot,
                    difficulty: difficultySnapshot
                )

            await MainActor.run {
                guard !Task.isCancelled,
                      computerGame.phase == .battle,
                      computerGame.activePlayerID ==
                        Self.computerID,
                      !humanGame.ownBoard.allShipsSunk else {
                    computerThinking = false
                    return
                }

                guard let coordinate else {
                    computerThinking = false
                    return
                }

                resolveComputerAttack(coordinate)
            }
        }
    }

    private func resolveComputerAttack(
        _ coordinate: BattleshipCoordinate
    ) {
        guard computerGame
                .opponentBoard
                .marks[coordinate] == nil,
              let result =
                humanGame.receiveAttack(
                    at: coordinate
                ) else {
            computerThinking = false
            scheduleComputerAttack()
            return
        }

        let sunkCoordinates =
            sunkCoordinatesForLastHit(
                result: result,
                defenderGame: humanGame
            )

        let winnerID =
            result.outcome == .gameOver
            ? Self.computerID
            : nil

        let nextTurnID = UUID()

        computerGame.applyAttackResult(
            coordinate: coordinate,
            outcome: result.outcome,
            sunkCoordinates: sunkCoordinates,
            defenderRemainingShips:
                humanGame.ownBoard.remainingShips,
            nextPlayerID: Self.humanID,
            nextTurnID: nextTurnID,
            winnerPlayerID: winnerID
        )

        humanGame.applyDefendedAttack(
            nextPlayerID: Self.humanID,
            nextTurnID: nextTurnID,
            winnerPlayerID: winnerID
        )

        computerThinking = false

        if result.outcome == .gameOver {
            showResultAfterDelay()
        }
    }

    // MARK: - Result

    private func showResultAfterDelay() {
        if let winnerID {
            sessionScore.record(
                winnerID == Self.humanID
                ? .firstPlayerWin
                : .secondPlayerWin,
                roundNumber: roundNumber
            )
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.85
        ) {
            guard humanGame.phase == .finished else {
                return
            }

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
        computerTask?.cancel()
        computerTask = nil

        roundNumber += 1
        humanGame = BattleshipGame()
        computerGame = BattleshipGame()
        pendingAttack = false
        computerThinking = false
        showResultOverlay = false
    }

    private var resultTitle: String {
        winnerID == Self.humanID
        ? "You Win!"
        : "Fleet Destroyed"
    }

    private var resultSubtitle: String {
        winnerID == Self.humanID
        ? "You sank every computer ship."
        : "The computer sank your fleet."
    }

    private var resultSymbol: String {
        winnerID == Self.humanID
        ? "crown.fill"
        : "cpu"
    }

    private var resultColor: Color {
        winnerID == Self.humanID
        ? BattleshipTheme.cyan
        : BattleshipTheme.purple
    }

    private var winnerID: String? {
        humanGame.winnerPlayerID ??
        computerGame.winnerPlayerID
    }


    // MARK: - Helpers

    private var isHumanTurn: Bool {
        humanGame.phase == .battle &&
        humanGame.activePlayerID ==
        Self.humanID
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
