import Combine
import SwiftUI
import UIKit

struct TiltRaceLocalView: View {
    let game: Game

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PlayerProfile.nameKey) private var playerName = ""
    @StateObject private var motion = TiltRaceMotionController()

    @State private var phase: LocalRacePhase = .ready
    @State private var currentPlayer = 0
    @State private var trackSeed = Int.random(in: 1...2_000_000_000)
    @State private var progress = 0
    @State private var playerTimes: [TimeInterval?] = [nil, nil]

    @State private var ballX = 0.5
    @State private var ballY = 0.91
    @State private var velocityX = 0.0
    @State private var velocityY = 0.0
    @State private var touchX = 0.5
    @State private var touchY = 0.91
    @State private var trail: [CGPoint] = []
    @State private var usesTouchControl = false

    @State private var now = Date()
    @State private var lastTick = Date()
    @State private var countdownEndsAt: Date?
    @State private var raceStartedAt: Date?
    @State private var pausedAt: Date?
    @State private var showQuitConfirmation = false
    @State private var passPhonePulse = false

    private let frameTimer = Timer.publish(
        every: 1.0 / 60.0,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        ZStack {
            TiltRaceTheme.background.ignoresSafeArea()

            VStack(spacing: 12) {
                header
                playerCards
                arena.frame(maxHeight: .infinity)
                controlBar
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            switch phase {
            case .ready:
                readyOverlay.zIndex(20)
            case .handoff:
                handoffOverlay.zIndex(20)
            case .finished:
                resultOverlay.zIndex(20)
            case .countdown, .racing:
                EmptyView()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .alert("Quit Tilt Race?", isPresented: $showQuitConfirmation) {
            Button("Quit Game", role: .destructive) {
                motion.stop()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current local race will be discarded.")
        }
        .onAppear {
            now = Date()
            lastTick = now
            motion.start(recalibrating: true)
            resetBall()
        }
        .onDisappear {
            motion.stop()
        }
        .onReceive(frameTimer, perform: tick)
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhase(newPhase)
        }
    }

    private var header: some View {
        HStack {
            Button { showQuitConfirmation = true } label: {
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
                    .foregroundStyle(activeColor)
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

    private var playerCards: some View {
        HStack(spacing: 10) {
            playerCard(
                index: 0,
                name: firstPlayerName,
                badge: "PLAYER 1",
                color: TiltRaceTheme.lime
            )
            playerCard(
                index: 1,
                name: "Guest",
                badge: "PLAYER 2",
                color: TiltRaceTheme.cyan
            )
        }
    }

    private func playerCard(
        index: Int,
        name: String,
        badge: String,
        color: Color
    ) -> some View {
        let isActive = currentPlayer == index && phase != .finished
        let displayedTime = timeToDisplay(for: index)

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .shadow(color: color, radius: isActive ? 6 : 0)
                Text(name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Spacer()
                Text(badge)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.white.opacity(0.34))
            }

            Text(displayedTime.map(formatTime) ?? "--:--.--")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(displayedTime == nil ? .white.opacity(0.24) : .white)

            HStack(spacing: 5) {
                Image(systemName: playerTimes[index] == nil ? "flag.fill" : "checkmark.circle.fill")
                Text(playerTimes[index] == nil ? (isActive ? "CURRENT RUN" : "WAITING") : "FINISHED")
            }
            .font(.system(size: 8, weight: .black, design: .rounded))
            .foregroundStyle(playerTimes[index] == nil && !isActive ? .white.opacity(0.28) : color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 17).fill(.white.opacity(0.045)))
        .overlay(
            RoundedRectangle(cornerRadius: 17)
                .stroke(isActive ? color.opacity(0.42) : color.opacity(0.12), lineWidth: 1)
        )
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

                ForEach(visibleCheckpoints) { checkpoint in
                    checkpointView(checkpoint)
                        .position(
                            x: proxy.size.width * checkpoint.x,
                            y: proxy.size.height * checkpoint.y
                        )
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.62).combined(with: .opacity),
                                removal: .scale(scale: 1.32).combined(with: .opacity)
                            )
                        )
                }

                ForEach(Array(trail.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(activeColor.opacity(
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

                if phase == .countdown {
                    countdownOverlay
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 27))
            .animation(
                .spring(response: 0.36, dampingFraction: 0.72),
                value: progress
            )
            .overlay(
                RoundedRectangle(cornerRadius: 27)
                    .stroke(activeColor.opacity(0.24), lineWidth: 1.2)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    guard phase == .racing,
                          usesTouchControl || !motion.isAvailable else { return }
                    touchX = (value.location.x / max(proxy.size.width, 1))
                        .clamped(to: 0.045...0.955)
                    touchY = (value.location.y / max(proxy.size.height, 1))
                        .clamped(to: 0.04...0.96)
                }
            )
        }
        .frame(minHeight: 340)
    }

    private func checkpointView(_ checkpoint: TiltRaceCheckpoint) -> some View {
        let completed = checkpoint.id < progress
        let isNext = checkpoint.id == progress

        return ZStack {
            if isNext {
                Circle()
                    .fill(activeColor.opacity(0.08))
                    .frame(width: 56, height: 56)
                Circle()
                    .stroke(activeColor.opacity(0.34), lineWidth: 1.5)
                    .frame(width: 54, height: 54)
            }

            Circle()
                .fill(completed ? activeColor.opacity(0.10) : Color.black.opacity(0.22))
                .frame(width: 40, height: 40)
            Circle()
                .stroke(
                    completed ? activeColor.opacity(0.38) :
                        (isNext ? activeColor : .white.opacity(0.20)),
                    lineWidth: isNext ? 3.5 : 2
                )
                .frame(width: 40, height: 40)

            if completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(activeColor.opacity(0.65))
            } else {
                Text("\(checkpoint.id + 1)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(isNext ? .white : .white.opacity(0.28))
            }

            if isNext {
                Image(systemName: "triangle.fill")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(activeColor)
                    .rotationEffect(.degrees(180))
                    .offset(y: -31)
            }
        }
        .shadow(color: isNext ? activeColor.opacity(0.58) : .clear, radius: 9)
    }

    private var racerBall: some View {
        ZStack {
            Circle()
                .fill(activeColor.opacity(0.22))
                .frame(width: 37, height: 37)
                .blur(radius: 5)
            Circle()
                .fill(RadialGradient(
                    colors: [.white, activeColor],
                    center: .topLeading,
                    startRadius: 1,
                    endRadius: 15
                ))
                .frame(width: 23, height: 23)
            Circle()
                .stroke(.white.opacity(0.7), lineWidth: 1)
                .frame(width: 23, height: 23)
        }
        .shadow(color: activeColor, radius: 12)
    }

    private var countdownOverlay: some View {
        VStack(spacing: 9) {
            Text("\(countdownValue)")
                .font(.system(size: 62, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: activeColor, radius: 18)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeInOut(duration: 0.28), value: countdownValue)
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
                    .foregroundStyle(activeColor)
                Text("Same track. Fastest time wins.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
    }

    private var overlayBackground: some View {
        Color.black.opacity(0.78)
            .ignoresSafeArea()
            .background(.ultraThinMaterial)
    }

    private var readyOverlay: some View {
        ZStack {
            overlayBackground

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(TiltRaceTheme.lime.opacity(0.14))
                        .frame(width: 92, height: 92)
                    Circle()
                        .stroke(TiltRaceTheme.lime.opacity(0.42), lineWidth: 1.5)
                        .frame(width: 92, height: 92)
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(TiltRaceTheme.lime)
                }

                VStack(spacing: 7) {
                    Text("PLAYER 1")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(2.2)
                        .foregroundStyle(TiltRaceTheme.lime)
                    Text("Ready to race?")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Complete all ten gates as quickly as possible. Player 2 will race on the exact same track.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                primaryButton(title: "START PLAYER 1", color: TiltRaceTheme.lime) {
                    startCountdown(for: 0)
                }
            }
            .padding(26)
            .frame(maxWidth: 390)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color(red: 0.035, green: 0.055, blue: 0.075))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(TiltRaceTheme.lime.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var handoffOverlay: some View {
        ZStack {
            overlayBackground

            VStack(spacing: 20) {
                Text("PLAYER 1 FINISHED")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(2.1)
                    .foregroundStyle(TiltRaceTheme.lime)

                Text(formatTime(playerTimes[0] ?? 0))
                    .font(.system(size: 39, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                ZStack {
                    Circle()
                        .fill(TiltRaceTheme.cyan.opacity(0.10))
                        .frame(width: 114, height: 114)
                        .scaleEffect(passPhonePulse ? 1.08 : 0.94)
                    Circle()
                        .stroke(TiltRaceTheme.cyan.opacity(0.45), lineWidth: 1.5)
                        .frame(width: 102, height: 102)
                    Image(systemName: "iphone")
                        .font(.system(size: 47, weight: .medium))
                        .foregroundStyle(.white)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(TiltRaceTheme.cyan)
                        .offset(x: 43, y: -35)
                }
                .animation(
                    .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                    value: passPhonePulse
                )

                VStack(spacing: 7) {
                    Text("PASS THE IPHONE")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(.white)
                    Text("Player 2 gets the same ten gates. The timer starts only after the countdown.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                primaryButton(title: "PLAYER 2 READY", color: TiltRaceTheme.cyan) {
                    passPhonePulse = false
                    startCountdown(for: 1)
                }
            }
            .padding(26)
            .frame(maxWidth: 390)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color(red: 0.035, green: 0.055, blue: 0.075))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(TiltRaceTheme.cyan.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
        .onAppear { passPhonePulse = true }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var resultOverlay: some View {
        ZStack {
            overlayBackground

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(resultAccent.opacity(0.14))
                        .frame(width: 96, height: 96)
                    Circle()
                        .stroke(resultAccent.opacity(0.42), lineWidth: 1.5)
                        .frame(width: 96, height: 96)
                    Image(systemName: resultIsTie ? "equal.circle.fill" : "trophy.fill")
                        .font(.system(size: 41, weight: .black))
                        .foregroundStyle(resultAccent)
                }

                VStack(spacing: 6) {
                    Text(resultTitle)
                        .font(.system(size: 29, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Same course. Fastest time wins.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                }

                VStack(spacing: 10) {
                    resultTimeRow(
                        name: firstPlayerName,
                        badge: "PLAYER 1",
                        time: playerTimes[0] ?? 0,
                        color: TiltRaceTheme.lime,
                        isWinner: winningPlayer == 0
                    )
                    resultTimeRow(
                        name: "Guest",
                        badge: "PLAYER 2",
                        time: playerTimes[1] ?? 0,
                        color: TiltRaceTheme.cyan,
                        isWinner: winningPlayer == 1
                    )
                }

                VStack(spacing: 10) {
                    primaryButton(title: "PLAY AGAIN", color: resultAccent, action: playAgain)

                    Button {
                        motion.stop()
                        dismiss()
                    } label: {
                        Text("EXIT GAME")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .tracking(1)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(.white.opacity(0.65))
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.white.opacity(0.055))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(26)
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color(red: 0.035, green: 0.055, blue: 0.075))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(resultAccent.opacity(0.26), lineWidth: 1)
            )
            .padding(.horizontal, 22)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }

    private func resultTimeRow(
        name: String,
        badge: String,
        time: TimeInterval,
        color: Color,
        isWinner: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .shadow(color: color, radius: 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(badge)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.34))
            }

            Spacer()

            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
            }

            Text(formatTime(time))
                .font(.system(size: 17, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isWinner ? color : .white.opacity(0.7))
        }
        .padding(.horizontal, 15)
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: 17)
                .fill(isWinner ? color.opacity(0.09) : .white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17)
                .stroke(isWinner ? color.opacity(0.30) : .white.opacity(0.07), lineWidth: 1)
        )
    }

    private func primaryButton(
        title: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text(title)
                Image(systemName: "arrow.right")
            }
            .font(.system(size: 14, weight: .black, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(Color.black.opacity(0.82))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 17)
            )
            .shadow(color: color.opacity(0.28), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
    }

    private func tick(_ date: Date) {
        now = date
        let dt = min(max(date.timeIntervalSince(lastTick), 0), 0.035)
        lastTick = date
        motion.updateHealth(at: date)

        if phase == .countdown {
            guard let countdownEndsAt, date >= countdownEndsAt else { return }
            raceStartedAt = date
            phase = .racing
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }

        guard phase == .racing, progress < TiltRaceGame.gateCount else { return }

        if usesTouchControl || !motion.isAvailable {
            ballX += (touchX - ballX) * min(1, dt * 15)
            ballY += (touchY - ballY) * min(1, dt * 15)
        } else if motion.isReady {
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
        } else {
            let recoveryDamping = pow(0.025, dt)
            velocityX *= recoveryDamping
            velocityY *= recoveryDamping
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
        guard phase == .racing, progress < TiltRaceGame.gateCount else { return }
        let checkpoint = checkpoints[progress]
        let dx = ballX - checkpoint.x
        let dy = ballY - checkpoint.y
        guard sqrt(dx * dx + dy * dy) < 0.072 else { return }

        progress += 1
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(
            intensity: min(1, 0.45 + Double(progress) * 0.07)
        )

        if progress == TiltRaceGame.gateCount {
            finishCurrentRun()
        }
    }

    private func finishCurrentRun() {
        guard let raceStartedAt else { return }
        let elapsed = max(0, now.timeIntervalSince(raceStartedAt))
        playerTimes[currentPlayer] = elapsed
        self.raceStartedAt = nil
        countdownEndsAt = nil
        velocityX = 0
        velocityY = 0
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
            phase = currentPlayer == 0 ? .handoff : .finished
        }
    }

    private func startCountdown(for player: Int) {
        currentPlayer = player
        resetBall()
        countdownEndsAt = Date().addingTimeInterval(3.2)
        raceStartedAt = nil
        now = Date()
        lastTick = now
        motion.calibrate()

        withAnimation(.easeInOut(duration: 0.24)) {
            phase = .countdown
        }
    }

    private func playAgain() {
        trackSeed = Int.random(in: 1...2_000_000_000)
        currentPlayer = 0
        playerTimes = [nil, nil]
        countdownEndsAt = nil
        raceStartedAt = nil
        passPhonePulse = false
        resetBall()
        motion.calibrate()

        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            phase = .ready
        }
    }

    private func resetBall() {
        progress = 0
        ballX = 0.5
        ballY = 0.91
        touchX = 0.5
        touchY = 0.91
        velocityX = 0
        velocityY = 0
        trail.removeAll()
    }

    private func handleScenePhase(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            let resumedAt = Date()
            if let pausedAt {
                let pauseDuration = resumedAt.timeIntervalSince(pausedAt)
                if let raceStartedAt {
                    self.raceStartedAt = raceStartedAt.addingTimeInterval(pauseDuration)
                }
                if let countdownEndsAt {
                    self.countdownEndsAt = countdownEndsAt.addingTimeInterval(pauseDuration)
                }
            }
            pausedAt = nil
            now = resumedAt
            lastTick = resumedAt
            velocityX = 0
            velocityY = 0
            motion.start(recalibrating: true)

        case .inactive, .background:
            if pausedAt == nil { pausedAt = Date() }
            velocityX = 0
            velocityY = 0
            motion.stop()

        @unknown default:
            break
        }
    }

    private func timeToDisplay(for player: Int) -> TimeInterval? {
        if let completed = playerTimes[player] { return completed }
        guard player == currentPlayer,
              phase == .racing,
              let raceStartedAt else { return nil }
        return max(0, now.timeIntervalSince(raceStartedAt))
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let totalCentiseconds = max(0, Int(interval * 100))
        let minutes = totalCentiseconds / 6_000
        let seconds = (totalCentiseconds / 100) % 60
        let centiseconds = totalCentiseconds % 100
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }

    private var checkpoints: [TiltRaceCheckpoint] {
        TiltRaceGame.checkpoints(for: trackSeed)
    }

    private var visibleCheckpoints: [TiltRaceCheckpoint] {
        guard progress < checkpoints.count else { return [] }
        return [checkpoints[progress]]
    }

    private var firstPlayerName: String {
        let trimmed = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "You" : trimmed
    }

    private var activeColor: Color {
        currentPlayer == 0 ? TiltRaceTheme.lime : TiltRaceTheme.cyan
    }

    private var countdownValue: Int {
        guard let countdownEndsAt else { return 3 }
        return min(3, max(1, Int(ceil(countdownEndsAt.timeIntervalSince(now)))))
    }

    private var controlTitle: String {
        if usesTouchControl || !motion.isAvailable { return "DRAG TO STEER" }
        if motion.isCalibrating { return "HOLD STEADY TO CALIBRATE" }
        if !motion.isReceivingUpdates { return "RECOVERING SENSOR" }
        return "TILT TO STEER"
    }

    private var statusText: String {
        switch phase {
        case .ready:
            return "PLAYER 1 READY"
        case .countdown:
            return "GET READY"
        case .racing:
            return "GATE \(min(progress + 1, TiltRaceGame.gateCount)) OF \(TiltRaceGame.gateCount)"
        case .handoff:
            return "PASS THE IPHONE"
        case .finished:
            return "RACE COMPLETE"
        }
    }

    private var winningPlayer: Int? {
        guard let first = playerTimes[0], let second = playerTimes[1] else { return nil }
        if abs(first - second) < 0.01 { return nil }
        return first < second ? 0 : 1
    }

    private var resultIsTie: Bool { winningPlayer == nil }

    private var resultTitle: String {
        switch winningPlayer {
        case 0:
            return "\(firstPlayerName) Wins!"
        case 1:
            return "Guest Wins!"
        default:
            return "It's a Tie!"
        }
    }

    private var resultAccent: Color {
        switch winningPlayer {
        case 0: return TiltRaceTheme.lime
        case 1: return TiltRaceTheme.cyan
        default: return TiltRaceTheme.violet
        }
    }
}

private enum LocalRacePhase: Equatable {
    case ready
    case countdown
    case racing
    case handoff
    case finished
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
