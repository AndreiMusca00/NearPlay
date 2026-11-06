import SwiftUI
import UIKit
import Combine

struct RicochetView: View {
    let game: Game
    @ObservedObject var nearbyService: NearbyService
    let localPlayerName: String
    let startPayload: RicochetStartPayload
    let onExitToHome: (NearbyGameExitReason) -> Void

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
    @State private var showQuit = false
    @State private var showResult = false
    @State private var isQuitting = false
    @State private var sessionScore = GameSessionScore()
    @State private var scoreRoundNumber = 1
    @State private var remoteBallX: Double?
    @State private var remoteBallLastSeenAt = Date.distantPast
    @State private var lastBallPositionSentAt = Date.distantPast
    @State private var arenaMoment: RicochetArenaMoment?
    @State private var arenaMomentPhase = 0
    @State private var isGameplayPaused = false

    private let frameTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let shieldY = 0.79
    private let shieldHalfWidth = 0.15

    init(game: Game, nearbyService: NearbyService, localPlayerName: String,
         startPayload: RicochetStartPayload, onExitToHome: @escaping (NearbyGameExitReason) -> Void = { _ in }) {
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

            if let arenaMoment {
                momentOverlay(arenaMoment)
                    .zIndex(15)
                    .transition(.opacity)
            }
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
            remoteBallX = nil
            lastBallPositionSentAt = .distantPast
        }
        .onChange(of: state.isRoundActive) { _, active in
            guard active else {
                remoteBallX = nil
                return
            }
            if state.serverPlayerID == localPlayerID {
                launchServe()
            }
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
            arenaMoment = nil
            isGameplayPaused = false
            ball = nil
            trail.removeAll()
            waitingForResolution = false
            remoteBallX = nil
            lastBallPositionSentAt = .distantPast

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
            try? await Task.sleep(nanoseconds: 2_800_000_000)
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
                portal(width: proxy.size.width)
                    .position(x: proxy.size.width / 2, y: 12)

                if ball == nil,
                   state.isRoundActive,
                   !waitingForResolution,
                   let remoteBallX {
                    remoteBallIndicator
                        .position(
                            x: proxy.size.width * remoteBallX,
                            y: 52
                        )
                        .animation(
                            .easeOut(duration: 0.14),
                            value: remoteBallX
                        )
                        .transition(.opacity.combined(with: .scale))
                }

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

                if !state.isRoundActive && !state.isFinished {
                    preRoundOverlay
                } else if state.isRoundActive && ball == nil {
                    Text(waitingForResolution ? "SYNCING IMPACT…" : "TRACKING RIVAL SCREEN")
                        .font(.system(size: 11, weight: .black, design: .rounded)).tracking(0.8)
                        .foregroundStyle(.white.opacity(0.38))
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

    private var remoteBallIndicator: some View {
        ZStack {
            Circle()
                .fill(opponentColor.opacity(0.20))
                .frame(width: 30, height: 30)
                .blur(radius: 6)
            Circle()
                .stroke(opponentColor.opacity(0.82), lineWidth: 2)
                .frame(width: 22, height: 22)
            Circle()
                .fill(.white)
                .frame(width: 9, height: 9)
                .shadow(color: opponentColor, radius: 8)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(opponentColor)
                .offset(y: 19)
        }
        .accessibilityLabel("Opponent ball position")
    }

    @ViewBuilder
    private func momentOverlay(_ moment: RicochetArenaMoment) -> some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()

            RadialGradient(
                colors: [moment.accent.opacity(0.30), .clear],
                center: .center,
                startRadius: 12,
                endRadius: 260
            )
            .ignoresSafeArea()

            switch moment.kind {
            case .speedUp:
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .stroke(moment.accent.opacity(0.18), lineWidth: 20)
                            .frame(width: 142, height: 142)
                        Circle()
                            .trim(from: 0.08, to: 0.82)
                            .stroke(
                                AngularGradient(
                                    colors: [.white, moment.accent, .white],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 142, height: 142)
                            .rotationEffect(.degrees(-70))
                            .shadow(color: moment.accent, radius: 16)
                        Image(systemName: "chevron.up.2")
                            .font(.system(size: 48, weight: .black))
                            .foregroundStyle(.white)
                    }

                    Text("SPEEDING UP")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .tracking(2.4)
                    Text("Get ready — the pulse is accelerating")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.56))
                }
                .transition(.scale(scale: 0.82).combined(with: .opacity))

            case let .point(winnerID, serverID, matchFinished):
                pointMomentContent(
                    winnerID: winnerID,
                    serverID: serverID,
                    matchFinished: matchFinished,
                    accent: moment.accent
                )
                .id(arenaMomentPhase)
                .transition(.scale(scale: 0.78).combined(with: .opacity))
            }
        }
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private func pointMomentContent(
        winnerID: String,
        serverID: String,
        matchFinished: Bool,
        accent: Color
    ) -> some View {
        if arenaMomentPhase == 0 {
            if winnerID == localPlayerID {
                VStack(spacing: 15) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 104, weight: .black))
                        .foregroundStyle(.black, accent)
                        .shadow(color: accent, radius: 28)
                    Text("POINT WON!")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .tracking(2.2)
                    Text("Great return")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "burst.fill")
                        .font(.system(size: 126, weight: .black))
                        .foregroundStyle(.white, Color.orange)
                        .shadow(color: .red.opacity(0.9), radius: 28)
                    Text("BOOM!")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .tracking(3)
                    Text("The pulse crossed your shield")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: matchFinished ? "trophy.fill" : "paperplane.circle.fill")
                    .font(.system(size: 88, weight: .black))
                    .foregroundStyle(accent)
                    .shadow(color: accent, radius: 22)
                Text(matchFinished ? "MATCH COMPLETE" : "NEXT SERVE")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(.white.opacity(0.52))
                Text(
                    matchFinished
                        ? (winnerID == localPlayerID ? "YOU WIN" : "\(displayName(for: winnerID).uppercased()) WINS")
                        : (serverID == localPlayerID ? "YOUR SERVE" : "\(displayName(for: serverID).uppercased()) SERVES")
                )
                .font(.system(size: 34, weight: .black, design: .rounded))
                .tracking(1.5)
            }
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
                Text("Deflect the pulse before it crosses your shield.")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.38)).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.foregroundStyle(.white)
    }

    private func tick(_ date: Date) {
        let dt = min(max(date.timeIntervalSince(lastTick), 0), 0.035)
        lastTick = date

        if remoteBallX != nil,
           date.timeIntervalSince(remoteBallLastSeenAt) > 0.8 {
            withAnimation(.easeOut(duration: 0.18)) {
                remoteBallX = nil
            }
        }

        guard var moving = ball,
              state.isRoundActive,
              !waitingForResolution,
              !isGameplayPaused else { return }

        let previousY = moving.y
        moving.x += moving.velocityX * dt
        moving.y += moving.velocityY * dt

        if moving.x < 0.035 { moving.x = 0.035; moving.velocityX = abs(moving.velocityX) }
        if moving.x > 0.965 { moving.x = 0.965; moving.velocityX = -abs(moving.velocityX) }

        if moving.velocityY > 0, previousY < shieldY, moving.y >= shieldY {
            let offset = (moving.x - shieldX) / shieldHalfWidth
            if abs(offset) <= 1 {
                state.rally += 1
                let shouldSpeedUp = state.rally.isMultiple(of: 5) && moving.speed < 1.22
                let newSpeed = shouldSpeedUp
                    ? min(1.22, moving.speed + 0.13)
                    : moving.speed
                let horizontal = (moving.velocityX + offset * 0.38 + (shieldX - 0.5) * 0.08).clamped(to: -0.72...0.72)
                let vertical = -sqrt(max(0.18, newSpeed * newSpeed - horizontal * horizontal))
                moving.y = shieldY - 0.012
                moving.velocityX = horizontal
                moving.velocityY = vertical
                moving.speed = newSpeed
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: min(1, 0.45 + Double(state.rally) * 0.08))
                if shouldSpeedUp {
                    announceSpeedIncrease(speed: newSpeed, rally: state.rally)
                }
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
            ball = nil
            trail.removeAll()
            remoteBallX = nil
            registerLocalMiss()
            return
        }

        sendProjectilePositionIfNeeded(moving, at: date)
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
            speed: outgoing.speed, rally: state.rally,
            targetPlayerID: nil, matchFinished: nil
        )
        send(payload)
        remoteBallX = outgoing.x.clamped(to: 0.04...0.96)
        remoteBallLastSeenAt = Date()
    }

    private func receiveProjectile(_ payload: RicochetActionPayload) {
        guard payload.roundID == state.roundID, state.isRoundActive,
              payload.playerID != localPlayerID, ball == nil,
              let x = payload.x, let vx = payload.velocityX, let speed = payload.speed else { return }
        let vertical = sqrt(max(0.18, speed * speed - vx * vx))
        state.rally = max(state.rally, payload.rally ?? 0)
        trail.removeAll()
        remoteBallX = nil
        ball = RicochetBall(x: x.clamped(to: 0.04...0.96), y: 0.025,
                             velocityX: vx.clamped(to: -0.76...0.76), velocityY: vertical, speed: speed)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func sendProjectilePositionIfNeeded(
        _ moving: RicochetBall,
        at date: Date
    ) {
        guard date.timeIntervalSince(lastBallPositionSentAt) >= 0.12 else {
            return
        }

        lastBallPositionSentAt = date
        send(.init(
            sessionID: startPayload.sessionID,
            kind: .projectilePosition,
            playerID: localPlayerID,
            roundID: state.roundID,
            eventID: UUID(),
            x: moving.x,
            velocityX: nil,
            speed: nil,
            rally: nil,
            targetPlayerID: nil,
            matchFinished: nil
        ))
    }

    private func receiveProjectilePosition(
        _ payload: RicochetActionPayload
    ) {
        guard payload.roundID == state.roundID,
              state.isRoundActive,
              payload.playerID != localPlayerID,
              ball == nil,
              let x = payload.x else {
            return
        }

        remoteBallLastSeenAt = Date()
        withAnimation(.easeOut(duration: 0.12)) {
            remoteBallX = (1 - x).clamped(to: 0.04...0.96)
        }
    }

    private func announceSpeedIncrease(speed: Double, rally: Int) {
        send(.init(
            sessionID: startPayload.sessionID,
            kind: .speedUp,
            playerID: localPlayerID,
            roundID: state.roundID,
            eventID: UUID(),
            x: nil,
            velocityX: nil,
            speed: speed,
            rally: rally,
            targetPlayerID: nil,
            matchFinished: nil
        ))
        presentSpeedIncrease(speed: speed, rally: rally)
    }

    private func announcePointResolution(
        loserID: String,
        matchFinished: Bool
    ) {
        send(.init(
            sessionID: startPayload.sessionID,
            kind: .pointResolved,
            playerID: localPlayerID,
            roundID: state.roundID,
            eventID: UUID(),
            x: nil,
            velocityX: nil,
            speed: nil,
            rally: state.rally,
            targetPlayerID: loserID,
            matchFinished: matchFinished
        ))
        presentPointResolution(
            loserID: loserID,
            matchFinished: matchFinished
        )
    }

    private func presentSpeedIncrease(speed: Double, rally: Int) {
        if let arenaMoment, case .point = arenaMoment.kind { return }

        let moment = RicochetArenaMoment(
            kind: .speedUp,
            accent: RicochetTheme.cyan
        )
        arenaMomentPhase = 0
        isGameplayPaused = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            arenaMoment = moment
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_550_000_000)
            guard arenaMoment?.id == moment.id else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                arenaMoment = nil
            }
            isGameplayPaused = false
        }
    }

    private func presentPointResolution(
        loserID: String,
        matchFinished: Bool
    ) {
        let winnerID = loserID == startPayload.playerOneID
            ? startPayload.playerTwoID
            : startPayload.playerOneID
        let moment = RicochetArenaMoment(
            kind: .point(
                winnerID: winnerID,
                serverID: loserID,
                matchFinished: matchFinished
            ),
            accent: playerColor(for: winnerID)
        )

        arenaMomentPhase = 0
        isGameplayPaused = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
            arenaMoment = moment
        }
        UINotificationFeedbackGenerator().notificationOccurred(
            winnerID == localPlayerID ? .success : .error
        )

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_050_000_000)
            guard arenaMoment?.id == moment.id else { return }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                arenaMomentPhase = 2
            }

            try? await Task.sleep(nanoseconds: 1_250_000_000)
            guard arenaMoment?.id == moment.id else { return }
            withAnimation(.easeOut(duration: 0.24)) {
                arenaMoment = nil
            }
            isGameplayPaused = false
        }
    }

    private func registerLocalMiss() {
        guard state.isRoundActive else { return }
        waitingForResolution = true
        UINotificationFeedbackGenerator().notificationOccurred(.error)
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
        announcePointResolution(
            loserID: playerID,
            matchFinished: state.isFinished
        )
    }

    private func handleIncoming(_ message: NearbyMessage?) {
        guard let message, message.gameID == game.id else { return }
        if rematchController.handleIncoming(message) { return }
        switch message.type {
        case .gameAction:
            guard let data = message.payload,
                  let payload = try? JSONDecoder().decode(RicochetActionPayload.self, from: data),
                  payload.sessionID == startPayload.sessionID else { return }

            if payload.kind == .projectilePosition {
                receiveProjectilePosition(payload)
                return
            }

            guard handledEvents.insert(payload.eventID).inserted else { return }
            switch payload.kind {
            case .projectileTransfer: receiveProjectile(payload)
            case .projectilePosition: break
            case .speedUp:
                guard payload.roundID == state.roundID,
                      let speed = payload.speed,
                      let rally = payload.rally else { return }
                presentSpeedIncrease(speed: speed, rally: rally)
            case .requestServe:
                guard isHost, payload.playerID == state.serverPlayerID else { return }
                activateRound()
            case .lifeLost:
                guard isHost, payload.roundID == state.roundID else { return }
                applyLifeLoss(to: payload.playerID)
            case .pointResolved:
                guard let loserID = payload.targetPlayerID,
                      loserID == startPayload.playerOneID || loserID == startPayload.playerTwoID else { return }
                presentPointResolution(
                    loserID: loserID,
                    matchFinished: payload.matchFinished ?? false
                )
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
                   roundID: state.roundID, eventID: UUID(), x: nil, velocityX: nil, speed: nil, rally: nil,
                   targetPlayerID: nil, matchFinished: nil))
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
            motion.stop(); nearbyService.stop(); onExitToHome(.localPlayerQuit); isQuitting = false
        }
    }

    private func opponentQuit() { motion.stop(); nearbyService.stop(); onExitToHome(.opponentQuit(playerName: opponentName)) }

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
    private func displayName(for playerID: String) -> String {
        playerID == localPlayerID ? localPlayerName : opponentName
    }
    private func playerColor(for playerID: String) -> Color {
        playerID == localPlayerID ? localColor : opponentColor
    }
    private var statusText: String {
        if state.isFinished { return "LINK CLOSED" }
        if !state.isRoundActive { return state.serverPlayerID == localPlayerID ? "READY TO SERVE" : "WAITING FOR \(opponentName.uppercased())" }
        if ball != nil { return "DEFLECT THE PULSE" }
        return "PULSE ACROSS THE LINK  •  RALLY \(state.rally)"
    }
}

private struct RicochetArenaMoment: Identifiable {
    enum Kind {
        case speedUp
        case point(winnerID: String, serverID: String, matchFinished: Bool)
    }

    let id = UUID()
    let kind: Kind
    let accent: Color
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double { min(max(self, range.lowerBound), range.upperBound) }
}
