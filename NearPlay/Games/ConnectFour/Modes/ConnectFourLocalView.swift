//
//  ConnectFourLocalView.swift
//  NearPlay
//

import SwiftUI
import UIKit

struct ConnectFourLocalView: View {
    let game: Game

    @Environment(\.dismiss)
    private var dismiss

    @AppStorage(PlayerProfile.nameKey)
    private var playerName: String = ""

    @StateObject
    private var controller:
        ConnectFourMatchController

    @State private var roundNumber = 0
    @State private var sessionScore = GameSessionScore()
    @State private var showResultOverlay = false
    @State private var showQuitConfirmation = false

    private static let playerOneID =
        "connect_four_local_player_one"

    private static let playerTwoID =
        "connect_four_local_player_two"

    init(game: Game) {
        self.game = game

        _controller = StateObject(
            wrappedValue:
                ConnectFourMatchController(
                    playerOneID:
                        Self.playerOneID,
                    playerTwoID:
                        Self.playerTwoID,
                    initialState:
                        ConnectFourGame
                        .makeInitialState(
                            startingPlayerID:
                                Self.playerOneID
                        )
                )
        )
    }

    var body: some View {
        ZStack {
            ConnectFourGameScreen(
                gameTitle: game.title,
                controller: controller,
                firstPlayer:
                    ConnectFourPlayerPresentation(
                        id: Self.playerOneID,
                        name: localPlayerDisplayName,
                        disc: .playerOne,
                        inactiveBadge: "YOU"
                    ),
                secondPlayer:
                    ConnectFourPlayerPresentation(
                        id: Self.playerTwoID,
                        name: "Guest",
                        disc: .playerTwo,
                        inactiveBadge: "GUEST"
                    ),
                headerSubtitle:
                    headerSubtitle,
                statusTitle:
                    statusTitle,
                statusSubtitle:
                    "Pass the phone after every move.",
                instructionText:
                    "Tap a column, then pass the iPhone to the other player.",
                isInteractionEnabled:
                    !controller.state.isFinished,
                showsProgress: false,
                onColumnSelected:
                    selectColumn,
                onQuitRequested: {
                    showQuitConfirmation = true
                }
            )

            if controller.state.isFinished &&
                showResultOverlay {
                SimpleGameResultOverlay(
                    title: resultTitle,
                    subtitle: resultSubtitle,
                    symbolName: resultSymbol,
                    accentColor: resultColor,
                    buttonGradient: ConnectFourTheme.primaryGradient,
                    cardBackground: ConnectFourTheme.cardBackground,
                    usesGradientBorder: false,
                    firstPlayerName: localPlayerDisplayName,
                    secondPlayerName: "Guest",
                    sessionScore: sessionScore,
                    firstPlayerColor: ConnectFourTheme.cyan,
                    secondPlayerColor: ConnectFourTheme.purple,
                    onPlayAgain: playAgain,
                    onQuit: {
                        dismiss()
                    }
                )
                .zIndex(10)
            }
        }
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
                "The current local round will be discarded."
            )
        }
        .task(
            id: controller.state.isFinished
        ) {
            showResultOverlay = false

            guard controller.state.isFinished else {
                return
            }

            recordFinishedRound()

            try? await Task.sleep(
                nanoseconds: 750_000_000
            )

            guard !Task.isCancelled,
                  controller.state.isFinished else {
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

    // MARK: - Moves

    private func selectColumn(
        _ column: Int
    ) {
        guard !controller.state.isFinished else {
            return
        }

        let movingPlayerID =
            controller.state.activePlayerID

        let result = controller.play(
            column: column,
            by: movingPlayerID
        )

        handleMoveResult(
            result,
            playerID: movingPlayerID
        )
    }

    private func handleMoveResult(
        _ result: ConnectFourMoveResult,
        playerID: String
    ) {
        switch result {
        case .ignored:
            break

        case .columnFull:
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)

        case .placed:
            UIImpactFeedbackGenerator(
                style: .medium
            )
            .impactOccurred()

        case .won:
            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)


        case .draw:
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)

        }
    }

    // MARK: - Rematch

    private func recordFinishedRound() {
        let outcome: GameSessionRoundOutcome

        if controller.state.isDraw {
            outcome = .draw
        } else if controller.state.winnerPlayerID == Self.playerOneID {
            outcome = .firstPlayerWin
        } else {
            outcome = .secondPlayerWin
        }

        sessionScore.record(
            outcome,
            roundNumber: roundNumber
        )
    }

    private func playAgain() {
        roundNumber += 1
        showResultOverlay = false

        let startingPlayerID =
            roundNumber.isMultiple(of: 2)
            ? Self.playerOneID
            : Self.playerTwoID

        controller.reset(
            startingPlayerID: startingPlayerID
        )
    }

    // MARK: - Presentation

    private var localPlayerDisplayName: String {
        let trimmedName =
            playerName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return trimmedName.isEmpty
        ? "Player"
        : trimmedName
    }

    private var activePlayerName: String {
        controller.state.activePlayerID ==
        Self.playerOneID
        ? localPlayerDisplayName
        : "Guest"
    }

    private var headerSubtitle: String {
        controller.state.isFinished
        ? "Round complete"
        : "\(activePlayerName)'s turn"
    }

    private var statusTitle: String {
        controller.state.isFinished
        ? resultTitle
        : "\(activePlayerName), choose a column"
    }

    private var resultTitle: String {
        if controller.state.isDraw {
            return "It's a Draw!"
        }

        return controller.state.winnerPlayerID ==
        Self.playerOneID
        ? "\(localPlayerDisplayName) Wins!"
        : "Guest Wins!"
    }

    private var resultSubtitle: String {
        if controller.state.isDraw {
            return "The board is full and nobody connected four."
        }

        if controller.state.winnerPlayerID ==
            Self.playerOneID {
            return "\(localPlayerDisplayName) connected four discs first."
        }

        return "Guest connected four discs first."
    }

    private var resultSymbol: String {
        controller.state.isDraw
        ? "equal"
        : "crown.fill"
    }

    private var resultColor: Color {
        if controller.state.isDraw {
            return Color.white.opacity(0.78)
        }

        return controller.state.winnerPlayerID ==
        Self.playerOneID
        ? ConnectFourTheme.cyan
        : ConnectFourTheme.purple
    }
}
