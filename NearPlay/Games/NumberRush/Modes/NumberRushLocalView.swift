import SwiftUI
import UIKit

struct NumberRushLocalView: View {
    let game: Game

    @Environment(\.dismiss)
    private var dismiss

    @AppStorage(PlayerProfile.nameKey)
    private var playerName: String = ""

    @StateObject
    private var controller: NumberRushMatchController

    @State private var roundNumber = 0
    @State private var wrongNumber: Int?
    @State private var correctNumber: Int?
    @State private var feedback: NumberRushFeedbackMessage?
    @State private var showQuitConfirmation = false
    @State private var showResultOverlay = false
    @State private var timeoutWorkItem: DispatchWorkItem?

    private static let playerOneID =
        "number_rush_local_player_one"

    private static let playerTwoID =
        "number_rush_local_player_two"

    init(game: Game) {
        self.game = game

        _controller = StateObject(
            wrappedValue:
                NumberRushMatchController(
                    playerOneID: Self.playerOneID,
                    playerTwoID: Self.playerTwoID,
                    shuffledNumbers: Array(1...100).shuffled(),
                    startingPlayerID: Self.playerOneID,
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
                        id: Self.playerOneID,
                        name: localPlayerDisplayName,
                        inactiveBadge: "YOU"
                    ),
                secondPlayer:
                    NumberRushPlayerPresentation(
                        id: Self.playerTwoID,
                        name: "Guest",
                        inactiveBadge: "GUEST"
                    ),
                localPlayerID:
                    controller.state.activePlayerID,
                headerSubtitle:
                    headerSubtitle,
                statusText:
                    statusText,
                instructionText:
                    "Find numbers in order. Pass the iPhone when the turn changes.",
                isInteractionEnabled:
                    !controller.state.isFinished,
                showsProgress:
                    false,
                wrongNumber:
                    wrongNumber,
                correctNumber:
                    correctNumber,
                feedback:
                    feedback,
                onNumberSelected:
                    selectNumber,
                onQuitRequested: {
                    showQuitConfirmation = true
                }
            )

            if controller.state.isFinished &&
                showResultOverlay {
                NumberRushSimpleResultOverlay(
                    title: resultTitle,
                    subtitle: resultSubtitle,
                    symbolName: resultSymbolName,
                    accentColor: resultAccentColor,
                    onPlayAgain: playAgain,
                    onQuit: {
                        timeoutWorkItem?.cancel()
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
                timeoutWorkItem?.cancel()
                dismiss()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "The current local round will be discarded."
            )
        }
        .onAppear {
            scheduleTimeout()
        }
        .onDisappear {
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
        }
        .task(
            id: controller.state.isFinished
        ) {
            showResultOverlay = false

            guard controller.state.isFinished else {
                return
            }

            timeoutWorkItem?.cancel()

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

    private func selectNumber(
        _ number: Int
    ) {
        guard !controller.state.isFinished else {
            return
        }

        let playerID = controller.state.activePlayerID

        let outcome = controller.select(
            number: number,
            by: playerID
        )

        handleOutcome(outcome)
        scheduleTimeout()
    }

    private func handleOutcome(
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

    private func scheduleTimeout() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil

        guard !controller.state.isFinished else {
            return
        }

        let expectedTurnID = controller.state.turnID
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

            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)

            showFeedback(
                "Time expired — turn switched",
                tone: .neutral
            )

            scheduleTimeout()
        }

        timeoutWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: workItem
        )
    }

    private func playAgain() {
        timeoutWorkItem?.cancel()

        roundNumber += 1
        showResultOverlay = false
        wrongNumber = nil
        correctNumber = nil
        feedback = nil

        let startingPlayerID =
            roundNumber.isMultiple(of: 2)
            ? Self.playerOneID
            : Self.playerTwoID

        controller.reset(
            shuffledNumbers: Array(1...100).shuffled(),
            startingPlayerID: startingPlayerID
        )

        scheduleTimeout()
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

    private var localPlayerDisplayName: String {
        playerName.isEmpty ? "You" : playerName
    }

    private var headerSubtitle: String {
        if controller.state.isFinished {
            return "Round complete"
        }

        return controller.state.activePlayerID == Self.playerOneID
            ? "\(localPlayerDisplayName)'s turn"
            : "Guest's turn"
    }

    private var statusText: String {
        if controller.state.isFinished {
            return resultTitle
        }

        return "Find \(controller.state.targetNumber)"
    }

    private var localRoundResult: GameRoundResult {
        let firstScore =
            controller.state.scores[Self.playerOneID] ?? 0
        let secondScore =
            controller.state.scores[Self.playerTwoID] ?? 0

        if firstScore == secondScore {
            return .draw
        }

        return firstScore > secondScore ? .win : .loss
    }

    private var resultTitle: String {
        let firstScore =
            controller.state.scores[Self.playerOneID] ?? 0
        let secondScore =
            controller.state.scores[Self.playerTwoID] ?? 0

        if firstScore == secondScore {
            return "It's a Draw!"
        }

        return firstScore > secondScore
            ? "\(localPlayerDisplayName) Wins!"
            : "Guest Wins!"
    }

    private var resultSubtitle: String {
        let firstScore =
            controller.state.scores[Self.playerOneID] ?? 0
        let secondScore =
            controller.state.scores[Self.playerTwoID] ?? 0

        return "\(firstScore) – \(secondScore) final score."
    }

    private var resultSymbolName: String {
        switch localRoundResult {
        case .win:
            return "crown.fill"
        case .loss:
            return "flag.checkered"
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
