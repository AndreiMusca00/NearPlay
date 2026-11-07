import Combine
import SwiftUI
import UIKit

struct TapFrenzyView: View {
    let game: Game
    @ObservedObject var nearbyService: NearbyService
    let localPlayerName: String
    let startPayload: TapFrenzyStartPayload
    let onExitToHome: (NearbyGameExitReason) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var rematchController: RematchController
    @State private var state: TapFrenzyMatchState
    @State private var localProgress: TapFrenzyPlayerProgress
    @State private var targets: [TapFrenzyTarget] = []
    @State private var relocationRound = 0
    @State private var handledEvents: Set<UUID> = []

    @State private var now = Date()
    @State private var sequenceStartedAt: Date?
    @State private var nextRelocationAt: Date?

    @State private var feedbackText: String?
    @State private var feedbackColor = TapFrenzyTheme.coral
    @State private var feedbackToken: UUID?
    @State private var wrongTargetNumber: Int?
    @State private var targetPulse = false

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
        startPayload: TapFrenzyStartPayload,
        onExitToHome: @escaping (NearbyGameExitReason) -> Void = { _ in }
    ) {
        self.game = game
        self.nearbyService = nearbyService
        self.localPlayerName = localPlayerName
        self.startPayload = startPayload
        self.onExitToHome = onExitToHome

        var prepared = startPayload.initialState
        prepared.progress[startPayload.playerOneID] =
            prepared.progress[startPayload.playerOneID] ?? TapFrenzyPlayerProgress()
        prepared.progress[startPayload.playerTwoID] =
            prepared.progress[startPayload.playerTwoID] ?? TapFrenzyPlayerProgress()
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
            TapFrenzyTheme.background.ignoresSafeArea()

            VStack(spacing: 12) {
                header
                playerCards
                instructionCard
                arena.frame(maxHeight: .infinity)
                speedFooter
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 13)

            if let feedbackText, hasRoundStarted, !localProgress.isFinished {
                feedbackBanner(text: feedbackText, color: feedbackColor)
                    .zIndex(12)
                    .transition(.scale(scale: 0.82).combined(with: .opacity))
            }

            if showResult {
                resultOverlay.zIndex(20)
            }

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
        .alert("Quit Tap Frenzy?", isPresented: $showQuitConfirmation) {
            Button("Quit Game", role: .destructive, action: quitGame)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You and your opponent will return to the game list.")
        }
        .onAppear {
            resetRuntimeForRound()
            targetPulse = true
        }
        .onReceive(frameTimer, perform: tick)
        .onReceive(nearbyService.$lastReceivedMessage) { handleIncoming($0) }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                now = Date()
            }
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
                state = TapFrenzyGame.makeInitialState(
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
            sessionScore.record(
                localResult: localRoundResult,
                roundNumber: scoreRoundNumber
            )
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
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                    .shadow(color: .green, radius: 4)
                Text(formatRemainingTime)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(remainingTime <= 10 && hasRoundStarted ? TapFrenzyTheme.coral : .white)
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background(Capsule().fill(.white.opacity(0.07)))
            .overlay(Capsule().stroke(localColor.opacity(0.25), lineWidth: 1))
        }
        .padding(.top, 5)
    }

    private var playerCards: some View {
        HStack(spacing: 9) {
            playerCard(
                name: localPlayerName,
                label: "YOU",
                progress: localProgress,
                color: localColor
            )
            playerCard(
                name: opponentName,
                label: "RIVAL",
                progress: opponentProgress,
                color: opponentColor
            )
        }
    }

    private func playerCard(
        name: String,
        label: String,
        progress: TapFrenzyPlayerProgress,
        color: Color
    ) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                    .shadow(color: color, radius: 5)
                Text(name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.34))
            }

            HStack(alignment: .firstTextBaseline) {
                Text("\(progress.score)")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(progress.completedSequences) SEQUENCES")
                    Text("\(progress.mistakes) MISTAKES")
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
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(targetColor(localProgress.expectedNumber).opacity(0.15))
                    .frame(width: 43, height: 43)
                Text("\(localProgress.expectedNumber)")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(targetColor(localProgress.expectedNumber))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(hasRoundStarted ? "TAP NUMBER \(localProgress.expectedNumber)" : "SAME TARGETS · SAME TIME")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Finish more sequences than \(opponentName).")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.40))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(localColor)
        }
        .padding(.horizontal, 13)
        .frame(height: 64)
        .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var arena: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.085, green: 0.035, blue: 0.13),
                            Color(red: 0.025, green: 0.09, blue: 0.11)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                arenaGlow(size: proxy.size)

                if hasRoundStarted, !localProgress.isFinished, !state.isFinished {
                    ForEach(activeTargets) { target in
                        targetButton(target)
                            .position(
                                x: proxy.size.width * target.x,
                                y: proxy.size.height * target.y
                            )
                            .transition(.scale(scale: 0.45).combined(with: .opacity))
                    }
                }

                if !hasRoundStarted, !state.isFinished {
                    countdownOverlay
                } else if localProgress.isFinished, !state.isFinished {
                    waitingOverlay
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .animation(.spring(response: 0.34, dampingFraction: 0.72), value: relocationRound)
            .animation(.spring(response: 0.27, dampingFraction: 0.74), value: localProgress.expectedNumber)
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(localColor.opacity(0.24), lineWidth: 1.2)
            )
        }
        .frame(minHeight: 330)
    }

    private func arenaGlow(size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(TapFrenzyTheme.coral.opacity(0.08))
                .frame(width: size.width * 0.65, height: size.width * 0.65)
                .blur(radius: 35)
                .offset(x: -size.width * 0.25, y: -size.height * 0.24)
            Circle()
                .fill(TapFrenzyTheme.cyan.opacity(0.07))
                .frame(width: size.width * 0.70, height: size.width * 0.70)
                .blur(radius: 38)
                .offset(x: size.width * 0.28, y: size.height * 0.28)
        }
        .allowsHitTesting(false)
    }

    private func targetButton(_ target: TapFrenzyTarget) -> some View {
        let color = targetColor(target.number)
        let isExpected = target.number == localProgress.expectedNumber
        let isWrong = wrongTargetNumber == target.number
        let size = CGFloat(TapFrenzyGame.targetSize(after: localProgress.completedSequences))

        return Button { tap(target.number) } label: {
            ZStack {
                if isExpected {
                    Circle()
                        .stroke(color.opacity(0.34), lineWidth: 2)
                        .frame(width: size + 15, height: size + 15)
                        .scaleEffect(targetPulse ? 1.09 : 0.91)
                        .opacity(targetPulse ? 0.25 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.72).repeatForever(autoreverses: true),
                            value: targetPulse
                        )
                }

                Circle()
                    .fill(RadialGradient(
                        colors: [.white.opacity(0.94), isWrong ? Color.red : color],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: size * 0.65
                    ))
                    .frame(width: size, height: size)
                Circle()
                    .stroke(.white.opacity(0.62), lineWidth: 1.2)
                    .frame(width: size, height: size)
                Text("\(target.number)")
                    .font(.system(size: max(18, size * 0.37), weight: .black, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.72))
            }
            .contentShape(Circle())
            .scaleEffect(isWrong ? 0.86 : 1)
            .shadow(color: (isWrong ? Color.red : color).opacity(0.58), radius: isExpected ? 14 : 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Target \(target.number)")
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
            ProgressView()
                .tint(localColor)
                .scaleEffect(1.2)
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

    private var speedFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(localColor)
            Text("Targets relocate every \(relocationInterval, specifier: "%.1f")s")
            Spacer()
            Text("LIVE MATCH")
                .foregroundStyle(Color.green.opacity(0.76))
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
            symbolName: state.isDraw ? "equal.circle.fill" : (didLocalPlayerWin ? "trophy.fill" : "hand.tap.fill"),
            accentColor: state.isDraw ? TapFrenzyTheme.violet : (didLocalPlayerWin ? localColor : opponentColor),
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
            return
        }

        if let nextRelocationAt, date >= nextRelocationAt {
            relocationRound += 1
            targets = TapFrenzyGame.targets(
                seed: state.targetSeed,
                sequence: localProgress.completedSequences,
                relocation: relocationRound
            )
            self.nextRelocationAt = date.addingTimeInterval(relocationInterval)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.35)
        }
    }

    private func tap(_ number: Int) {
        let tapDate = Date()
        now = tapDate
        guard hasRoundStarted,
              !state.isFinished,
              !localProgress.isFinished,
              remainingTime > 0 else { return }

        guard number == localProgress.expectedNumber else {
            localProgress.mistakes += 1
            localProgress.score = max(0, localProgress.score - TapFrenzyGame.mistakePenalty)
            wrongTargetNumber = number
            showFeedback("−\(TapFrenzyGame.mistakePenalty) · WRONG ORDER", color: TapFrenzyTheme.coral)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            publishLocalProgress()

            let capturedNumber = number
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                if wrongTargetNumber == capturedNumber {
                    wrongTargetNumber = nil
                }
            }
            return
        }

        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.58)

        if number < TapFrenzyGame.targetCount {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                localProgress.expectedNumber += 1
            }
            publishLocalProgress()
            return
        }

        completeSequence(at: tapDate)
    }

    private func completeSequence(at date: Date) {
        let executionTime = max(0, date.timeIntervalSince(sequenceStartedAt ?? date))
        let bonus = TapFrenzyGame.speedBonus(for: executionTime)
        localProgress.score += 10 + bonus
        localProgress.completedSequences += 1
        localProgress.totalSequenceTime += executionTime
        localProgress.expectedNumber = 1
        relocationRound = 0
        targets = TapFrenzyGame.targets(
            seed: state.targetSeed,
            sequence: localProgress.completedSequences,
            relocation: 0
        )
        sequenceStartedAt = date
        nextRelocationAt = date.addingTimeInterval(relocationInterval)
        showFeedback("SEQUENCE +\(10 + bonus)", color: TapFrenzyTheme.cyan)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        publishLocalProgress()
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

        let payload = TapFrenzyProgressPayload(
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
            coalescingKey: "tap-frenzy-progress-\(state.roundID.uuidString)-\(localPlayerID)"
        ))
    }

    private func handleIncoming(_ message: NearbyMessage?) {
        guard let message, message.gameID == game.id else { return }
        if rematchController.handleIncoming(message) { return }

        switch message.type {
        case .gameAction:
            guard isHost,
                  let data = message.payload,
                  let payload = try? JSONDecoder().decode(TapFrenzyProgressPayload.self, from: data),
                  payload.sessionID == startPayload.sessionID,
                  payload.roundID == state.roundID,
                  payload.playerID == opponentID,
                  handledEvents.insert(payload.eventID).inserted else { return }
            applyRemoteProgress(payload.progress, playerID: payload.playerID)

        case .gameState:
            guard !isHost,
                  let data = message.payload,
                  let payload = try? JSONDecoder().decode(TapFrenzyStatePayload.self, from: data),
                  payload.sessionID == startPayload.sessionID else { return }
            state = payload.state

        case .gameQuit:
            opponentQuit()

        default:
            break
        }
    }

    private func applyRemoteProgress(
        _ incoming: TapFrenzyPlayerProgress,
        playerID: String
    ) {
        let current = state.progress(for: playerID)
        guard incoming.completedSequences >= current.completedSequences,
              incoming.mistakes >= current.mistakes,
              (1...TapFrenzyGame.targetCount).contains(incoming.expectedNumber),
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

        let winner = TapFrenzyGame.winner(
            firstPlayerID: startPayload.playerOneID,
            first: first.result,
            secondPlayerID: startPayload.playerTwoID,
            second: second.result
        )
        state.winnerPlayerID = winner
        state.isDraw = winner == nil
    }

    private func broadcastState() {
        let payload = TapFrenzyStatePayload(
            sessionID: startPayload.sessionID,
            state: state
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        nearbyService.send(NearbyMessage(
            gameID: game.id,
            senderName: localPlayerName,
            type: .gameState,
            payload: data,
            coalescingKey: "tap-frenzy-state-\(state.roundID.uuidString)"
        ))
    }

    private func resetRuntimeForRound() {
        localProgress = state.progress(for: localPlayerID)
        relocationRound = 0
        targets = TapFrenzyGame.targets(
            seed: state.targetSeed,
            sequence: 0,
            relocation: 0
        )
        now = Date()
        sequenceStartedAt = state.startsAt
        nextRelocationAt = state.startsAt.addingTimeInterval(relocationInterval)
        feedbackText = nil
        feedbackToken = nil
        wrongTargetNumber = nil
    }

    private func showFeedback(_ text: String, color: Color) {
        let token = UUID()
        feedbackToken = token
        feedbackColor = color
        withAnimation(.spring(response: 0.30, dampingFraction: 0.76)) {
            feedbackText = text
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            guard feedbackToken == token else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                feedbackText = nil
            }
        }
    }

    private func quitGame() {
        guard !isQuitting else { return }
        isQuitting = true
        nearbyService.send(NearbyMessage(
            gameID: game.id,
            senderName: localPlayerName,
            type: .gameQuit
        ))
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

    private func targetColor(_ number: Int) -> Color {
        switch number {
        case 1: return TapFrenzyTheme.coral
        case 2: return TapFrenzyTheme.orange
        case 3: return TapFrenzyTheme.cyan
        case 4: return TapFrenzyTheme.violet
        default: return Color(red: 0.60, green: 1.00, blue: 0.22)
        }
    }

    private var activeTargets: [TapFrenzyTarget] {
        targets.filter { $0.number >= localProgress.expectedNumber }
    }

    private var localPlayerID: String { nearbyService.localPlayerID }

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

    private var isHost: Bool {
        (nearbyService.lobbySession?.hostPlayerID ?? startPayload.playerOneID) == localPlayerID
    }

    private var localColor: Color {
        localPlayerID == startPayload.playerOneID
            ? TapFrenzyTheme.coral
            : TapFrenzyTheme.cyan
    }

    private var opponentColor: Color {
        localPlayerID == startPayload.playerOneID
            ? TapFrenzyTheme.cyan
            : TapFrenzyTheme.coral
    }

    private var opponentProgress: TapFrenzyPlayerProgress {
        state.progress(for: opponentID)
    }

    private var finalLocalProgress: TapFrenzyPlayerProgress {
        state.progress(for: localPlayerID)
    }

    private var finalOpponentProgress: TapFrenzyPlayerProgress {
        state.progress(for: opponentID)
    }

    private var relocationInterval: TimeInterval {
        TapFrenzyGame.relocationInterval(after: localProgress.completedSequences)
    }

    private var hasRoundStarted: Bool {
        now >= state.startsAt
    }

    private var remainingTime: TimeInterval {
        guard hasRoundStarted else { return TapFrenzyGame.runDuration }
        return max(0, TapFrenzyGame.runDuration - now.timeIntervalSince(state.startsAt))
    }

    private var formatRemainingTime: String {
        String(format: "%04.1f", remainingTime)
    }

    private var countdownValue: Int {
        min(3, max(1, Int(ceil(state.startsAt.timeIntervalSince(now)))))
    }

    private var didLocalPlayerWin: Bool {
        state.winnerPlayerID == localPlayerID
    }

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
        return "SEQUENCE \(localProgress.completedSequences + 1) · LIVE DUEL"
    }
}
