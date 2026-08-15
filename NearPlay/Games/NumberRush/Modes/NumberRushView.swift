import SwiftUI
import UIKit

struct NumberRushView: View {
    let game: Game

    @ObservedObject
    var nearbyService: NearbyService

    let localPlayerName: String
    let startPayload: NumberRushStartPayload
    let onExitToHome: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var controller: NumberRushMatchController

    @StateObject
    private var rematchController: RematchController

    @State private var currentRoundNumber = 1
    @State private var wrongNumber: Int?
    @State private var correctNumber: Int?
    @State private var feedback: NumberRushFeedbackMessage?
    @State private var pendingSelection = false
    @State private var awaitingRoundReset = false

    @State private var showQuitConfirmation = false
    @State private var isQuitting = false
    @State private var showResultOverlay = false

    @State private var timeoutWorkItem: DispatchWorkItem?

    init(
        game: Game,
        nearbyService: NearbyService,
        localPlayerName: String,
        startPayload: NumberRushStartPayload,
        onExitToHome: @escaping () -> Void = {}
    ) {
        self.game = game
        self.nearbyService = nearbyService
        self.localPlayerName = localPlayerName
        self.startPayload = startPayload
        self.onExitToHome = onExitToHome

        _controller = StateObject(
            wrappedValue:
                NumberRushMatchController(
                    playerOneID: startPayload.playerOneID,
                    playerTwoID: startPayload.playerTwoID,
                    shuffledNumbers: startPayload.shuffledNumbers,
                    startingPlayerID: startPayload.startingPlayerID,
                    baseTurnDuration: startPayload.turnDuration
                )
        )

        _rematchController = StateObject(
            wrappedValue:
                RematchController(
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
            NumberRushGameScreen(
                gameTitle: game.title,
                controller: controller,
                firstPlayer:
                    NumberRushPlayerPresentation(
                        id: startPayload.playerOneID,
                        name: startPayload.playerOneName,
                        inactiveBadge: "P1"
                    ),
                secondPlayer:
                    NumberRushPlayerPresentation(
                        id: startPayload.playerTwoID,
                        name: startPayload.playerTwoName,
                        inactiveBadge: "P2"
                    ),
                localPlayerID:
                    localPlayerID,
                headerSubtitle:
                    headerSubtitle,
                statusText:
                    statusText,
                instructionText:
                    statusSubtitle,
                isInteractionEnabled:
                    canPlay,
                showsProgress:
                    pendingSelection || awaitingRoundReset,
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
        .onAppear {
            scheduleHostTimeout()
        }
        .onDisappear {
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
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
            wrongNumber = nil
            correctNumber = nil
            feedback = nil
            pendingSelection = false

            let startingPlayerID =
                confirmedRound.isMultiple(of: 2)
                ? startPayload.playerTwoID
                : startPayload.playerOneID

            if isLocalHost {
                currentRoundNumber = confirmedRound

                controller.reset(
                    shuffledNumbers: Array(1...100).shuffled(),
                    startingPlayerID: startingPlayerID
                )

                awaitingRoundReset = false
                broadcastAuthoritativeState()
                scheduleHostTimeout()
            } else {
                awaitingRoundReset =
                    currentRoundNumber < confirmedRound
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

    // MARK: - Selection

    private func selectNumber(
        _ number: Int
    ) {
        guard canPlay else {
            return
        }

        pendingSelection = true

        let payload = NumberRushSelectionPayload(
            sessionID: startPayload.sessionID,
            playerID: localPlayerID,
            selectedNumber: number,
            turnID: controller.state.turnID
        )

        if isLocalHost {
            resolveSelection(payload)
        } else {
            sendSelection(payload)
        }
    }

    private func sendSelection(
        _ payload: NumberRushSelectionPayload
    ) {
        do {
            let data = try JSONEncoder().encode(payload)

            nearbyService.send(
                NearbyMessage(
                    gameID: game.id,
                    senderName: localPlayerName,
                    type: .gameAction,
                    payload: data
                )
            )
        } catch {
            pendingSelection = false
            nearbyService.errorMessage =
                "Failed to send your number."
        }
    }

    private func resolveSelection(
        _ selection: NumberRushSelectionPayload
    ) {
        guard isLocalHost,
              selection.sessionID == startPayload.sessionID else {
            pendingSelection = false
            return
        }

        let outcome = controller.select(
            number: selection.selectedNumber,
            by: selection.playerID,
            turnID: selection.turnID
        )

        handleOutcome(outcome)
        pendingSelection = false
        broadcastAuthoritativeState()
        scheduleHostTimeout()
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

    // MARK: - Networking state

    private func broadcastAuthoritativeState() {
        guard isLocalHost else {
            return
        }

        let payload = NumberRushStatePayload(
            sessionID: startPayload.sessionID,
            roundNumber: currentRoundNumber,
            state: controller.state
        )

        do {
            let data = try JSONEncoder().encode(payload)

            nearbyService.send(
                NearbyMessage(
                    gameID: game.id,
                    senderName: localPlayerName,
                    type: .gameState,
                    payload: data
                )
            )
        } catch {
            nearbyService.errorMessage =
                "Failed to synchronize Number Rush."
        }
    }

    private func scheduleHostTimeout() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil

        guard isLocalHost,
              !controller.state.isFinished else {
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

            pendingSelection = false
            showFeedback(
                "Time expired — turn switched",
                tone: .neutral
            )
            broadcastAuthoritativeState()
            scheduleHostTimeout()
        }

        timeoutWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: workItem
        )
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
            handleIncomingSelection(message)

        case .gameState:
            handleIncomingState(message)

        case .gameQuit:
            handleOpponentQuit()

        default:
            break
        }
    }

    private func handleIncomingSelection(
        _ message: NearbyMessage
    ) {
        guard isLocalHost,
              let data = message.payload else {
            return
        }

        do {
            let payload = try JSONDecoder().decode(
                NumberRushSelectionPayload.self,
                from: data
            )

            resolveSelection(payload)
        } catch {
            print("Failed to decode NumberRushSelectionPayload: \(error)")
        }
    }

    private func handleIncomingState(
        _ message: NearbyMessage
    ) {
        guard !isLocalHost,
              let data = message.payload else {
            return
        }

        do {
            let payload = try JSONDecoder().decode(
                NumberRushStatePayload.self,
                from: data
            )

            guard payload.sessionID ==
                    startPayload.sessionID else {
                return
            }

            currentRoundNumber = max(
                currentRoundNumber,
                payload.roundNumber
            )

            applyRemoteState(payload.state)
        } catch {
            print("Failed to decode NumberRushStatePayload: \(error)")
        }
    }

    private func applyRemoteState(
        _ newState: NumberRushGameState
    ) {
        let oldTarget = controller.state.targetNumber
        let oldActivePlayer = controller.state.activePlayerID

        withAnimation(
            .spring(
                response: 0.32,
                dampingFraction: 0.80
            )
        ) {
            controller.applyRemoteState(
                newState,
                animate: true
            )
        }

        pendingSelection = false
        awaitingRoundReset = false

        if newState.targetNumber > oldTarget {
            showCorrectFeedback(newState.targetNumber - 1)
        } else if newState.activePlayerID != oldActivePlayer {
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)
        }
    }

    // MARK: - Feedback

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

    // MARK: - Quit

    private func quitGame() {
        guard !isQuitting else {
            return
        }

        isQuitting = true
        timeoutWorkItem?.cancel()

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
            deadline: .now() + 0.4
        ) {
            nearbyService.stop()
            dismiss()
            onExitToHome()
            isQuitting = false
        }
    }

    private func handleOpponentQuit() {
        timeoutWorkItem?.cancel()
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
                .fill(NumberRushTheme.cardBackground)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(
                    NumberRushTheme.primaryGradient,
                    lineWidth: 1.2
                )
            }
        }
    }

    // MARK: - Computed state

    private var localPlayerID: String {
        nearbyService.localPlayerID
    }

    private var isLocalHost: Bool {
        let hostPlayerID =
            nearbyService.lobbySession?.hostPlayerID ??
            startPayload.playerOneID

        return hostPlayerID == localPlayerID
    }

    private var canPlay: Bool {
        !pendingSelection &&
        !awaitingRoundReset &&
        !controller.state.isFinished &&
        controller.state.activePlayerID == localPlayerID
    }

    private var opponentID: String {
        startPayload.playerOneID == localPlayerID
            ? startPayload.playerTwoID
            : startPayload.playerOneID
    }

    private var opponentName: String {
        startPayload.playerOneID == localPlayerID
            ? startPayload.playerTwoName
            : startPayload.playerOneName
    }

    private var headerSubtitle: String {
        if controller.state.isFinished {
            return "Round complete"
        }

        return controller.state.activePlayerID == localPlayerID
            ? "Your turn"
            : "\(opponentName)'s turn"
    }

    private var statusText: String {
        if controller.state.isFinished {
            return resultTitle
        }

        return controller.state.activePlayerID == localPlayerID
            ? "Find \(controller.state.targetNumber)"
            : "Waiting for \(opponentName)"
    }

    private var statusSubtitle: String {
        if awaitingRoundReset {
            return "Starting next round…"
        }

        if pendingSelection {
            return "Sending selection…"
        }

        if controller.state.isFinished {
            return "Round finished"
        }

        return isLocalHost
            ? "Host validates every selection."
            : "Your selections are sent to the host."
    }

    private var localRoundResult: GameRoundResult {
        let localScore =
            controller.state.scores[localPlayerID] ?? 0
        let remoteScore =
            controller.state.scores[opponentID] ?? 0

        if localScore == remoteScore {
            return .draw
        }

        return localScore > remoteScore ? .win : .loss
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
        let localScore =
            controller.state.scores[localPlayerID] ?? 0
        let remoteScore =
            controller.state.scores[opponentID] ?? 0

        return "\(localScore) – \(remoteScore) against \(opponentName)."
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
