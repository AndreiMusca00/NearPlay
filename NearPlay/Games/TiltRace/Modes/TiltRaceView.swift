import Combine
import SwiftUI
import UIKit

struct TiltRaceView: View {
    let game: Game
    @ObservedObject var nearbyService: NearbyService
    let localPlayerName: String
    let startPayload: TiltRaceStartPayload
    let onExitToHome: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var motion = TiltRaceMotionController()
    @State private var state: TiltRaceMatchState
    @State private var ballX = 0.5
    @State private var ballY = 0.91
    @State private var velocityX = 0.0
    @State private var velocityY = 0.0
    @State private var touchX = 0.5
    @State private var touchY = 0.91
    @State private var trail: [CGPoint] = []
    @State private var usesTouchControl = false
    @State private var handledEvents: Set<UUID> = []
    @State private var now = Date()
    @State private var lastTick = Date()
    @State private var showQuit = false
    @State private var showResult = false
    @State private var isQuitting = false

    private let frameTimer = Timer.publish(
        every: 1.0 / 60.0,
        on: .main,
        in: .common
    ).autoconnect()

    init(
        game: Game,
        nearbyService: NearbyService,
        localPlayerName: String,
        startPayload: TiltRaceStartPayload,
        onExitToHome: @escaping () -> Void = {}
    ) {
        self.game = game
        self.nearbyService = nearbyService
        self.localPlayerName = localPlayerName
        self.startPayload = startPayload
        self.onExitToHome = onExitToHome

        var prepared = startPayload.initialState
        prepared.progress[startPayload.playerOneID] =
            prepared.progress[startPayload.playerOneID] ?? 0
        prepared.progress[startPayload.playerTwoID] =
            prepared.progress[startPayload.playerTwoID] ?? 0
        _state = State(initialValue: prepared)
    }

    var body: some View {
        ZStack {
            TiltRaceTheme.background.ignoresSafeArea()

            VStack(spacing: 12) {
                header
                progressCards
                arena.frame(maxHeight: .infinity)
                controlBar
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            if showResult {
                resultOverlay.zIndex(20)
            }

            if isQuitting {
                Color.black.opacity(0.72).ignoresSafeArea()
                    .overlay(ProgressView("Leaving race…").tint(.white))
                    .zIndex(30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .alert("Quit Tilt Race?", isPresented: $showQuit) {
            Button("Quit Game", role: .destructive, action: quitGame)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You and your opponent will return to the game list.")
        }
        .onAppear {
            motion.start()
            resetLocalBall()
            now = Date()
            lastTick = now
        }
        .onDisappear { motion.stop() }
        .onReceive(frameTimer, perform: tick)
        .onReceive(nearbyService.$lastReceivedMessage) { handleIncoming($0) }
        .onChange(of: state.roundID) { _, _ in
            resetLocalBall()
            showResult = false
        }
        .onChange(of: state.winnerPlayerID) { _, winner in
            guard winner != nil else {
                showResult = false
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(
                winner == localPlayerID ? .success : .warning
            )
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                showResult = true
            }
        }
    }

    private var header: some View {
        HStack {
            Button { showQuit = true } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white.opacity(0.07)))
            }

            Spacer()

            VStack(spacing: 3) {
                Text("TILT RACE")
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .tracking(1.3)
                Text(statusText)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(localColor)
            }

            Spacer()

            Button {
                motion.calibrate()
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                Image(systemName: "scope")
                    .font(.system(size: 19, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white.opacity(0.07)))
            }
        }
        .foregroundStyle(.white)
        .padding(.top, 5)
    }

    private var progressCards: some View {
        HStack(spacing: 10) {
            progressCard(
                name: localPlayerName,
                playerID: localPlayerID,
                color: localColor,
                label: "YOU"
            )
            progressCard(
                name: opponentName,
                playerID: opponentID,
                color: opponentColor,
                label: "RIVAL"
            )
        }
    }

    private func progressCard(
        name: String,
        playerID: String,
        color: Color,
        label: String
    ) -> some View {
        let progress = state.progress(for: playerID)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                    .shadow(color: color, radius: 5)
                Text(name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Spacer()
                Text(label)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.white.opacity(0.34))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [color.opacity(0.55), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: proxy.size.width * progressFraction(progress))
                        .shadow(color: color.opacity(0.4), radius: 5)
                }
            }
            .frame(height: 6)

            Text("GATE \(min(progress + 1, TiltRaceGame.gateCount)) / \(TiltRaceGame.gateCount)")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 17).fill(.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(color.opacity(0.18)))
    }

    private var arena: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 27)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.025, green: 0.09, blue: 0.105),
                            Color(red: 0.095, green: 0.035, blue: 0.13)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ))

                trackPath(in: proxy.size)

                ForEach(checkpoints) { checkpoint in
                    checkpointView(checkpoint)
                        .position(
                            x: proxy.size.width * checkpoint.x,
                            y: proxy.size.height * checkpoint.y
                        )
                }

                ForEach(Array(trail.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(localColor.opacity(
                            Double(index + 1) / Double(max(trail.count, 1)) * 0.38
                        ))
                        .frame(width: 6, height: 6)
                        .position(
                            x: proxy.size.width * point.x,
                            y: proxy.size.height * point.y
                        )
                }

                racerBall
                    .position(
                        x: proxy.size.width * ballX,
                        y: proxy.size.height * ballY
                    )

                if !hasRaceStarted && !state.isFinished {
                    countdownOverlay
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 27))
            .overlay(
                RoundedRectangle(cornerRadius: 27)
                    .stroke(localColor.opacity(0.24), lineWidth: 1.2)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    guard usesTouchControl || !motion.isAvailable else { return }
                    touchX = (value.location.x / max(proxy.size.width, 1))
                        .clamped(to: 0.045...0.955)
                    touchY = (value.location.y / max(proxy.size.height, 1))
                        .clamped(to: 0.04...0.96)
                }
            )
        }
        .frame(minHeight: 360)
    }

    private func trackPath(in size: CGSize) -> some View {
        Canvas { context, _ in
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.91))
            for checkpoint in checkpoints {
                path.addLine(to: CGPoint(
                    x: size.width * checkpoint.x,
                    y: size.height * checkpoint.y
                ))
            }
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [localColor.opacity(0.12), opponentColor.opacity(0.28)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: 0)
                ),
                style: StrokeStyle(lineWidth: 2, dash: [6, 8])
            )
        }
    }

    private func checkpointView(_ checkpoint: TiltRaceCheckpoint) -> some View {
        let progress = localProgress
        let completed = checkpoint.id < progress
        let isNext = checkpoint.id == progress

        return ZStack {
            if isNext {
                Circle()
                    .fill(localColor.opacity(0.08))
                    .frame(width: 56, height: 56)
                Circle()
                    .stroke(localColor.opacity(0.34), lineWidth: 1.5)
                    .frame(width: 54, height: 54)
            }

            Circle()
                .fill(completed ? localColor.opacity(0.10) : Color.black.opacity(0.22))
                .frame(width: 40, height: 40)
            Circle()
                .stroke(
                    completed ? localColor.opacity(0.38) :
                        (isNext ? localColor : .white.opacity(0.20)),
                    lineWidth: isNext ? 3.5 : 2
                )
                .frame(width: 40, height: 40)

            if completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(localColor.opacity(0.65))
            } else {
                Text("\(checkpoint.id + 1)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(isNext ? .white : .white.opacity(0.28))
            }

            if isNext {
                Image(systemName: "triangle.fill")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(localColor)
                    .rotationEffect(.degrees(180))
                    .offset(y: -31)
            }
        }
        .shadow(color: isNext ? localColor.opacity(0.58) : .clear, radius: 9)
    }

    private var racerBall: some View {
        ZStack {
            Circle().fill(localColor.opacity(0.22)).frame(width: 37, height: 37).blur(radius: 5)
            Circle()
                .fill(RadialGradient(
                    colors: [.white, localColor],
                    center: .topLeading,
                    startRadius: 1,
                    endRadius: 15
                ))
                .frame(width: 23, height: 23)
            Circle().stroke(.white.opacity(0.7), lineWidth: 1).frame(width: 23, height: 23)
        }
        .shadow(color: localColor, radius: 12)
    }

    private var countdownOverlay: some View {
        VStack(spacing: 9) {
            Text(countdownText)
                .font(.system(size: 62, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: localColor, radius: 18)
                .contentTransition(.numericText())
            Text("HOLD STEADY")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button {
                let willUseTouch = !usesTouchControl
                touchX = ballX
                touchY = ballY
                usesTouchControl = willUseTouch
                if !willUseTouch { motion.calibrate() }
            } label: {
                Label(
                    usesTouchControl ? "Touch" : "Tilt",
                    systemImage: usesTouchControl ? "hand.draw.fill" : "gyroscope"
                )
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 15).fill(.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.10)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(controlTitle)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(localColor)
                Text("Guide the orb through every gate.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
    }

    private func tick(_ date: Date) {
        now = date
        let dt = min(max(date.timeIntervalSince(lastTick), 0), 0.035)
        lastTick = date

        guard hasRaceStarted, !state.isFinished, localProgress < TiltRaceGame.gateCount else {
            return
        }

        if usesTouchControl || !motion.isAvailable {
            ballX += (touchX - ballX) * min(1, dt * 15)
            ballY += (touchY - ballY) * min(1, dt * 15)
        } else {
            velocityX += motion.tiltX * 0.92 * dt
            velocityY += motion.tiltY * 0.92 * dt

            let damping = pow(0.18, dt)
            velocityX *= damping
            velocityY *= damping

            let speed = sqrt(velocityX * velocityX + velocityY * velocityY)
            if speed > 0.56 {
                let scale = 0.56 / speed
                velocityX *= scale
                velocityY *= scale
            }

            ballX += velocityX * dt
            ballY += velocityY * dt
        }

        if ballX < 0.045 { ballX = 0.045; velocityX = abs(velocityX) * 0.45 }
        if ballX > 0.955 { ballX = 0.955; velocityX = -abs(velocityX) * 0.45 }
        if ballY < 0.04 { ballY = 0.04; velocityY = abs(velocityY) * 0.45 }
        if ballY > 0.96 { ballY = 0.96; velocityY = -abs(velocityY) * 0.45 }

        trail.append(CGPoint(x: ballX, y: ballY))
        if trail.count > 13 { trail.removeFirst(trail.count - 13) }

        detectCheckpoint()
    }

    private func detectCheckpoint() {
        guard localProgress < TiltRaceGame.gateCount else { return }
        let checkpoint = checkpoints[localProgress]
        let dx = ballX - checkpoint.x
        let dy = ballY - checkpoint.y
        guard sqrt(dx * dx + dy * dy) < 0.072 else { return }

        let nextProgress = localProgress + 1
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(
            intensity: min(1, 0.45 + Double(nextProgress) * 0.07)
        )

        if isHost {
            applyProgress(playerID: localPlayerID, gateIndex: nextProgress)
        } else {
            state.progress[localPlayerID] = nextProgress
            sendProgress(nextProgress)
        }
    }

    private func applyProgress(playerID: String, gateIndex: Int) {
        guard !state.isFinished,
              playerID == startPayload.playerOneID || playerID == startPayload.playerTwoID else {
            return
        }

        let current = state.progress(for: playerID)
        guard gateIndex == current + 1, gateIndex <= TiltRaceGame.gateCount else { return }
        state.progress[playerID] = gateIndex
        if gateIndex == TiltRaceGame.gateCount {
            state.winnerPlayerID = playerID
        }
        broadcastState()
    }

    private func sendProgress(_ gateIndex: Int) {
        let payload = TiltRaceProgressPayload(
            sessionID: startPayload.sessionID,
            roundID: state.roundID,
            eventID: UUID(),
            playerID: localPlayerID,
            gateIndex: gateIndex
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        nearbyService.send(.init(
            gameID: game.id,
            senderName: localPlayerName,
            type: .gameAction,
            payload: data
        ))
    }

    private func handleIncoming(_ message: NearbyMessage?) {
        guard let message, message.gameID == game.id else { return }

        switch message.type {
        case .gameAction:
            guard isHost,
                  let data = message.payload,
                  let payload = try? JSONDecoder().decode(TiltRaceProgressPayload.self, from: data),
                  payload.sessionID == startPayload.sessionID,
                  payload.roundID == state.roundID,
                  handledEvents.insert(payload.eventID).inserted else { return }
            applyProgress(playerID: payload.playerID, gateIndex: payload.gateIndex)

        case .gameState:
            guard let data = message.payload,
                  let payload = try? JSONDecoder().decode(TiltRaceStatePayload.self, from: data),
                  payload.sessionID == startPayload.sessionID else { return }
            var incoming = payload.state
            if incoming.roundID == state.roundID {
                incoming.progress[localPlayerID] = max(
                    incoming.progress(for: localPlayerID),
                    localProgress
                )
            }
            state = incoming

        case .rematch:
            handleReset(message)

        case .gameQuit:
            opponentQuit()

        default:
            break
        }
    }

    private func broadcastState() {
        let payload = TiltRaceStatePayload(
            sessionID: startPayload.sessionID,
            state: state
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        nearbyService.send(.init(
            gameID: game.id,
            senderName: localPlayerName,
            type: .gameState,
            payload: data
        ))
    }

    private func requestRematch() {
        showResult = false
        if isHost {
            resetMatch()
        } else {
            let payload = TiltRaceResetPayload(sessionID: startPayload.sessionID)
            guard let data = try? JSONEncoder().encode(payload) else { return }
            nearbyService.send(.init(
                gameID: game.id,
                senderName: localPlayerName,
                type: .rematch,
                payload: data
            ))
        }
    }

    private func handleReset(_ message: NearbyMessage) {
        guard isHost,
              let data = message.payload,
              let payload = try? JSONDecoder().decode(TiltRaceResetPayload.self, from: data),
              payload.sessionID == startPayload.sessionID else { return }
        resetMatch()
    }

    private func resetMatch() {
        state = TiltRaceGame.makeInitialState(
            playerOneID: startPayload.playerOneID,
            playerTwoID: startPayload.playerTwoID
        )
        handledEvents.removeAll()
        showResult = false
        broadcastState()
    }

    private func resetLocalBall() {
        ballX = 0.5
        ballY = 0.91
        touchX = 0.5
        touchY = 0.91
        velocityX = 0
        velocityY = 0
        trail.removeAll()
        now = Date()
        lastTick = now
        motion.calibrate()
    }

    private func quitGame() {
        guard !isQuitting else { return }
        isQuitting = true
        nearbyService.send(.init(
            gameID: game.id,
            senderName: localPlayerName,
            type: .gameQuit
        ))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            motion.stop()
            nearbyService.stop()
            dismiss()
            onExitToHome()
            isQuitting = false
        }
    }

    private func opponentQuit() {
        motion.stop()
        nearbyService.stop()
        dismiss()
        onExitToHome()
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: didLocalPlayerWin ? "trophy.fill" : "flag.checkered")
                    .font(.system(size: 45, weight: .bold))
                    .foregroundStyle(didLocalPlayerWin ? localColor : opponentColor)

                Text(didLocalPlayerWin ? "You Win!" : "\(opponentName) Wins")
                    .font(.system(size: 29, weight: .black, design: .rounded))

                Text("All ten gates cleared.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                Button(action: requestRematch) {
                    Label("Race Again", systemImage: "arrow.clockwise")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 17)
                                .fill(LinearGradient(
                                    colors: [localColor, TiltRaceTheme.violet],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                        .foregroundStyle(Color.black.opacity(0.8))
                }
                .buttonStyle(.plain)

                Button("Quit", action: quitGame)
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(height: 35)
            }
            .padding(27)
            .frame(maxWidth: 350)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 0.04, green: 0.065, blue: 0.085))
            )
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12)))
            .padding(24)
        }
        .foregroundStyle(.white)
    }

    private func progressFraction(_ progress: Int) -> Double {
        Double(progress) / Double(max(TiltRaceGame.gateCount, 1))
    }

    private var checkpoints: [TiltRaceCheckpoint] {
        TiltRaceGame.checkpoints(for: state.trackSeed)
    }
    private var localProgress: Int { state.progress(for: localPlayerID) }
    private var hasRaceStarted: Bool { now >= state.startsAt }
    private var countdownText: String {
        String(max(1, Int(ceil(state.startsAt.timeIntervalSince(now)))))
    }
    private var didLocalPlayerWin: Bool { state.winnerPlayerID == localPlayerID }
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
        localPlayerID == startPayload.playerOneID ? TiltRaceTheme.lime : TiltRaceTheme.cyan
    }
    private var opponentColor: Color {
        localPlayerID == startPayload.playerOneID ? TiltRaceTheme.cyan : TiltRaceTheme.lime
    }
    private var controlTitle: String {
        if usesTouchControl || !motion.isAvailable { return "DRAG TO STEER" }
        return "TILT TO STEER"
    }
    private var statusText: String {
        if state.isFinished { return "RACE COMPLETE" }
        if !hasRaceStarted { return "GET READY" }
        return "GATE \(min(localProgress + 1, TiltRaceGame.gateCount)) OF \(TiltRaceGame.gateCount)"
    }
}

private extension TiltRaceMatchState {
    var isFinished: Bool { winnerPlayerID != nil }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
