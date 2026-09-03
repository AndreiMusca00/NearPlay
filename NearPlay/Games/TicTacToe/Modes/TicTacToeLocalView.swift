import SwiftUI
import UIKit

struct TicTacToeLocalView: View {
    let game: Game

    @Environment(\.dismiss)
    private var dismiss

    @AppStorage(PlayerProfile.nameKey)
    private var playerName: String = ""

    @StateObject
    private var controller: TicTacToeMatchController

    @State private var roundNumber = 0
    @State private var sessionScore = GameSessionScore()
    @State private var showResultOverlay = false
    @State private var showQuitConfirmation = false

    private static let playerOneID =
        "tic_tac_toe_local_player_one"

    private static let playerTwoID =
        "tic_tac_toe_local_player_two"

    init(game: Game) {
        self.game = game

        _controller = StateObject(
            wrappedValue:
                TicTacToeMatchController(
                    playerOneID: Self.playerOneID,
                    playerTwoID: Self.playerTwoID,
                    initialState:
                        TicTacToeGame
                        .makeInitialState(
                            startingPlayerID:
                                Self.playerOneID
                        )
                )
        )
    }

    var body: some View {
        ZStack {
            TicTacToeGameScreen(
                gameTitle: game.title,
                controller: controller,
                firstPlayer:
                    TicTacToePlayerPresentation(
                        id: Self.playerOneID,
                        name: localPlayerDisplayName,
                        mark: .x,
                        inactiveBadge: "YOU"
                    ),
                secondPlayer:
                    TicTacToePlayerPresentation(
                        id: Self.playerTwoID,
                        name: "Guest",
                        mark: .o,
                        inactiveBadge: "GUEST"
                    ),
                headerSubtitle:
                    headerSubtitle,
                statusTitle:
                    statusTitle,
                statusSubtitle:
                    "Pass the phone after every move.",
                instructionText:
                    "Tap a cell, then pass the iPhone to the other player.",
                isInteractionEnabled:
                    !controller.state.isFinished,
                showsProgress: false,
                onCellSelected:
                    selectCell,
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
                    buttonGradient: TicTacToeTheme.primaryGradient,
                    cardBackground: TicTacToeTheme.cardBackground,
                    usesGradientBorder: false,
                    firstPlayerName: localPlayerDisplayName,
                    secondPlayerName: "Guest",
                    sessionScore: sessionScore,
                    firstPlayerColor: TicTacToeTheme.xBlue,
                    secondPlayerColor: TicTacToeTheme.oPurple,
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

    private func selectCell(
        _ index: Int
    ) {
        guard !controller.state.isFinished else {
            return
        }

        let movingPlayerID =
            controller.state.activePlayerID

        let result = controller.play(
            index: index,
            by: movingPlayerID
        )

        handleMoveResult(
            result,
            playerID: movingPlayerID
        )
    }

    private func handleMoveResult(
        _ result: TicTacToeMoveResult,
        playerID: String
    ) {
        switch result {
        case .ignored:
            break

        case .occupied:
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


    private var localPlayerDisplayName: String {
        playerName.isEmpty ? "You" : playerName
    }

    private var headerSubtitle: String {
        if let winnerName {
            return "\(winnerName) wins"
        }

        if controller.state.isDraw {
            return "Round draw"
        }

        return controller.state.activePlayerID ==
            Self.playerOneID
            ? "\(localPlayerDisplayName)'s turn"
            : "Guest's turn"
    }

    private var statusTitle: String {
        if controller.state.isFinished {
            return resultTitle
        }

        return controller.state.activePlayerID ==
            Self.playerOneID
            ? "\(localPlayerDisplayName)'s move"
            : "Guest's move"
    }

    private var winnerName: String? {
        guard let winnerID =
                controller.state.winnerPlayerID else {
            return nil
        }

        return winnerID == Self.playerOneID
            ? localPlayerDisplayName
            : "Guest"
    }

    private var resultTitle: String {
        if controller.state.isDraw {
            return "It's a Draw!"
        }

        return "\(winnerName ?? "Player") Wins!"
    }

    private var resultSubtitle: String {
        if controller.state.isDraw {
            return "Nobody won this round."
        }

        return "Start another local round when you're ready."
    }

    private var resultSymbol: String {
        if controller.state.isDraw {
            return "equal"
        }

        let mark =
            controller.state.winnerPlayerID == Self.playerOneID
            ? TicTacToeMark.x
            : TicTacToeMark.o

        return mark.systemName
    }

    private var resultColor: Color {
        if controller.state.isDraw {
            return Color.white.opacity(0.78)
        }

        let mark =
            controller.state.winnerPlayerID == Self.playerOneID
            ? TicTacToeMark.x
            : TicTacToeMark.o

        return TicTacToeTheme.color(for: mark)
    }
}
