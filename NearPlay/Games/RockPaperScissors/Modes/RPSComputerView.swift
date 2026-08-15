import SwiftUI
import UIKit

struct RPSComputerView: View {
    let game: Game
    let difficulty: GameAIDifficulty

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var controller:
        RPSMatchController

    @State private var roundNumber = 0
    @State private var humanHistory: [RPSChoice] = []
    @State private var computerThinking = false
    @State private var showResultOverlay = false
    @State private var showQuitConfirmation = false
    @State private var feedback:
        RPSFeedbackMessage?
    @State private var computerTask:
        Task<Void, Never>?

    private static let humanID =
        "rps_human"

    private static let computerID =
        "rps_computer"

    init(
        game: Game,
        difficulty: GameAIDifficulty
    ) {
        self.game = game
        self.difficulty = difficulty

        _controller = StateObject(
            wrappedValue:
                RPSMatchController(
                    playerOneID:
                        Self.humanID,
                    playerTwoID:
                        Self.computerID,
                    initialState:
                        RPSGame.makeInitialState()
                )
        )
    }

    var body: some View {
        ZStack {
            RPSGameScreen(
                gameTitle: game.title,
                controller: controller,
                firstPlayer:
                    RPSPlayerPresentation(
                        id: Self.humanID,
                        name: "You",
                        inactiveBadge: "YOU"
                    ),
                secondPlayer:
                    RPSPlayerPresentation(
                        id: Self.computerID,
                        name: "Computer",
                        inactiveBadge:
                            difficulty.title.uppercased()
                    ),
                choosingPlayerID:
                    Self.humanID,
                headerSubtitle:
                    headerSubtitle,
                statusTitle:
                    statusTitle,
                statusSubtitle:
                    statusSubtitle,
                instructionText:
                    "Difficulty: \(difficulty.title). Choose your move and the computer will answer.",
                isInteractionEnabled:
                    canHumanChoose,
                showsProgress:
                    computerThinking,
                hidesLockedChoice: false,
                feedback: feedback,
                onChoiceSelected:
                    selectHumanChoice,
                onQuitRequested: {
                    showQuitConfirmation = true
                }
            )

            if controller.state.isFinished &&
                showResultOverlay {
                RPSSimpleResultOverlay(
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
                nanoseconds: 950_000_000
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

    private func selectHumanChoice(
        _ choice: RPSChoice
    ) {
        guard canHumanChoose else {
            return
        }

        let result = controller.choose(
            choice,
            by: Self.humanID
        )

        handleHumanResult(result)

        guard result.didStoreChoice,
              !controller.state.isFinished else {
            return
        }

        humanHistory.append(choice)
        scheduleComputerChoice()
    }

    private func scheduleComputerChoice() {
        computerTask?.cancel()

        guard !controller.state.isFinished,
              controller.choice(
                for: Self.computerID
              ) == nil else {
            computerThinking = false
            return
        }

        computerThinking = true

        let roundID = controller.state.roundID
        let difficultySnapshot = difficulty
        let historySnapshot = humanHistory

        computerTask = Task {
            try? await Task.sleep(
                nanoseconds: 520_000_000
            )

            guard !Task.isCancelled else {
                return
            }

            let choice = RPSAI.chooseChoice(
                difficulty: difficultySnapshot,
                humanHistory: historySnapshot
            )

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard controller.state.roundID == roundID,
                      controller.choice(
                        for: Self.computerID
                      ) == nil,
                      !controller.state.isFinished else {
                    computerThinking = false
                    return
                }

                let result = controller.choose(
                    choice,
                    by: Self.computerID,
                    roundID: roundID
                )

                computerThinking = false
                handleComputerResult(result)
            }
        }
    }

    private func handleHumanResult(
        _ result: RPSMoveResult
    ) {
        switch result {
        case .ignored:
            break

        case .alreadyChosen:
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)

        case .stored:
            UIImpactFeedbackGenerator(
                style: .medium
            )
            .impactOccurred()

        case .completed:
            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)
        }
    }

    private func handleComputerResult(
        _ result: RPSMoveResult
    ) {
        switch result {
        case .ignored, .alreadyChosen:
            break

        case .stored:
            UIImpactFeedbackGenerator(
                style: .light
            )
            .impactOccurred()

        case .completed:
            UINotificationFeedbackGenerator()
                .notificationOccurred(
                    localRoundResult == .win
                    ? .success
                    : .warning
                )

            showFeedback(
                resultTitle,
                tone:
                    localRoundResult == .win
                    ? .success
                    : localRoundResult == .loss
                    ? .danger
                    : .neutral
            )
        }
    }

    private func playAgain() {
        computerTask?.cancel()
        computerTask = nil

        roundNumber += 1
        showResultOverlay = false
        feedback = nil
        computerThinking = false

        controller.reset()
    }

    private func showFeedback(
        _ text: String,
        tone: RPSFeedbackTone
    ) {
        feedback = RPSFeedbackMessage(
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

    private var canHumanChoose: Bool {
        !computerThinking &&
        !controller.state.isFinished &&
        controller.choice(for: Self.humanID) == nil
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
            : "Choose your move"
    }

    private var statusSubtitle: String {
        if controller.state.isFinished {
            return "Both choices are revealed."
        }

        return computerThinking
            ? "The computer is choosing its move."
            : "Pick rock, paper or scissors."
    }

    private var localRoundResult: GameRoundResult {
        if controller.state.isDraw {
            return .draw
        }

        return controller.state.winnerPlayerID ==
            Self.humanID
            ? .win
            : .loss
    }

    private var resultTitle: String {
        switch localRoundResult {
        case .win:
            return "You Win!"
        case .loss:
            return "You Lose"
        case .draw:
            return "It's a Draw!"
        }
    }

    private var resultSubtitle: String {
        guard let humanChoice =
                controller.choice(for: Self.humanID),
              let computerChoice =
                controller.choice(for: Self.computerID) else {
            return "The round has ended."
        }

        if humanChoice == computerChoice {
            return "You both chose \(humanChoice.title)."
        }

        if humanChoice.beats(computerChoice) {
            return "\(humanChoice.title) beats \(computerChoice.title)."
        }

        return "\(computerChoice.title) beats \(humanChoice.title)."
    }

    private var resultSymbol: String {
        if controller.state.isDraw {
            return "equal"
        }

        let winningChoice =
            localRoundResult == .win
            ? controller.choice(for: Self.humanID)
            : controller.choice(for: Self.computerID)

        return winningChoice?.systemName ?? "gamecontroller.fill"
    }

    private var resultColor: Color {
        if controller.state.isDraw {
            return Color.white.opacity(0.78)
        }

        let winningChoice =
            localRoundResult == .win
            ? controller.choice(for: Self.humanID)
            : controller.choice(for: Self.computerID)

        return RPSTheme.color(for: winningChoice)
    }
}
