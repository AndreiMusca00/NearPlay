import SwiftUI
import UIKit

struct NumberRushComputerView: View {
    let game: Game
    let difficulty: GameAIDifficulty

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var controller: NumberRushMatchController

    @State private var roundNumber = 0
    @State private var sessionScore = GameSessionScore()
    @State private var wrongNumber: Int?
    @State private var correctNumber: Int?
    @State private var feedback: NumberRushFeedbackMessage?
    @State private var showQuitConfirmation = false
    @State private var showResultOverlay = false
    @State private var computerThinking = false
    @State private var computerConsecutiveCorrectChoices = 0

    @State private var timeoutWorkItem: DispatchWorkItem?
    @State private var computerTask: Task<Void, Never>?

    private static let humanID =
        "number_rush_human"

    private static let computerID =
        "number_rush_computer"

    init(
        game: Game,
        difficulty: GameAIDifficulty
    ) {
        self.game = game
        self.difficulty = difficulty

        _controller = StateObject(
            wrappedValue:
                NumberRushMatchController(
                    playerOneID: Self.humanID,
                    playerTwoID: Self.computerID,
                    shuffledNumbers: Array(1...100).shuffled(),
                    startingPlayerID: Self.humanID,
                    baseTurnDuration: 5
                )
        )
    }

    var body: some View {
        ZStack {
            NumberRushGameScreen(
                gameTitle: game.title,
                controller: controller,
                firstPlayer:
                    NumberRushPlayerPresentation(
                        id: Self.humanID,
                        name: "You",
                        inactiveBadge: "YOU"
                    ),
                secondPlayer:
                    NumberRushPlayerPresentation(
                        id: Self.computerID,
                        name: "Computer",
                        inactiveBadge:
                            difficulty.title.uppercased()
                    ),
                localPlayerID:
                    Self.humanID,
                headerSubtitle:
                    headerSubtitle,
                statusText:
                    statusText,
                instructionText:
                    "Difficulty: \(difficulty.title). Find numbers before the computer does.",
                isInteractionEnabled:
                    canHumanPlay,
                showsProgress:
                    computerThinking,
                wrongNumber:
                    wrongNumber,
                correctNumber:
                    correctNumber,
                feedback:
                    feedback,
                onNumberSelected:
                    selectHumanNumber,
                onQuitRequested: {
                    showQuitConfirmation = true
                }
            )

            if controller.state.isFinished &&
                showResultOverlay {
                SimpleGameResultOverlay(
                    title: resultTitle,
                    subtitle: resultSubtitle,
                    symbolName: resultSymbolName,
                    accentColor: resultAccentColor,
                    buttonGradient: NumberRushTheme.primaryGradient,
                    cardBackground: NumberRushTheme.cardBackground,
                    usesGradientBorder: false,
                    firstPlayerName: "You",
                    secondPlayerName: "Computer",
                    sessionScore: sessionScore,
                    firstPlayerColor: NumberRushTheme.blue,
                    secondPlayerColor: NumberRushTheme.purple,
                    onPlayAgain: playAgain,
                    onQuit: {
                        cancelScheduledWork()
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
                cancelScheduledWork()
                dismiss()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "The current match against the computer will be discarded."
            )
        }
        .onAppear {
            scheduleAfterStateChange()
        }
        .onDisappear {
            cancelScheduledWork()
        }
        .task(
            id: controller.state.isFinished
        ) {
            showResultOverlay = false

            guard controller.state.isFinished else {
                return
            }

            recordFinishedRound()

            cancelScheduledWork()

            try? await Task.sleep(
                nanoseconds: 900_000_000
            )

            guard !Task.isCancelled,
                  controller.state.isFinished else {
                return
            }

            withAnimation(
                .spring(
                    response: 0.40,
                    dampingFraction: 0.84
                )
            ) {
                showResultOverlay = true
            }
        }
    }

    private func selectHumanNumber(
        _ number: Int
    ) {
        guard canHumanPlay else {
            return
        }

        let outcome = controller.select(
            number: number,
            by: Self.humanID
        )

        handleHumanOutcome(outcome)
        scheduleAfterStateChange()
    }

    private func handleHumanOutcome(
        _ outcome: NumberRushSelectionOutcome
    ) {
        switch outcome {
        case .ignored:
            break

        case .correct(let number),
             .finished(let number):
            showCorrectFeedback(number)

        case .wrong(let number):
            showWrongFeedback(number)
        }
    }

    private func scheduleAfterStateChange() {
        scheduleTimeout()
        scheduleComputerActionIfNeeded()
    }

    private func scheduleComputerActionIfNeeded() {
        computerTask?.cancel()

        guard !controller.state.isFinished,
              controller.state.activePlayerID ==
                Self.computerID else {
            computerThinking = false
            return
        }

        let stateSnapshot = controller.state
        let turnID = stateSnapshot.turnID
        let difficultySnapshot = difficulty
        let streakSnapshot = computerConsecutiveCorrectChoices

        guard let action = NumberRushAI.action(
            state: stateSnapshot,
            difficulty: difficultySnapshot,
            consecutiveCorrectChoices: streakSnapshot
        ) else {
            computerThinking = false
            return
        }

        if action.waitsForTimeout {
            computerThinking = false
            return
        }

        computerThinking = true

        computerTask = Task {
            try? await Task.sleep(
                nanoseconds: UInt64(action.delay * 1_000_000_000)
            )

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard controller.state.turnID == turnID,
                      controller.state.activePlayerID == Self.computerID,
                      !controller.state.isFinished,
                      let selectedNumber = action.selectedNumber else {
                    computerThinking = false
                    return
                }

                let outcome = controller.select(
                    number: selectedNumber,
                    by: Self.computerID,
                    turnID: turnID
                )

                computerThinking = false
                handleComputerOutcome(outcome)
                scheduleAfterStateChange()
            }
        }
    }

    private func handleComputerOutcome(
        _ outcome: NumberRushSelectionOutcome
    ) {
        switch outcome {
        case .ignored:
            break

        case .correct(let number),
             .finished(let number):
            computerConsecutiveCorrectChoices += 1
            showCorrectFeedback(number)

        case .wrong(let number):
            computerConsecutiveCorrectChoices = 0
            showWrongFeedback(number)
        }
    }

    private func scheduleTimeout() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil

        guard !controller.state.isFinished else {
            return
        }

        let expectedTurnID = controller.state.turnID
        let activePlayerID = controller.state.activePlayerID
        let delay = max(
            controller.state.deadline.timeIntervalSinceNow,
            0
        )

        let workItem = DispatchWorkItem {
            guard controller.state.turnID == expectedTurnID else {
                return
            }

            let changed = controller.expireTurn(
                expectedTurnID: expectedTurnID
            )

            guard changed else {
                return
            }

            if activePlayerID == Self.computerID {
                computerConsecutiveCorrectChoices = 0
            }

            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)

            showFeedback(
                activePlayerID == Self.humanID
                ? "Time expired — computer's turn"
                : "Computer ran out of time",
                tone: .neutral
            )

            scheduleAfterStateChange()
        }

        timeoutWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: workItem
        )
    }

    private func recordFinishedRound() {
        let outcome: GameSessionRoundOutcome

        switch localRoundResult {
        case .win:
            outcome = .firstPlayerWin
        case .loss:
            outcome = .secondPlayerWin
        case .draw:
            outcome = .draw
        }

        sessionScore.record(
            outcome,
            roundNumber: roundNumber
        )
    }

    private func playAgain() {
        cancelScheduledWork()

        roundNumber += 1
        showResultOverlay = false
        wrongNumber = nil
        correctNumber = nil
        feedback = nil
        computerThinking = false
        computerConsecutiveCorrectChoices = 0

        let startingPlayerID =
            roundNumber.isMultiple(of: 2)
            ? Self.humanID
            : Self.computerID

        controller.reset(
            shuffledNumbers: Array(1...100).shuffled(),
            startingPlayerID: startingPlayerID
        )

        scheduleAfterStateChange()
    }

    private func cancelScheduledWork() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        computerTask?.cancel()
        computerTask = nil
    }

    private func showCorrectFeedback(
        _ number: Int
    ) {
        correctNumber = number

        UIImpactFeedbackGenerator(style: .light)
            .impactOccurred()

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.30
        ) {
            if correctNumber == number {
                correctNumber = nil
            }
        }
    }

    private func showWrongFeedback(
        _ number: Int
    ) {
        wrongNumber = number

        UINotificationFeedbackGenerator()
            .notificationOccurred(.error)

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.38
        ) {
            withAnimation(.easeOut(duration: 0.18)) {
                if wrongNumber == number {
                    wrongNumber = nil
                }
            }
        }
    }

    private func showFeedback(
        _ text: String,
        tone: NumberRushFeedbackTone
    ) {
        feedback = NumberRushFeedbackMessage(
            text: text,
            tone: tone
        )

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1.15
        ) {
            if feedback?.text == text {
                withAnimation(.easeOut(duration: 0.18)) {
                    feedback = nil
                }
            }
        }
    }

    private var canHumanPlay: Bool {
        !computerThinking &&
        !controller.state.isFinished &&
        controller.state.activePlayerID == Self.humanID
    }

    private var headerSubtitle: String {
        if controller.state.isFinished {
            return "Round complete"
        }

        return controller.state.activePlayerID == Self.humanID
            ? "Your turn"
            : "Computer's turn"
    }

    private var statusText: String {
        if controller.state.isFinished {
            return resultTitle
        }

        return controller.state.activePlayerID == Self.humanID
            ? "Find \(controller.state.targetNumber)"
            : "Computer is searching"
    }

    private var localRoundResult: GameRoundResult {
        let humanScore =
            controller.state.scores[Self.humanID] ?? 0
        let computerScore =
            controller.state.scores[Self.computerID] ?? 0

        if humanScore == computerScore {
            return .draw
        }

        return humanScore > computerScore ? .win : .loss
    }

    private var resultTitle: String {
        switch localRoundResult {
        case .win:
            return "You Win!"
        case .loss:
            return "Computer Wins"
        case .draw:
            return "It's a Draw!"
        }
    }

    private var resultSubtitle: String {
        let humanScore =
            controller.state.scores[Self.humanID] ?? 0
        let computerScore =
            controller.state.scores[Self.computerID] ?? 0

        return "\(humanScore) – \(computerScore) final score."
    }

    private var resultSymbolName: String {
        switch localRoundResult {
        case .win:
            return "crown.fill"
        case .loss:
            return "cpu"
        case .draw:
            return "equal"
        }
    }

    private var resultAccentColor: Color {
        switch localRoundResult {
        case .win:
            return NumberRushTheme.blue
        case .loss:
            return NumberRushTheme.purple
        case .draw:
            return Color.white.opacity(0.78)
        }
    }
}
