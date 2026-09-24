import SwiftUI
import UIKit

struct BackgammonComputerView: View {
    let game: Game
    let difficulty: GameAIDifficulty

    @Environment(\.dismiss)
    private var dismiss

    @AppStorage(PlayerProfile.nameKey)
    private var playerName: String = ""

    @StateObject
    private var controller: BackgammonMatchController

    @State private var selectedSource: BackgammonSelectedSource?
    @State private var roundNumber = 1
    @State private var sessionScore = GameSessionScore()
    @State private var showResultOverlay = false
    @State private var showQuitConfirmation = false
    @State private var isComputerThinking = false

    private static let humanID = "backgammon_human"
    private static let computerID = "backgammon_computer"

    init(
        game: Game,
        difficulty: GameAIDifficulty
    ) {
        self.game = game
        self.difficulty = difficulty

        _controller = StateObject(
            wrappedValue: BackgammonMatchController(
                playerOneID: Self.humanID,
                playerTwoID: Self.computerID,
                initialState: BackgammonGame.makeInitialState(
                    startingPlayerID: Self.humanID
                )
            )
        )
    }

    var body: some View {
        ZStack {
            BackgammonGameScreen(
                gameTitle: game.title,
                state: controller.state,
                playerOneID: Self.humanID,
                playerOneName: localPlayerDisplayName,
                playerTwoID: Self.computerID,
                playerTwoName: "Computer",
                selectedSource: selectedSource,
                legalMoves: humanLegalMoves,
                interactionPlayer: .playerOne,
                isInteractionEnabled: canHumanPlay,
                showsProgress: isComputerThinking,
                statusTitle: statusTitle,
                statusSubtitle: statusSubtitle,
                onRoll: rollHumanDice,
                onPointTap: handlePointTap,
                onBarTap: selectBar,
                onMove: { source, destination in
                    guard canHumanPlay else { return }
                    playHumanMove(
                        source: source,
                        destination: destination
                    )
                },
                onBearOff: bearOff,
                onQuitRequested: {
                    showQuitConfirmation = true
                }
            )

            if controller.state.isFinished && showResultOverlay {
                SimpleGameResultOverlay(
                    title: resultTitle,
                    subtitle: resultSubtitle,
                    symbolName: "crown.fill",
                    accentColor: resultColor,
                    buttonGradient: BackgammonTheme.primaryGradient,
                    cardBackground: BackgammonTheme.cardBackground,
                    usesGradientBorder: true,
                    firstPlayerName: localPlayerDisplayName,
                    secondPlayerName: "Computer",
                    sessionScore: sessionScore,
                    firstPlayerColor: BackgammonTheme.cyan,
                    secondPlayerColor: BackgammonTheme.purple,
                    onPlayAgain: playAgain,
                    onQuit: { dismiss() }
                )
                .zIndex(10)
            }
        }
        .alert(
            "Quit game?",
            isPresented: $showQuitConfirmation
        ) {
            Button("Quit Game", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current round will be discarded.")
        }
        .task(id: controller.state.turnID) {
            guard controller.state.activePlayerID == Self.computerID,
                  !controller.state.isFinished else {
                return
            }

            await runComputerTurn()
        }
        .task(id: controller.state.isFinished) {
            showResultOverlay = false

            guard controller.state.isFinished else {
                return
            }

            recordFinishedRound()

            try? await Task.sleep(nanoseconds: 700_000_000)

            guard !Task.isCancelled,
                  controller.state.isFinished else {
                return
            }

            withAnimation(
                .spring(response: 0.38, dampingFraction: 0.84)
            ) {
                showResultOverlay = true
            }
        }
        .onAppear {
            OrientationManager.shared.lockToLandscape()
        }
        .onDisappear {
            OrientationManager.shared.lockToPortrait()
        }

    }

    private var canHumanPlay: Bool {
        controller.state.activePlayerID == Self.humanID &&
        !controller.state.isFinished &&
        !isComputerThinking
    }

    private var humanLegalMoves: [BackgammonMove] {
        guard canHumanPlay else {
            return []
        }

        return controller.legalMoves(for: Self.humanID)
    }

    private func rollHumanDice() {
        guard canHumanPlay else {
            return
        }

        selectedSource = nil
        _ = controller.roll(
            by: Self.humanID,
            turnID: controller.state.turnID
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func handlePointTap(_ index: Int) {
        guard canHumanPlay else {
            return
        }

        if let selectedSource {
            let sourceIndex: Int?
            switch selectedSource {
            case .bar:
                sourceIndex = nil
            case .point(let point):
                sourceIndex = point
            }

            if humanLegalMoves.contains(where: {
                $0.source == sourceIndex && $0.destination == index
            }) {
                playHumanMove(source: sourceIndex, destination: index)
                return
            }
        }

        guard humanLegalMoves.contains(where: { $0.source == index }) else {
            selectedSource = nil
            return
        }

        selectedSource = .point(index)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func selectBar() {
        guard humanLegalMoves.contains(where: { $0.source == nil }) else {
            return
        }

        selectedSource = .bar
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func bearOff() {
        guard case .point(let source)? = selectedSource,
              humanLegalMoves.contains(where: {
                  $0.source == source && $0.destination == nil
              }) else {
            return
        }

        playHumanMove(source: source, destination: nil)
    }

    private func playHumanMove(
        source: Int?,
        destination: Int?
    ) {
        let result = controller.play(
            source: source,
            destination: destination,
            by: Self.humanID,
            turnID: controller.state.turnID
        )

        selectedSource = nil

        if result != .ignored {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    @MainActor
    private func runComputerTurn() async {
        guard !isComputerThinking else {
            return
        }

        isComputerThinking = true
        defer { isComputerThinking = false }

        try? await Task.sleep(nanoseconds: 500_000_000)

        guard controller.state.activePlayerID == Self.computerID,
              !controller.state.isFinished else {
            return
        }

        if controller.state.dice.isEmpty {
            _ = controller.roll(
                by: Self.computerID,
                turnID: controller.state.turnID
            )
        }

        while controller.state.activePlayerID == Self.computerID,
              !controller.state.isFinished,
              !controller.state.remainingDice.isEmpty {
            let moves = controller.legalMoves(for: Self.computerID)

            guard let move = BackgammonAI.chooseMove(
                from: moves,
                state: controller.state,
                player: .playerTwo,
                difficulty: difficulty
            ) else {
                break
            }

            try? await Task.sleep(nanoseconds: 420_000_000)

            guard controller.state.activePlayerID == Self.computerID,
                  !controller.state.isFinished else {
                break
            }

            _ = controller.play(
                source: move.source,
                destination: move.destination,
                by: Self.computerID,
                turnID: controller.state.turnID
            )
        }
    }

    private func recordFinishedRound() {
        let outcome: GameSessionRoundOutcome =
            controller.state.winnerPlayerID == Self.humanID
            ? .firstPlayerWin
            : .secondPlayerWin

        sessionScore.record(outcome, roundNumber: roundNumber)
    }

    private func playAgain() {
        roundNumber += 1
        showResultOverlay = false
        selectedSource = nil

        controller.reset(
            startingPlayerID:
                roundNumber.isMultiple(of: 2)
                ? Self.computerID
                : Self.humanID
        )
    }

    private var localPlayerDisplayName: String {
        let trimmed = playerName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmed.isEmpty ? "Player" : trimmed
    }

    private var statusTitle: String {
        if controller.state.isFinished {
            return resultTitle
        }

        if controller.state.activePlayerID == Self.computerID {
            return isComputerThinking ? "Computer is thinking…" : "Computer's turn"
        }

        return controller.state.dice.isEmpty
            ? "Roll the dice"
            : "Make your move"
    }

    private var statusSubtitle: String {
        if controller.state.isFinished {
            return "All 15 checkers have been borne off."
        }

        return "\(difficulty.title) computer opponent"
    }

    private var resultTitle: String {
        controller.state.winnerPlayerID == Self.humanID
            ? "You Win!"
            : "Computer Wins"
    }

    private var resultSubtitle: String {
        controller.state.winnerPlayerID == Self.humanID
            ? "You bore off all 15 checkers first."
            : "The computer bore off all 15 checkers first."
    }

    private var resultColor: Color {
        controller.state.winnerPlayerID == Self.humanID
            ? BackgammonTheme.cyan
            : BackgammonTheme.purple
    }
}
