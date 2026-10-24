import SwiftUI
import UIKit
import Combine

struct RicochetView: View {
    let game: Game
    @ObservedObject var nearbyService: NearbyService
    let localPlayerName: String
    let startPayload: RicochetStartPayload
    let onExitToHome: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var motion = RicochetMotionController()
    @StateObject private var rematchController: RematchController
    @State private var state: RicochetMatchState
    @State private var ball: RicochetBall?
    @State private var trail: [CGPoint] = []
    @State private var manualShieldX = 0.5
    @State private var usesTouchControl = false
    @State private var handledEvents: Set<UUID> = []
    @State private var lastTick = Date()
    @State private var waitingForResolution = false
    @State private var impactFlash = false
    @State private var showQuit = false
    @State private var showResult = false
    @State private var isQuitting = false
    @State private var sessionScore = GameSessionScore()
    @State private var scoreRoundNumber = 1

    private let frameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let shieldY = 0.79
    private let shieldHalfWidth = 0.15

    init(game: Game, nearbyService: NearbyService, localPlayerName: String,
         startPayload: RicochetStartPayload, onExitToHome: @escaping () -> Void = {}) {
        self.game = game
        self.nearbyService = nearbyService
        self.localPlayerName = localPlayerName
        self.startPayload = startPayload
        self.onExitToHome = onExitToHome
        var prepared = startPayload.initialState
        prepared.lives[startPayload.playerOneID] = prepared.lives[startPayload.playerOneID] ?? 3
        prepared.lives[startPayload.playerTwoID] = prepared.lives[startPayload.playerTwoID] ?? 3
        _state = State(initialValue: prepared)
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
            RicochetTheme.background.ignoresSafeArea()
            VStack(spacing: 12) {
                header
                scoreRow
                arena
                    .frame(maxHeight: .infinity)
                controlBar
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            if showResult { resultOverlay.zIndex(20) }
            if isQuitting {
                Color.black.opacity(0.72).ignoresSafeArea()
                    .overlay(ProgressView("Leaving match…").tint(.white)).zIndex(30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .alert("Quit Ricochet?", isPresented: $showQuit) {
            Button("Quit Game", role: .destructive, action: quitGame)
            Button("Cancel", role: .cancel) {}
        } message: { Text("You and your opponent will return to the game list.") }
        .onAppear {
            motion.start()
            lastTick = Date()
        }
        .onDisappear { motion.stop() }
        .onReceive(frameTimer, perform: tick)
        .onReceive(nearbyService.$lastReceivedMessage) { handleIncoming($0) }
        .onChange(of: state.roundID) { _, _ in
            ball = nil; trail.removeAll(); waitingForResolution = false
        }
        .onChange(of: state.isRoundActive) { _, active in
            guard active, state.serverPlayerID == localPlayerID else { return }
            launchServe()
        }
        .onChange(of: state.winnerPlayerID) { _, winner in
            guard winner != nil else { showResult = false; return }
            UINotificationFeedbackGenerator().notificationOccurred(
                winner == localPlayerID ? .success : .warning
            )
        }
        .onChange(of: rematchController.confirmedRoundNumber) { _, confirmedRound in
            guard let confirmedRound else { return }
            scoreRoundNumber = confirmedRound
            showResult = false
            ball = nil
            trail.removeAll()
            waitingForResolution = false

            if isHost {
                let starter = confirmedRound.isMultiple(of: 2)
                    ? startPayload.playerTwoID
                    : startPayload.playerOneID
                var fresh = RicochetGame.makeInitialState(startingPlayerID: starter)
                fresh.lives[startPayload.playerOneID] = 3
                fresh.lives[startPayload.playerTwoID] = 3
                state = fresh
                handledEvents.removeAll()
                broadcastState()
            }
            rematchController.finishStartingRound()
        }
        .task(id: state.isFinished) {
            showResult = false
            guard state.isFinished else { return }
            sessionScore.record(localResult: localRoundResult, roundNumber: scoreRoundNumber)
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled, state.isFinished else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { showResult = true }
        }
    }

    private var header: some View {
        HStack {
            Button { showQuit = true } label: {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44).background(Circle().fill(.white.opacity(0.07)))
            }
            Spacer()
            VStack(spacing: 3) {
                Text("RICOCHET").font(.system(size: 23, weight: .black, design: .rounded)).tracking(1.4)
                Text(statusText).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(activeColor)
            }
            Spacer()
            Button {
                motion.calibrate(); manualShieldX = 0.5
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                Image(systemName: "scope").font(.system(size: 19, weight: .bold))
                    .frame(width: 44, height: 44).background(Circle().fill(.white.opacity(0.07)))
            }
        }.foregroundStyle(.white).padding(.top, 5)
    }

    private var scoreRow: some View {
        HStack(spacing: 10) {
            playerCard(name: localPlayerName, playerID: localPlayerID, color: localColor, label: "YOU")
            playerCard(name: opponentName, playerID: opponentID, color: opponentColor, label: "OPPONENT")
        }
    }

    private func playerCard(name: String, playerID: String, color: Color, label: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Circle().fill(color).frame(width: 9, height: 9).shadow(color: color, radius: 6)
                Text(name).font(.system(size: 13, weight: .bold, design: .rounded)).lineLimit(1)
                Spacer()
                Text(label).font(.system(size: 8, weight: .black)).foregroundStyle(.white.opacity(0.34))
            }
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < state.lives(for: playerID) ? "diamond.fill" : "diamond")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(color.opacity(index < state.lives(for: playerID) ? 1 : 0.25))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .padding(12).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 17).fill(.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(color.opacity(0.18)))
    }

    private var arena: some View {
        GeometryReader { proxy in
            let shieldPoint = CGPoint(x: proxy.size.width * shieldX, y: proxy.size.height * shieldY)
            ZStack {
                RoundedRectangle(cornerRadius: 27)
                    .fill(LinearGradient(colors: [Color(red: 0.03, green: 0.09, blue: 0.16), Color(red: 0.10, green: 0.035, blue: 0.14)], startPoint: .top, endPoint: .bottom))
                grid(in: proxy.size)
                portal(width: proxy.size.width)
                    .position(x: proxy.size.width / 2, y: 12)

                ForEach(Array(trail.enumerated()), id: \.offset) { index, point in
                    Circle().fill(activeColor.opacity(Double(index + 1) / Double(max(trail.count, 1)) * 0.45))
                        .frame(width: 5, height: 5).position(x: proxy.size.width * point.x, y: proxy.size.height * point.y)
                }
                if let ball {
                    ZStack {
                        Circle().fill(.white).frame(width: 15, height: 15)
                        Circle().stroke(activeColor.opacity(0.75), lineWidth: 4).frame(width: 25, height: 25)
                    }
                    .shadow(color: activeColor, radius: 14)
                    .position(x: proxy.size.width * ball.x, y: proxy.size.height * ball.y)
                }

                shield
                    .position(shieldPoint)
                core
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.925)

                if !state.isRoundActive && !state.isFinished {
                    preRoundOverlay
                } else if state.isRoundActive && ball == nil {
                    Text(waitingForResolution ? "SYNCING IMPACT…" : "PROJECTILE ON OTHER SCREEN")
                        .font(.system(size: 11, weight: .black, design: .rounded)).tracking(0.8)
                        .foregroundStyle(.white.opacity(0.38))
                }

                if impactFlash {
                    Color.red.opacity(0.25).transition(.opacity)
                    Image(systemName: "burst.fill").font(.system(size: 80)).foregroundStyle(.white, .red)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 27))
            .overlay(RoundedRectangle(cornerRadius: 27).stroke(activeColor.opacity(0.22), lineWidth: 1.2))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                guard usesTouchControl else { return }
                manualShieldX = (value.location.x / max(proxy.size.width, 1)).clamped(to: 0.08...0.92)
            })
        }
        .frame(minHeight: 350)
    }

    private func grid(in size: CGSize) -> some View {
        Canvas { context, _ in
            var path = Path()
            for column in 1..<8 {
                let x = size.width * CGFloat(column) / 8
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for row in 1..<12 {
                let y = size.height * CGFloat(row) / 12
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(activeColor.opacity(0.055)), lineWidth: 1)
        }
    }

    private func portal(width: CGFloat) -> some View {
        ZStack {
            Capsule().fill(activeColor.opacity(0.12)).frame(width: width * 0.58, height: 18).blur(radius: 8)
            Capsule().fill(LinearGradient(colors: [.clear, activeColor, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(width: width * 0.66, height: 3)
            Text("LINKED TO \(opponentName.uppercased())")
                .font(.system(size: 8, weight: .black, design: .rounded)).tracking(1).foregroundStyle(.white.opacity(0.42)).offset(y: 14)
        }
    }

    private var shield: some View {
        ZStack {
            Capsule().fill(activeColor.opacity(0.18)).frame(width: 116, height: 24).blur(radius: 8)
            Capsule().fill(LinearGradient(colors: [activeColor.opacity(0.5), .white, activeColor], startPoint: .leading, endPoint: .trailing))
                .frame(width: 105, height: 8)
            Circle().fill(.white).frame(width: 12, height: 12).shadow(color: activeColor, radius: 9)
        }.animation(.interactiveSpring(response: 0.16, dampingFraction: 0.76), value: shieldX)
    }

    private var core: some View {
        ZStack {
            Circle().fill(activeColor.opacity(0.14)).frame(width: 72, height: 72).blur(radius: 5)
            Circle().stroke(activeColor.opacity(0.50), lineWidth: 2).frame(width: 54, height: 54)
            Circle().fill(activeColor).frame(width: 25, height: 25).shadow(color: activeColor, radius: 15)
            Circle().fill(.white).frame(width: 8, height: 8)
        }
    }

    private var preRoundOverlay: some View {
        VStack(spacing: 13) {
            if state.serverPlayerID == localPlayerID {
                Text("YOUR SERVE").font(.system(size: 13, weight: .black, design: .rounded)).tracking(1.4).foregroundStyle(activeColor)
                Button(action: requestServe) {
                    Label("LAUNCH", systemImage: "paperplane.fill")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .padding(.horizontal, 25).frame(height: 48)
                        .background(Capsule().fill(activeColor)).foregroundStyle(Color.black.opacity(0.8))
                        .shadow(color: activeColor.opacity(0.55), radius: 14)
                }.buttonStyle(.plain)
            } else {
                ProgressView().tint(opponentColor)
                Text("\(opponentName.uppercased()) IS SERVING")
                    .font(.system(size: 11, weight: .black, design: .rounded)).tracking(1).foregroundStyle(.white.opacity(0.46))
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button {
                let willUseTouch = !usesTouchControl
                if willUseTouch { manualShieldX = shieldX }
                usesTouchControl = willUseTouch
                if !willUseTouch { motion.calibrate() }
            } label: {
                Label(usesTouchControl ? "Touch" : "Tilt", systemImage: usesTouchControl ? "hand.draw.fill" : "gyroscope")
                    .font(.system(size: 13, weight: .bold, design: .rounded)).frame(maxWidth: .infinity).frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 15).fill(.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.10)))
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                Text(usesTouchControl ? "DRAG THE SHIELD" : (motion.isAvailable ? "TILT TO MOVE" : "MOTION UNAVAILABLE"))
                    .font(.system(size: 10, weight: .black)).foregroundStyle(activeColor)
                Text("Block the pulse and send it back faster.")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.38)).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.foregroundStyle(.white)
    }

    private func tick(_ date: Date) {
        let dt = min(max(date.timeIntervalSince(lastTick), 0), 0.035)
        lastTick = date
        guard var moving = ball, state.isRoundActive, !waitingForResolution else { return }

        let previousY = moving.y
        moving.x += moving.velocityX * dt
        moving.y += moving.velocityY * dt

        if moving.x < 0.035 { moving.x = 0.035; moving.velocityX = abs(moving.velocityX) }
        if moving.x > 0.965 { moving.x = 0.965; moving.velocityX = -abs(moving.velocityX) }

        if moving.velocityY > 0, previousY < shieldY, moving.y >= shieldY {
            let offset = (moving.x - shieldX) / shieldHalfWidth
            if abs(offset) <= 1 {
                let newSpeed = min(1.22, moving.speed + 0.055)
                let horizontal = (moving.velocityX + offset * 0.38 + (shieldX - 0.5) * 0.08).clamped(to: -0.72...0.72)
                let vertical = -sqrt(max(0.18, newSpeed * newSpeed - horizontal * horizontal))
                moving.y = shieldY - 0.012
                moving.velocityX = horizontal
                moving.velocityY = vertical
                moving.speed = newSpeed
                state.rally += 1
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: min(1, 0.45 + Double(state.rally) * 0.08))
            }
        }

        trail.append(CGPoint(x: moving.x, y: moving.y))
        if trail.count > 14 { trail.removeFirst(trail.count - 14) }

        if moving.velocityY < 0, moving.y <= 0.015 {
            sendProjectile(moving)
            ball = nil; trail.removeAll()
            return
        }
        if moving.y > 1.04 {
            ball = nil; trail.removeAll(); registerLocalMiss()
            return
        }
        ball = moving
    }

    private func requestServe() {
        guard !state.isRoundActive, state.serverPlayerID == localPlayerID, !state.isFinished else { return }
        if isHost { activateRound() }
        else { sendAction(kind: .requestServe) }
    }

    private func activateRound() {
        guard !state.isRoundActive, !state.isFinished else { return }
        state.isRoundActive = true
        state.rally = 0
        broadcastState()
    }

    private func launchServe() {
        guard ball == nil, state.isRoundActive, state.serverPlayerID == localPlayerID else { return }
        let horizontal = (shieldX - 0.5) * 0.42
        ball = RicochetBall(x: 0.5, y: 0.89, velocityX: horizontal, velocityY: -0.68, speed: 0.68)
        trail.removeAll()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func sendProjectile(_ outgoing: RicochetBall) {
        let payload = RicochetActionPayload(
            sessionID: startPayload.sessionID, kind: .projectileTransfer,
            playerID: localPlayerID, roundID: state.roundID, eventID: UUID(),
            x: 1 - outgoing.x, velocityX: -outgoing.velocityX,
            speed: outgoing.speed, rally: state.rally
        )
        send(payload)
    }

    private func receiveProjectile(_ payload: RicochetActionPayload) {
        guard payload.roundID == state.roundID, state.isRoundActive,
              payload.playerID != localPlayerID, ball == nil,
              let x = payload.x, let vx = payload.velocityX, let speed = payload.speed else { return }
        let vertical = sqrt(max(0.18, speed * speed - vx * vx))
        state.rally = max(state.rally, payload.rally ?? 0)
        trail.removeAll()
        ball = RicochetBall(x: x.clamped(to: 0.04...0.96), y: 0.025,
                             velocityX: vx.clamped(to: -0.76...0.76), velocityY: vertical, speed: speed)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func registerLocalMiss() {
        guard state.isRoundActive else { return }
        waitingForResolution = true
        withAnimation(.easeOut(duration: 0.15)) { impactFlash = true }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            withAnimation(.easeOut(duration: 0.3)) { impactFlash = false }
        }
        if isHost { applyLifeLoss(to: localPlayerID) }
        else { sendAction(kind: .lifeLost) }
    }

    private func applyLifeLoss(to playerID: String) {
        guard state.isRoundActive, playerID == startPayload.playerOneID || playerID == startPayload.playerTwoID else { return }
        state.lives[playerID] = max(0, state.lives(for: playerID) - 1)
        state.isRoundActive = false
        state.serverPlayerID = playerID
        state.roundID = UUID()
        if state.lives(for: playerID) == 0 {
            state.winnerPlayerID = playerID == startPayload.playerOneID ? startPayload.playerTwoID : startPayload.playerOneID
        }
        broadcastState()
    }

    private func handleIncoming(_ message: NearbyMessage?) {
        guard let message, message.gameID == game.id else { return }
        if rematchController.handleIncoming(message) { return }
        switch message.type {
        case .gameAction:
            guard let data = message.payload,
                  let payload = try? JSONDecoder().decode(RicochetActionPayload.self, from: data),
                  payload.sessionID == startPayload.sessionID,
                  handledEvents.insert(payload.eventID).inserted else { return }
            switch payload.kind {
            case .projectileTransfer: receiveProjectile(payload)
            case .requestServe:
                guard isHost, payload.playerID == state.serverPlayerID else { return }
                activateRound()
            case .lifeLost:
                guard isHost, payload.roundID == state.roundID else { return }
                applyLifeLoss(to: payload.playerID)
            }
        case .gameState:
            guard let data = message.payload,
                  let payload = try? JSONDecoder().decode(RicochetStatePayload.self, from: data),
                  payload.sessionID == startPayload.sessionID else { return }
            state = payload.state
        case .gameQuit: opponentQuit()
        default: break
        }
    }

    private func sendAction(kind: RicochetActionKind) {
        send(.init(sessionID: startPayload.sessionID, kind: kind, playerID: localPlayerID,
                   roundID: state.roundID, eventID: UUID(), x: nil, velocityX: nil, speed: nil, rally: nil))
    }

    private func send(_ payload: RicochetActionPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        nearbyService.send(.init(gameID: game.id, senderName: localPlayerName, type: .gameAction, payload: data))
    }

    private func broadcastState() {
        let payload = RicochetStatePayload(sessionID: startPayload.sessionID, state: state)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        nearbyService.send(.init(gameID: game.id, senderName: localPlayerName, type: .gameState, payload: data))
    }

    private func quitGame() {
        guard !isQuitting else { return }; isQuitting = true
        nearbyService.send(.init(gameID: game.id, senderName: localPlayerName, type: .gameQuit))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            motion.stop(); nearbyService.stop(); dismiss(); onExitToHome(); isQuitting = false
        }
    }

    private func opponentQuit() { motion.stop(); nearbyService.stop(); dismiss(); onExitToHome() }

    private var resultOverlay: some View {
        GameResultOverlay(
            result: localRoundResult,
            title: localRoundResult == .win ? "You Win!" : "\(opponentName) Wins",
            subtitle: "Three breaches ended the link.",
            symbolName: localRoundResult == .win ? "bolt.shield.fill" : "shield.slash.fill",
            accentColor: localRoundResult == .win ? localColor : opponentColor,
            firstPlayerName: localPlayerName,
            secondPlayerName: opponentName,
            sessionScore: sessionScore,
            rematchState: rematchController.state,
            onPrimaryAction: rematchController.performPrimaryAction,
            onQuit: quitGame
        )
    }

    private var localRoundResult: GameRoundResult {
        state.winnerPlayerID == localPlayerID ? .win : .loss
    }

    private var shieldX: Double { usesTouchControl || !motion.isAvailable ? manualShieldX : motion.position }
    private var localPlayerID: String { nearbyService.localPlayerID }
    private var opponentID: String { localPlayerID == startPayload.playerOneID ? startPayload.playerTwoID : startPayload.playerOneID }
    private var opponentName: String { localPlayerID == startPayload.playerOneID ? startPayload.playerTwoName : startPayload.playerOneName }
    private var isHost: Bool { (nearbyService.lobbySession?.hostPlayerID ?? startPayload.playerOneID) == localPlayerID }
    private var localColor: Color { localPlayerID == startPayload.playerOneID ? RicochetTheme.cyan : RicochetTheme.magenta }
    private var opponentColor: Color { localPlayerID == startPayload.playerOneID ? RicochetTheme.magenta : RicochetTheme.cyan }
    private var activeColor: Color { localColor }
    private var statusText: String {
        if state.isFinished { return "LINK CLOSED" }
        if !state.isRoundActive { return state.serverPlayerID == localPlayerID ? "READY TO SERVE" : "WAITING FOR \(opponentName.uppercased())" }
        if ball != nil { return "DEFEND YOUR CORE" }
        return "PULSE ACROSS THE LINK  •  RALLY \(state.rally)"
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double { min(max(self, range.lowerBound), range.upperBound) }
}
