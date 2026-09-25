import SwiftUI
import UIKit

struct BackgammonView: View {
    let game: Game

    @ObservedObject
    var nearbyService: NearbyService

    let localPlayerName: String
    let startPayload: BackgammonStartPayload
    let onExitToHome: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var controller: BackgammonMatchController

    @StateObject
    private var rematchController: RematchController

    @State private var selectedSource: BackgammonSelectedSource?
    @State private var pendingAction = false
    @State private var awaitingRoundReset = false
    @State private var currentRoundNumber = 1
    @State private var sessionScore = GameSessionScore()
    @State private var scoreRoundNumber = 1

    @State private var showQuitConfirmation = false
    @State private var isQuitting = false
    @State private var showResultOverlay = false
    @State private var noPossibleMovesTurnID: UUID?
    @State private var isPresentingRoll = false
    @State private var isAutoPlaying = false
    @State private var automaticMove: BackgammonMove?
    @State private var automaticMoveTask: Task<Void, Never>?
    @State private var remoteCanUndo = false

    init(
        game: Game,
        nearbyService: NearbyService,
        localPlayerName: String,
        startPayload: BackgammonStartPayload,
        onExitToHome: @escaping () -> Void = {}
    ) {
        self.game = game
        self.nearbyService = nearbyService
        self.localPlayerName = localPlayerName
        self.startPayload = startPayload
        self.onExitToHome = onExitToHome

        _controller = StateObject(
            wrappedValue: BackgammonMatchController(
                playerOneID: startPayload.playerOneID,
                playerTwoID: startPayload.playerTwoID,
                initialState: startPayload.initialState,
                manualTurnCommit: true
            )
        )

        _rematchController = StateObject(
            wrappedValue: RematchController(
                gameID: game.id,
                sessionID: startPayload.sessionID,
                localPlayerID: nearbyService.localPlayerID,
                localPlayerName: localPlayerName,
                hostPlayerID:
                    nearbyService.lobbySession?.hostPlayerID ??
                    startPayload.playerOneID,
                nearbyService: nearbyService
            )
        )
    }

    var body: some View {
        ZStack {
            BackgammonLocalLandscapeScreen(
                gameTitle: game.title,
                state: controller.state,
                playerOneID: startPayload.playerOneID,
                playerOneName: startPayload.playerOneName,
                playerTwoID: startPayload.playerTwoID,
                playerTwoName: startPayload.playerTwoName,
                boardPerspective: .localPlayer(
                    localPlayer ?? .playerTwo
                ),
                selectedSource: selectedSource,
                legalMoves: localLegalMoves,
                moveOptions: localMoveOptions,
                interactionPlayer: localPlayer,
                isInteractionEnabled: canPlay,
                automaticMove: automaticMove,
                onAutomaticMoveFinished: finishAutomaticMove,
                onDiceSettled: diceDidSettle,
                statusTitle: statusTitle,
                statusSubtitle: statusSubtitle,
                onRoll: rollDice,
                onPointTap: handlePointTap,
                onBarTap: selectBar,
                onMove: { source, destination in
                    guard canPlay else { return }
                    submitCombinedMove(
                        source: source,
                        destination: destination
                    )
                },
                canUndo: canPlay && canUndoAvailable,
                canReady: canPlay && canReady,
                onUndo: submitUndo,
                onReady: submitCommit,
                onQuitRequested: {
                    showQuitConfirmation = true
                }
            )

            if noPossibleMovesTurnID != nil {
                BackgammonNoMovesNotice(
                    playerName: activePlayerName,
                    accent: localPlayer == .playerOne
                        ? BackgammonTheme.cyan : BackgammonTheme.purple
                )
                .id(noPossibleMovesTurnID)
                .transition(.opacity)
                .zIndex(9)
            }

            if controller.state.isFinished && showResultOverlay {
                GameResultOverlay(
                    result: localRoundResult,
                    title: resultTitle,
                    subtitle: resultSubtitle,
                    symbolName: "crown.fill",
                    accentColor: resultAccentColor,
                    firstPlayerName: localPlayerName,
                    secondPlayerName: opponentName,
                    sessionScore: sessionScore,
                    rematchState: rematchController.state,
                    onPrimaryAction: {
                        rematchController.performPrimaryAction()
                    },
                    onQuit: quitGame
                )
                .zIndex(10)
            }

            if isQuitting {
                quittingOverlay
                    .zIndex(20)
            }
        }
        .alert(
            "Quit game?",
            isPresented: $showQuitConfirmation
        ) {
            Button(
                "Quit Game",
                role: .destructive,
                action: quitGame
            )

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You and your opponent will return to the main screen.")
        }
        .onReceive(
            nearbyService.$lastReceivedMessage
        ) { message in
            handleIncoming(message)
        }
        .onChange(
            of: rematchController.confirmedRoundNumber
        ) { _, confirmedRound in
            guard let confirmedRound else {
                return
            }

            scoreRoundNumber = confirmedRound
            currentRoundNumber = confirmedRound
            showResultOverlay = false
            selectedSource = nil
            pendingAction = false
            noPossibleMovesTurnID = nil
            isPresentingRoll = false
            isAutoPlaying = false
            automaticMove = nil
            automaticMoveTask?.cancel()
            remoteCanUndo = false

            let startingPlayerID = confirmedRound.isMultiple(of: 2)
                ? startPayload.playerTwoID
                : startPayload.playerOneID

            if isLocalHost {
                controller.reset(
                    startingPlayerID: startingPlayerID
                )
                awaitingRoundReset = false
                broadcastAuthoritativeState()
            } else {
                awaitingRoundReset = true
            }

            rematchController.finishStartingRound()
        }
        .task(id: controller.state.isFinished) {
            showResultOverlay = false

            guard controller.state.isFinished else {
                return
            }

            sessionScore.record(
                localResult: localRoundResult,
                roundNumber: scoreRoundNumber
            )

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
        .task(id: noPossibleMovesTurnID) {
            guard let turnID = noPossibleMovesTurnID else { return }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, controller.state.turnID == turnID,
                  isLocalTurn, !controller.state.isFinished else { return }
            submitCommit()
            withAnimation(.easeOut(duration: 0.2)) {
                noPossibleMovesTurnID = nil
            }
        }
        .onAppear {
            OrientationManager.shared.lockToLandscape()
        }
        .onDisappear {
            automaticMoveTask?.cancel()
            OrientationManager.shared.lockToPortrait()
        }

    }

    // MARK: - Interaction

    private var localLegalMoves: [BackgammonMove] {
        guard canPlay else {
            return []
        }

        return controller.legalMoves(for: localPlayerID)
    }

    private var localMoveOptions: [BackgammonMoveOption] {
        guard canPlay else { return [] }
        return controller.moveOptions(for: localPlayerID)
    }

    private func rollDice() {
        guard canPlay,
              controller.state.dice.isEmpty else {
            return
        }

        selectedSource = nil
        isPresentingRoll = true

        let payload = BackgammonActionPayload(
            sessionID: startPayload.sessionID,
            playerID: localPlayerID,
            turnID: controller.state.turnID,
            kind: .roll,
            source: nil,
            destination: nil
        )

        submitAction(payload)
    }

    private func handlePointTap(_ index: Int) {
        guard canPlay,
              let move = localLegalMoves.filter({ $0.source == index })
                .sorted(by: { $0.die > $1.die }).first else { return }
        submitMove(source: move.source, destination: move.destination)
    }

    private func selectBar() {
        guard canPlay,
              let move = localLegalMoves.filter({ $0.source == nil })
                .sorted(by: { $0.die > $1.die }).first else { return }
        submitMove(source: move.source, destination: move.destination)
    }

    private func submitMove(
        source: Int?,
        destination: Int?
    ) {
        let payload = BackgammonActionPayload(
            sessionID: startPayload.sessionID,
            playerID: localPlayerID,
            turnID: controller.state.turnID,
            kind: .move,
            source: source,
            destination: destination
        )

        submitAction(payload)
    }

    private func submitCombinedMove(source: Int?, destination: Int?) {
        guard localMoveOptions.contains(where: {
            $0.source == source && $0.destination == destination
        }) else { return }
        submitAction(BackgammonActionPayload(
            sessionID: startPayload.sessionID, playerID: localPlayerID,
            turnID: controller.state.turnID, kind: .combinedMove,
            source: source, destination: destination
        ))
    }

    private func submitUndo() {
        guard isLocalTurn, canUndoAvailable else { return }
        submitAction(BackgammonActionPayload(
            sessionID: startPayload.sessionID, playerID: localPlayerID,
            turnID: controller.state.turnID, kind: .undo,
            source: nil, destination: nil
        ))
    }

    private func submitCommit() {
        guard isLocalTurn else { return }
        submitAction(BackgammonActionPayload(
            sessionID: startPayload.sessionID, playerID: localPlayerID,
            turnID: controller.state.turnID, kind: .commit,
            source: nil, destination: nil
        ))
    }

    private func submitAction(
        _ payload: BackgammonActionPayload
    ) {
        selectedSource = nil

        if isLocalHost {
            resolveAction(
                payload,
                isLocalAction: true
            )
        } else {
            pendingAction = true
            sendPayload(
                payload,
                type: .gameAction
            )
        }
    }

    private func diceDidSettle(_ turnID: UUID) {
        guard isPresentingRoll, controller.state.turnID == turnID,
              isLocalTurn else { return }
        isPresentingRoll = false
        if controller.legalMoves(for: localPlayerID).isEmpty {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                noPossibleMovesTurnID = turnID
            }
        } else {
            continueAutomaticSequenceIfNeeded()
        }
    }

    private func continueAutomaticSequenceIfNeeded() {
        guard isLocalTurn, !pendingAction, !isPresentingRoll,
              !controller.state.isFinished else {
            if !isLocalTurn { isAutoPlaying = false }
            return
        }
        if let move = controller.nextForcedMove(for: localPlayerID) {
            scheduleAutomaticMove(move)
        } else if isAutoPlaying && canReady {
            automaticMoveTask?.cancel()
            automaticMoveTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                submitCommit()
                isAutoPlaying = false
            }
        } else {
            isAutoPlaying = false
        }
    }

    private func scheduleAutomaticMove(_ move: BackgammonMove) {
        automaticMoveTask?.cancel()
        isAutoPlaying = true
        automaticMoveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, isLocalTurn,
                  !controller.state.isFinished else { return }
            automaticMove = move
        }
    }

    private func finishAutomaticMove(_ move: BackgammonMove) {
        guard automaticMove == move, isLocalTurn else { return }
        automaticMove = nil
        submitMove(source: move.source, destination: move.destination)
    }

    private func resolveAction(
        _ payload: BackgammonActionPayload,
        isLocalAction: Bool
    ) {
        guard isLocalHost,
              payload.sessionID == startPayload.sessionID,
              payload.turnID == controller.state.turnID,
              payload.playerID == controller.state.activePlayerID else {
            pendingAction = false
            return
        }

        switch payload.kind {
        case .roll:
            let result = controller.roll(
                by: payload.playerID,
                turnID: payload.turnID
            )

            if isLocalAction,
               result != .ignored {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }

        case .move:
            let result = controller.play(
                source: payload.source,
                destination: payload.destination,
                by: payload.playerID,
                turnID: payload.turnID
            )

            switch result {
            case .ignored:
                break

            case .moved(_, let didHit),
                 .turnEnded(_, let didHit):
                if didHit {
                    UINotificationFeedbackGenerator()
                        .notificationOccurred(.success)
                } else {
                    UIImpactFeedbackGenerator(
                        style: isLocalAction ? .medium : .light
                    )
                    .impactOccurred()
                }

            case .won:
                UINotificationFeedbackGenerator()
                    .notificationOccurred(
                        isLocalAction ? .success : .warning
                    )
            }

        case .combinedMove:
            guard let option = controller.moveOptions(for: payload.playerID)
                .first(where: {
                    $0.source == payload.source &&
                    $0.destination == payload.destination
                }) else {
                pendingAction = false
                return
            }
            _ = controller.play(
                option: option,
                by: payload.playerID,
                turnID: payload.turnID
            )

        case .undo:
            _ = controller.undoLastMove()

        case .commit:
            _ = controller.commitTurn(
                by: payload.playerID,
                turnID: payload.turnID
            )
        }

        pendingAction = false
        broadcastAuthoritativeState()
        continueAutomaticSequenceIfNeeded()
    }

    private func broadcastAuthoritativeState() {
        guard isLocalHost else {
            return
        }

        sendPayload(
            BackgammonStatePayload(
                sessionID: startPayload.sessionID,
                roundNumber: currentRoundNumber,
                state: controller.state,
                canUndo: controller.canUndo
            ),
            type: .gameState
        )
    }

    private func applyRemoteState(
        _ newState: BackgammonGameState,
        roundNumber: Int,
        canUndo: Bool
    ) {
        guard roundNumber >= currentRoundNumber else {
            return
        }

        currentRoundNumber = roundNumber
        controller.applyRemoteState(newState)
        remoteCanUndo = canUndo
        selectedSource = nil
        pendingAction = false
        awaitingRoundReset = false
        continueAutomaticSequenceIfNeeded()
    }

    // MARK: - Messages

    private func handleIncoming(
        _ message: NearbyMessage?
    ) {
        guard let message,
              message.gameID == game.id else {
            return
        }

        if rematchController.handleIncoming(message) {
            return
        }

        switch message.type {
        case .gameAction:
            guard isLocalHost,
                  let data = message.payload,
                  let payload = try? JSONDecoder().decode(
                    BackgammonActionPayload.self,
                    from: data
                  ) else {
                return
            }

            resolveAction(
                payload,
                isLocalAction: false
            )

        case .gameState:
            guard !isLocalHost,
                  let data = message.payload,
                  let payload = try? JSONDecoder().decode(
                    BackgammonStatePayload.self,
                    from: data
                  ),
                  payload.sessionID == startPayload.sessionID else {
                return
            }

            applyRemoteState(
                payload.state,
                roundNumber: payload.roundNumber,
                canUndo: payload.canUndo ?? false
            )

        case .gameQuit:
            handleOpponentQuit()

        default:
            break
        }
    }

    private func sendPayload<T: Encodable>(
        _ payload: T,
        type: NearbyMessageType
    ) {
        do {
            let data = try JSONEncoder().encode(payload)

            nearbyService.send(
                NearbyMessage(
                    gameID: game.id,
                    senderName: localPlayerName,
                    type: type,
                    payload: data
                )
            )
        } catch {
            pendingAction = false
            nearbyService.errorMessage =
                "Failed to synchronize Backgammon."

            print("Backgammon payload encoding failed: \(error)")
        }
    }

    // MARK: - Quit

    private func quitGame() {
        guard !isQuitting else {
            return
        }

        isQuitting = true

        let payload = GameQuitPayload(
            playerName: localPlayerName,
            reason: "quit"
        )

        let data = try? JSONEncoder().encode(payload)

        nearbyService.send(
            NearbyMessage(
                gameID: game.id,
                senderName: localPlayerName,
                type: .gameQuit,
                payload: data
            )
        )

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.35
        ) {
            nearbyService.stop()
            OrientationManager.shared.transition(to: .portrait) {
                dismiss()
                onExitToHome()
                isQuitting = false
            }
        }
    }

    private func handleOpponentQuit() {
        nearbyService.stop()
        OrientationManager.shared.transition(to: .portrait) {
            dismiss()
            onExitToHome()
        }
    }

    private var quittingOverlay: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)

                Text("Leaving game…")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .background {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .fill(BackgammonTheme.cardBackground)
            }
        }
    }

    // MARK: - Presentation

    private var localPlayerID: String {
        nearbyService.localPlayerID
    }

    private var opponentID: String {
        localPlayerID == startPayload.playerOneID
            ? startPayload.playerTwoID
            : startPayload.playerOneID
    }

    private var opponentName: String {
        localPlayerID == startPayload.playerOneID
            ? startPayload.playerTwoName
            : startPayload.playerOneName
    }

    private var localPlayer: BackgammonPlayer? {
        controller.player(for: localPlayerID)
    }

    private var isLocalHost: Bool {
        nearbyService.lobbySession?.hostPlayerID == localPlayerID
    }

    private var isLocalTurn: Bool {
        controller.state.activePlayerID == localPlayerID
    }

    private var canPlay: Bool {
        isLocalTurn &&
        !controller.state.isFinished &&
        !pendingAction &&
        !awaitingRoundReset &&
        !isPresentingRoll &&
        !isAutoPlaying &&
        noPossibleMovesTurnID == nil
    }

    private var canReady: Bool {
        controller.canCommitTurn(
            for: localPlayerID,
            turnID: controller.state.turnID
        )
    }

    private var canUndoAvailable: Bool {
        isLocalHost ? controller.canUndo : remoteCanUndo
    }

    private var activePlayerName: String {
        isLocalTurn ? localPlayerName : opponentName
    }

    private var statusTitle: String {
        if awaitingRoundReset {
            return "Preparing the board"
        }

        if pendingAction {
            return "Synchronizing move…"
        }

        if controller.state.isFinished {
            return resultTitle
        }

        if isLocalTurn {
            if controller.state.dice.isEmpty { return "\(localPlayerName), roll the dice" }
            return canReady ? "\(localPlayerName), ready?" : "\(localPlayerName), make your move"
        }

        return "Waiting for \(opponentName)"
    }

    private var statusSubtitle: String {
        if controller.state.isFinished {
            return "All 15 checkers have been borne off."
        }

        if let localPlayer,
           isLocalTurn,
           controller.state.barCount(for: localPlayer) > 0 {
            return "Re-enter your checker from the bar first."
        }

        if isLocalTurn && canReady {
            return "Tap Ready to finish the turn. You can still Undo first."
        }
        return isLocalTurn
            ? "Tap for one die, or drag to a combined destination."
            : "Moves are synchronized by the NearPlay host."
    }

    private var localRoundResult: GameRoundResult {
        controller.state.winnerPlayerID == localPlayerID
            ? .win
            : .loss
    }

    private var resultTitle: String {
        localRoundResult == .win
            ? "You Win!"
            : "\(opponentName) Wins"
    }

    private var resultSubtitle: String {
        localRoundResult == .win
            ? "You bore off all 15 checkers first."
            : "\(opponentName) bore off all 15 checkers first."
    }

    private var resultAccentColor: Color {
        localRoundResult == .win
            ? BackgammonTheme.cyan
            : BackgammonTheme.purple
    }
}
