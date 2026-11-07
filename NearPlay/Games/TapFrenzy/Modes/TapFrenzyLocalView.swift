import Combine
import SwiftUI
import UIKit

struct TapFrenzyLocalView: View {
    let game: Game

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PlayerProfile.nameKey) private var playerName = ""

    @State private var phase: TapFrenzyLocalPhase = .ready
    @State private var currentPlayer = 0
    @State private var runSeed = Int.random(in: 1...2_000_000_000)
    @State private var results: [TapFrenzyRunResult?] = [nil, nil]

    @State private var score = 0
    @State private var completedSequences = 0
    @State private var mistakes = 0
    @State private var totalSequenceTime: TimeInterval = 0
    @State private var expectedNumber = 1
    @State private var targets: [TapFrenzyTarget] = []
    @State private var relocationRound = 0

    @State private var now = Date()
    @State private var countdownEndsAt: Date?
    @State private var runStartedAt: Date?
    @State private var sequenceStartedAt: Date?
    @State private var nextRelocationAt: Date?
    @State private var pausedAt: Date?

    @State private var feedbackText: String?
    @State private var feedbackColor = TapFrenzyTheme.coral
    @State private var feedbackToken: UUID?
    @State private var wrongTargetNumber: Int?
    @State private var showQuitConfirmation = false
    @State private var targetPulse = false
    @State private var passPhonePulse = false

    private let frameTimer = Timer.publish(
        every: 1.0 / 30.0,
        on: .main,
        in: .common
    ).autoconnect()

    var body: some View {
        ZStack {
            TapFrenzyTheme.background.ignoresSafeArea()

            VStack(spacing: 12) {
                header
                instructionCard
                statCards
                arena.frame(maxHeight: .infinity)
                speedFooter
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
        .alert("Quit Tap Frenzy?", isPresented: $showQuitConfirmation) {
            Button("Quit Game", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current local match will be discarded.")
        }
        .onAppear {
            now = Date()
            prepareRunBoard()
            targetPulse = true
        }
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
            .foregroundStyle(remainingTime <= 10 && phase == .racing ? TapFrenzyTheme.coral : .white)
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background(Capsule().fill(.white.opacity(0.07)))
            .overlay(Capsule().stroke(playerColor.opacity(0.25), lineWidth: 1))
        }
        .padding(.top, 5)
    }

    private var instructionCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(targetColor(expectedNumber).opacity(0.15))
                    .frame(width: 45, height: 45)
                Text("\(expectedNumber)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(targetColor(expectedNumber))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(phase == .racing ? "TAP NUMBER \(expectedNumber)" : "TAP 1 → 5 IN ORDER")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Complete as many sequences as you can in 60 seconds.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.40))
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 4) {
                ForEach(1...TapFrenzyGame.targetCount, id: \.self) { number in
                    Circle()
                        .fill(
                            number < expectedNumber
                                ? targetColor(number).opacity(0.28)
                                : (number == expectedNumber
                                    ? targetColor(number)
                                    : .white.opacity(0.10))
                        )
                        .frame(width: number == expectedNumber ? 9 : 7, height: number == expectedNumber ? 9 : 7)
                }
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 68)
        .background(RoundedRectangle(cornerRadius: 19).fill(.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var statCards: some View {
        HStack(spacing: 9) {
            statCard(title: "SCORE", value: "\(score)", symbol: "bolt.fill", color: TapFrenzyTheme.coral)
            statCard(title: "SEQUENCES", value: "\(completedSequences)", symbol: "checkmark.circle.fill", color: TapFrenzyTheme.cyan)
            statCard(title: "MISTAKES", value: "\(mistakes)", symbol: "xmark.circle.fill", color: TapFrenzyTheme.orange)
        }
    }

    private func statCard(
        title: String,
        value: String,
        symbol: String,
        color: Color
    ) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.system(size: 8, weight: .black, design: .rounded))
            .foregroundStyle(color.opacity(0.78))

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

                if phase == .racing {
                    ForEach(activeTargets) { target in
                        targetButton(target)
                            .position(
                                x: proxy.size.width * target.x,
                                y: proxy.size.height * target.y
                            )
                            .transition(.scale(scale: 0.45).combined(with: .opacity))
                    }
                }

                if phase == .countdown {
                    countdownOverlay
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .animation(
                .spring(response: 0.34, dampingFraction: 0.72),
                value: relocationRound
            )
            .animation(
                .spring(response: 0.27, dampingFraction: 0.74),
                value: expectedNumber
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(playerColor.opacity(0.24), lineWidth: 1.2)
            )
        }
        .frame(minHeight: 330)
    }

    private func arenaGlow(size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(TapFrenzyTheme.coral.opacity(0.08))
                .frame(width: size.width * 0.65)
                .blur(radius: 35)
                .offset(x: -size.width * 0.25, y: -size.height * 0.24)
            Circle()
                .fill(TapFrenzyTheme.cyan.opacity(0.07))
                .frame(width: size.width * 0.7)
                .blur(radius: 38)
                .offset(x: size.width * 0.28, y: size.height * 0.28)
        }
        .allowsHitTesting(false)
    }

    private func targetButton(_ target: TapFrenzyTarget) -> some View {
        let color = targetColor(target.number)
        let isExpected = target.number == expectedNumber
        let isWrong = wrongTargetNumber == target.number
        let size = CGFloat(TapFrenzyGame.targetSize(after: completedSequences))

        return Button {
            tap(target.number)
        } label: {
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
                        colors: [
                            .white.opacity(0.94),
                            isWrong ? Color.red : color
                        ],
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
                .shadow(color: playerColor, radius: 20)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeInOut(duration: 0.28), value: countdownValue)
            Text("GET YOUR FINGERS READY")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.7)
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var speedFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(playerColor)
            Text("Targets relocate every \(relocationInterval, specifier: "%.1f")s")
            Spacer()
            Text("SIZE \(Int(TapFrenzyGame.targetSize(after: completedSequences)))")
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
        Color.black.opacity(0.80)
            .ignoresSafeArea()
            .background(.ultraThinMaterial)
    }

    private var readyOverlay: some View {
        ZStack {
            overlayBackground

            overlayCard(borderColor: TapFrenzyTheme.coral) {
                VStack(spacing: 19) {
                    ZStack {
                        Circle()
                            .fill(TapFrenzyTheme.coral.opacity(0.14))
                            .frame(width: 92, height: 92)
                        Circle()
                            .stroke(TapFrenzyTheme.coral.opacity(0.42), lineWidth: 1.5)
                            .frame(width: 92, height: 92)
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 39, weight: .black))
                            .foregroundStyle(TapFrenzyTheme.coral)
                    }

                    VStack(spacing: 7) {
                        Text("PLAYER 1")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(2.2)
                            .foregroundStyle(TapFrenzyTheme.coral)
                        Text("Ready for the frenzy?")
                            .font(.system(size: 29, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text("Tap 1–5 in order. You have 60 seconds to build the highest score.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    rulePills

                    primaryButton(title: "START PLAYER 1", color: TapFrenzyTheme.coral) {
                        startCountdown(for: 0)
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var rulePills: some View {
        HStack(spacing: 8) {
            rulePill("+10", subtitle: "SEQUENCE", color: TapFrenzyTheme.cyan)
            rulePill("BONUS", subtitle: "FOR SPEED", color: TapFrenzyTheme.orange)
            rulePill("−2", subtitle: "MISTAKE", color: TapFrenzyTheme.coral)
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

    private var handoffOverlay: some View {
        ZStack {
            overlayBackground

            overlayCard(borderColor: TapFrenzyTheme.cyan) {
                VStack(spacing: 18) {
                    Text("PLAYER 1 FINISHED")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(2.1)
                        .foregroundStyle(TapFrenzyTheme.coral)

                    HStack(spacing: 18) {
                        resultMetric(value: "\(results[0]?.score ?? 0)", label: "SCORE", color: TapFrenzyTheme.coral)
                        resultMetric(value: "\(results[0]?.completedSequences ?? 0)", label: "SEQUENCES", color: TapFrenzyTheme.cyan)
                        resultMetric(value: "\(results[0]?.mistakes ?? 0)", label: "MISTAKES", color: TapFrenzyTheme.orange)
                    }

                    ZStack {
                        Circle()
                            .fill(TapFrenzyTheme.cyan.opacity(0.10))
                            .frame(width: 110, height: 110)
                            .scaleEffect(passPhonePulse ? 1.08 : 0.94)
                        Circle()
                            .stroke(TapFrenzyTheme.cyan.opacity(0.44), lineWidth: 1.5)
                            .frame(width: 98, height: 98)
                        Image(systemName: "iphone")
                            .font(.system(size: 46, weight: .medium))
                            .foregroundStyle(.white)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 21, weight: .black))
                            .foregroundStyle(TapFrenzyTheme.cyan)
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
                        Text("Player 2 receives the same target sequences. The timer starts after the countdown.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    primaryButton(title: "PLAYER 2 READY", color: TapFrenzyTheme.cyan) {
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
                    ZStack {
                        Circle()
                            .fill(resultAccent.opacity(0.14))
                            .frame(width: 84, height: 84)
                        Circle()
                            .stroke(resultAccent.opacity(0.44), lineWidth: 1.5)
                            .frame(width: 84, height: 84)
                        Image(systemName: winningPlayer == nil ? "equal.circle.fill" : "trophy.fill")
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(resultAccent)
                    }

                    VStack(spacing: 5) {
                        Text(resultTitle)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text("Highest score wins the frenzy.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.48))
                    }

                    VStack(spacing: 9) {
                        resultRow(
                            name: firstPlayerName,
                            badge: "PLAYER 1",
                            result: results[0],
                            color: TapFrenzyTheme.coral,
                            isWinner: winningPlayer == 0
                        )
                        resultRow(
                            name: "Guest",
                            badge: "PLAYER 2",
                            result: results[1],
                            color: TapFrenzyTheme.cyan,
                            isWinner: winningPlayer == 1
                        )
                    }

                    VStack(spacing: 9) {
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
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }

    private func overlayCard<Content: View>(
        borderColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
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
        result: TapFrenzyRunResult?,
        color: Color,
        isWinner: Bool
    ) -> some View {
        HStack(spacing: 11) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .shadow(color: color, radius: 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(result?.completedSequences ?? 0) sequences · \(result?.mistakes ?? 0) mistakes")
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
            .foregroundStyle(Color.black.opacity(0.80))
            .frame(maxWidth: .infinity)
            .frame(height: 53)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
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
            return
        }

        if let nextRelocationAt, date >= nextRelocationAt {
            relocationRound += 1
            targets = TapFrenzyGame.targets(
                seed: runSeed,
                sequence: completedSequences,
                relocation: relocationRound
            )
            self.nextRelocationAt = date.addingTimeInterval(relocationInterval)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.35)
        }
    }

    private func tap(_ number: Int) {
        guard phase == .racing else { return }

        guard number == expectedNumber else {
            mistakes += 1
            score = max(0, score - TapFrenzyGame.mistakePenalty)
            wrongTargetNumber = number
            showFeedback("−\(TapFrenzyGame.mistakePenalty) · WRONG ORDER", color: TapFrenzyTheme.coral)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)

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
                expectedNumber += 1
            }
            return
        }

        completeSequence()
    }

    private func completeSequence() {
        let executionTime = max(0, now.timeIntervalSince(sequenceStartedAt ?? now))
        let bonus = TapFrenzyGame.speedBonus(for: executionTime)
        score += 10 + bonus
        completedSequences += 1
        totalSequenceTime += executionTime
        expectedNumber = 1
        relocationRound = 0
        targets = TapFrenzyGame.targets(
            seed: runSeed,
            sequence: completedSequences,
            relocation: 0
        )
        sequenceStartedAt = now
        nextRelocationAt = now.addingTimeInterval(relocationInterval)
        showFeedback("SEQUENCE +\(10 + bonus)", color: TapFrenzyTheme.cyan)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
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

    private func startCountdown(for player: Int) {
        currentPlayer = player
        resetRunState()
        prepareRunBoard()
        let date = Date()
        now = date
        countdownEndsAt = date.addingTimeInterval(3.2)

        withAnimation(.easeInOut(duration: 0.24)) {
            phase = .countdown
        }
    }

    private func beginRun(at date: Date) {
        runStartedAt = date
        sequenceStartedAt = date
        nextRelocationAt = date.addingTimeInterval(relocationInterval)
        countdownEndsAt = nil
        withAnimation(.easeOut(duration: 0.18)) {
            phase = .racing
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func finishCurrentRun() {
        guard phase == .racing else { return }

        let result = TapFrenzyRunResult(
            score: score,
            completedSequences: completedSequences,
            mistakes: mistakes,
            totalSequenceTime: totalSequenceTime
        )
        results[currentPlayer] = result
        runStartedAt = nil
        sequenceStartedAt = nil
        nextRelocationAt = nil
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
        prepareRunBoard()

        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            phase = .ready
        }
    }

    private func resetRunState() {
        score = 0
        completedSequences = 0
        mistakes = 0
        totalSequenceTime = 0
        expectedNumber = 1
        relocationRound = 0
        runStartedAt = nil
        sequenceStartedAt = nil
        nextRelocationAt = nil
        countdownEndsAt = nil
        feedbackText = nil
        feedbackToken = nil
        wrongTargetNumber = nil
    }

    private func prepareRunBoard() {
        targets = TapFrenzyGame.targets(
            seed: runSeed,
            sequence: 0,
            relocation: 0
        )
    }

    private func handleScenePhase(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            let resumedAt = Date()
            if let pausedAt {
                let pauseDuration = resumedAt.timeIntervalSince(pausedAt)
                shiftDate(&countdownEndsAt, by: pauseDuration)
                shiftDate(&runStartedAt, by: pauseDuration)
                shiftDate(&sequenceStartedAt, by: pauseDuration)
                shiftDate(&nextRelocationAt, by: pauseDuration)
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
        targets.filter { $0.number >= expectedNumber }
    }

    private var firstPlayerName: String {
        let trimmed = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "You" : trimmed
    }

    private var playerColor: Color {
        currentPlayer == 0 ? TapFrenzyTheme.coral : TapFrenzyTheme.cyan
    }

    private var relocationInterval: TimeInterval {
        TapFrenzyGame.relocationInterval(after: completedSequences)
    }

    private var remainingTime: TimeInterval {
        guard phase == .racing, let runStartedAt else {
            return TapFrenzyGame.runDuration
        }
        return max(0, TapFrenzyGame.runDuration - now.timeIntervalSince(runStartedAt))
    }

    private var formatRemainingTime: String {
        String(format: "%04.1f", remainingTime)
    }

    private var countdownValue: Int {
        guard let countdownEndsAt else { return 3 }
        return min(3, max(1, Int(ceil(countdownEndsAt.timeIntervalSince(now)))))
    }

    private var phaseStatus: String {
        switch phase {
        case .ready: return "READY"
        case .countdown: return "GET READY"
        case .racing: return "SEQUENCE \(completedSequences + 1)"
        case .handoff: return "PASS THE IPHONE"
        case .finished: return "COMPLETE"
        }
    }

    private var winningPlayer: Int? {
        guard let first = results[0], let second = results[1] else { return nil }
        if first.score != second.score { return first.score > second.score ? 0 : 1 }
        if first.completedSequences != second.completedSequences {
            return first.completedSequences > second.completedSequences ? 0 : 1
        }
        if first.mistakes != second.mistakes { return first.mistakes < second.mistakes ? 0 : 1 }
        if abs(first.totalSequenceTime - second.totalSequenceTime) >= 0.01 {
            return first.totalSequenceTime < second.totalSequenceTime ? 0 : 1
        }
        return nil
    }

    private var resultTitle: String {
        switch winningPlayer {
        case 0: return "\(firstPlayerName) Wins!"
        case 1: return "Guest Wins!"
        default: return "It's a Tie!"
        }
    }

    private var resultAccent: Color {
        switch winningPlayer {
        case 0: return TapFrenzyTheme.coral
        case 1: return TapFrenzyTheme.cyan
        default: return TapFrenzyTheme.violet
        }
    }
}

private enum TapFrenzyLocalPhase: Equatable {
    case ready
    case countdown
    case racing
    case handoff
    case finished
}
