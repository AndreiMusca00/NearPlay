//
//  ConnectFourGameScreen.swift
//  NearPlay
//

import SwiftUI

struct ConnectFourPlayerPresentation: Identifiable, Equatable {
    let id: String
    let name: String
    let disc: ConnectFourDisc
    let inactiveBadge: String
}

enum ConnectFourFeedbackTone {
    case neutral
    case success
    case danger

    var color: Color {
        switch self {
        case .neutral:
            return ConnectFourTheme.blue
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

struct ConnectFourFeedbackMessage: Equatable {
    let text: String
    let tone: ConnectFourFeedbackTone
}

struct ConnectFourGameScreen: View {
    let gameTitle: String

    @ObservedObject
    var controller: ConnectFourMatchController

    let firstPlayer: ConnectFourPlayerPresentation
    let secondPlayer: ConnectFourPlayerPresentation

    let headerSubtitle: String
    let statusTitle: String
    let statusSubtitle: String
    let instructionText: String

    let isInteractionEnabled: Bool
    let showsProgress: Bool
    let feedback: ConnectFourFeedbackMessage?

    let onColumnSelected: (Int) -> Void
    let onQuitRequested: () -> Void

    var body: some View {
        ZStack {
            ConnectFourTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                GeometryReader { geometry in
                    let metrics = ConnectFourLayoutMetrics(
                        size: geometry.size
                    )

                    VStack(spacing: metrics.spacing) {
                        turnStatusCard(
                            height: metrics.statusHeight
                        )

                        ConnectFourBoardView(
                            state: controller.state,
                            isInteractionEnabled:
                                isInteractionEnabled,
                            animationID:
                                controller.animationID,
                            onColumnTap:
                                onColumnSelected
                        )
                        .frame(
                            width: metrics.boardWidth,
                            height: metrics.boardHeight
                        )
                        .frame(maxWidth: .infinity)

                        playersRow(
                            height: metrics.playersHeight
                        )

                        instructionCard(
                            height: metrics.instructionHeight
                        )
                    }
                    .frame(
                        width: metrics.contentWidth,
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

                Image(
                    systemName:
                        "circle.grid.3x3.fill"
                )
                .font(
                    .system(
                        size: 18,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    ConnectFourTheme.primaryGradient
                )
            }
        }
    }

    // MARK: - Status

    private func turnStatusCard(
        height: CGFloat
    ) -> some View {
        HStack(spacing: 12) {
            ConnectFourDiscView(
                disc: activeDisc,
                size: height * 0.52
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
                            size: 12,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.47)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer()

            if showsProgress {
                ProgressView()
                    .tint(activeColor)
            } else {
                Image(systemName: "hand.tap.fill")
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(activeColor)
            }
        }
        .padding(.horizontal, 15)
        .frame(height: height)
        .background(ConnectFourTheme.cardBackground)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
            .stroke(
                activeColor.opacity(0.34),
                lineWidth: 1
            )
        }
    }

    // MARK: - Players

    private func playersRow(
        height: CGFloat
    ) -> some View {
        HStack(spacing: 10) {
            playerCard(
                firstPlayer,
                height: height
            )

            playerCard(
                secondPlayer,
                height: height
            )
        }
    }

    private func playerCard(
        _ player: ConnectFourPlayerPresentation,
        height: CGFloat
    ) -> some View {
        let isActive =
            controller.state.activePlayerID ==
            player.id

        let color = ConnectFourTheme.color(
            for: player.disc
        )

        return HStack(spacing: 9) {
            ConnectFourDiscView(
                disc: player.disc,
                size: height * 0.43
            )

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(player.name)
                    .font(
                        .system(
                            size: 14,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(
                    isActive
                    ? "ACTIVE"
                    : player.inactiveBadge
                )
                .font(
                    .system(
                        size: 10,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    isActive
                    ? color
                    : Color.white.opacity(0.35)
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .fill(
                isActive
                ? color.opacity(0.09)
                : Color.white.opacity(0.025)
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .stroke(
                isActive
                ? color.opacity(0.54)
                : Color.white.opacity(0.08),
                lineWidth: 1
            )
        }
    }

    private func instructionCard(
        height: CGFloat
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(
                    ConnectFourTheme.primaryGradient
                )

            Text(instructionText)
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.53)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .frame(height: height)
        .background {
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
            .fill(Color.white.opacity(0.025))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 15,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.08),
                lineWidth: 1
            )
        }
    }

    // MARK: - Feedback

    private func feedbackBanner(
        _ message: ConnectFourFeedbackMessage
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: message.tone.iconName)
                .font(
                    .system(
                        size: 17,
                        weight: .bold
                    )
                )

            Text(message.text)
                .font(
                    .system(
                        size: 15,
                        weight: .bold,
                        design: .rounded
                    )
                )
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(height: 48)
        .background {
            Capsule()
                .fill(
                    message.tone.color.opacity(0.88)
                )
        }
        .overlay {
            Capsule()
                .stroke(
                    Color.white.opacity(0.26),
                    lineWidth: 1
                )
        }
        .shadow(
            color:
                message.tone.color.opacity(0.42),
            radius: 12
        )
        .frame(
            maxHeight: .infinity,
            alignment: .top
        )
        .padding(.top, 72)
    }

    private var activeDisc: ConnectFourDisc {
        if controller.state.activePlayerID ==
            firstPlayer.id {
            return firstPlayer.disc
        }

        return secondPlayer.disc
    }

    private var activeColor: Color {
        ConnectFourTheme.color(
            for: activeDisc
        )
    }
}

private struct ConnectFourLayoutMetrics {
    let contentWidth: CGFloat
    let spacing: CGFloat
    let statusHeight: CGFloat
    let playersHeight: CGFloat
    let instructionHeight: CGFloat
    let boardWidth: CGFloat
    let boardHeight: CGFloat

    init(size: CGSize) {
        let compact = size.height < 590

        contentWidth = max(
            size.width - 28,
            0
        )

        spacing = compact ? 7 : 9
        statusHeight = compact ? 56 : 64
        playersHeight = compact ? 54 : 62
        instructionHeight = compact ? 39 : 44

        let reservedHeight =
            statusHeight +
            playersHeight +
            instructionHeight +
            spacing * 3

        let availableBoardHeight =
            max(
                size.height - reservedHeight,
                1
            )

        let maximumBoardWidth =
            contentWidth

        let widthBasedHeight =
            maximumBoardWidth *
            CGFloat(ConnectFourGame.rows) /
            CGFloat(ConnectFourGame.columns)

        boardHeight = min(
            availableBoardHeight,
            widthBasedHeight
        )

        boardWidth = min(
            maximumBoardWidth,
            boardHeight *
            CGFloat(ConnectFourGame.columns) /
            CGFloat(ConnectFourGame.rows)
        )
    }
}
