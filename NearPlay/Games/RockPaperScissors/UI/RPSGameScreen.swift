import SwiftUI

struct RPSPlayerPresentation:
    Identifiable,
    Equatable {

    let id: String
    let name: String
    let inactiveBadge: String
}

enum RPSFeedbackTone {
    case neutral
    case success
    case danger

    var color: Color {
        switch self {
        case .neutral:
            return RPSTheme.brightBlue
        case .success:
            return .green
        case .danger:
            return .red
        }
    }

    var iconName: String {
        switch self {
        case .neutral:
            return "circle.dotted"
        case .success:
            return "checkmark.circle.fill"
        case .danger:
            return "xmark.octagon.fill"
        }
    }
}

struct RPSFeedbackMessage: Equatable {
    let text: String
    let tone: RPSFeedbackTone
}

struct RPSGameScreen: View {
    let gameTitle: String

    @ObservedObject
    var controller: RPSMatchController

    let firstPlayer: RPSPlayerPresentation
    let secondPlayer: RPSPlayerPresentation

    let choosingPlayerID: String

    let headerSubtitle: String
    let statusTitle: String
    let statusSubtitle: String
    let instructionText: String

    let isInteractionEnabled: Bool
    let showsProgress: Bool
    let hidesLockedChoice: Bool
    let feedback: RPSFeedbackMessage?

    let onChoiceSelected: (RPSChoice) -> Void
    let onQuitRequested: () -> Void

    @State
    private var duelCardsVisible = false

    @State
    private var highlightWinner = false

    @State
    private var revealSequenceID = UUID()

    var body: some View {
        ZStack {
            RPSTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                GeometryReader { geometry in
                    let compact =
                        geometry.size.height < 660

                    let contentWidth = min(
                        geometry.size.width - 32,
                        430
                    )

                    VStack(
                        spacing: compact ? 13 : 17
                    ) {
                        statusCard

                        stageSection(
                            compact: compact
                        )

                        playersRow

                        instructionCard
                    }
                    .frame(
                        width: contentWidth,
                        height: geometry.size.height,
                        alignment: .top
                    )
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
                }
            }

            if let feedback {
                feedbackBanner(feedback)
                    .transition(
                        .move(edge: .top)
                        .combined(with: .opacity)
                    )
                    .zIndex(8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .task(
            id: controller.state.roundID
        ) {
            resetRevealState()
        }
        .task(
            id: controller.state.isFinished
        ) {
            guard controller.state.isFinished else {
                resetRevealState()
                return
            }

            startRevealSequence()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Button(action: onQuitRequested) {
                Image(systemName: "chevron.left")
                    .font(
                        .system(
                            size: 20,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background {
                        Circle()
                            .fill(
                                Color.white.opacity(0.055)
                            )
                    }
                    .overlay {
                        Circle()
                            .stroke(
                                Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 3) {
                Text(gameTitle)
                    .font(
                        .system(
                            size: 23,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(headerSubtitle)
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(headerSubtitleColor)
                    .lineLimit(1)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(
                        Color.white.opacity(0.055)
                    )
                    .frame(width: 46, height: 46)

                Circle()
                    .stroke(
                        Color.white.opacity(0.12),
                        lineWidth: 1
                    )
                    .frame(width: 46, height: 46)

                Image(systemName: "hand.raised.fill")
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        RPSTheme.primaryGradient
                    )
            }
        }
    }

    private var headerSubtitleColor: Color {
        if controller.state.isFinished {
            if controller.state.isDraw {
                return Color.white.opacity(0.58)
            }

            return .yellow
        }

        return isInteractionEnabled
            ? RPSTheme.brightBlue
            : RPSTheme.brightPurple
    }

    // MARK: - Status

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: roundStatusIcon)
                .font(
                    .system(
                        size: 16,
                        weight: .semibold
                    )
                )
                .foregroundStyle(roundStatusColor)

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(statusTitle)
                    .font(
                        .system(
                            size: 17,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)

                Text(statusSubtitle)
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.54)
                    )
                    .lineLimit(2)
            }

            Spacer()

            if showsProgress {
                ProgressView()
                    .tint(.white)
            } else {
                statusPill
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 70)
        .background {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(Color.white.opacity(0.035))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.10),
                lineWidth: 1
            )
        }
    }

    private var roundStatusIcon: String {
        if controller.state.isFinished {
            if controller.state.isDraw {
                return "equal.circle.fill"
            }

            return "crown.fill"
        }

        if choosingChoice != nil {
            return "lock.fill"
        }

        return "hand.tap.fill"
    }

    private var roundStatusColor: Color {
        if controller.state.isFinished {
            return controller.state.isDraw
                ? Color.white.opacity(0.70)
                : .yellow
        }

        return isInteractionEnabled
            ? RPSTheme.brightBlue
            : RPSTheme.brightPurple
    }

    @ViewBuilder
    private var statusPill: some View {
        if controller.state.isFinished {
            Text("DONE")
                .rpsPillStyle()
        } else if choosingChoice != nil {
            Text("LOCKED")
                .rpsPillStyle()
        } else {
            Text("1 vs 1")
                .rpsPillStyle()
        }
    }

    // MARK: - Stage

    private func stageSection(
        compact: Bool
    ) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text(stageTitle)
                    .font(
                        .system(
                            size: compact ? 21 : 24,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)

                Spacer()

                if let choice = choosingChoice,
                   !hidesLockedChoice {
                    Text(choice.emoji)
                        .font(
                            .system(
                                size: compact ? 23 : 26
                            )
                        )
                }
            }

            ZStack {
                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.035),
                            Color.white.opacity(0.015)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
                .stroke(
                    Color.white.opacity(0.10),
                    lineWidth: 1
                )

                stageContent
                    .padding(18)
            }
            .frame(
                minHeight: compact ? 300 : 340
            )
        }
    }

    private var stageTitle: String {
        if controller.state.isFinished {
            return "Battle Reveal"
        }

        if choosingChoice == nil {
            return "Choose Your Move"
        }

        return "Choice Locked"
    }

    @ViewBuilder
    private var stageContent: some View {
        if controller.state.isFinished {
            duelStage
        } else if choosingChoice == nil {
            choosingStage
        } else {
            lockedChoiceStage
        }
    }

    private var choosingStage: some View {
        VStack(spacing: 16) {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(
                        .flexible(),
                        spacing: 12
                    ),
                    count: 3
                ),
                spacing: 12
            ) {
                ForEach(RPSChoice.allCases) { choice in
                    Button {
                        onChoiceSelected(choice)
                    } label: {
                        RPSSelectableChoiceCard(
                            choice: choice,
                            subtitle: "Choose",
                            isEmphasized: false
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isInteractionEnabled)
                    .opacity(isInteractionEnabled ? 1 : 0.55)
                }
            }

            Text(instructionText)
                .font(
                    .system(
                        size: 14,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.48)
                )
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var lockedChoiceStage: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            if let choice = choosingChoice,
               !hidesLockedChoice {
                RPSSelectableChoiceCard(
                    choice: choice,
                    subtitle: "Locked",
                    isEmphasized: true
                )
                .frame(maxWidth: 240)
            } else {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                RPSTheme
                                    .brightPurple
                                    .opacity(0.14)
                            )
                            .frame(width: 92, height: 92)

                        Circle()
                            .stroke(
                                RPSTheme.primaryGradient,
                                lineWidth: 1.4
                            )
                            .frame(width: 92, height: 92)

                        Image(systemName: "lock.fill")
                            .font(
                                .system(
                                    size: 34,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(.white)
                    }

                    Text("Move Locked")
                        .font(
                            .system(
                                size: 22,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)
                }
            }

            VStack(spacing: 8) {
                Text(statusTitle)
                    .font(
                        .system(
                            size: 20,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(statusSubtitle)
                    .font(
                        .system(
                            size: 14,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.46)
                    )
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(
            .opacity.combined(
                with: .scale(scale: 0.96)
            )
        )
    }

    private var duelStage: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            HStack(spacing: 14) {
                if let firstChoice {
                    RPSDuelChoiceCard(
                        title: firstPlayer.name,
                        choice: firstChoice,
                        isWinner:
                            controller.state.winnerPlayerID ==
                            firstPlayer.id,
                        isDimmed:
                            highlightWinner &&
                            controller.state.winnerPlayerID ==
                            secondPlayer.id
                    )
                    .scaleEffect(
                        firstDuelScale
                    )
                    .opacity(
                        duelCardsVisible ? 1 : 0
                    )
                    .offset(
                        x: duelCardsVisible ? 0 : -120,
                        y: duelCardsVisible ? 0 : 12
                    )
                }

                ZStack {
                    Circle()
                        .fill(RPSTheme.backgroundBottom)
                        .frame(width: 58, height: 58)

                    Circle()
                        .stroke(
                            RPSTheme.primaryGradient,
                            lineWidth: 1.6
                        )
                        .frame(width: 58, height: 58)
                        .shadow(
                            color:
                                RPSTheme
                                .brightPurple
                                .opacity(0.34),
                            radius: 10
                        )

                    Text("VS")
                        .font(
                            .system(
                                size: 17,
                                weight: .black,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)
                }
                .scaleEffect(
                    duelCardsVisible ? 1 : 0.72
                )
                .opacity(
                    duelCardsVisible ? 1 : 0
                )

                if let secondChoice {
                    RPSDuelChoiceCard(
                        title: secondPlayer.name,
                        choice: secondChoice,
                        isWinner:
                            controller.state.winnerPlayerID ==
                            secondPlayer.id,
                        isDimmed:
                            highlightWinner &&
                            controller.state.winnerPlayerID ==
                            firstPlayer.id
                    )
                    .scaleEffect(
                        secondDuelScale
                    )
                    .opacity(
                        duelCardsVisible ? 1 : 0
                    )
                    .offset(
                        x: duelCardsVisible ? 0 : 120,
                        y: duelCardsVisible ? 0 : 12
                    )
                }
            }
            .animation(
                .spring(
                    response: 0.42,
                    dampingFraction: 0.84
                ),
                value: duelCardsVisible
            )
            .animation(
                .spring(
                    response: 0.32,
                    dampingFraction: 0.82
                ),
                value: highlightWinner
            )

            VStack(spacing: 8) {
                Text(duelHeadlineText)
                    .font(
                        .system(
                            size: 22,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(duelSubheadlineText)
                    .font(
                        .system(
                            size: 14,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.48)
                    )
                    .multilineTextAlignment(.center)
            }
            .opacity(duelCardsVisible ? 1 : 0)
            .offset(y: duelCardsVisible ? 0 : 12)
            .animation(
                .easeOut(duration: 0.28),
                value: duelCardsVisible
            )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    // MARK: - Players

    private var playersRow: some View {
        HStack(spacing: 12) {
            playerCard(firstPlayer)
            playerCard(secondPlayer)
        }
    }

    private func playerCard(
        _ player: RPSPlayerPresentation
    ) -> some View {
        let choice =
            controller.choice(for: player.id)

        let isReady =
            choice != nil

        let isWinner =
            controller.state.winnerPlayerID == player.id

        let shouldHideChoice =
            hidesLockedChoice &&
            !controller.state.isFinished &&
            choice != nil

        let color =
            shouldHideChoice
            ? RPSTheme.brightPurple
            : RPSTheme.color(for: choice)

        return HStack(spacing: 12) {
            if let choice,
               !shouldHideChoice {
                RPSChoiceIcon(
                    choice: choice,
                    size: 26
                )
            } else if shouldHideChoice {
                Image(systemName: "lock.fill")
                    .font(
                        .system(
                            size: 18,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(RPSTheme.brightPurple)
                    .frame(width: 42, height: 42)
                    .background {
                        Circle()
                            .fill(
                                RPSTheme
                                    .brightPurple
                                    .opacity(0.10)
                            )
                    }
                    .overlay {
                        Circle()
                            .stroke(
                                RPSTheme
                                    .brightPurple
                                    .opacity(0.26),
                                lineWidth: 1
                            )
                    }
            } else {
                Image(systemName: "questionmark")
                    .font(
                        .system(
                            size: 20,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.35)
                    )
                    .frame(width: 42, height: 42)
                    .background {
                        Circle()
                            .fill(
                                Color.white.opacity(0.045)
                            )
                    }
            }

            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text(player.name)
                    .font(
                        .system(
                            size: 15,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(
                    isWinner
                    ? "Winner"
                    : isReady
                    ? "Ready"
                    : player.inactiveBadge
                )
                .font(
                    .system(
                        size: 12,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    isReady || isWinner
                    ? color
                    : Color.white.opacity(0.42)
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background {
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .fill(
                Color.white.opacity(
                    isReady || isWinner ? 0.052 : 0.026
                )
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                isReady || isWinner
                ? color.opacity(0.65)
                : Color.white.opacity(0.09),
                lineWidth: 1.2
            )
        }
    }

    private var instructionCard: some View {
        Text(instructionText)
            .font(
                .system(
                    size: 14,
                    weight: .medium
                )
            )
            .foregroundStyle(
                Color.white.opacity(0.55)
            )
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background {
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .fill(Color.white.opacity(0.024))
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 18,
                    style: .continuous
                )
                .stroke(
                    Color.white.opacity(0.075),
                    lineWidth: 1
                )
            }
    }

    private func feedbackBanner(
        _ feedback: RPSFeedbackMessage
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: feedback.tone.iconName)

            Text(feedback.text)
                .lineLimit(2)
        }
        .font(
            .system(
                size: 14,
                weight: .semibold,
                design: .rounded
            )
        )
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background {
            Capsule()
                .fill(
                    feedback.tone.color.opacity(0.88)
                )
        }
        .padding(.top, 18)
    }

    // MARK: - Reveal

    private func startRevealSequence() {
        let sequenceID = UUID()
        revealSequenceID = sequenceID

        duelCardsVisible = false
        highlightWinner = false

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.16
        ) {
            guard revealSequenceID == sequenceID,
                  controller.state.isFinished else {
                return
            }

            withAnimation(
                .spring(
                    response: 0.42,
                    dampingFraction: 0.84
                )
            ) {
                duelCardsVisible = true
            }

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.55
            ) {
                guard revealSequenceID == sequenceID,
                      controller.state.isFinished else {
                    return
                }

                withAnimation(
                    .spring(
                        response: 0.34,
                        dampingFraction: 0.84
                    )
                ) {
                    highlightWinner = true
                }
            }
        }
    }

    private func resetRevealState() {
        revealSequenceID = UUID()
        duelCardsVisible = false
        highlightWinner = false
    }

    // MARK: - Helpers

    private var choosingChoice: RPSChoice? {
        controller.choice(
            for: choosingPlayerID
        )
    }

    private var firstChoice: RPSChoice? {
        controller.choice(
            for: firstPlayer.id
        )
    }

    private var secondChoice: RPSChoice? {
        controller.choice(
            for: secondPlayer.id
        )
    }

    private var firstDuelScale: CGFloat {
        guard highlightWinner else {
            return 1.0
        }

        if controller.state.winnerPlayerID ==
            firstPlayer.id {
            return 1.08
        }

        if controller.state.winnerPlayerID ==
            secondPlayer.id {
            return 0.94
        }

        return 1.0
    }

    private var secondDuelScale: CGFloat {
        guard highlightWinner else {
            return 1.0
        }

        if controller.state.winnerPlayerID ==
            secondPlayer.id {
            return 1.08
        }

        if controller.state.winnerPlayerID ==
            firstPlayer.id {
            return 0.94
        }

        return 1.0
    }

    private var duelHeadlineText: String {
        if !highlightWinner {
            return "Moves Revealed"
        }

        if controller.state.isDraw {
            return "It's a Draw!"
        }

        if let winnerID =
            controller.state.winnerPlayerID {
            return winnerID == choosingPlayerID
                ? "You Win!"
                : "Round Complete"
        }

        return "Round Complete"
    }

    private var duelSubheadlineText: String {
        guard let firstChoice,
              let secondChoice else {
            return "The round has ended."
        }

        if !highlightWinner {
            return "Let’s see who takes the round."
        }

        if firstChoice == secondChoice {
            return "Both players chose \(firstChoice.title)."
        }

        if firstChoice.beats(secondChoice) {
            return "\(firstChoice.title) beats \(secondChoice.title)."
        }

        return "\(secondChoice.title) beats \(firstChoice.title)."
    }
}

private extension Text {
    func rpsPillStyle() -> some View {
        self
            .font(
                .system(
                    size: 12,
                    weight: .bold,
                    design: .rounded
                )
            )
            .foregroundStyle(RPSTheme.primaryGradient)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.045))
            }
            .overlay {
                Capsule()
                    .stroke(
                        Color.white.opacity(0.09),
                        lineWidth: 1
                    )
            }
    }
}
