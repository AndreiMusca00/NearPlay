import SwiftUI

struct TicTacToePlayerPresentation: Identifiable, Equatable {
    let id: String
    let name: String
    let mark: TicTacToeMark
    let inactiveBadge: String
}

enum TicTacToeFeedbackTone {
    case neutral
    case success
    case danger

    var color: Color {
        switch self {
        case .neutral:
            return TicTacToeTheme.xBlue
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

struct TicTacToeFeedbackMessage: Equatable {
    let text: String
    let tone: TicTacToeFeedbackTone
}

struct TicTacToeGameScreen: View {
    let gameTitle: String

    @ObservedObject
    var controller: TicTacToeMatchController

    let firstPlayer: TicTacToePlayerPresentation
    let secondPlayer: TicTacToePlayerPresentation

    let headerSubtitle: String
    let statusTitle: String
    let statusSubtitle: String
    let instructionText: String

    let isInteractionEnabled: Bool
    let showsProgress: Bool
    let feedback: TicTacToeFeedbackMessage?

    let onCellSelected: (Int) -> Void
    let onQuitRequested: () -> Void

    var body: some View {
        ZStack {
            TicTacToeTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                GeometryReader { geometry in
                    let contentWidth = min(
                        geometry.size.width - 32,
                        430
                    )

                    VStack(spacing: 18) {
                        turnStatusCard

                        TicTacToeBoardView(
                            state: controller.state,
                            isInteractionEnabled:
                                isInteractionEnabled,
                            animationID:
                                controller.animationID,
                            onCellTap:
                                onCellSelected
                        )
                        .frame(
                            width: contentWidth,
                            height: contentWidth
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
    }

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

                Text(headerSubtitle)
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(activeColor)
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

                Image(systemName: "grid")
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        TicTacToeTheme.primaryGradient
                    )
            }
        }
    }

    private var turnStatusCard: some View {
        HStack(spacing: 12) {
            TicTacToeMarkIcon(
                mark: activeMark,
                size: 28
            )

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
            }

            Spacer()

            if showsProgress {
                ProgressView()
                    .tint(.white)
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

    private var playersRow: some View {
        HStack(spacing: 12) {
            playerCard(firstPlayer)
            playerCard(secondPlayer)
        }
    }

    private func playerCard(
        _ player: TicTacToePlayerPresentation
    ) -> some View {
        let isActive =
            !controller.state.isFinished &&
            controller.state.activePlayerID == player.id

        let isWinner =
            controller.state.winnerPlayerID == player.id

        let color =
            TicTacToeTheme.color(for: player.mark)

        return HStack(spacing: 12) {
            TicTacToeMarkIcon(
                mark: player.mark,
                size: 28
            )

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
                    : isActive
                    ? "Playing"
                    : player.inactiveBadge
                )
                .font(
                    .system(
                        size: 12,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    isActive || isWinner
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
                    isActive || isWinner ? 0.052 : 0.026
                )
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                isActive || isWinner
                ? color.opacity(0.65)
                : Color.white.opacity(0.09),
                lineWidth: 1.2
            )
        }
        .shadow(
            color:
                isActive || isWinner
                ? color.opacity(0.24)
                : .clear,
            radius: 12
        )
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
        _ feedback: TicTacToeFeedbackMessage
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

    private var activeMark: TicTacToeMark {
        if controller.state.activePlayerID == firstPlayer.id {
            return firstPlayer.mark
        }

        return secondPlayer.mark
    }

    private var activeColor: Color {
        TicTacToeTheme.color(for: activeMark)
    }
}
