import Combine
import SwiftUI
import UIKit

struct SwipeRushView: View {
    let game: Game
    @ObservedObject var nearbyService: NearbyService
    let localPlayerName: String
    let startPayload: SwipeRushStartPayload
    let onExitToHome: (NearbyGameExitReason) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var rematchController: RematchController
    @State private var state: SwipeRushMatchState
    @State private var localProgress: SwipeRushPlayerProgress
    @State private var handledEvents: Set<UUID> = []

    @State private var now = Date()
    @State private var promptStartedAt: Date?
    @State private var promptDeadline: Date?

    @State private var feedbackText: String?
    @State private var feedbackColor = SwipeRushTheme.magenta
    @State private var feedbackToken: UUID?
    @State private var showQuitConfirmation = false
    @State private var showResult = false
    @State private var isQuitting = false
    @State private var sessionScore = GameSessionScore()
    @State private var scoreRoundNumber = 1

    private let frameTimer = Timer.publish(
        every: 1.0 / 30.0,
        on: .main,
        in: .common
    ).autoconnect()

    init(
        game: Game,
        nearbyService: NearbyService,
        localPlayerName: String,
        startPayload: SwipeRushStartPayload,
        onExitToHome: @escaping (NearbyGameExitReason) -> Void = { _ in }
    ) {
        self.game = game
        self.nearbyService = nearbyService
        self.localPlayerName = localPlayerName
        self.startPayload = startPayload
        self.onExitToHome = onExitToHome

        var prepared = startPayload.initialState
        prepared.progress[startPayload.playerOneID] =
            prepared.progress[startPayload.playerOneID] ?? SwipeRushPlayerProgress()
        prepared.progress[startPayload.playerTwoID] =
            prepared.progress[startPayload.playerTwoID] ?? SwipeRushPlayerProgress()
        _state = State(initialValue: prepared)
        _localProgress = State(
            initialValue: prepared.progress(for: nearbyService.localPlayerID)
        )
        _rematchController = StateObject(wrappedValue: RematchController(
            gameID: game.id,
            sessionID: startPayload.sessionID,
            localPlayerID: nearbyService.localPlayerID,
            localPlayerName: localPlayerName,
            hostPlayerID: nearbyService.lobbySession?.hostPlayerID ?? startPayload.playerOneID,
            nearbyService: nearbyService
        ))
    }

    var body: some View {
        ZStack {
            SwipeRushTheme.background.ignoresSafeArea()

            VStack(spacing: 12) {
                header
                playerCards
                instructionCard
                arena.frame(maxHeight: .infinity)
                footer
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 13)

            if let feedbackText, hasRoundStarted, !localProgress.isFinished {
                feedbackBanner(text: feedbackText, color: feedbackColor)
                    .zIndex(12)
                    .transition(.scale(scale: 0.82).combined(with: .opacity))
            }

            if showResult { resultOverlay.zIndex(20) }

            if isQuitting {
                Color.black.opacity(0.72)
                    .ignoresSafeArea()
                    .overlay(ProgressView("Leaving match…").tint(.white))
                    .zIndex(30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .alert("Quit Swipe Rush?", isPresented: $showQuitConfirmation) {
            Button("Quit Game", role: .destructive, action: quitGame)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You and your opponent will return to the game list.")
        }
        .onAppear { resetRuntimeForRound() }
        .onReceive(frameTimer, perform: tick)
        .onReceive(nearbyService.$lastReceivedMessage) { handleIncoming($0) }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { now = Date() }
        }
        .onChange(of: state.roundID) { _, _ in
            resetRuntimeForRound()
            showResult = false
        }
        .onChange(of: rematchController.confirmedRoundNumber) { _, confirmedRound in
            guard let confirmedRound else { return }
            scoreRoundNumber = confirmedRound
            showResult = false

            if isHost {
                state = SwipeRushGame.makeInitialState(
                    playerOneID: startPayload.playerOneID,
                    playerTwoID: startPayload.playerTwoID
                )
                handledEvents.removeAll()
                broadcastState()
            }
            rematchController.finishStartingRound()
        }
        .task(id: state.isFinished) {
            showResult = false
            guard state.isFinished else { return }
            sessionScore.record(localResult: localRoundResult, roundNumber: scoreRoundNumber)
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled, state.isFinished else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                showResult = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { showQuitConfirmation = true } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white.opacity(0.07)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(game.title.uppercased())
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.white)
                Text(statusText)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(localColor)
            }

            Spacer()

            HStack(spacing: 7) {
                Circle().fill(Color.green).frame(width: 7, height: 7).shadow(color: .green, radius: 4)
                Text(formatRemainingTime)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(remainingTime <= 10 && hasRoundStarted ? SwipeRushTheme.magenta : .white)
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background(Capsule().fill(.white.opacity(0.07)))
            .overlay(Capsule().stroke(localColor.opacity(0.25), lineWidth: 1))
        }
        .padding(.top, 5)
    }

    private var playerCards: some View {
        HStack(spacing: 9) {
            playerCard(name: localPlayerName, label: "YOU", progress: localProgress, color: localColor)
            playerCard(name: opponentName, label: "RIVAL", progress: opponentProgress, color: opponentColor)
        }
    }

    private func playerCard(
        name: String,
        label: String,
        progress: SwipeRushPlayerProgress,
        color: Color
    ) -> some View {
        VStack(spacing: 7) {
            PlayerCardHeading(name: name, badge: label, color: color, fontSize: 12)

            HStack(alignment: .firstTextBaseline) {
                Text("\(progress.score)")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(progress.completedSwipes) SWIPES")
                    Text("×\(progress.bestCombo) BEST COMBO")
                }
                .font(.system(size: 7, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 75)
        .background(RoundedRectangle(cornerRadius: 17).fill(color.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(color.opacity(0.18), lineWidth: 1))
    }

    private var instructionCard: some View {
        let direction = currentTarget.direction
        let color = SwipeRushTheme.color(for: direction)

        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 43, height: 43)
                Image(systemName: direction.symbolName)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(hasRoundStarted ? "SWIPE \(direction.title)" : "SAME ARROWS · SAME TIME")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("React faster and outscore \(opponentName).")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.40))
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                Text("×\(localProgress.combo)")
                    .monospacedDigit()
            }
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(localProgress.combo >= 4 ? SwipeRushTheme.lime : localColor)
        }
        .padding(.horizontal, 13)
        .frame(height: 64)
        .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var arena: some View {
        ZStack {
            SwipeRushArena(
                target: currentTarget,
                targetSize: CGFloat(SwipeRushGame.targetSize(after: localProgress.completedSwipes)),
                timeProgress: promptTimeProgress,
                accentColor: localColor,
                isActive: hasRoundStarted && !localProgress.isFinished && !state.isFinished,
                onSwipe: handleSwipe,
                onInvalidSwipe: { registerMistake(message: "START ON THE ARROW") }
            )

            if !hasRoundStarted, !state.isFinished {
                countdownOverlay
            } else if localProgress.isFinished, !state.isFinished {
                waitingOverlay
            }
        }
        .frame(minHeight: 330)
    }

    private var countdownOverlay: some View {
        VStack(spacing: 9) {
            Text("\(countdownValue)")
                .font(.system(size: 66, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: localColor, radius: 20)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeInOut(duration: 0.28), value: countdownValue)
            Text("BOTH PLAYERS START TOGETHER")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var waitingOverlay: some View {
        VStack(spacing: 13) {
            ProgressView().tint(localColor).scaleEffect(1.2)
            Text("TIME'S UP")
                .font(.system(size: 25, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Waiting for \(opponentName)'s final score…")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope").foregroundStyle(localColor)
            Text("Swipe from the target · wrong direction costs 3")
            Spacer()
            Text("LIVE MATCH").foregroundStyle(Color.green.opacity(0.76))
        }
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .foregroundStyle(.white.opacity(0.46))
        .padding(.horizontal, 3)
    }

    private func feedbackBanner(text: String, color: Color) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .frame(height: 52)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(color.opacity(0.62), lineWidth: 1.3))
                .shadow(color: color.opacity(0.45), radius: 18)
                .padding(.bottom, 45)
        }
        .allowsHitTesting(false)
    }

    private var resultOverlay: some View {
        GameResultOverlay(
            result: localRoundResult,
            title: resultTitle,
            subtitle: "\(localPlayerName): \(finalLocalProgress.score) · \(opponentName): \(finalOpponentProgress.score)",
            symbolName: state.isDraw ? "equal.circle.fill" : (didLocalPlayerWin ? "trophy.fill" : "hand.draw.fill"),
            accentColor: state.isDraw ? SwipeRushTheme.violet : (didLocalPlayerWin ? localColor : opponentColor),
            firstPlayerName: localPlayerName,
            secondPlayerName: opponentName,
            sessionScore: sessionScore,
            rematchState: rematchController.state,
            onPrimaryAction: rematchController.performPrimaryAction,
            onQuit: quitGame
        )
    }

    private func tick(_ date: Date) {
        now = date
        guard !state.isFinished, hasRoundStarted, !localProgress.isFinished else { return }

        if remainingTime <= 0 {
            finishLocalRun()
        } else if let promptDeadline, date >= promptDeadline {
            registerMistake(message: "TOO SLOW")
        }
    }

    private func handleSwipe(_ direction: SwipeRushDirection) {
        let eventDate = Date()
        now = eventDate
        guard hasRoundStarted,
              !state.isFinished,
              !localProgress.isFinished,
              remainingTime > 0 else { return }

        guard direction == currentTarget.direction else {
            registerMistake(message: "WRONG DIRECTION")
            return
        }

        let reactionTime = max(0, eventDate.timeIntervalSince(promptStartedAt ?? eventDate))
        localProgress.combo += 1
        localProgress.bestCombo = max(localProgress.bestCombo, localProgress.combo)
        let points = SwipeRushGame.points(reactionTime: reactionTime, combo: localProgress.combo)
        localProgress.score += points
        localProgress.completedSwipes += 1
        localProgress.totalReactionTime += reactionTime
        advancePrompt(at: eventDate)
        showFeedback("PERFECT +\(points) · ×\(localProgress.combo)", color: SwipeRushTheme.cyan)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.65)
        publishLocalProgress()
    }

    private func registerMistake(message: String) {
        guard hasRoundStarted,
              !state.isFinished,
              !localProgress.isFinished,
              remainingTime > 0 else { return }
        localProgress.mistakes += 1
        localProgress.combo = 0
        localProgress.score = max(0, localProgress.score - SwipeRushGame.mistakePenalty)
        advancePrompt(at: Date())
        showFeedback("−\(SwipeRushGame.mistakePenalty) · \(message)", color: SwipeRushTheme.orange)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        publishLocalProgress()
    }

    private func advancePrompt(at date: Date) {
        localProgress.challengeIndex += 1
        promptStartedAt = date
        promptDeadline = date.addingTimeInterval(promptTimeLimit)
    }

    private func finishLocalRun() {
        guard !localProgress.isFinished else { return }
        localProgress.isFinished = true
        feedbackText = nil
        publishLocalProgress()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func publishLocalProgress() {
        if isHost {
            state.progress[localPlayerID] = localProgress
            finalizeRoundIfPossible()
            broadcastState()
            return
        }

        let payload = SwipeRushProgressPayload(
            sessionID: startPayload.sessionID,
            roundID: state.roundID,
            eventID: UUID(),
            playerID: localPlayerID,
            progress: localProgress
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        nearbyService.send(NearbyMessage(
            gameID: game.id,
            senderName: localPlayerName,
            type: .gameAction,
            payload: data,
            coalescingKey: "swipe-rush-progress-\(state.roundID.uuidString)-\(localPlayerID)"
        ))
    }

    private func handleIncoming(_ message: NearbyMessage?) {
        guard let message, message.gameID == game.id else { return }
        if rematchController.handleIncoming(message) { return }

        switch message.type {
        case .gameAction:
            guard isHost,
                  let data = message.payload,
                  let payload = try? JSONDecoder().decode(SwipeRushProgressPayload.self, from: data),
                  payload.sessionID == startPayload.sessionID,
                  payload.roundID == state.roundID,
                  payload.playerID == opponentID,
                  handledEvents.insert(payload.eventID).inserted else { return }
            applyRemoteProgress(payload.progress, playerID: payload.playerID)

        case .gameState:
            guard !isHost,
                  let data = message.payload,
                  let payload = try? JSONDecoder().decode(SwipeRushStatePayload.self, from: data),
                  payload.sessionID == startPayload.sessionID else { return }
            state = payload.state

        case .gameQuit:
            opponentQuit()

        default:
            break
        }
    }

    private func applyRemoteProgress(_ incoming: SwipeRushPlayerProgress, playerID: String) {
        let current = state.progress(for: playerID)
        guard incoming.challengeIndex >= current.challengeIndex,
              incoming.completedSwipes >= current.completedSwipes,
              incoming.mistakes >= current.mistakes,
              incoming.score >= 0 else { return }

        state.progress[playerID] = incoming
        finalizeRoundIfPossible()
        broadcastState()
    }

    private func finalizeRoundIfPossible() {
        guard isHost, !state.isFinished else { return }
        let first = state.progress(for: startPayload.playerOneID)
        let second = state.progress(for: startPayload.playerTwoID)
        guard first.isFinished, second.isFinished else { return }

        let winner = SwipeRushGame.winner(
            firstPlayerID: startPayload.playerOneID,
            first: first.result,
            secondPlayerID: startPayload.playerTwoID,
            second: second.result
        )
        state.winnerPlayerID = winner
        state.isDraw = winner == nil
    }

    private func broadcastState() {
        let payload = SwipeRushStatePayload(sessionID: startPayload.sessionID, state: state)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        nearbyService.send(NearbyMessage(
            gameID: game.id,
            senderName: localPlayerName,
            type: .gameState,
            payload: data,
            coalescingKey: "swipe-rush-state-\(state.roundID.uuidString)"
        ))
    }

    private func resetRuntimeForRound() {
        localProgress = state.progress(for: localPlayerID)
        now = Date()
        promptStartedAt = state.startsAt
        promptDeadline = state.startsAt.addingTimeInterval(promptTimeLimit)
        feedbackText = nil
        feedbackToken = nil
    }

    private func showFeedback(_ text: String, color: Color) {
        let token = UUID()
        feedbackToken = token
        feedbackColor = color
        withAnimation(.spring(response: 0.30, dampingFraction: 0.76)) { feedbackText = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.68) {
            guard feedbackToken == token else { return }
            withAnimation(.easeOut(duration: 0.18)) { feedbackText = nil }
        }
    }

    private func quitGame() {
        guard !isQuitting else { return }
        isQuitting = true
        nearbyService.send(NearbyMessage(gameID: game.id, senderName: localPlayerName, type: .gameQuit))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            nearbyService.stop()
            onExitToHome(.localPlayerQuit)
            isQuitting = false
        }
    }

    private func opponentQuit() {
        nearbyService.stop()
        onExitToHome(.opponentQuit(playerName: opponentName))
    }

    private var currentTarget: SwipeRushTarget {
        SwipeRushGame.target(seed: state.targetSeed, index: localProgress.challengeIndex)
    }

    private var localPlayerID: String { nearbyService.localPlayerID }

    private var opponentID: String {
        localPlayerID == startPayload.playerOneID ? startPayload.playerTwoID : startPayload.playerOneID
    }

    private var opponentName: String {
        localPlayerID == startPayload.playerOneID ? startPayload.playerTwoName : startPayload.playerOneName
    }

    private var isHost: Bool {
        (nearbyService.lobbySession?.hostPlayerID ?? startPayload.playerOneID) == localPlayerID
    }

    private var localColor: Color {
        localPlayerID == startPayload.playerOneID ? SwipeRushTheme.magenta : SwipeRushTheme.cyan
    }

    private var opponentColor: Color {
        localPlayerID == startPayload.playerOneID ? SwipeRushTheme.cyan : SwipeRushTheme.magenta
    }

    private var opponentProgress: SwipeRushPlayerProgress { state.progress(for: opponentID) }
    private var finalLocalProgress: SwipeRushPlayerProgress { state.progress(for: localPlayerID) }
    private var finalOpponentProgress: SwipeRushPlayerProgress { state.progress(for: opponentID) }

    private var promptTimeLimit: TimeInterval {
        SwipeRushGame.promptTimeLimit(after: localProgress.completedSwipes)
    }

    private var promptTimeProgress: Double {
        guard hasRoundStarted, let promptDeadline else { return 1 }
        return max(0, min(1, promptDeadline.timeIntervalSince(now) / promptTimeLimit))
    }

    private var hasRoundStarted: Bool { now >= state.startsAt }

    private var remainingTime: TimeInterval {
        guard hasRoundStarted else { return SwipeRushGame.runDuration }
        return max(0, SwipeRushGame.runDuration - now.timeIntervalSince(state.startsAt))
    }

    private var formatRemainingTime: String { String(format: "%04.1f", remainingTime) }
    private var countdownValue: Int { min(3, max(1, Int(ceil(state.startsAt.timeIntervalSince(now))))) }
    private var didLocalPlayerWin: Bool { state.winnerPlayerID == localPlayerID }

    private var localRoundResult: GameRoundResult {
        if state.isDraw { return .draw }
        return didLocalPlayerWin ? .win : .loss
    }

    private var resultTitle: String {
        if state.isDraw { return "It's a Tie!" }
        return didLocalPlayerWin ? "You Win!" : "\(opponentName) Wins"
    }

    private var statusText: String {
        if state.isFinished { return "MATCH COMPLETE" }
        if !hasRoundStarted { return "GET READY · LIVE DUEL" }
        if localProgress.isFinished { return "WAITING FOR RIVAL" }
        return "SWIPE \(localProgress.completedSwipes + 1) · LIVE DUEL"
    }
}
