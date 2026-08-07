//
//  ConnectFourComputerView.swift
//  NearPlay
//

import SwiftUI
import UIKit

struct ConnectFourComputerView: View {
    let game: Game
    let difficulty: ConnectFourDifficulty

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var controller:
        ConnectFourMatchController

    @State private var roundNumber = 0
    @State private var computerThinking = false
    @State private var showResultOverlay = false
    @State private var showQuitConfirmation = false
    @State private var feedback:
        ConnectFourFeedbackMessage?
    @State private var computerTask:
        Task<Void, Never>?

    private static let humanID =
        "connect_four_human"

    private static let computerID =
        "connect_four_computer"

    init(
        game: Game,
        difficulty: ConnectFourDifficulty
    ) {
        self.game = game
        self.difficulty = difficulty

        _controller = StateObject(
            wrappedValue:
                ConnectFourMatchController(
                    playerOneID:
                        Self.humanID,
                    playerTwoID:
                        Self.computerID,
                    initialState:
                        ConnectFourGame
                        .makeInitialState(
                            startingPlayerID:
                                Self.humanID
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
                        id: Self.humanID,
                        name: "You",
                        disc: .playerOne,
                        inactiveBadge: "YOU"
                    ),
                secondPlayer:
                    ConnectFourPlayerPresentation(
                        id: Self.computerID,
                        name: "Computer",
                        disc: .playerTwo,
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
                    "Difficulty: \(difficulty.title) • You play cyan.",
                isInteractionEnabled:
                    canHumanPlay,
                showsProgress:
                    computerThinking,
                feedback: feedback,
                onColumnSelected:
                    selectHumanColumn,
                onQuitRequested: {
                    showQuitConfirmation = true
                }
            )

            if controller.state.isFinished &&
                showResultOverlay {
                ConnectFourSimpleResultOverlay(
                    title: resultTitle,
                    subtitle: resultSubtitle,
                    symbolName: resultSymbol,
                    accentColor: resultColor,
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

    private func selectHumanColumn(
        _ column: Int
    ) {
        guard canHumanPlay else {
            return
        }

        let result = controller.play(
            column: column,
            by: Self.humanID
        )

        handleHumanResult(result)

        guard !controller.state.isFinished else {
            return
        }

        scheduleComputerMove()
    }

    private func scheduleComputerMove() {
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

            let column = await Task.detached(
                priority: .userInitiated
            ) {
                ConnectFourAI.chooseColumn(
                    state: stateSnapshot,
                    playerOneID: Self.humanID,
                    playerTwoID: Self.computerID,
                    computerPlayerID:
                        Self.computerID,
                    difficulty:
                        difficultySnapshot
                )
            }
            .value

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard controller.state.turnID ==
                        turnID,
                      controller.state.activePlayerID ==
                        Self.computerID,
                      !controller.state.isFinished else {
                    computerThinking = false
                    return
                }

                guard let column else {
                    computerThinking = false
                    return
                }

                let result = controller.play(
                    column: column,
                    by: Self.computerID,
                    turnID: turnID
                )

                computerThinking = false
                handleComputerResult(result)
            }
        }
    }

    private func handleHumanResult(
        _ result: ConnectFourMoveResult
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

            showFeedback(
                "Connect Four!",
                tone: .success
            )

        case .draw:
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)

            showFeedback(
                "Board full — draw",
                tone: .neutral
            )
        }
    }

    private func handleComputerResult(
        _ result: ConnectFourMoveResult
    ) {
        switch result {
        case .ignored, .columnFull:
            break

        case .placed:
            UIImpactFeedbackGenerator(
                style: .light
            )
            .impactOccurred()

        case .won:
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)

            showFeedback(
                "Computer connected four",
                tone: .danger
            )

        case .draw:
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)

            showFeedback(
                "Board full — draw",
                tone: .neutral
            )
        }
    }

    private func playAgain() {
        computerTask?.cancel()
        computerTask = nil
        computerThinking = false
        showResultOverlay = false
        feedback = nil

        roundNumber += 1

        let startingPlayerID =
            roundNumber.isMultiple(of: 2)
            ? Self.humanID
            : Self.computerID

        controller.reset(
            startingPlayerID: startingPlayerID
        )

        if startingPlayerID ==
            Self.computerID {
            scheduleComputerMove()
        }
    }

    private func showFeedback(
        _ text: String,
        tone: ConnectFourFeedbackTone
    ) {
        feedback = ConnectFourFeedbackMessage(
            text: text,
            tone: tone
        )

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1.15
        ) {
            if feedback?.text == text {
                withAnimation(
                    .easeOut(duration: 0.18)
                ) {
                    feedback = nil
                }
            }
        }
    }

    private var canHumanPlay: Bool {
        !computerThinking &&
        !controller.state.isFinished &&
        controller.state.activePlayerID ==
        Self.humanID
    }

    private var headerSubtitle: String {
        if controller.state.isFinished {
            return "Round complete"
        }

        return computerThinking
        ? "Computer is thinking…"
        : "Your turn"
    }

    private var statusTitle: String {
        if controller.state.isFinished {
            return resultTitle
        }

        return computerThinking
        ? "Computer is choosing"
        : "Choose a column"
    }

    private var statusSubtitle: String {
        computerThinking
        ? "The board is locked until the computer moves."
        : "Connect four before the computer does."
    }

    private var resultTitle: String {
        if controller.state.isDraw {
            return "It's a Draw!"
        }

        return controller.state.winnerPlayerID ==
        Self.humanID
        ? "You Win!"
        : "Computer Wins"
    }

    private var resultSubtitle: String {
        if controller.state.isDraw {
            return "The board is full and nobody connected four."
        }

        return controller.state.winnerPlayerID ==
        Self.humanID
        ? "You connected four discs before the computer."
        : "The computer connected four discs first."
    }

    private var resultSymbol: String {
        if controller.state.isDraw {
            return "equal"
        }

        return controller.state.winnerPlayerID ==
        Self.humanID
        ? "crown.fill"
        : "cpu"
    }

    private var resultColor: Color {
        if controller.state.isDraw {
            return Color.white.opacity(0.78)
        }

        return controller.state.winnerPlayerID ==
        Self.humanID
        ? ConnectFourTheme.cyan
        : ConnectFourTheme.purple
    }
}
