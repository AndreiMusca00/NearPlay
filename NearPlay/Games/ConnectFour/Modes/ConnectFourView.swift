//
//  ConnectFourView.swift
//  NearPlay
//
//  Nearby multiplayer adapter.
//

import SwiftUI
import UIKit

struct ConnectFourView: View {
    let game: Game

    @ObservedObject
    var nearbyService: NearbyService

    let localPlayerName: String
    let startPayload: ConnectFourStartPayload
    let onExitToHome: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var controller:
        ConnectFourMatchController

    @StateObject
    private var rematchController:
        RematchController

    @State private var pendingMove = false
    @State private var awaitingRoundReset = false
    @State private var currentRoundNumber = 0

    @State private var showQuitConfirmation = false
    @State private var isQuitting = false
    @State private var showResultOverlay = false

    @State private var feedback:
        ConnectFourFeedbackMessage?

    init(
        game: Game,
        nearbyService: NearbyService,
        localPlayerName: String,
        startPayload: ConnectFourStartPayload,
        onExitToHome: @escaping () -> Void = {}
    ) {
        self.game = game
        self.nearbyService = nearbyService
        self.localPlayerName = localPlayerName
        self.startPayload = startPayload
        self.onExitToHome = onExitToHome

        _controller = StateObject(
            wrappedValue:
                ConnectFourMatchController(
                    playerOneID:
                        startPayload.playerOneID,
                    playerTwoID:
                        startPayload.playerTwoID,
                    initialState:
                        startPayload.initialState
                )
        )

        _rematchController = StateObject(
            wrappedValue: RematchController(
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
                nearbyService: nearbyService
            )
        )
    }

    var body: some View {
        ZStack {
            ConnectFourGameScreen(
                gameTitle: game.title,
                controller: controller,
                firstPlayer:
                    ConnectFourPlayerPresentation(
                        id: localPlayerID,
                        name: localPlayerName,
                        disc: localDisc,
                        inactiveBadge: "YOU"
                    ),
                secondPlayer:
                    ConnectFourPlayerPresentation(
                        id: opponentID,
                        name: opponentName,
                        disc: opponentDisc,
                        inactiveBadge: "OPPONENT"
                    ),
                headerSubtitle:
                    headerSubtitle,
                statusTitle:
                    statusTitle,
                statusSubtitle:
                    statusSubtitle,
                instructionText:
                    "Tap any space in a column to drop one disc.",
                isInteractionEnabled:
                    canPlay,
                showsProgress:
                    pendingMove ||
                    awaitingRoundReset,
                feedback: feedback,
                onColumnSelected:
                    selectColumn,
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
        ) { confirmedRound in
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

    private func selectColumn(
        _ column: Int
    ) {
        guard canPlay,
              !controller
                .state
                .isColumnFull(column) else {
            return
        }

        let payload = ConnectFourMovePayload(
            sessionID:
                startPayload.sessionID,
            playerID: localPlayerID,
            column: column,
            turnID:
                controller.state.turnID
        )

        if isLocalHost {
            resolveMove(
                payload,
                isLocalMove: true
            )
        } else {
            pendingMove = true

            sendPayload(
                payload,
                type: .gameAction
            )
        }
    }

    private func resolveMove(
        _ payload: ConnectFourMovePayload,
        isLocalMove: Bool
    ) {
        guard isLocalHost,
              payload.sessionID ==
                startPayload.sessionID else {
            pendingMove = false
            return
        }

        let result = controller.play(
            column: payload.column,
            by: payload.playerID,
            turnID: payload.turnID
        )

        pendingMove = false

        switch result {
        case .ignored:
            break

        case .columnFull:
            if isLocalMove {
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.warning)
            }

        case .placed:
            UIImpactFeedbackGenerator(
                style:
                    isLocalMove
                    ? .medium
                    : .light
            )
            .impactOccurred()

        case .won:
            UINotificationFeedbackGenerator()
                .notificationOccurred(
                    isLocalMove
                    ? .success
                    : .warning
                )

            showFeedback(
                isLocalMove
                ? "Connect Four!"
                : "Opponent connected four",
                tone:
                    isLocalMove
                    ? .success
                    : .danger
            )

        case .draw:
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)

            showFeedback(
                "Board full — draw",
                tone: .neutral
            )
        }

        broadcastAuthoritativeState()
    }

    private func broadcastAuthoritativeState() {
        guard isLocalHost else {
            return
        }

        sendPayload(
            ConnectFourStatePayload(
                sessionID:
                    startPayload.sessionID,
                roundNumber:
                    currentRoundNumber,
                state: controller.state
            ),
            type: .gameState
        )
    }

    private func applyRemoteState(
        _ newState: ConnectFourGameState,
        roundNumber: Int
    ) {
        guard roundNumber >=
                currentRoundNumber else {
            return
        }

        let previousRoundNumber =
            currentRoundNumber

        let previousLastMove =
            controller.state.lastMove

        let previousWinner =
            controller.state.winnerPlayerID

        currentRoundNumber = roundNumber

        controller.applyRemoteState(
            newState,
            animateLastMove:
                roundNumber ==
                previousRoundNumber
        )

        pendingMove = false
        awaitingRoundReset = false

        if roundNumber ==
            previousRoundNumber,
           newState.lastMove != previousLastMove,
           newState.lastMove != nil {
            let lastDisc =
                newState.lastMove.flatMap {
                    newState.disc(
                        row: $0.row,
                        column: $0.column
                    )
                }

            UIImpactFeedbackGenerator(
                style:
                    lastDisc == localDisc
                    ? .medium
                    : .light
            )
            .impactOccurred()
        }

        if previousWinner == nil,
           let winner =
            newState.winnerPlayerID {
            showFeedback(
                winner == localPlayerID
                ? "Connect Four!"
                : "Opponent connected four",
                tone:
                    winner == localPlayerID
                    ? .success
                    : .danger
            )
        }
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
                  let payload =
                    try? JSONDecoder().decode(
                        ConnectFourMovePayload.self,
                        from: data
                    ) else {
                return
            }

            resolveMove(
                payload,
                isLocalMove: false
            )

        case .gameState:
            guard !isLocalHost,
                  let data = message.payload,
                  let payload =
                    try? JSONDecoder().decode(
                        ConnectFourStatePayload.self,
                        from: data
                    ),
                  payload.sessionID ==
                    startPayload.sessionID else {
                return
            }

            applyRemoteState(
                payload.state,
                roundNumber:
                    payload.roundNumber
            )

        case .gameQuit:
            handleOpponentQuit()

        default:
            break
        }
    }

    // MARK: - Network

    private func sendPayload<T: Encodable>(
        _ payload: T,
        type: NearbyMessageType
    ) {
        do {
            let data = try JSONEncoder()
                .encode(payload)

            nearbyService.send(
                NearbyMessage(
                    gameID: game.id,
                    senderName:
                        localPlayerName,
                    type: type,
                    payload: data
                )
            )
        } catch {
            pendingMove = false
            nearbyService.errorMessage =
                "Failed to synchronize Connect Four."

            print(
                "Connect Four payload encoding failed: \(error)"
            )
        }
    }

    // MARK: - Feedback

    private func showFeedback(
        _ text: String,
        tone: ConnectFourFeedbackTone
    ) {
        feedback = ConnectFourFeedbackMessage(
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

        let data = try? JSONEncoder()
            .encode(payload)

        nearbyService.send(
            NearbyMessage(
                gameID: game.id,
                senderName:
                    localPlayerName,
                type: .gameQuit,
                payload: data
            )
        )

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.35
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
                .fill(
                    ConnectFourTheme.cardBackground
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(
                    ConnectFourTheme.primaryGradient,
                    lineWidth: 1.2
                )
            }
        }
    }

    // MARK: - Presentation

    private var headerSubtitle: String {
        if awaitingRoundReset {
            return "Starting next round…"
        }

        if controller.state.isFinished {
            return "Round complete"
        }

        return isLocalTurn
        ? "Your turn"
        : "\(opponentName)'s turn"
    }

    private var statusTitle: String {
        if awaitingRoundReset {
            return "Preparing the board"
        }

        if pendingMove {
            return "Dropping your disc…"
        }

        if controller.state.isFinished {
            return resultTitle
        }

        return isLocalTurn
        ? "Choose a column"
        : "Waiting for \(opponentName)"
    }

    private var statusSubtitle: String {
        controller.state.isFinished
        ? "Four connected discs end the round."
        : "Connect four horizontally, vertically or diagonally."
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
            return "You connected four discs before \(opponentName)."
        case .loss:
            return "\(opponentName) connected four discs first."
        case .draw:
            return "The board is full and nobody connected four."
        }
    }

    private var resultSymbolName: String {
        switch localRoundResult {
        case .win:
            return "crown.fill"
        case .loss:
            return "circle.grid.3x3.fill"
        case .draw:
            return "equal"
        }
    }

    private var resultAccentColor: Color {
        switch localRoundResult {
        case .win:
            return ConnectFourTheme.cyan
        case .loss:
            return ConnectFourTheme.purple
        case .draw:
            return Color.white.opacity(0.78)
        }
    }

    // MARK: - Identity

    private var localPlayerID: String {
        nearbyService.localPlayerID
    }

    private var opponentID: String {
        startPayload.playerOneID ==
        localPlayerID
        ? startPayload.playerTwoID
        : startPayload.playerOneID
    }

    private var opponentName: String {
        startPayload.playerOneID ==
        localPlayerID
        ? startPayload.playerTwoName
        : startPayload.playerOneName
    }

    private var localDisc: ConnectFourDisc {
        startPayload.playerOneID ==
        localPlayerID
        ? .playerOne
        : .playerTwo
    }

    private var opponentDisc: ConnectFourDisc {
        localDisc == .playerOne
        ? .playerTwo
        : .playerOne
    }

    private var isLocalHost: Bool {
        nearbyService
            .lobbySession?
            .hostPlayerID ==
        localPlayerID
    }

    private var isLocalTurn: Bool {
        controller.state.activePlayerID ==
        localPlayerID
    }

    private var canPlay: Bool {
        isLocalTurn &&
        !pendingMove &&
        !awaitingRoundReset &&
        !controller.state.isFinished
    }
}
