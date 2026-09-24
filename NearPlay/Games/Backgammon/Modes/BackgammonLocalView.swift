import SwiftUI
import UIKit

struct BackgammonLocalView: View {
    let game: Game

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
    @State private var noPossibleMovesTurnID: UUID?
    @State private var isPresentingRoll = false
    @State private var isAutoPlaying = false
    @State private var automaticMove: BackgammonMove?
    @State private var automaticMoveTask: Task<Void, Never>?

    private var canInteract: Bool {
        !controller.state.isFinished && !isPresentingRoll && !isAutoPlaying && noPossibleMovesTurnID == nil
    }

    // For Same Phone UX, Guest owns Player One (top home board)
    // and the local user owns Player Two (bottom home board).
    private static let guestPlayerID = "backgammon_local_player_one"
    private static let localPlayerID = "backgammon_local_player_two"

    init(game: Game) {
        self.game = game

        _controller = StateObject(
            wrappedValue: BackgammonMatchController(
                playerOneID: Self.guestPlayerID,
                playerTwoID: Self.localPlayerID,
                initialState: BackgammonGame.makeInitialState(
                    startingPlayerID: Self.localPlayerID
                ),
                manualTurnCommit: true
            )
        )
    }

    var body: some View {
        ZStack {
            BackgammonLocalLandscapeScreen(
                gameTitle: game.title,
                state: controller.state,
                playerOneID: Self.guestPlayerID,
                playerOneName: "Guest",
                playerTwoID: Self.localPlayerID,
                playerTwoName: localPlayerDisplayName,
                selectedSource: selectedSource,
                legalMoves: currentLegalMoves,
                moveOptions: currentMoveOptions,
                interactionPlayer: activePlayer,
                isInteractionEnabled: canInteract,
                automaticMove: automaticMove,
                onAutomaticMoveFinished: finishAutomaticMove,
                onDiceSettled: diceDidSettle,
                statusTitle: statusTitle,
                statusSubtitle: statusSubtitle,
                onRoll: rollDice,
                onPointTap: handlePointTap,
                onBarTap: selectBar,
                onMove: { source, destination in
                    playDraggedMove(
                        from: source,
                        to: destination
                    )
                },
                canUndo: canInteract && controller.canUndo,
                canReady: canInteract && canReady,
                onUndo: undoMove,
                onReady: commitTurn,
                onQuitRequested: {
                    showQuitConfirmation = true
                }
            )

            if noPossibleMovesTurnID != nil {
                BackgammonNoMovesNotice(
                    playerName: activePlayerName,
                    accent: activePlayer == .playerOne ? BackgammonTheme.cyan : BackgammonTheme.purple
                )
                .id(noPossibleMovesTurnID)
                .transition(.opacity)
                .zIndex(20)
            }

            if controller.state.isFinished && showResultOverlay {
                LandscapeGameResultOverlay(
                    title: resultTitle,
                    subtitle: resultSubtitle,
                    symbolName: "crown.fill",
                    accentColor: resultColor,
                    buttonGradient: BackgammonTheme.primaryGradient,
                    cardBackground: BackgammonTheme.cardBackground,
                    usesGradientBorder: true,
                    firstPlayerName: localPlayerDisplayName,
                    secondPlayerName: "Guest",
                    sessionScore: sessionScore,
                    firstPlayerColor: BackgammonTheme.purple,
                    secondPlayerColor: BackgammonTheme.cyan,
                    onPlayAgain: playAgain,
                    onQuit: exitGame
                )
                .zIndex(10)
            }
        }
        .alert(
            "Quit game?",
            isPresented: $showQuitConfirmation
        ) {
            Button("Quit Game", role: .destructive) {
                exitGame()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current local round will be discarded.")
        }
        .task(id: controller.state.isFinished) {
            showResultOverlay = false

            guard controller.state.isFinished else {
                return
            }

            recordFinishedRound()

            withAnimation(
                .spring(response: 0.38, dampingFraction: 0.84)
            ) {
                showResultOverlay = true
            }
        }
        .task(id: noPossibleMovesTurnID) {
            guard let blockedTurnID = noPossibleMovesTurnID else {
                return
            }

            try? await Task.sleep(
                nanoseconds: 2_000_000_000
            )

            guard !Task.isCancelled,
                  noPossibleMovesTurnID == blockedTurnID,
                  controller.state.turnID == blockedTurnID,
                  !controller.state.isFinished,
                  currentLegalMoves.isEmpty else {
                return
            }

            _ = controller.commitTurn(
                by: controller.state.activePlayerID,
                turnID: blockedTurnID
            )

            selectedSource = nil

            withAnimation(.easeOut(duration: 0.18)) {
                noPossibleMovesTurnID = nil
            }
        }
        .onAppear {
            OrientationManager.shared.lockToLandscape()
        }
        .onDisappear {
            automaticMoveTask?.cancel()
            automaticMove = nil
            isAutoPlaying = false
            OrientationManager.shared.lockToPortrait()
        }

    }

    private func exitGame() {
        OrientationManager.shared.transition(to: .portrait) {
            dismiss()
        }
    }

    private var currentLegalMoves: [BackgammonMove] {
        controller.legalMoves(
            for: controller.state.activePlayerID
        )
    }


    private var currentMoveOptions: [BackgammonMoveOption] {
        controller.moveOptions(
            for: controller.state.activePlayerID
        )
    }

    private var activePlayer: BackgammonPlayer? {
        controller.player(
            for: controller.state.activePlayerID
        )
    }

    private func rollDice() {
        guard canInteract else { return }
        isPresentingRoll = true
        selectedSource = nil
        noPossibleMovesTurnID = nil

        let result = controller.roll(
            by: controller.state.activePlayerID,
            turnID: controller.state.turnID
        )

        switch result {
        case .ignored:
            isPresentingRoll = false

        case .rolled:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        case .noLegalMoves:
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)


        }
    }

    private func handlePointTap(_ index: Int) {
        guard canInteract,
              let move = bestSingleMove(from: index) else {
            return
        }

        playSingleMove(move)
    }

    private func selectBar() {
        guard canInteract, let move = bestSingleMove(from: nil) else {
            return
        }

        playSingleMove(move)
    }

    /// One tap always means ONE checker move using ONE die.
    /// If this checker can legally use more than one remaining die, use the
    /// largest legal die first. The next tap/drag consumes the next die.
    private func bestSingleMove(
        from source: Int?
    ) -> BackgammonMove? {
        currentLegalMoves
            .filter { $0.source == source }
            .sorted { lhs, rhs in
                lhs.die > rhs.die
            }
            .first
    }

    /// Drop on either a single-die destination or a legal combined route.
    private func playDraggedMove(
        from source: Int?,
        to destination: Int?
    ) {
        guard canInteract else { return }
        guard let option = currentMoveOptions.first(where: {
            $0.source == source && $0.destination == destination
        }), controller.play(
            option: option,
            by: controller.state.activePlayerID,
            turnID: controller.state.turnID
        ) else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        selectedSource = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        autoPlayForcedMovesIfNeeded()
    }

    private func playSingleMove(
        _ move: BackgammonMove
    ) {
        guard canInteract else { return }
        let movingPlayerID =
            controller.state.activePlayerID

        let result = controller.play(
            source: move.source,
            destination: move.destination,
            by: movingPlayerID,
            turnID: controller.state.turnID,
            preferredDie: move.die
        )

        switch result {
        case .ignored:
            selectedSource = nil

            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)

        case .moved(let appliedMove, let didHit),
             .turnEnded(let appliedMove, let didHit):
            selectedSource = nil

            if didHit {
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.success)
            } else {
                UIImpactFeedbackGenerator(
                    style: .medium
                )
                .impactOccurred()
            }

            autoPlayForcedMovesIfNeeded()

        case .won(let appliedMove):
            selectedSource = nil

            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)

            autoPlayForcedMovesIfNeeded()
        }
    }

    private func diceDidSettle(_ turnID: UUID) {
        guard isPresentingRoll, controller.state.turnID == turnID else { return }
        isPresentingRoll = false
        if currentLegalMoves.isEmpty && !controller.state.isFinished {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                noPossibleMovesTurnID = turnID
            }
        } else {
            autoPlayForcedMovesIfNeeded()
        }
    }

    /// Present one forced move at a time; apply it only when the board's
    /// animation completes, then recompute the next move from the new state.
    private func autoPlayForcedMovesIfNeeded() {
        guard !isPresentingRoll, !controller.state.isFinished else { return }
        automaticMoveTask?.cancel()
        let turnID = controller.state.turnID
        let playerID = controller.state.activePlayerID
        guard let move = controller.nextForcedMove(for: playerID) else {
            isAutoPlaying = false
            return
        }
        isAutoPlaying = true
        selectedSource = nil
        automaticMoveTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 300_000_000) }
            catch { return }
            guard !Task.isCancelled, controller.state.turnID == turnID,
                  controller.state.activePlayerID == playerID,
                  !controller.state.isFinished else { return }
            automaticMove = move
        }
    }

    private func finishAutomaticMove(_ move: BackgammonMove) {
        guard isAutoPlaying, automaticMove == move else { return }
        let result = controller.play(
            source: move.source, destination: move.destination,
            by: controller.state.activePlayerID, turnID: controller.state.turnID,
            preferredDie: move.die
        )
        automaticMove = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if result == .ignored || controller.state.isFinished {
            isAutoPlaying = false
        } else if canReady {
            // Let the last checker land before passing a completed automatic turn.
            let turnID = controller.state.turnID
            let playerID = controller.state.activePlayerID
            automaticMoveTask = Task { @MainActor in
                do { try await Task.sleep(nanoseconds: 450_000_000) }
                catch { return }
                guard !Task.isCancelled, controller.state.turnID == turnID,
                      !controller.state.isFinished else { return }
                _ = controller.commitTurn(by: playerID, turnID: turnID)
                isAutoPlaying = false
                selectedSource = nil
            }
        } else {
            autoPlayForcedMovesIfNeeded()
        }
    }

    private var canReady: Bool {
        controller.canCommitTurn(
            for: controller.state.activePlayerID,
            turnID: controller.state.turnID
        )
    }

    private func undoMove() {
        guard canInteract else { return }
        noPossibleMovesTurnID = nil

        guard controller.undoLastMove() else {
            return
        }

        selectedSource = nil
        UIImpactFeedbackGenerator(style: .light)
            .impactOccurred()
    }

    private func commitTurn() {
        guard canInteract else { return }
        noPossibleMovesTurnID = nil

        let activePlayerID =
            controller.state.activePlayerID
        let turnID = controller.state.turnID

        guard controller.commitTurn(
            by: activePlayerID,
            turnID: turnID
        ) else {
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)
            return
        }

        selectedSource = nil
        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred()
    }

    private func recordFinishedRound() {
        let outcome: GameSessionRoundOutcome =
            controller.state.winnerPlayerID == Self.localPlayerID
            ? .firstPlayerWin
            : .secondPlayerWin

        sessionScore.record(
            outcome,
            roundNumber: roundNumber
        )
    }

    private func playAgain() {
        automaticMoveTask?.cancel()
        automaticMove = nil
        isAutoPlaying = false
        isPresentingRoll = false
        roundNumber += 1
        showResultOverlay = false
        selectedSource = nil
        noPossibleMovesTurnID = nil

        let startingPlayerID = roundNumber.isMultiple(of: 2)
            ? Self.guestPlayerID
            : Self.localPlayerID

        controller.reset(
            startingPlayerID: startingPlayerID
        )
    }

    private var localPlayerDisplayName: String {
        let trimmed = playerName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmed.isEmpty ? "Player" : trimmed
    }

    private var activePlayerName: String {
        controller.state.activePlayerID == Self.localPlayerID
            ? localPlayerDisplayName
            : "Guest"
    }

    private var statusTitle: String {
        if controller.state.isFinished {
            return resultTitle
        }

        if controller.state.dice.isEmpty {
            return "\(activePlayerName), roll the dice"
        }

        if canReady {
            return "\(activePlayerName), ready?"
        }

        return "\(activePlayerName), make your move"
    }

    private var statusSubtitle: String {
        if controller.state.isFinished {
            return "All 15 checkers have been borne off."
        }

        if canReady {
            return "Tap Ready to finish the turn. You can still Undo first."
        }

        if activePlayer.map({ controller.state.barCount(for: $0) > 0 }) == true {
            return "A checker on the bar must re-enter before any other move."
        }

        return "Tap for the largest legal die, or drag to choose a destination."
    }

    private var resultTitle: String {
        controller.state.winnerPlayerID == Self.localPlayerID
            ? "\(localPlayerDisplayName) Wins!"
            : "Guest Wins!"
    }

    private var resultSubtitle: String {
        controller.state.winnerPlayerID == Self.localPlayerID
            ? "You bore off all 15 checkers first."
            : "Guest bore off all 15 checkers first."
    }

    private var resultColor: Color {
        controller.state.winnerPlayerID == Self.localPlayerID
            ? BackgammonTheme.purple
            : BackgammonTheme.cyan
    }
}

struct BackgammonNoMovesNotice: View {
    let playerName: String
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private let cream = Color(red: 1, green: 0.91, blue: 0.73)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.48)
                    .ignoresSafeArea()

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Circle().fill(accent).frame(width: 6, height: 6)
                        Text(playerName.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(2)
                            .lineLimit(1)
                    }
                    .foregroundStyle(cream.opacity(0.7))

                    Text("No possible moves")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(cream)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Label("Passing turn", systemImage: "arrow.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(cream.opacity(0.65))
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 19)
                .background {
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.72), Color.black.opacity(0.72), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                }
                .overlay(alignment: .top) { bannerLine }
                .overlay(alignment: .bottom) { bannerLine }
                .offset(x: reduceMotion ? 0 : (appeared ? 0 : -geometry.size.width))
                .opacity(appeared ? 1 : 0)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .task {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.9)) {
                appeared = true
            }
            do { try await Task.sleep(nanoseconds: 1_650_000_000) }
            catch { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                appeared = false
            }
        }
    }

    private var bannerLine: some View {
        LinearGradient(colors: [.clear, cream.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
            .frame(height: 1)
    }
}
