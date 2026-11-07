import Combine
import SwiftUI
import UIKit

struct SwipeRushLocalView: View {
    let game: Game

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PlayerProfile.nameKey) private var playerName = ""

    @State private var phase: SwipeRushLocalPhase = .ready
    @State private var currentPlayer = 0
    @State private var runSeed = Int.random(in: 1...2_000_000_000)
    @State private var results: [SwipeRushRunResult?] = [nil, nil]
    @State private var progress = SwipeRushPlayerProgress()

    @State private var now = Date()
    @State private var countdownEndsAt: Date?
    @State private var runStartedAt: Date?
    @State private var promptStartedAt: Date?
    @State private var promptDeadline: Date?
    @State private var pausedAt: Date?

    @State private var feedbackText: String?
    @State private var feedbackColor = SwipeRushTheme.magenta
    @State private var feedbackToken: UUID?
    @State private var showQuitConfirmation = false
    @State private var passPhonePulse = false

    private let frameTimer = Timer.publish(
        every: 1.0 / 30.0,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        ZStack {
            SwipeRushTheme.background.ignoresSafeArea()

            VStack(spacing: 12) {
                header
                instructionCard
                statCards
                arena.frame(maxHeight: .infinity)
                footer
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 13)

            if let feedbackText, phase == .racing {
                feedbackBanner(text: feedbackText, color: feedbackColor)
                    .zIndex(12)
                    .transition(.scale(scale: 0.82).combined(with: .opacity))
            }

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
        .alert("Quit Swipe Rush?", isPresented: $showQuitConfirmation) {
            Button("Quit Game", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current local match will be discarded.")
        }
        .onAppear { now = Date() }
        .onReceive(frameTimer, perform: tick)
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhase(newPhase)
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
                Text("PLAYER \(currentPlayer + 1) · \(phaseStatus)")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(playerColor)
            }

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .bold))
                Text(formatRemainingTime)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(remainingTime <= 10 && phase == .racing ? SwipeRushTheme.magenta : .white)
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background(Capsule().fill(.white.opacity(0.07)))
            .overlay(Capsule().stroke(playerColor.opacity(0.28), lineWidth: 1))
        }
        .padding(.top, 5)
    }

    private var instructionCard: some View {
        let direction = currentTarget.direction
        let color = SwipeRushTheme.color(for: direction)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 45, height: 45)
                Image(systemName: direction.symbolName)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(phase == .racing ? "SWIPE \(direction.title)" : "SWIPE FROM THE GLOWING ARROW")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("React fast, keep your combo, and avoid wrong directions.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.40))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "hand.draw.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(playerColor)
        }
        .padding(.horizontal, 13)
        .frame(height: 68)
        .background(RoundedRectangle(cornerRadius: 19).fill(.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var statCards: some View {
        HStack(spacing: 9) {
            statCard(title: "SCORE", value: "\(progress.score)", symbol: "bolt.fill", color: SwipeRushTheme.magenta)
            statCard(title: "COMBO", value: "×\(progress.combo)", symbol: "flame.fill", color: SwipeRushTheme.cyan)
            statCard(title: "MISTAKES", value: "\(progress.mistakes)", symbol: "xmark.circle.fill", color: SwipeRushTheme.orange)
        }
    }

    private func statCard(title: String, value: String, symbol: String, color: Color) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.system(size: 8, weight: .black, design: .rounded))
            .foregroundStyle(color.opacity(0.80))

            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 59)
        .background(RoundedRectangle(cornerRadius: 16).fill(color.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.16), lineWidth: 1))
    }

    private var arena: some View {
        ZStack {
            SwipeRushArena(
                target: currentTarget,
                targetSize: CGFloat(SwipeRushGame.targetSize(after: progress.completedSwipes)),
                timeProgress: promptTimeProgress,
                accentColor: playerColor,
                isActive: phase == .racing,
                onSwipe: handleSwipe,
                onInvalidSwipe: { registerMistake(message: "START ON THE ARROW") }
            )

            if phase == .countdown {
                countdownOverlay
            }
        }
        .frame(minHeight: 330)
    }

    private var countdownOverlay: some View {
        VStack(spacing: 9) {
            Text("\(countdownValue)")
                .font(.system(size: 66, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: playerColor, radius: 20)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeInOut(duration: 0.28), value: countdownValue)
            Text("GET READY TO SWIPE")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.7)
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .foregroundStyle(playerColor)
            Text("Start on the target, then swipe in its direction")
            Spacer()
            Text("\(Int(promptTimeLimit * 1000)) MS")
                .foregroundStyle(.white.opacity(0.34))
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

    private var overlayBackground: some View {
        Color.black.opacity(0.82)
            .ignoresSafeArea()
            .background(.ultraThinMaterial)
    }

    private var readyOverlay: some View {
        ZStack {
            overlayBackground
            overlayCard(borderColor: SwipeRushTheme.magenta) {
                VStack(spacing: 19) {
                    ZStack {
                        Circle()
                            .fill(SwipeRushTheme.magenta.opacity(0.14))
                            .frame(width: 92, height: 92)
                        Circle()
                            .stroke(SwipeRushTheme.magenta.opacity(0.42), lineWidth: 1.5)
                            .frame(width: 92, height: 92)
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: 38, weight: .black))
                            .foregroundStyle(SwipeRushTheme.magenta)
                    }

                    VStack(spacing: 7) {
                        Text("PLAYER 1")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(2.2)
                            .foregroundStyle(SwipeRushTheme.magenta)
                        Text("Ready to swipe?")
                            .font(.system(size: 29, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Start on each glowing arrow and swipe in its direction. Build the highest score in 60 seconds.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    HStack(spacing: 8) {
                        rulePill("FAST", subtitle: "REACTION", color: SwipeRushTheme.cyan)
                        rulePill("COMBO", subtitle: "BONUS", color: SwipeRushTheme.lime)
                        rulePill("−3", subtitle: "MISTAKE", color: SwipeRushTheme.orange)
                    }

                    primaryButton(title: "START PLAYER 1", color: SwipeRushTheme.magenta) {
                        startCountdown(for: 0)
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var handoffOverlay: some View {
        ZStack {
            overlayBackground
            overlayCard(borderColor: SwipeRushTheme.cyan) {
                VStack(spacing: 18) {
                    Text("PLAYER 1 FINISHED")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(2.1)
                        .foregroundStyle(SwipeRushTheme.magenta)

                    HStack(spacing: 18) {
                        resultMetric(value: "\(results[0]?.score ?? 0)", label: "SCORE", color: SwipeRushTheme.magenta)
                        resultMetric(value: "\(results[0]?.completedSwipes ?? 0)", label: "SWIPES", color: SwipeRushTheme.cyan)
                        resultMetric(value: "×\(results[0]?.bestCombo ?? 0)", label: "BEST COMBO", color: SwipeRushTheme.lime)
                    }

                    ZStack {
                        Circle()
                            .fill(SwipeRushTheme.cyan.opacity(0.10))
                            .frame(width: 110, height: 110)
                            .scaleEffect(passPhonePulse ? 1.08 : 0.94)
                        Circle()
                            .stroke(SwipeRushTheme.cyan.opacity(0.44), lineWidth: 1.5)
                            .frame(width: 98, height: 98)
                        Image(systemName: "iphone")
                            .font(.system(size: 46, weight: .medium))
                            .foregroundStyle(.white)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 21, weight: .black))
                            .foregroundStyle(SwipeRushTheme.cyan)
                            .offset(x: 42, y: -34)
                    }
                    .animation(
                        .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                        value: passPhonePulse
                    )

                    VStack(spacing: 7) {
                        Text("PASS THE IPHONE")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Player 2 receives the exact same arrows and positions.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                    }

                    primaryButton(title: "PLAYER 2 READY", color: SwipeRushTheme.cyan) {
                        passPhonePulse = false
                        startCountdown(for: 1)
                    }
                }
            }
        }
        .onAppear { passPhonePulse = true }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var resultOverlay: some View {
        ZStack {
            overlayBackground
            overlayCard(borderColor: resultAccent) {
                VStack(spacing: 18) {
                    Image(systemName: winningPlayer == nil ? "equal.circle.fill" : "trophy.fill")
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(resultAccent)
                        .shadow(color: resultAccent.opacity(0.45), radius: 18)

                    VStack(spacing: 5) {
                        Text(resultTitle)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Fast reactions and long combos win the rush.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.48))
                    }

                    VStack(spacing: 9) {
                        resultRow(name: firstPlayerName, badge: "PLAYER 1", result: results[0], color: SwipeRushTheme.magenta, isWinner: winningPlayer == 0)
                        resultRow(name: "Guest", badge: "PLAYER 2", result: results[1], color: SwipeRushTheme.cyan, isWinner: winningPlayer == 1)
                    }

                    primaryButton(title: "PLAY AGAIN", color: resultAccent, action: playAgain)

                    Button { dismiss() } label: {
                        Text("EXIT GAME")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.64))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.055)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }

    private func overlayCard<Content: View>(
        borderColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let cardContent = content()

        return GeometryReader { geometry in
            ScrollView {
                cardContent
                    .padding(25)
                    .frame(maxWidth: 400)
                    .background(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(Color(red: 0.045, green: 0.045, blue: 0.075))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(borderColor.opacity(0.26), lineWidth: 1)
                    )
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func rulePill(_ value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(subtitle)
                .font(.system(size: 7, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.34))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 13).fill(color.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(color.opacity(0.15), lineWidth: 1))
    }

    private func resultMetric(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.34))
        }
        .frame(maxWidth: .infinity)
    }

    private func resultRow(
        name: String,
        badge: String,
        result: SwipeRushRunResult?,
        color: Color,
        isWinner: Bool
    ) -> some View {
        HStack(spacing: 11) {
            Circle().fill(color).frame(width: 9, height: 9).shadow(color: color, radius: 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(result?.completedSwipes ?? 0) swipes · ×\(result?.bestCombo ?? 0) best combo")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.40))
            }
            Spacer()
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
            }
            Text("\(result?.score ?? 0)")
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(isWinner ? color : .white.opacity(0.72))
        }
        .padding(.horizontal, 14)
        .frame(height: 62)
        .background(RoundedRectangle(cornerRadius: 17).fill(isWinner ? color.opacity(0.09) : .white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(isWinner ? color.opacity(0.30) : .white.opacity(0.07), lineWidth: 1))
    }

    private func primaryButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text(title)
                Image(systemName: "arrow.right")
            }
            .font(.system(size: 14, weight: .black, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(Color.black.opacity(0.80))
            .frame(maxWidth: .infinity)
            .frame(height: 53)
            .background(
                LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 17)
            )
            .shadow(color: color.opacity(0.26), radius: 14, y: 7)
        }
        .buttonStyle(.plain)
    }

    private func tick(_ date: Date) {
        now = date

        if phase == .countdown {
            guard let countdownEndsAt, date >= countdownEndsAt else { return }
            beginRun(at: date)
            return
        }

        guard phase == .racing else { return }
        if remainingTime <= 0 {
            finishCurrentRun()
        } else if let promptDeadline, date >= promptDeadline {
            registerMistake(message: "TOO SLOW")
        }
    }

    private func handleSwipe(_ direction: SwipeRushDirection) {
        guard phase == .racing else { return }
        let eventDate = Date()
        now = eventDate

        guard direction == currentTarget.direction else {
            registerMistake(message: "WRONG DIRECTION")
            return
        }

        let reactionTime = max(0, eventDate.timeIntervalSince(promptStartedAt ?? eventDate))
        progress.combo += 1
        progress.bestCombo = max(progress.bestCombo, progress.combo)
        let points = SwipeRushGame.points(reactionTime: reactionTime, combo: progress.combo)
        progress.score += points
        progress.completedSwipes += 1
        progress.totalReactionTime += reactionTime
        advancePrompt(at: eventDate)
        showFeedback("PERFECT +\(points) · ×\(progress.combo)", color: SwipeRushTheme.cyan)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.65)
    }

    private func registerMistake(message: String) {
        guard phase == .racing else { return }
        progress.mistakes += 1
        progress.combo = 0
        progress.score = max(0, progress.score - SwipeRushGame.mistakePenalty)
        advancePrompt(at: Date())
        showFeedback("−\(SwipeRushGame.mistakePenalty) · \(message)", color: SwipeRushTheme.orange)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func advancePrompt(at date: Date) {
        progress.challengeIndex += 1
        promptStartedAt = date
        promptDeadline = date.addingTimeInterval(promptTimeLimit)
    }

    private func showFeedback(_ text: String, color: Color) {
        let token = UUID()
        feedbackToken = token
        feedbackColor = color
        withAnimation(.spring(response: 0.30, dampingFraction: 0.76)) {
            feedbackText = text
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.68) {
            guard feedbackToken == token else { return }
            withAnimation(.easeOut(duration: 0.18)) { feedbackText = nil }
        }
    }

    private func startCountdown(for player: Int) {
        currentPlayer = player
        resetRunState()
        let date = Date()
        now = date
        countdownEndsAt = date.addingTimeInterval(3.2)
        withAnimation(.easeInOut(duration: 0.24)) { phase = .countdown }
    }

    private func beginRun(at date: Date) {
        runStartedAt = date
        promptStartedAt = date
        promptDeadline = date.addingTimeInterval(promptTimeLimit)
        countdownEndsAt = nil
        withAnimation(.easeOut(duration: 0.18)) { phase = .racing }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func finishCurrentRun() {
        guard phase == .racing else { return }
        results[currentPlayer] = progress.result
        runStartedAt = nil
        promptStartedAt = nil
        promptDeadline = nil
        feedbackText = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
            phase = currentPlayer == 0 ? .handoff : .finished
        }
    }

    private func playAgain() {
        runSeed = Int.random(in: 1...2_000_000_000)
        currentPlayer = 0
        results = [nil, nil]
        passPhonePulse = false
        resetRunState()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) { phase = .ready }
    }

    private func resetRunState() {
        progress = SwipeRushPlayerProgress()
        runStartedAt = nil
        promptStartedAt = nil
        promptDeadline = nil
        countdownEndsAt = nil
        feedbackText = nil
        feedbackToken = nil
    }

    private func handleScenePhase(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            let resumedAt = Date()
            if let pausedAt {
                let pauseDuration = resumedAt.timeIntervalSince(pausedAt)
                shiftDate(&countdownEndsAt, by: pauseDuration)
                shiftDate(&runStartedAt, by: pauseDuration)
                shiftDate(&promptStartedAt, by: pauseDuration)
                shiftDate(&promptDeadline, by: pauseDuration)
            }
            pausedAt = nil
            now = resumedAt
        case .inactive, .background:
            if pausedAt == nil { pausedAt = Date() }
        @unknown default:
            break
        }
    }

    private func shiftDate(_ date: inout Date?, by interval: TimeInterval) {
        guard let current = date else { return }
        date = current.addingTimeInterval(interval)
    }

    private var currentTarget: SwipeRushTarget {
        SwipeRushGame.target(seed: runSeed, index: progress.challengeIndex)
    }

    private var promptTimeLimit: TimeInterval {
        SwipeRushGame.promptTimeLimit(after: progress.completedSwipes)
    }

    private var promptTimeProgress: Double {
        guard phase == .racing, let promptDeadline else { return 1 }
        return max(0, min(1, promptDeadline.timeIntervalSince(now) / promptTimeLimit))
    }

    private var firstPlayerName: String {
        let trimmed = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "You" : trimmed
    }

    private var playerColor: Color {
        currentPlayer == 0 ? SwipeRushTheme.magenta : SwipeRushTheme.cyan
    }

    private var remainingTime: TimeInterval {
        guard phase == .racing, let runStartedAt else { return SwipeRushGame.runDuration }
        return max(0, SwipeRushGame.runDuration - now.timeIntervalSince(runStartedAt))
    }

    private var formatRemainingTime: String { String(format: "%04.1f", remainingTime) }

    private var countdownValue: Int {
        guard let countdownEndsAt else { return 3 }
        return min(3, max(1, Int(ceil(countdownEndsAt.timeIntervalSince(now)))))
    }

    private var phaseStatus: String {
        switch phase {
        case .ready: "READY"
        case .countdown: "GET READY"
        case .racing: "SWIPE \(progress.completedSwipes + 1)"
        case .handoff: "PASS THE IPHONE"
        case .finished: "COMPLETE"
        }
    }

    private var winningPlayer: Int? {
        guard let first = results[0], let second = results[1] else { return nil }
        let winner = SwipeRushGame.winner(
            firstPlayerID: "player-1",
            first: first,
            secondPlayerID: "player-2",
            second: second
        )
        if winner == "player-1" { return 0 }
        if winner == "player-2" { return 1 }
        return nil
    }

    private var resultTitle: String {
        switch winningPlayer {
        case 0: "\(firstPlayerName) Wins!"
        case 1: "Guest Wins!"
        default: "It's a Tie!"
        }
    }

    private var resultAccent: Color {
        switch winningPlayer {
        case 0: SwipeRushTheme.magenta
        case 1: SwipeRushTheme.cyan
        default: SwipeRushTheme.violet
        }
    }
}

private enum SwipeRushLocalPhase: Equatable {
    case ready
    case countdown
    case racing
    case handoff
    case finished
}
