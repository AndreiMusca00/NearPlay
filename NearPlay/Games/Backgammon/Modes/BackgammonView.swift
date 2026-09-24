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
                initialState: startPayload.initialState
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
            BackgammonGameScreen(
                gameTitle: game.title,
                state: controller.state,
                playerOneID: startPayload.playerOneID,
                playerOneName: startPayload.playerOneName,
                playerTwoID: startPayload.playerTwoID,
                playerTwoName: startPayload.playerTwoName,
                selectedSource: selectedSource,
                legalMoves: localLegalMoves,
                interactionPlayer: localPlayer,
                isInteractionEnabled: canPlay,
                showsProgress: pendingAction || awaitingRoundReset,
                statusTitle: statusTitle,
                statusSubtitle: statusSubtitle,
                onRoll: rollDice,
                onPointTap: handlePointTap,
                onBarTap: selectBar,
                onMove: { source, destination in
                    guard canPlay else { return }
                    submitMove(
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
        .onAppear {
            OrientationManager.shared.lockToLandscape()
        }
        .onDisappear {
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

    private func rollDice() {
        guard canPlay,
              controller.state.dice.isEmpty else {
            return
        }

        selectedSource = nil

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
        guard canPlay else {
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

            if localLegalMoves.contains(where: {
                $0.source == sourceIndex &&
                $0.destination == index
            }) {
                submitMove(
                    source: sourceIndex,
                    destination: index
                )
                return
            }
        }

        guard localLegalMoves.contains(where: {
            $0.source == index
        }) else {
            selectedSource = nil
            return
        }

        selectedSource = .point(index)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func selectBar() {
        guard canPlay,
              localLegalMoves.contains(where: {
                  $0.source == nil
              }) else {
            return
        }

        selectedSource = .bar
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func bearOff() {
        guard canPlay,
              case .point(let source)? = selectedSource,
              localLegalMoves.contains(where: {
                  $0.source == source &&
                  $0.destination == nil
              }) else {
            return
        }

        submitMove(source: source, destination: nil)
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
        }

        pendingAction = false
        broadcastAuthoritativeState()
    }

    private func broadcastAuthoritativeState() {
        guard isLocalHost else {
            return
        }

        sendPayload(
            BackgammonStatePayload(
                sessionID: startPayload.sessionID,
                roundNumber: currentRoundNumber,
                state: controller.state
            ),
            type: .gameState
        )
    }

    private func applyRemoteState(
        _ newState: BackgammonGameState,
        roundNumber: Int
    ) {
        guard roundNumber >= currentRoundNumber else {
            return
        }

        currentRoundNumber = roundNumber
        controller.applyRemoteState(newState)
        selectedSource = nil
        pendingAction = false
        awaitingRoundReset = false
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
                roundNumber: payload.roundNumber
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
        !awaitingRoundReset
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
            return controller.state.dice.isEmpty
                ? "Roll the dice"
                : "Make your move"
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

        return "Moves are validated by the NearPlay host."
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
