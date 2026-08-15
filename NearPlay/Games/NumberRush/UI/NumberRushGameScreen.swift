import SwiftUI

struct NumberRushGameScreen: View {
    let gameTitle: String

    @ObservedObject
    var controller: NumberRushMatchController

    let firstPlayer: NumberRushPlayerPresentation
    let secondPlayer: NumberRushPlayerPresentation
    let localPlayerID: String

    let headerSubtitle: String
    let statusText: String
    let instructionText: String

    let isInteractionEnabled: Bool
    let showsProgress: Bool
    let wrongNumber: Int?
    let correctNumber: Int?
    let feedback: NumberRushFeedbackMessage?

    let onNumberSelected: (Int) -> Void
    let onQuitRequested: () -> Void

    private let columnsCount = 10
    private let gridSpacing: CGFloat = 4

    var body: some View {
        ZStack {
            NumberRushTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                targetSection
                    .padding(.horizontal, 18)
                    .padding(.top, 15)

                numberGrid
                    .padding(.horizontal, 10)
                    .padding(.top, 13)
                    .padding(.bottom, 10)

                playersTimerSection
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
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
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Button(action: onQuitRequested) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.055))
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

                Text(headerSubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(headerSubtitleColor)
                    .lineLimit(1)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.055))
                    .frame(width: 46, height: 46)

                Circle()
                    .stroke(
                        Color.white.opacity(0.12),
                        lineWidth: 1
                    )
                    .frame(width: 46, height: 46)

                if showsProgress {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.82)
                } else {
                    Image(systemName: "number")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(NumberRushTheme.primaryGradient)
                }
            }
        }
    }

    private var headerSubtitleColor: Color {
        controller.state.activePlayerID == firstPlayer.id
            ? NumberRushTheme.blue
            : NumberRushTheme.purple
    }

    // MARK: - Target

    private var targetSection: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        NumberRushTheme.blue.opacity(0.12)
                    )
                    .frame(width: 58, height: 58)

                Circle()
                    .stroke(
                        NumberRushTheme.primaryGradient,
                        lineWidth: 1.5
                    )
                    .frame(width: 58, height: 58)
                    .shadow(
                        color:
                            NumberRushTheme.blue.opacity(0.42),
                        radius: 10
                    )

                Text(
                    controller.state.isFinished
                    ? "✓"
                    : "\(controller.state.targetNumber)"
                )
                .font(
                    .system(
                        size: 24,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .id(controller.animationID)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(
                    controller.state.isFinished
                    ? "Grid complete"
                    : "Find number"
                )
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.44))

                Text(
                    controller.state.isFinished
                    ? "Excellent!"
                    : "\(controller.state.targetNumber)"
                )
                .font(
                    .system(
                        size: 22,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .id("target-\(controller.animationID)")
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("FOUND")
                    .font(
                        .system(
                            size: 11,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(Color.white.opacity(0.38))

                Text(
                    "\(controller.state.completedNumbers.count)/100"
                )
                .font(
                    .system(
                        size: 18,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(NumberRushTheme.purple)
                .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 78)
        .background {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(Color.white.opacity(0.028))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.09), lineWidth: 1)
        }
    }

    // MARK: - Grid

    private var numberGrid: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let totalSpacing =
                CGFloat(columnsCount - 1) * gridSpacing
            let cellSize =
                (availableWidth - totalSpacing) /
                CGFloat(columnsCount)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(
                        .fixed(cellSize),
                        spacing: gridSpacing
                    ),
                    count: columnsCount
                ),
                spacing: gridSpacing
            ) {
                ForEach(
                    controller.state.shuffledNumbers,
                    id: \.self
                ) { number in
                    numberCell(
                        number,
                        size: cellSize
                    )
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .top
            )
        }
    }

    private func numberCell(
        _ number: Int,
        size: CGFloat
    ) -> some View {
        let isCompleted =
            controller
                .state
                .completedNumbers
                .contains(number)

        let isWrong = wrongNumber == number
        let isCorrect = correctNumber == number

        return Button {
            onNumberSelected(number)
        } label: {
            ZStack {
                RoundedRectangle(
                    cornerRadius: max(6, size * 0.22),
                    style: .continuous
                )
                .fill(
                    cellBackground(
                        completed: isCompleted,
                        wrong: isWrong,
                        correct: isCorrect
                    )
                )

                RoundedRectangle(
                    cornerRadius: max(6, size * 0.22),
                    style: .continuous
                )
                .stroke(
                    cellBorder(
                        completed: isCompleted,
                        wrong: isWrong,
                        correct: isCorrect
                    ),
                    lineWidth:
                        isCompleted || isWrong || isCorrect
                        ? 1.5
                        : 0.7
                )

                if isCompleted {
                    Circle()
                        .stroke(
                            NumberRushTheme.primaryGradient,
                            lineWidth: 2
                        )
                        .padding(3)
                        .shadow(
                            color:
                                NumberRushTheme.blue.opacity(0.70),
                            radius: 5
                        )
                }

                Text("\(number)")
                    .font(
                        .system(
                            size:
                                number == 100
                                ? size * 0.31
                                : size * 0.37,
                            weight:
                                isCompleted
                                ? .bold
                                : .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        numberTextColor(
                            completed: isCompleted,
                            wrong: isWrong
                        )
                    )
                    .minimumScaleFactor(0.7)
            }
            .frame(width: size, height: size)
            .scaleEffect(isWrong ? 0.86 : 1)
            .rotationEffect(.degrees(isWrong ? -4 : 0))
            .animation(
                .spring(
                    response: 0.24,
                    dampingFraction: 0.55
                ),
                value: isWrong
            )
        }
        .buttonStyle(.plain)
        .disabled(
            isCompleted ||
            !isInteractionEnabled ||
            controller.state.isFinished
        )
    }

    // MARK: - Players and timer

    private var playersTimerSection: some View {
        GeometryReader { geometry in
            let compactWidth: CGFloat = 104
            let spacing: CGFloat = 10
            let expandedWidth =
                max(
                    geometry.size.width -
                    compactWidth -
                    spacing,
                    compactWidth
                )

            HStack(spacing: spacing) {
                playerTimerCard(
                    firstPlayer,
                    accentColor: NumberRushTheme.blue
                )
                .frame(
                    width:
                        controller.state.activePlayerID ==
                        firstPlayer.id
                        ? expandedWidth
                        : compactWidth
                )

                playerTimerCard(
                    secondPlayer,
                    accentColor: NumberRushTheme.purple
                )
                .frame(
                    width:
                        controller.state.activePlayerID ==
                        secondPlayer.id
                        ? expandedWidth
                        : compactWidth
                )
            }
            .animation(
                .spring(
                    response: 0.48,
                    dampingFraction: 0.84
                ),
                value: controller.state.activePlayerID
            )
        }
        .frame(height: 76)
    }

    private func playerTimerCard(
        _ player: NumberRushPlayerPresentation,
        accentColor: Color
    ) -> some View {
        NumberRushPlayerTimerCard(
            playerName: player.name,
            score:
                controller.state.scores[player.id] ?? 0,
            isLocalPlayer:
                player.id == localPlayerID,
            isActive:
                controller.state.activePlayerID == player.id,
            turnStartedAt:
                controller.state.turnStartedAt,
            turnDuration:
                controller.state.turnDuration,
            accentColor:
                accentColor
        )
    }

    // MARK: - Feedback

    private func feedbackBanner(
        _ feedback: NumberRushFeedbackMessage
    ) -> some View {
        let color = NumberRushTheme.feedbackColor(
            for: feedback.tone
        )

        return HStack(spacing: 10) {
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
                .fill(color.opacity(0.88))
        }
        .padding(.top, 18)
    }

    // MARK: - Cell styling

    private func cellBackground(
        completed: Bool,
        wrong: Bool,
        correct: Bool
    ) -> Color {
        if wrong {
            return Color.red.opacity(0.16)
        }

        if correct {
            return Color.green.opacity(0.18)
        }

        if completed {
            return NumberRushTheme.blue.opacity(0.10)
        }

        return Color.white.opacity(0.028)
    }

    private func cellBorder(
        completed: Bool,
        wrong: Bool,
        correct: Bool
    ) -> Color {
        if wrong {
            return Color.red.opacity(0.90)
        }

        if correct {
            return Color.green.opacity(0.95)
        }

        if completed {
            return NumberRushTheme.blue.opacity(0.72)
        }

        return Color.white.opacity(0.09)
    }

    private func numberTextColor(
        completed: Bool,
        wrong: Bool
    ) -> Color {
        if wrong {
            return Color.red.opacity(0.95)
        }

        if completed {
            return Color.white.opacity(0.44)
        }

        return Color.white.opacity(0.88)
    }
}
