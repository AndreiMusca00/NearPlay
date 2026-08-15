import SwiftUI
import UIKit

struct RPSView: View {
    let game: Game

    @ObservedObject
    var nearbyService: NearbyService

    let localPlayerName: String
    let startPayload: RPSStartPayload
    let onExitToHome: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var controller:
        RPSMatchController

    @StateObject
    private var rematchController:
        RematchController

    @State private var pendingChoice = false
    @State private var awaitingRoundReset = false
    @State private var currentRoundNumber = 0

    @State private var showQuitConfirmation = false
    @State private var isQuitting = false
    @State private var showResultOverlay = false

    @State private var feedback:
        RPSFeedbackMessage?

    init(
        game: Game,
        nearbyService: NearbyService,
        localPlayerName: String,
        startPayload: RPSStartPayload,
        onExitToHome: @escaping () -> Void = {}
    ) {
        self.game = game
        self.nearbyService = nearbyService
        self.localPlayerName = localPlayerName
        self.startPayload = startPayload
        self.onExitToHome = onExitToHome

        _controller = StateObject(
            wrappedValue:
                RPSMatchController(
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
            RPSGameScreen(
                gameTitle: game.title,
                controller: controller,
                firstPlayer:
                    RPSPlayerPresentation(
                        id: localPlayerID,
                        name: localPlayerName,
                        inactiveBadge: "YOU"
                    ),
                secondPlayer:
                    RPSPlayerPresentation(
                        id: opponentID,
                        name: opponentName,
                        inactiveBadge: "OPPONENT"
                    ),
                choosingPlayerID:
                    localPlayerID,
                headerSubtitle:
                    headerSubtitle,
                statusTitle:
                    statusTitle,
                statusSubtitle:
                    statusSubtitle,
                instructionText:
                    "Choose rock, paper or scissors. The moves are revealed after both players choose.",
                isInteractionEnabled:
                    canChoose,
                showsProgress:
                    pendingChoice ||
                    awaitingRoundReset,
                hidesLockedChoice: false,
                feedback: feedback,
                onChoiceSelected:
                    selectChoice,
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
            pendingChoice = false
            feedback = nil

            if isLocalHost {
                currentRoundNumber = confirmedRound

                controller.reset()

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

            gameResultHapticIfNeeded()

            try? await Task.sleep(
                nanoseconds: 1_050_000_000
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

    private func selectChoice(
        _ choice: RPSChoice
    ) {
        guard canChoose else {
            return
        }

        if isLocalHost {
            let result = controller.choose(
                choice,
                by: localPlayerID
            )

            handleChoiceResult(
                result,
                playerID: localPlayerID,
                shouldBroadcast:
                    result.didStoreChoice
            )
        } else {
            sendChoiceRequest(choice)
        }
    }

    private func sendChoiceRequest(
        _ choice: RPSChoice
    ) {
        let payload = RPSChoicePayload(
            sessionID: startPayload.sessionID,
            playerID: localPlayerID,
            choice: choice,
            roundID: controller.state.roundID
        )

        do {
            let data = try JSONEncoder().encode(payload)

            let message = NearbyMessage(
                gameID: game.id,
                senderName: localPlayerName,
                type: .gameAction,
                payload: data
            )

            pendingChoice = true
            nearbyService.send(message)
        } catch {
            pendingChoice = false
            print("Failed to encode RPSChoicePayload: \(error)")
        }
    }

    private func handleIncomingChoice(
        _ message: NearbyMessage
    ) {
        guard isLocalHost,
              let data = message.payload else {
            return
        }

        do {
            let payload = try JSONDecoder().decode(
                RPSChoicePayload.self,
                from: data
            )

            guard payload.sessionID ==
                    startPayload.sessionID else {
                return
            }

            let result = controller.choose(
                payload.choice,
                by: payload.playerID,
                roundID: payload.roundID
            )

            handleChoiceResult(
                result,
                playerID: payload.playerID,
                shouldBroadcast:
                    result.didStoreChoice
            )
        } catch {
            print("Failed to decode RPSChoicePayload: \(error)")
        }
    }

    private func handleChoiceResult(
        _ result: RPSMoveResult,
        playerID: String,
        shouldBroadcast: Bool
    ) {
        switch result {
        case .ignored:
            pendingChoice = false

        case .alreadyChosen:
            pendingChoice = false

            if playerID == localPlayerID {
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.warning)
            }

        case .stored:
            pendingChoice = false

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

        case .completed:
            pendingChoice = false

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

        if shouldBroadcast {
            broadcastAuthoritativeState()
        }
    }

    // MARK: - Network state

    private func broadcastAuthoritativeState() {
        let payload = RPSStatePayload(
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
            print("Failed to encode RPSStatePayload: \(error)")
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
                RPSStatePayload.self,
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

            pendingChoice = false
            awaitingRoundReset = false
            feedback = nil

            controller.applyRemoteState(
                payload.state,
                animate: true
            )
        } catch {
            // The message may be a rematch state from another shared flow.
            // Ignore if it is not an RPSStatePayload.
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
            handleIncomingChoice(message)

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
                .fill(RPSTheme.cardBackground)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(
                    RPSTheme.primaryGradient,
                    lineWidth: 1.2
                )
            }
        }
    }

    // MARK: - Feedback

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

    private func gameResultHapticIfNeeded() {
        guard controller.state.isFinished else {
            return
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.05
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

    private var canChoose: Bool {
        !controller.state.isFinished &&
        !pendingChoice &&
        !awaitingRoundReset &&
        controller.choice(for: localPlayerID) == nil
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
        guard let localChoice =
                controller.choice(for: localPlayerID),
              let opponentChoice =
                controller.choice(for: opponentID) else {
            return "The round has ended."
        }

        switch localRoundResult {
        case .win:
            return "\(localChoice.title) beats \(opponentChoice.title)."
        case .loss:
            return "\(opponentChoice.title) beats \(localChoice.title)."
        case .draw:
            return "You both chose \(localChoice.title)."
        }
    }

    private var resultSymbolName: String {
        if controller.state.isDraw {
            return "equal"
        }

        let winningChoice =
            localRoundResult == .win
            ? controller.choice(for: localPlayerID)
            : controller.choice(for: opponentID)

        return winningChoice?.systemName ?? "gamecontroller.fill"
    }

    private var resultAccentColor: Color {
        if controller.state.isDraw {
            return Color.white.opacity(0.78)
        }

        let winningChoice =
            localRoundResult == .win
            ? controller.choice(for: localPlayerID)
            : controller.choice(for: opponentID)

        return RPSTheme.color(for: winningChoice)
    }

    private var headerSubtitle: String {
        if controller.state.isFinished {
            return "Round complete"
        }

        if pendingChoice {
            return "Sending your move"
        }

        if awaitingRoundReset {
            return "Starting next round"
        }

        if controller.choice(for: localPlayerID) != nil {
            return "Waiting for \(opponentName)"
        }

        if controller.choice(for: opponentID) != nil {
            return "\(opponentName) is ready"
        }

        return "Choose your move"
    }

    private var statusTitle: String {
        if controller.state.isFinished {
            return resultTitle
        }

        if pendingChoice {
            return "Sending move"
        }

        if awaitingRoundReset {
            return "Starting next round"
        }

        if controller.choice(for: localPlayerID) != nil {
            return "Choice locked"
        }

        return "Choose your move"
    }

    private var statusSubtitle: String {
        if controller.state.isFinished {
            return "Both choices are revealed."
        }

        if pendingChoice {
            return "Waiting for the host to confirm your move."
        }

        if awaitingRoundReset {
            return "Waiting for the new round state."
        }

        if controller.choice(for: localPlayerID) != nil {
            return "Waiting for \(opponentName) to choose."
        }

        if controller.choice(for: opponentID) != nil {
            return "\(opponentName) has already locked a move."
        }

        return isLocalHost
            ? "Host validates every choice."
            : "Your choice is sent to the host."
    }
}

#Preview {
    Text("RPSView requires an active NearbyService session.")
        .preferredColorScheme(.dark)
}
