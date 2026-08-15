import SwiftUI
import UIKit

struct TicTacToeView: View {
    let game: Game

    @ObservedObject
    var nearbyService: NearbyService

    let localPlayerName: String
    let startPayload: TicTacToeStartPayload
    let onExitToHome: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var controller: TicTacToeMatchController

    @StateObject
    private var rematchController: RematchController

    @State private var pendingMove = false
    @State private var awaitingRoundReset = false
    @State private var currentRoundNumber = 0

    @State private var showQuitConfirmation = false
    @State private var isQuitting = false
    @State private var showResultOverlay = false

    @State private var feedback:
        TicTacToeFeedbackMessage?

    init(
        game: Game,
        nearbyService: NearbyService,
        localPlayerName: String,
        startPayload: TicTacToeStartPayload,
        onExitToHome: @escaping () -> Void = {}
    ) {
        self.game = game
        self.nearbyService = nearbyService
        self.localPlayerName = localPlayerName
        self.startPayload = startPayload
        self.onExitToHome = onExitToHome

        _controller = StateObject(
            wrappedValue:
                TicTacToeMatchController(
                    playerOneID:
                        startPayload.playerOneID,
                    playerTwoID:
                        startPayload.playerTwoID,
                    initialState:
                        startPayload.initialState
                )
        )

        _rematchController = StateObject(
            wrappedValue:
                RematchController(
                    gameID: game.id,
                    sessionID:
                        startPayload.sessionID,
                    localPlayerID:
                        nearbyService.localPlayerID,
                    localPlayerName:
                        localPlayerName,
                    hostPlayerID:
                        nearbyService
                        .lobbySession?
                        .hostPlayerID ??
                        startPayload.playerOneID,
                    nearbyService:
                        nearbyService
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
                        id: localPlayerID,
                        name: localPlayerName,
                        mark: localMark,
                        inactiveBadge: "YOU"
                    ),
                secondPlayer:
                    TicTacToePlayerPresentation(
                        id: opponentID,
                        name: opponentName,
                        mark: opponentMark,
                        inactiveBadge: "OPPONENT"
                    ),
                headerSubtitle:
                    headerSubtitle,
                statusTitle:
                    statusTitle,
                statusSubtitle:
                    statusSubtitle,
                instructionText:
                    "Tap an empty cell when it is your turn.",
                isInteractionEnabled:
                    canPlay,
                showsProgress:
                    pendingMove ||
                    awaitingRoundReset,
                feedback:
                    feedback,
                onCellSelected:
                    selectCell,
                onQuitRequested: {
                    showQuitConfirmation = true
                }
            )

            if controller.state.isFinished &&
                showResultOverlay {
                GameResultOverlay(
                    result: localRoundResult,
                    title: resultTitle,
                    subtitle: resultSubtitle,
                    symbolName: resultSymbolName,
                    accentColor: resultAccentColor,
                    rematchState:
                        rematchController.state,
                    onPrimaryAction: {
                        rematchController
                            .performPrimaryAction()
                    },
                    onQuit:
                        quitGame
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
            Text(
                "You and your opponent will return to the main screen."
            )
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

            showResultOverlay = false
            pendingMove = false
            feedback = nil

            let startingPlayerID =
                confirmedRound.isMultiple(of: 2)
                ? startPayload.playerTwoID
                : startPayload.playerOneID

            if isLocalHost {
                currentRoundNumber = confirmedRound

                controller.reset(
                    startingPlayerID:
                        startingPlayerID
                )

                awaitingRoundReset = false
                broadcastAuthoritativeState()
            } else {
                awaitingRoundReset =
                    currentRoundNumber <
                    confirmedRound
            }

            rematchController.finishStartingRound()
        }
        .task(
            id: controller.state.isFinished
        ) {
            showResultOverlay = false

            guard controller.state.isFinished else {
                return
            }

            try? await Task.sleep(
                nanoseconds: 850_000_000
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

    // MARK: - Moves

    private func selectCell(
        _ index: Int
    ) {
        guard canPlay else {
            return
        }

        if isLocalHost {
            let result = controller.play(
                index: index,
                by: localPlayerID
            )

            handleMoveResult(
                result,
                playerID: localPlayerID,
                shouldBroadcast:
                    result.didPlaceMark
            )
        } else {
            sendMoveRequest(index)
        }
    }

    private func sendMoveRequest(
        _ index: Int
    ) {
        let payload = TicTacToeMovePayload(
            sessionID: startPayload.sessionID,
            playerID: localPlayerID,
            index: index,
            turnID: controller.state.turnID
        )

        do {
            let data = try JSONEncoder().encode(payload)

            let message = NearbyMessage(
                gameID: game.id,
                senderName: localPlayerName,
                type: .gameAction,
                payload: data
            )

            pendingMove = true
            nearbyService.send(message)
        } catch {
            pendingMove = false
            print("Failed to encode TicTacToeMovePayload: \(error)")
        }
    }

    private func handleIncomingMove(
        _ message: NearbyMessage
    ) {
        guard isLocalHost,
              let data = message.payload else {
            return
        }

        do {
            let payload = try JSONDecoder().decode(
                TicTacToeMovePayload.self,
                from: data
            )

            guard payload.sessionID ==
                    startPayload.sessionID else {
                return
            }

            let result = controller.play(
                index: payload.index,
                by: payload.playerID,
                turnID: payload.turnID
            )

            handleMoveResult(
                result,
                playerID: payload.playerID,
                shouldBroadcast:
                    result.didPlaceMark
            )
        } catch {
            print("Failed to decode TicTacToeMovePayload: \(error)")
        }
    }

    private func handleMoveResult(
        _ result: TicTacToeMoveResult,
        playerID: String,
        shouldBroadcast: Bool
    ) {
        switch result {
        case .ignored:
            pendingMove = false

        case .occupied:
            pendingMove = false

            if playerID == localPlayerID {
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.warning)
            }

        case .placed:
            pendingMove = false

            if playerID == localPlayerID {
                UIImpactFeedbackGenerator(
                    style: .medium
                )
                .impactOccurred()
            } else {
                UIImpactFeedbackGenerator(
                    style: .soft
                )
                .impactOccurred()
            }

        case .won:
            pendingMove = false

            UINotificationFeedbackGenerator()
                .notificationOccurred(
                    playerID == localPlayerID
                    ? .success
                    : .warning
                )

            showFeedback(
                playerID == localPlayerID
                ? "You won the round!"
                : "\(opponentName) won the round.",
                tone:
                    playerID == localPlayerID
                    ? .success
                    : .danger
            )

        case .draw:
            pendingMove = false

            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)

            showFeedback(
                "The round ended in a draw.",
                tone: .neutral
            )
        }

        if shouldBroadcast {
            broadcastAuthoritativeState()
        }
    }

    // MARK: - Networking state

    private func broadcastAuthoritativeState() {
        let payload = TicTacToeStatePayload(
            sessionID: startPayload.sessionID,
            roundNumber: currentRoundNumber,
            state: controller.state
        )

        do {
            let data = try JSONEncoder().encode(payload)

            let message = NearbyMessage(
                gameID: game.id,
                senderName: localPlayerName,
                type: .gameState,
                payload: data
            )

            nearbyService.send(message)
        } catch {
            print("Failed to encode TicTacToeStatePayload: \(error)")
        }
    }

    private func handleIncomingState(
        _ message: NearbyMessage
    ) {
        guard let data = message.payload else {
            return
        }

        do {
            let payload = try JSONDecoder().decode(
                TicTacToeStatePayload.self,
                from: data
            )

            guard payload.sessionID ==
                    startPayload.sessionID else {
                return
            }

            currentRoundNumber =
                max(
                    currentRoundNumber,
                    payload.roundNumber
                )

            pendingMove = false
            awaitingRoundReset = false
            feedback = nil

            controller.applyRemoteState(
                payload.state,
                animateLastMove: true
            )

            gameResultHapticIfNeeded()
        } catch {
            // This may be a rematch message handled by RematchController.
            // Ignore if it is not a TicTacToeStatePayload.
        }
    }

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
            handleIncomingMove(message)

        case .gameState:
            handleIncomingState(message)

        case .gameQuit:
            handleOpponentQuit()

        default:
            break
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

        let message = NearbyMessage(
            gameID: game.id,
            senderName: localPlayerName,
            type: .gameQuit,
            payload: data
        )

        nearbyService.send(message)

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.4
        ) {
            nearbyService.stop()
            dismiss()
            onExitToHome()
            isQuitting = false
        }
    }

    private func handleOpponentQuit() {
        nearbyService.stop()
        dismiss()
        onExitToHome()
    }

    private var quittingOverlay: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.15)

                Text("Leaving game…")
                    .font(
                        .system(
                            size: 16,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .background {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .fill(TicTacToeTheme.cardBackground)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(
                    TicTacToeTheme.primaryGradient,
                    lineWidth: 1.2
                )
            }
        }
    }

    // MARK: - Feedback

    private func showFeedback(
        _ text: String,
        tone: TicTacToeFeedbackTone
    ) {
        feedback = TicTacToeFeedbackMessage(
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

    private func gameResultHapticIfNeeded() {
        guard controller.state.isFinished else {
            return
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.15
        ) {
            switch localRoundResult {
            case .win:
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.success)
            case .loss:
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.warning)
            case .draw:
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.warning)
            }
        }
    }

    // MARK: - Computed state

    private var localPlayerID: String {
        nearbyService.localPlayerID
    }

    private var opponentID: String {
        localPlayerID == startPayload.playerOneID
        ? startPayload.playerTwoID
        : startPayload.playerOneID
    }

    private var localMark: TicTacToeMark {
        controller.mark(for: localPlayerID) ?? .x
    }

    private var opponentMark: TicTacToeMark {
        controller.mark(for: opponentID) ?? .o
    }

    private var opponentName: String {
        localPlayerID == startPayload.playerOneID
        ? startPayload.playerTwoName
        : startPayload.playerOneName
    }

    private var isLocalHost: Bool {
        let hostPlayerID =
            nearbyService.lobbySession?.hostPlayerID ??
            startPayload.playerOneID

        return hostPlayerID == localPlayerID
    }

    private var canPlay: Bool {
        !controller.state.isFinished &&
        !pendingMove &&
        !awaitingRoundReset &&
        controller.state.activePlayerID == localPlayerID
    }

    private var localRoundResult: GameRoundResult {
        if controller.state.isDraw {
            return .draw
        }

        return controller.state.winnerPlayerID ==
            localPlayerID
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
        switch localRoundResult {
        case .win:
            return "Great game, \(localPlayerName)."
        case .loss:
            return "Better luck in the next round."
        case .draw:
            return "Nobody won this round."
        }
    }

    private var resultSymbolName: String {
        if controller.state.isDraw {
            return "equal"
        }

        guard let winnerID =
                controller.state.winnerPlayerID,
              let mark =
                controller.mark(for: winnerID) else {
            return "gamecontroller.fill"
        }

        return mark.systemName
    }

    private var resultAccentColor: Color {
        guard let winnerID =
                controller.state.winnerPlayerID,
              let mark =
                controller.mark(for: winnerID) else {
            return Color.white.opacity(0.78)
        }

        return TicTacToeTheme.color(for: mark)
    }

    private var headerSubtitle: String {
        if controller.state.isDraw {
            return "Round draw"
        }

        if let winnerID =
            controller.state.winnerPlayerID {
            return winnerID == localPlayerID
                ? "You win"
                : "\(opponentName) wins"
        }

        return canPlay
            ? "Your turn"
            : "\(opponentName)'s turn"
    }

    private var statusTitle: String {
        if controller.state.isFinished {
            return resultTitle
        }

        return canPlay
            ? "Your move"
            : "Waiting for \(opponentName)"
    }

    private var statusSubtitle: String {
        if awaitingRoundReset {
            return "Starting next round…"
        }

        if pendingMove {
            return "Sending move…"
        }

        if controller.state.isFinished {
            return "Round finished"
        }

        return isLocalHost
            ? "Host validates every move."
            : "Your moves are sent to the host."
    }
}

#Preview {
    Text("TicTacToeView requires an active NearbyService session.")
        .preferredColorScheme(.dark)
}
