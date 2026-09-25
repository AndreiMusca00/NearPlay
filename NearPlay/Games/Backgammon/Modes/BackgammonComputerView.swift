import SwiftUI
import UIKit

struct BackgammonComputerView: View {
    let game: Game
    let difficulty: GameAIDifficulty

    @Environment(\.dismiss) private var dismiss
    @AppStorage(PlayerProfile.nameKey) private var playerName = ""
    @StateObject private var controller: BackgammonMatchController
    @State private var selectedSource: BackgammonSelectedSource?
    @State private var roundNumber = 1
    @State private var sessionScore = GameSessionScore()
    @State private var showResultOverlay = false
    @State private var showQuitConfirmation = false
    @State private var showResignConfirmation = false
    @State private var noPossibleMovesTurnID: UUID?
    @State private var isPresentingRoll = false
    @State private var isAutoPlaying = false
    @State private var automaticMove: BackgammonMove?
    @State private var automaticMoveTask: Task<Void, Never>?

    private static let humanID = "backgammon_human"
    private static let computerID = "backgammon_computer"

    init(game: Game, difficulty: GameAIDifficulty) {
        self.game = game
        self.difficulty = difficulty
        _controller = StateObject(wrappedValue: BackgammonMatchController(
            playerOneID: Self.humanID,
            playerTwoID: Self.computerID,
            initialState: BackgammonGame.makeInitialState(startingPlayerID: Self.humanID),
            manualTurnCommit: true
        ))
    }

    var body: some View {
        ZStack {
            BackgammonLocalLandscapeScreen(
                gameTitle: game.title, state: controller.state,
                playerOneID: Self.humanID, playerOneName: localPlayerDisplayName,
                playerTwoID: Self.computerID, playerTwoName: "Computer",
                boardPerspective: .localPlayer(.playerOne),
                selectedSource: selectedSource,
                legalMoves: visibleLegalMoves, moveOptions: visibleMoveOptions,
                interactionPlayer: activePlayer,
                isInteractionEnabled: canHumanInteract,
                automaticMove: automaticMove,
                onAutomaticMoveFinished: finishAutomaticMove,
                onDiceSettled: diceDidSettle,
                statusTitle: statusTitle, statusSubtitle: statusSubtitle,
                onRoll: rollHumanDice, onPointTap: handlePointTap,
                onBarTap: selectBar, onMove: playDraggedMove,
                canUndo: canHumanInteract && controller.canUndo,
                canReady: canHumanInteract && canReady,
                onUndo: undoMove, onReady: commitHumanTurn,
                onQuitRequested: { showQuitConfirmation = true },
                onResignRequested: { showResignConfirmation = true }
            )

            if noPossibleMovesTurnID != nil {
                BackgammonNoMovesNotice(
                    playerName: activePlayerName,
                    accent: activePlayer == .playerOne
                        ? BackgammonTheme.cyan : BackgammonTheme.purple
                )
                .id(noPossibleMovesTurnID)
                .transition(.opacity)
                .zIndex(20)
            }

            if controller.state.isFinished && showResultOverlay {
                LandscapeGameResultOverlay(
                    title: resultTitle, subtitle: resultSubtitle,
                    symbolName: "crown.fill", accentColor: resultColor,
                    buttonGradient: BackgammonTheme.primaryGradient,
                    cardBackground: BackgammonTheme.cardBackground,
                    usesGradientBorder: true,
                    firstPlayerName: localPlayerDisplayName,
                    secondPlayerName: "Computer", sessionScore: sessionScore,
                    firstPlayerColor: BackgammonTheme.cyan,
                    secondPlayerColor: BackgammonTheme.purple,
                    onPlayAgain: playAgain, onQuit: exitGame
                )
                .zIndex(30)
            }
        }
        .alert("Quit game?", isPresented: $showQuitConfirmation) {
            Button("Quit Game", role: .destructive, action: exitGame)
            Button("Cancel", role: .cancel) {}
        } message: { Text("The current round will be discarded.") }
        .alert("Resign this round?", isPresented: $showResignConfirmation) {
            Button("Resign", role: .destructive, action: resignGame)
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text("The computer will win this round.")
        }
        .task(id: controller.state.turnID) { await startComputerTurnIfNeeded() }
        .task(id: noPossibleMovesTurnID) { await passBlockedTurnIfNeeded() }
        .task(id: controller.state.isFinished) { showResultIfNeeded() }
        .onAppear { OrientationManager.shared.lockToLandscape() }
        .onDisappear {
            automaticMoveTask?.cancel()
            OrientationManager.shared.lockToPortrait()
        }
    }

    private var canHumanInteract: Bool {
        controller.state.activePlayerID == Self.humanID &&
        !controller.state.isFinished && !isPresentingRoll && !isAutoPlaying &&
        noPossibleMovesTurnID == nil
    }
    private var visibleLegalMoves: [BackgammonMove] {
        canHumanInteract ? controller.legalMoves(for: Self.humanID) : []
    }
    private var visibleMoveOptions: [BackgammonMoveOption] {
        canHumanInteract ? controller.moveOptions(for: Self.humanID) : []
    }
    private var activePlayer: BackgammonPlayer? {
        controller.player(for: controller.state.activePlayerID)
    }
    private var activePlayerName: String {
        controller.state.activePlayerID == Self.humanID
            ? localPlayerDisplayName : "Computer"
    }

    @MainActor
    private func startComputerTurnIfNeeded() async {
        guard controller.state.activePlayerID == Self.computerID,
              !controller.state.isFinished else { return }
        try? await Task.sleep(nanoseconds: 550_000_000)
        guard !Task.isCancelled,
              controller.state.activePlayerID == Self.computerID else { return }
        isPresentingRoll = true
        _ = controller.roll(by: Self.computerID, turnID: controller.state.turnID)
    }

    @MainActor
    private func passBlockedTurnIfNeeded() async {
        guard let turnID = noPossibleMovesTurnID else { return }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        guard !Task.isCancelled, controller.state.turnID == turnID,
              !controller.state.isFinished else { return }
        _ = controller.commitTurn(by: controller.state.activePlayerID, turnID: turnID)
        withAnimation(.easeOut(duration: 0.2)) { noPossibleMovesTurnID = nil }
    }

    private func showResultIfNeeded() {
        showResultOverlay = false
        guard controller.state.isFinished else { return }
        recordFinishedRound()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
            showResultOverlay = true
        }
    }

    private func rollHumanDice() {
        guard canHumanInteract else { return }
        isPresentingRoll = true
        selectedSource = nil
        let result = controller.roll(by: Self.humanID, turnID: controller.state.turnID)
        if result == .ignored { isPresentingRoll = false }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func diceDidSettle(_ turnID: UUID) {
        guard isPresentingRoll, controller.state.turnID == turnID else { return }
        isPresentingRoll = false
        let moves = controller.legalMoves(for: controller.state.activePlayerID)
        guard !moves.isEmpty else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                noPossibleMovesTurnID = turnID
            }
            return
        }
        controller.state.activePlayerID == Self.computerID
            ? scheduleComputerMove() : scheduleForcedHumanMoveIfNeeded()
    }

    private func handlePointTap(_ index: Int) {
        guard canHumanInteract,
              let move = visibleLegalMoves.filter({ $0.source == index })
                .sorted(by: { $0.die > $1.die }).first else { return }
        playHumanMove(move)
    }

    private func selectBar() {
        guard canHumanInteract,
              let move = visibleLegalMoves.filter({ $0.source == nil })
                .sorted(by: { $0.die > $1.die }).first else { return }
        playHumanMove(move)
    }

    private func playDraggedMove(source: Int?, destination: Int?) {
        guard canHumanInteract,
              let option = visibleMoveOptions.first(where: {
                  $0.source == source && $0.destination == destination
              }), controller.play(option: option, by: Self.humanID,
                                   turnID: controller.state.turnID) else { return }
        selectedSource = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        scheduleForcedHumanMoveIfNeeded()
    }

    private func playHumanMove(_ move: BackgammonMove) {
        guard canHumanInteract else { return }
        let result = controller.play(
            source: move.source, destination: move.destination,
            by: Self.humanID, turnID: controller.state.turnID,
            preferredDie: move.die
        )
        selectedSource = nil
        guard result != .ignored else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        scheduleForcedHumanMoveIfNeeded()
    }

    private func scheduleForcedHumanMoveIfNeeded() {
        guard !controller.state.isFinished,
              let move = controller.nextForcedMove(for: Self.humanID) else { return }
        schedule(move)
    }

    private func scheduleComputerMove() {
        guard !controller.state.isFinished else { return }
        let moves = controller.legalMoves(for: Self.computerID)
        guard let move = BackgammonAI.chooseMove(
            from: moves, state: controller.state,
            player: .playerTwo, difficulty: difficulty
        ) else {
            finishAutomaticTurn()
            return
        }
        schedule(move)
    }

    private func schedule(_ move: BackgammonMove) {
        automaticMoveTask?.cancel()
        isAutoPlaying = true
        automaticMoveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, !controller.state.isFinished else { return }
            automaticMove = move
        }
    }

    private func finishAutomaticMove(_ move: BackgammonMove) {
        guard automaticMove == move else { return }
        let playerID = controller.state.activePlayerID
        let result = controller.play(
            source: move.source, destination: move.destination,
            by: playerID, turnID: controller.state.turnID,
            preferredDie: move.die
        )
        automaticMove = nil
        guard result != .ignored, !controller.state.isFinished else {
            isAutoPlaying = false
            return
        }
        if playerID == Self.computerID {
            controller.legalMoves(for: playerID).isEmpty
                ? finishAutomaticTurn() : scheduleComputerMove()
        } else if let next = controller.nextForcedMove(for: playerID) {
            schedule(next)
        } else if canReady {
            finishAutomaticTurn()
        } else {
            isAutoPlaying = false
        }
    }

    private func finishAutomaticTurn() {
        let playerID = controller.state.activePlayerID
        let turnID = controller.state.turnID
        automaticMoveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            _ = controller.commitTurn(by: playerID, turnID: turnID)
            isAutoPlaying = false
        }
    }

    private var canReady: Bool {
        controller.canCommitTurn(for: controller.state.activePlayerID,
                                 turnID: controller.state.turnID)
    }
    private func undoMove() {
        guard canHumanInteract, controller.undoLastMove() else { return }
        selectedSource = nil
    }
    private func commitHumanTurn() {
        guard canHumanInteract else { return }
        _ = controller.commitTurn(by: Self.humanID, turnID: controller.state.turnID)
        selectedSource = nil
    }

    private func resignGame() {
        automaticMoveTask?.cancel()
        automaticMove = nil
        isAutoPlaying = false
        isPresentingRoll = false
        noPossibleMovesTurnID = nil
        selectedSource = nil
        _ = controller.resign(by: Self.humanID)
    }

    private func playAgain() {
        roundNumber += 1
        showResultOverlay = false
        selectedSource = nil
        noPossibleMovesTurnID = nil
        isAutoPlaying = false
        isPresentingRoll = false
        controller.reset(startingPlayerID: roundNumber.isMultiple(of: 2)
                         ? Self.computerID : Self.humanID)
    }
    private func recordFinishedRound() {
        sessionScore.record(controller.state.winnerPlayerID == Self.humanID
                            ? .firstPlayerWin : .secondPlayerWin,
                            roundNumber: roundNumber)
    }
    private func exitGame() {
        OrientationManager.shared.transition(to: .portrait) { dismiss() }
    }
    private var localPlayerDisplayName: String {
        let name = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Player" : name
    }
    private var statusTitle: String {
        if controller.state.isFinished { return resultTitle }
        if controller.state.dice.isEmpty { return "\(activePlayerName), roll the dice" }
        if controller.state.activePlayerID == Self.computerID { return "Computer is moving…" }
        return canReady ? "\(activePlayerName), ready?" : "\(activePlayerName), make your move"
    }
    private var statusSubtitle: String {
        if controller.state.isFinished { return "All 15 checkers have been borne off." }
        if controller.state.activePlayerID == Self.computerID {
            return "\(difficulty.title) computer opponent"
        }
        return canReady ? "Tap Ready to finish the turn. You can still Undo first."
            : "Tap for one die, or drag to a combined destination."
    }
    private var resultTitle: String {
        controller.state.winnerPlayerID == Self.humanID ? "You Win!" : "Computer Wins"
    }
    private var resultSubtitle: String {
        if controller.state.resignedPlayerID == Self.humanID {
            return "You resigned this round."
        }

        return controller.state.winnerPlayerID == Self.humanID
            ? "You bore off all 15 checkers first."
            : "The computer bore off all 15 checkers first."
    }
    private var resultColor: Color {
        controller.state.winnerPlayerID == Self.humanID
            ? BackgammonTheme.cyan : BackgammonTheme.purple
    }
}
