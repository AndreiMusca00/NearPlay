import SwiftUI
import UIKit

struct TicTacToeComputerView: View {
    let game: Game
    let difficulty: GameAIDifficulty

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var controller: TicTacToeMatchController

    @State private var roundNumber = 0
    @State private var sessionScore = GameSessionScore()
    @State private var computerThinking = false
    @State private var showResultOverlay = false
    @State private var showQuitConfirmation = false
    @State private var computerTask: Task<Void, Never>?

    private static let humanID =
        "tic_tac_toe_human"

    private static let computerID =
        "tic_tac_toe_computer"

    init(
        game: Game,
        difficulty: GameAIDifficulty
    ) {
        self.game = game
        self.difficulty = difficulty

        _controller = StateObject(
            wrappedValue:
                TicTacToeMatchController(
                    playerOneID: Self.humanID,
                    playerTwoID: Self.computerID,
                    initialState:
                        TicTacToeGame
                        .makeInitialState(
                            startingPlayerID:
                                Self.humanID
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
                        id: Self.humanID,
                        name: "You",
                        mark: .x,
                        inactiveBadge: "YOU"
                    ),
                secondPlayer:
                    TicTacToePlayerPresentation(
                        id: Self.computerID,
                        name: "Computer",
                        mark: .o,
                        inactiveBadge:
                            difficulty.title.uppercased()
                    ),
                headerSubtitle:
                    headerSubtitle,
                statusTitle:
                    statusTitle,
                statusSubtitle:
                    statusSubtitle,
                instructionText:
                    "Difficulty: \(difficulty.title) • You play X.",
                isInteractionEnabled:
                    canHumanPlay,
                showsProgress:
                    computerThinking,
                onCellSelected:
                    selectHumanCell,
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
                    firstPlayerName: "You",
                    secondPlayerName: "Computer",
                    sessionScore: sessionScore,
                    firstPlayerColor: TicTacToeTheme.xBlue,
                    secondPlayerColor: TicTacToeTheme.oPurple,
                    onPlayAgain: playAgain,
                    onQuit: {
                        computerTask?.cancel()
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
        .task(
            id: controller.state.turnID
        ) {
            scheduleComputerMoveIfNeeded()
        }
    }

    private func selectHumanCell(
        _ index: Int
    ) {
        guard canHumanPlay else {
            return
        }

        let result = controller.play(
            index: index,
            by: Self.humanID
        )

        handleHumanResult(result)
    }

    private func scheduleComputerMoveIfNeeded() {
        computerTask?.cancel()

        guard !controller.state.isFinished,
              controller.state.activePlayerID ==
                Self.computerID else {
            computerThinking = false
            return
        }

        computerThinking = true

        let stateSnapshot = controller.state
        let turnID = stateSnapshot.turnID
        let difficultySnapshot = difficulty

        computerTask = Task {
            try? await Task.sleep(
                nanoseconds: 520_000_000
            )

            guard !Task.isCancelled else {
                return
            }

            let index = TicTacToeAI.chooseIndex(
                state: stateSnapshot,
                playerOneID: Self.humanID,
                playerTwoID: Self.computerID,
                computerPlayerID: Self.computerID,
                difficulty: difficultySnapshot
            )

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard controller.state.turnID == turnID,
                      controller.state.activePlayerID ==
                        Self.computerID,
                      !controller.state.isFinished else {
                    computerThinking = false
                    return
                }

                guard let index else {
                    computerThinking = false
                    return
                }

                let result = controller.play(
                    index: index,
                    by: Self.computerID,
                    turnID: turnID
                )

                computerThinking = false
                handleComputerResult(result)
            }
        }
    }

    private func handleHumanResult(
        _ result: TicTacToeMoveResult
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

    private func handleComputerResult(
        _ result: TicTacToeMoveResult
    ) {
        switch result {
        case .ignored, .occupied:
            break

        case .placed:
            UIImpactFeedbackGenerator(
                style: .light
            )
            .impactOccurred()

        case .won:
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)


        case .draw:
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)

        }
    }

    private func recordFinishedRound() {
        let outcome: GameSessionRoundOutcome

        if controller.state.isDraw {
            outcome = .draw
        } else if controller.state.winnerPlayerID == Self.humanID {
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
        computerTask?.cancel()
        computerTask = nil

        roundNumber += 1
        showResultOverlay = false
        computerThinking = false

        let startingPlayerID =
            roundNumber.isMultiple(of: 2)
            ? Self.humanID
            : Self.computerID

        controller.reset(
            startingPlayerID: startingPlayerID
        )

        scheduleComputerMoveIfNeeded()
    }


    private var canHumanPlay: Bool {
        !controller.state.isFinished &&
        !computerThinking &&
        controller.state.activePlayerID == Self.humanID
    }

    private var headerSubtitle: String {
        if controller.state.isDraw {
            return "Round draw"
        }

        if controller.state.winnerPlayerID == Self.humanID {
            return "You win"
        }

        if controller.state.winnerPlayerID == Self.computerID {
            return "Computer wins"
        }

        return canHumanPlay
            ? "Your turn"
            : "Computer thinking"
    }

    private var statusTitle: String {
        if controller.state.isFinished {
            return resultTitle
        }

        return canHumanPlay
            ? "Your move"
            : "Computer's move"
    }

    private var statusSubtitle: String {
        if controller.state.isFinished {
            return "Round finished"
        }

        return computerThinking
            ? "The computer is choosing a cell."
            : "Pick an empty cell."
    }

    private var resultTitle: String {
        if controller.state.isDraw {
            return "It's a Draw!"
        }

        return controller.state.winnerPlayerID == Self.humanID
            ? "You Win!"
            : "You Lose"
    }

    private var resultSubtitle: String {
        if controller.state.isDraw {
            return "Nobody won this round."
        }

        return controller.state.winnerPlayerID == Self.humanID
            ? "Nice move."
            : "Try another round."
    }

    private var resultSymbol: String {
        if controller.state.isDraw {
            return "equal"
        }

        return controller.state.winnerPlayerID == Self.humanID
            ? "xmark"
            : "circle"
    }

    private var resultColor: Color {
        if controller.state.isDraw {
            return Color.white.opacity(0.78)
        }

        return controller.state.winnerPlayerID == Self.humanID
            ? TicTacToeTheme.xBlue
            : TicTacToeTheme.oPurple
    }
}
