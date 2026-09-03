import SwiftUI
import UIKit

struct RPSLocalView: View {
    let game: Game

    @Environment(\.dismiss)
    private var dismiss

    @AppStorage(PlayerProfile.nameKey)
    private var playerName: String = ""

    @StateObject
    private var controller:
        RPSMatchController

    @State private var roundNumber = 0
    @State private var sessionScore = GameSessionScore()
    @State private var showResultOverlay = false
    @State private var showQuitConfirmation = false
    @State private var feedback:
        RPSFeedbackMessage?

    private static let playerOneID =
        "rps_local_player_one"

    private static let playerTwoID =
        "rps_local_player_two"

    init(game: Game) {
        self.game = game

        _controller = StateObject(
            wrappedValue:
                RPSMatchController(
                    playerOneID:
                        Self.playerOneID,
                    playerTwoID:
                        Self.playerTwoID,
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
                        id: Self.playerOneID,
                        name: localPlayerDisplayName,
                        inactiveBadge: "YOU"
                    ),
                secondPlayer:
                    RPSPlayerPresentation(
                        id: Self.playerTwoID,
                        name: "Guest",
                        inactiveBadge: "GUEST"
                    ),
                choosingPlayerID:
                    currentChoosingPlayerID,
                headerSubtitle:
                    headerSubtitle,
                statusTitle:
                    statusTitle,
                statusSubtitle:
                    statusSubtitle,
                instructionText:
                    instructionText,
                isInteractionEnabled:
                    canChoose,
                showsProgress: false,
                hidesLockedChoice: true,
                feedback: feedback,
                onChoiceSelected:
                    selectChoice,
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
                    buttonGradient: RPSTheme.primaryGradient,
                    cardBackground: RPSTheme.cardBackground,
                    usesGradientBorder: false,
                    firstPlayerName: localPlayerDisplayName,
                    secondPlayerName: "Guest",
                    sessionScore: sessionScore,
                    firstPlayerColor: RPSTheme.brightBlue,
                    secondPlayerColor: RPSTheme.brightPurple,
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

    private func selectChoice(
        _ choice: RPSChoice
    ) {
        guard canChoose else {
            return
        }

        let movingPlayerID =
            currentChoosingPlayerID

        let result = controller.choose(
            choice,
            by: movingPlayerID
        )

        handleMoveResult(
            result,
            playerID: movingPlayerID
        )
    }

    private func handleMoveResult(
        _ result: RPSMoveResult,
        playerID: String
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

            if playerID == Self.playerOneID {
                showFeedback(
                    "First move locked. Pass the phone.",
                    tone: .neutral
                )
            }

        case .completed:
            UINotificationFeedbackGenerator()
                .notificationOccurred(
                    controller.state.isDraw
                    ? .warning
                    : .success
                )

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
        feedback = nil

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

    private var currentChoosingPlayerID: String {
        let firstID =
            roundNumber.isMultiple(of: 2)
            ? Self.playerOneID
            : Self.playerTwoID

        let secondID =
            firstID == Self.playerOneID
            ? Self.playerTwoID
            : Self.playerOneID

        if controller.choice(for: firstID) == nil {
            return firstID
        }

        if controller.choice(for: secondID) == nil {
            return secondID
        }

        return firstID
    }

    private var canChoose: Bool {
        !controller.state.isFinished &&
        controller.choice(
            for: currentChoosingPlayerID
        ) == nil
    }

    private var localPlayerDisplayName: String {
        let trimmed = playerName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty ? "You" : trimmed
    }

    private var currentChoosingName: String {
        currentChoosingPlayerID == Self.playerOneID
            ? localPlayerDisplayName
            : "Guest"
    }

    private var headerSubtitle: String {
        if controller.state.isFinished {
            return "Round complete"
        }

        return "\(currentChoosingName)'s turn"
    }

    private var statusTitle: String {
        if controller.state.isFinished {
            return resultTitle
        }

        return "\(currentChoosingName), choose your move"
    }

    private var statusSubtitle: String {
        if controller.state.isFinished {
            return "Both choices are revealed."
        }

        if controller.state.hasAnyChoice {
            return "Pass the phone without showing the first move."
        }

        return "First player chooses secretly."
    }

    private var instructionText: String {
        if controller.state.hasAnyChoice &&
            !controller.state.isFinished {
            return "The first move is hidden. Pass the iPhone to the other player."
        }

        return "Choose rock, paper or scissors. The result appears after both players choose."
    }

    private var resultTitle: String {
        if controller.state.isDraw {
            return "It's a Draw!"
        }

        if controller.state.winnerPlayerID ==
            Self.playerOneID {
            return "\(localPlayerDisplayName) Wins!"
        }

        return "Guest Wins!"
    }

    private var resultSubtitle: String {
        guard let firstChoice =
                controller.choice(for: Self.playerOneID),
              let secondChoice =
                controller.choice(for: Self.playerTwoID) else {
            return "The round has ended."
        }

        if firstChoice == secondChoice {
            return "You both chose \(firstChoice.title)."
        }

        if firstChoice.beats(secondChoice) {
            return "\(firstChoice.title) beats \(secondChoice.title)."
        }

        return "\(secondChoice.title) beats \(firstChoice.title)."
    }

    private var resultSymbol: String {
        if controller.state.isDraw {
            return "equal"
        }

        let winnerChoice =
            controller.state.winnerPlayerID ==
            Self.playerOneID
            ? controller.choice(for: Self.playerOneID)
            : controller.choice(for: Self.playerTwoID)

        return winnerChoice?.systemName ?? "gamecontroller.fill"
    }

    private var resultColor: Color {
        if controller.state.isDraw {
            return Color.white.opacity(0.78)
        }

        let winnerChoice =
            controller.state.winnerPlayerID ==
            Self.playerOneID
            ? controller.choice(for: Self.playerOneID)
            : controller.choice(for: Self.playerTwoID)

        return RPSTheme.color(for: winnerChoice)
    }
}
