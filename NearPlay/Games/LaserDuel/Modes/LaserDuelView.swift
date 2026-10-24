import Combine
import SwiftUI
import UIKit

struct LaserDuelView: View {
    let game: Game
    @ObservedObject var nearbyService: NearbyService
    let localPlayerName: String
    let startPayload: LaserDuelStartPayload
    let onExitToHome: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var motion = LaserDuelMotionController()
    @StateObject private var rematchController: RematchController
    @State private var state: LaserDuelMatchState
    @State private var projectiles: [LaserDuelProjectile] = []
    @State private var manualShipX = 0.5
    @State private var remoteShipX = 0.5
    @State private var usesTouchControl = false
    @State private var handledEvents: Set<UUID> = []
    @State private var now = Date()
    @State private var lastTick = Date()
    @State private var lastPositionSentAt = Date.distantPast
    @State private var lastSentPosition = 0.5
    @State private var nextFireDate = Date.distantPast
    @State private var invulnerableUntil = Date.distantPast
    @State private var muzzleFlash = false
    @State private var remoteMuzzleFlash = false
    @State private var hitFlash = false
    @State private var shipHitPulse = false
    @State private var showQuit = false
    @State private var showResult = false
    @State private var isQuitting = false
    @State private var sessionScore = GameSessionScore()
    @State private var scoreRoundNumber = 1

    private let frameTimer = Timer.publish(
        every: 1.0 / 60.0,
        on: .main,
        in: .common
    ).autoconnect()
    private let shipY = 0.86
    private let enemyShipY = 0.105
    private let incomingMuzzleY = 0.18
    private let projectileSpeed = 1.18
    private let fireCooldown = 0.82

    init(
        game: Game,
        nearbyService: NearbyService,
        localPlayerName: String,
        startPayload: LaserDuelStartPayload,
        onExitToHome: @escaping () -> Void = {}
    ) {
        self.game = game
        self.nearbyService = nearbyService
        self.localPlayerName = localPlayerName
        self.startPayload = startPayload
        self.onExitToHome = onExitToHome

        var prepared = startPayload.initialState
        prepared.lives[startPayload.playerOneID] =
            prepared.lives[startPayload.playerOneID] ?? LaserDuelGame.startingLives
        prepared.lives[startPayload.playerTwoID] =
            prepared.lives[startPayload.playerTwoID] ?? LaserDuelGame.startingLives
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
            LaserDuelTheme.background.ignoresSafeArea()

            VStack(spacing: 12) {
                header
                scoreRow
                arena.frame(maxHeight: .infinity)
                controlBar
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            if showResult {
                resultOverlay.zIndex(20)
            }

            if isQuitting {
                Color.black.opacity(0.74).ignoresSafeArea()
                    .overlay(ProgressView("Leaving duel…").tint(.white))
                    .zIndex(30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .alert("Quit Laser Duel?", isPresented: $showQuit) {
            Button("Quit Game", role: .destructive, action: quitGame)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You and your opponent will return to the game list.")
        }
        .onAppear {
            motion.start()
            resetLocalRound()
        }
        .onDisappear { motion.stop() }
        .onReceive(frameTimer, perform: tick)
        .onReceive(nearbyService.$lastReceivedMessage) { handleIncoming($0) }
        .onChange(of: state.roundID) { _, _ in
            resetLocalRound()
            showResult = false
        }
        .onChange(of: state.winnerPlayerID) { _, winner in
            guard winner != nil else {
                showResult = false
                return
            }
            projectiles.removeAll()
            UINotificationFeedbackGenerator().notificationOccurred(
                winner == localPlayerID ? .success : .warning
            )
        }
        .onChange(of: rematchController.confirmedRoundNumber) { _, confirmedRound in
            guard let confirmedRound else { return }
            scoreRoundNumber = confirmedRound
            showResult = false

            if isHost {
                state = LaserDuelGame.makeInitialState(
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
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled, state.isFinished else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { showResult = true }
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
                Text("LASER DUEL")
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .tracking(1.3)
                Text(statusText)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(localColor)
            }

            Spacer()

            Button {
                motion.calibrate()
                manualShipX = 0.5
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

    private var scoreRow: some View {
        HStack(spacing: 10) {
            playerCard(
                name: localPlayerName,
                playerID: localPlayerID,
                color: localColor,
                label: "YOU"
            )
            playerCard(
                name: opponentName,
                playerID: opponentID,
                color: opponentColor,
                label: "RIVAL"
            )
        }
    }

    private func playerCard(
        name: String,
        playerID: String,
        color: Color,
        label: String
    ) -> some View {
        let lives = state.lives(for: playerID)
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

            HStack(spacing: 7) {
                ForEach(0..<LaserDuelGame.startingLives, id: \.self) { index in
                    Image(systemName: index < lives ? "shield.fill" : "shield")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(color.opacity(index < lives ? 1 : 0.22))
                        .contentTransition(.symbolEffect(.replace))
                }
            }
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
                            Color(red: 0.025, green: 0.07, blue: 0.13),
                            Color(red: 0.10, green: 0.025, blue: 0.09)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ))

                arenaGrid(in: proxy.size)
                transferPortal(width: proxy.size.width)
                    .position(x: proxy.size.width / 2, y: 9)

                enemyShip
                    .position(
                        x: proxy.size.width * remoteShipX,
                        y: proxy.size.height * enemyShipY
                    )

                if remoteMuzzleFlash {
                    LaserBurst(color: opponentColor)
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(180))
                        .position(
                            x: proxy.size.width * remoteShipX,
                            y: proxy.size.height * incomingMuzzleY
                        )
                        .transition(.scale.combined(with: .opacity))
                }

                ForEach(projectiles) { projectile in
                    projectileView(projectile)
                        .position(
                            x: proxy.size.width * projectile.x,
                            y: proxy.size.height * projectile.y
                        )
                }

                if muzzleFlash {
                    LaserBurst(color: localColor)
                        .frame(width: 54, height: 54)
                        .position(
                            x: proxy.size.width * shipX,
                            y: proxy.size.height * (shipY - 0.07)
                        )
                        .transition(.scale.combined(with: .opacity))
                }

                localShip
                    .scaleEffect(shipHitPulse ? 1.18 : 1)
                    .position(
                        x: proxy.size.width * shipX,
                        y: proxy.size.height * shipY
                    )

                if !hasDuelStarted && !state.isFinished {
                    countdownOverlay
                }

                if hitFlash {
                    Color.red.opacity(0.30)
                    VStack(spacing: 6) {
                        Image(systemName: "burst.fill")
                            .font(.system(size: 66, weight: .bold))
                        Text("DIRECT HIT")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .tracking(1.5)
                    }
                    .foregroundStyle(.white, LaserDuelTheme.crimson)
                    .transition(.opacity.combined(with: .scale))
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
                    manualShipX = (value.location.x / max(proxy.size.width, 1))
                        .clamped(to: 0.08...0.92)
                }
            )
        }
        .frame(minHeight: 350)
    }

    private func arenaGrid(in size: CGSize) -> some View {
        Canvas { context, _ in
            var path = Path()
            for column in 1..<9 {
                let x = size.width * CGFloat(column) / 9
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for row in 1..<13 {
                let y = size.height * CGFloat(row) / 13
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(
                path,
                with: .color(localColor.opacity(0.055)),
                lineWidth: 1
            )
        }
    }

    private func transferPortal(width: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(opponentColor.opacity(0.12))
                .frame(width: width * 0.66, height: 18)
                .blur(radius: 8)
            Capsule()
                .fill(LinearGradient(
                    colors: [.clear, opponentColor, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: width * 0.72, height: 3)
            Text("LINKED TO \(opponentName.uppercased())")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.42))
                .offset(y: 15)
        }
    }

    private var localShip: some View {
        LaserDuelShip(color: localColor, isEnemy: false)
            .shadow(color: localColor.opacity(0.72), radius: 13)
            .animation(
                .interactiveSpring(response: 0.16, dampingFraction: 0.76),
                value: shipX
            )
    }

    private var enemyShip: some View {
        LaserDuelShip(color: opponentColor, isEnemy: true)
            .opacity(0.48)
            .scaleEffect(0.74)
            .shadow(color: opponentColor.opacity(0.55), radius: 10)
            .animation(.easeOut(duration: 0.12), value: remoteShipX)
    }

    private func projectileView(_ projectile: LaserDuelProjectile) -> some View {
        let color = projectile.isIncoming ? opponentColor : localColor
        return ZStack {
            Capsule().fill(color.opacity(0.22)).frame(width: 18, height: 62).blur(radius: 8)
            Capsule().fill(color).frame(width: 7, height: 48)
            Capsule().fill(.white).frame(width: 2.5, height: 42)
            Circle().fill(.white).frame(width: 9, height: 9)
                .offset(y: projectile.direction > 0 ? 22 : -22)
        }
        .shadow(color: color, radius: 12)
    }

    private var countdownOverlay: some View {
        VStack(spacing: 8) {
            Text(countdownText)
                .font(.system(size: 62, weight: .black, design: .rounded))
                .contentTransition(.numericText())
                .shadow(color: localColor, radius: 18)
            Text("WEAPONS ARMING")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.48))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button {
                let willUseTouch = !usesTouchControl
                manualShipX = shipX
                usesTouchControl = willUseTouch
                if !willUseTouch { motion.calibrate() }
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: usesTouchControl ? "hand.draw.fill" : "gyroscope")
                        .font(.system(size: 18, weight: .bold))
                    Text(usesTouchControl ? "TOUCH" : "TILT")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                }
                .frame(width: 66, height: 54)
                .background(RoundedRectangle(cornerRadius: 17).fill(.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.10)))
            }
            .buttonStyle(.plain)

            Button(action: fire) {
                ZStack {
                    Capsule()
                        .fill(canFire ? localColor : .white.opacity(0.07))
                    if !canFire && hasDuelStarted && !state.isFinished {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(localColor.opacity(0.20))
                                .frame(
                                    width: proxy.size.width * cooldownProgress,
                                    alignment: .leading
                                )
                        }
                    }
                    HStack(spacing: 9) {
                        Image(systemName: "scope")
                            .font(.system(size: 19, weight: .black))
                        Text(canFire ? "FIRE" : "RECHARGING")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .tracking(0.8)
                    }
                    .foregroundStyle(canFire ? Color.black.opacity(0.82) : .white.opacity(0.38))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .shadow(color: canFire ? localColor.opacity(0.45) : .clear, radius: 12)
            }
            .buttonStyle(.plain)
            .disabled(!canFire)
        }
        .foregroundStyle(.white)
    }

    private var resultOverlay: some View {
        GameResultOverlay(
            result: localRoundResult,
            title: didLocalPlayerWin ? "Duel Won!" : "\(opponentName) Wins",
            subtitle: didLocalPlayerWin ? "Enemy shields eliminated." : "Your shields were eliminated.",
            symbolName: didLocalPlayerWin ? "scope" : "shield.slash.fill",
            accentColor: didLocalPlayerWin ? localColor : opponentColor,
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
        let dt = min(max(date.timeIntervalSince(lastTick), 0), 0.035)
        lastTick = date

        sendPositionIfNeeded(at: date)

        guard hasDuelStarted, !state.isFinished else { return }

        var survivors: [LaserDuelProjectile] = []
        for var projectile in projectiles {
            let previousY = projectile.y
            projectile.y += projectile.direction * projectileSpeed * dt

            if projectile.isIncoming,
               previousY < shipY,
               projectile.y >= shipY {
                if abs(projectile.x - shipX) <= 0.085,
                   date >= invulnerableUntil {
                    registerLocalHit(at: date)
                }
                continue
            }

            if projectile.isIncoming {
                if projectile.y <= 1.06 { survivors.append(projectile) }
            } else if projectile.y <= -0.04 {
                continue
            } else {
                survivors.append(projectile)
            }
        }
        projectiles = survivors
    }

    private func fire() {
        guard canFire else { return }
        nextFireDate = now.addingTimeInterval(fireCooldown)
        let projectileID = UUID()
        let launchX = shipX
        projectiles.append(LaserDuelProjectile(
            id: projectileID,
            x: launchX,
            y: shipY - 0.075,
            direction: -1,
            isIncoming: false
        ))
        sendAction(
            kind: .projectile,
            eventID: projectileID,
            targetPlayerID: opponentID,
            x: launchX
        )
        lastPositionSentAt = now
        lastSentPosition = launchX
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.72)
        withAnimation(.easeOut(duration: 0.10)) { muzzleFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.12)) { muzzleFlash = false }
        }
    }

    private func registerLocalHit(at date: Date) {
        invulnerableUntil = date.addingTimeInterval(0.78)
        UINotificationFeedbackGenerator().notificationOccurred(.error)

        withAnimation(.spring(response: 0.20, dampingFraction: 0.48)) {
            hitFlash = true
            shipHitPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.easeOut(duration: 0.26)) {
                hitFlash = false
                shipHitPulse = false
            }
        }

        if isHost {
            applyDamage(to: localPlayerID)
        } else {
            sendAction(
                kind: .hit,
                targetPlayerID: localPlayerID,
                x: nil
            )
        }
    }

    private func applyDamage(to playerID: String) {
        guard !state.isFinished,
              playerID == startPayload.playerOneID || playerID == startPayload.playerTwoID else {
            return
        }

        let remaining = max(0, state.lives(for: playerID) - 1)
        state.lives[playerID] = remaining
        if remaining == 0 {
            state.winnerPlayerID = playerID == startPayload.playerOneID
                ? startPayload.playerTwoID
                : startPayload.playerOneID
        }
        broadcastState()
    }

    private func sendPositionIfNeeded(at date: Date) {
        guard !state.isFinished else { return }
        let elapsed = date.timeIntervalSince(lastPositionSentAt)
        guard elapsed >= 0.25,
              abs(shipX - lastSentPosition) >= 0.025 || elapsed >= 1.0 else {
            return
        }
        lastPositionSentAt = date
        lastSentPosition = shipX
        sendAction(kind: .position, targetPlayerID: nil, x: shipX)
    }

    private func sendAction(
        kind: LaserDuelActionKind,
        eventID: UUID = UUID(),
        targetPlayerID: String?,
        x: Double?
    ) {
        let payload = LaserDuelActionPayload(
            sessionID: startPayload.sessionID,
            roundID: state.roundID,
            eventID: eventID,
            kind: kind,
            playerID: localPlayerID,
            targetPlayerID: targetPlayerID,
            x: x
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
        if rematchController.handleIncoming(message) { return }

        switch message.type {
        case .gameAction:
            guard let data = message.payload,
                  let payload = try? JSONDecoder().decode(LaserDuelActionPayload.self, from: data),
                  payload.sessionID == startPayload.sessionID,
                  payload.roundID == state.roundID,
                  payload.playerID == opponentID else { return }
            handleAction(payload)

        case .gameState:
            guard let data = message.payload,
                  let payload = try? JSONDecoder().decode(LaserDuelStatePayload.self, from: data),
                  payload.sessionID == startPayload.sessionID else { return }
            state = payload.state

        case .gameQuit:
            opponentQuit()

        default:
            break
        }
    }

    private func handleAction(_ payload: LaserDuelActionPayload) {
        switch payload.kind {
        case .position:
            guard let x = payload.x else { return }
            remoteShipX = x.clamped(to: 0.08...0.92)

        case .projectile:
            guard payload.targetPlayerID == localPlayerID,
                  let x = payload.x,
                  handledEvents.insert(payload.eventID).inserted else { return }
            remoteShipX = x.clamped(to: 0.08...0.92)
            projectiles.append(LaserDuelProjectile(
                id: payload.eventID,
                x: x.clamped(to: 0.04...0.96),
                y: incomingMuzzleY,
                direction: 1,
                isIncoming: true
            ))
            withAnimation(.easeOut(duration: 0.08)) {
                remoteMuzzleFlash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation(.easeOut(duration: 0.12)) {
                    remoteMuzzleFlash = false
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.35)

        case .hit:
            guard isHost,
                  payload.targetPlayerID == payload.playerID,
                  handledEvents.insert(payload.eventID).inserted else { return }
            applyDamage(to: payload.playerID)
        }
    }

    private func broadcastState() {
        let payload = LaserDuelStatePayload(
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

    private func resetLocalRound() {
        projectiles.removeAll()
        handledEvents.removeAll()
        manualShipX = 0.5
        remoteShipX = 0.5
        nextFireDate = Date.distantPast
        invulnerableUntil = Date.distantPast
        now = Date()
        lastTick = now
        lastPositionSentAt = .distantPast
        lastSentPosition = 0.5
        hitFlash = false
        muzzleFlash = false
        remoteMuzzleFlash = false
        shipHitPulse = false
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

    private var shipX: Double {
        usesTouchControl || !motion.isAvailable ? manualShipX : motion.position
    }

    private var canFire: Bool {
        hasDuelStarted && !state.isFinished && now >= nextFireDate
    }

    private var cooldownProgress: Double {
        let remaining = max(0, nextFireDate.timeIntervalSince(now))
        return (1 - remaining / fireCooldown).clamped(to: 0...1)
    }

    private var hasDuelStarted: Bool { now >= state.startsAt }
    private var countdownText: String {
        String(max(1, Int(ceil(state.startsAt.timeIntervalSince(now)))))
    }
    private var didLocalPlayerWin: Bool { state.winnerPlayerID == localPlayerID }
    private var localRoundResult: GameRoundResult { didLocalPlayerWin ? .win : .loss }
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
            ? LaserDuelTheme.cyan
            : LaserDuelTheme.crimson
    }
    private var opponentColor: Color {
        localPlayerID == startPayload.playerOneID
            ? LaserDuelTheme.crimson
            : LaserDuelTheme.cyan
    }
    private var statusText: String {
        if state.isFinished { return "DUEL COMPLETE" }
        if !hasDuelStarted { return "GET READY" }
        return canFire ? "WEAPON READY" : "RECHARGING"
    }
}

private struct LaserDuelShip: View {
    let color: Color
    let isEnemy: Bool

    var body: some View {
        ZStack {
            Capsule()
                .fill(color.opacity(0.20))
                .frame(width: 76, height: 30)
                .blur(radius: 7)
            RoundedRectangle(cornerRadius: 11)
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.78), color, color.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 66, height: 25)
            Capsule()
                .fill(Color.black.opacity(0.64))
                .frame(width: 30, height: 13)
            Capsule()
                .fill(color)
                .frame(width: 9, height: 37)
                .offset(y: -17)
            Capsule()
                .fill(.white)
                .frame(width: 3, height: 29)
                .offset(y: -17)
            Circle().fill(.white).frame(width: 9, height: 9)
                .shadow(color: color, radius: 8)
        }
        .rotationEffect(.degrees(isEnemy ? 180 : 0))
    }
}

private struct LaserBurst: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.28)).blur(radius: 6)
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? Color.white : color)
                    .frame(width: 3, height: 22)
                    .offset(y: -15)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
