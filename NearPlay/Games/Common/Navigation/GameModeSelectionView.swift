//
//  GameModeSelectionView.swift
//  NearPlay
//

import SwiftUI

struct GameModeSelectionView: View {
    let game: Game

    let onNearby: () -> Void
    let onLocal: () -> Void
    let onComputer: (GameAIDifficulty) -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var difficulty:
        GameAIDifficulty = .medium

    var body: some View {
        ZStack {
            GameModeSelectionTheme.background
                .ignoresSafeArea()

            GeometryReader { geometry in
                let compact =
                    geometry.size.height < 690

                VStack(
                    spacing: compact ? 13 : 17
                ) {
                    header

                    VStack(
                        spacing: compact ? 10 : 13
                    ) {
                        modeButton(
                            mode: .nearby,
                            title: "Nearby Player",
                            subtitle:
                                "Play wirelessly with another iPhone.",
                            systemName:
                                "antenna.radiowaves.left.and.right",
                            accent:
                                GameModeSelectionTheme.cyan,
                            action: onNearby
                        )

                        modeButton(
                            mode: .local,
                            title: "Two Players",
                            subtitle:
                                "Take turns on the same iPhone.",
                            systemName:
                                "person.2.fill",
                            accent:
                                GameModeSelectionTheme.blue,
                            action: onLocal
                        )

                        computerCard(
                            compact: compact
                        )
                    }

                    Spacer(minLength: 0)

                    Text(
                        footerText
                    )
                    .font(
                        .system(
                            size: 12,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.38)
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
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
            .accessibilityLabel("Back")

            Spacer()

            VStack(spacing: 3) {
                Text(game.title)
                    .font(
                        .system(
                            size: 23,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("Choose how to play")
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        GameModeSelectionTheme.cyan
                    )
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
                        game.fallbackSystemImage
                )
                .font(
                    .system(
                        size: 18,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    GameModeSelectionTheme
                        .primaryGradient
                )
            }
        }
        .padding(.bottom, 5)
    }

    // MARK: - Normal mode card

    private func modeButton(
        mode: GamePlayMode,
        title: String,
        subtitle: String,
        systemName: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        let isAvailable =
            game.supportedModes.contains(mode)

        return Button {
            guard isAvailable else {
                return
            }

            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            accent.opacity(
                                isAvailable
                                ? 0.13
                                : 0.055
                            )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: systemName)
                        .font(
                            .system(
                                size: 21,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            isAvailable
                            ? accent
                            : Color.white.opacity(0.24)
                        )
                }

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(title)
                        .font(
                            .system(
                                size: 18,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(
                            isAvailable
                            ? Color.white
                            : Color.white.opacity(0.42)
                        )

                    Text(
                        isAvailable
                        ? subtitle
                        : "This mode will be available soon."
                    )
                    .font(
                        .system(
                            size: 12,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(
                            isAvailable
                            ? 0.47
                            : 0.28
                        )
                    )
                    .multilineTextAlignment(.leading)
                }

                Spacer()

                if isAvailable {
                    Image(systemName: "chevron.right")
                        .font(
                            .system(
                                size: 15,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(
                            Color.white.opacity(0.52)
                        )
                } else {
                    comingSoonBadge
                }
            }
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity)
            .frame(height: 82)
            .background {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .fill(
                    GameModeSelectionTheme
                        .cardBackground
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(
                    isAvailable
                    ? accent.opacity(0.28)
                    : Color.white.opacity(0.07),
                    lineWidth: 1
                )
            }
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }

    // MARK: - Computer card

    private func computerCard(
        compact: Bool
    ) -> some View {
        let isAvailable =
            game.supportedModes.contains(.computer)

        return VStack(
            spacing: compact ? 11 : 14
        ) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            GameModeSelectionTheme
                                .purple
                                .opacity(
                                    isAvailable
                                    ? 0.13
                                    : 0.055
                                )
                        )
                        .frame(width: 50, height: 50)

                    Image(systemName: "cpu")
                        .font(
                            .system(
                                size: 21,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            isAvailable
                            ? GameModeSelectionTheme.purple
                            : Color.white.opacity(0.24)
                        )
                }

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text("Play vs Computer")
                        .font(
                            .system(
                                size: 18,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(
                            isAvailable
                            ? Color.white
                            : Color.white.opacity(0.42)
                        )

                    Text(
                        isAvailable
                        ? difficulty.subtitle
                        : "This mode will be available soon."
                    )
                    .font(
                        .system(
                            size: 12,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(
                            isAvailable
                            ? 0.47
                            : 0.28
                        )
                    )
                }

                Spacer()

                if !isAvailable {
                    comingSoonBadge
                }
            }

            HStack(spacing: 7) {
                ForEach(
                    GameAIDifficulty.allCases
                ) { option in
                    Button {
                        guard isAvailable else {
                            return
                        }

                        difficulty = option
                    } label: {
                        Text(option.title)
                            .font(
                                .system(
                                    size: 12,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(
                                difficulty == option &&
                                isAvailable
                                ? Color.white
                                : Color.white.opacity(
                                    isAvailable
                                    ? 0.45
                                    : 0.22
                                )
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 35)
                            .background {
                                Capsule()
                                    .fill(
                                        difficulty == option &&
                                        isAvailable
                                        ? GameModeSelectionTheme
                                            .purple
                                            .opacity(0.28)
                                        : Color.white
                                            .opacity(0.025)
                                    )
                            }
                            .overlay {
                                Capsule()
                                    .stroke(
                                        difficulty == option &&
                                        isAvailable
                                        ? GameModeSelectionTheme
                                            .purple
                                        : Color.white
                                            .opacity(0.06),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!isAvailable)
                }
            }

            Button {
                guard isAvailable else {
                    return
                }

                onComputer(difficulty)
            } label: {
                HStack(spacing: 8) {
                    Image(
                        systemName:
                            isAvailable
                            ? "play.fill"
                            : "clock.fill"
                    )

                    Text(
                        isAvailable
                        ? "Start vs \(difficulty.title)"
                        : "Coming Soon"
                    )
                }
                .font(
                    .system(
                        size: 15,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    isAvailable
                    ? Color.white
                    : Color.white.opacity(0.32)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background {
                    RoundedRectangle(
                        cornerRadius: 15,
                        style: .continuous
                    )
                    .fill(
                        isAvailable
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    GameModeSelectionTheme.blue,
                                    GameModeSelectionTheme.purple
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        : AnyShapeStyle(
                            Color.white.opacity(0.035)
                        )
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(!isAvailable)
        }
        .padding(15)
        .background {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(
                GameModeSelectionTheme.cardBackground
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                isAvailable
                ? GameModeSelectionTheme
                    .purple
                    .opacity(0.30)
                : Color.white.opacity(0.07),
                lineWidth: 1
            )
        }
    }

    private var comingSoonBadge: some View {
        Text("COMING SOON")
            .font(
                .system(
                    size: 9,
                    weight: .black,
                    design: .rounded
                )
            )
            .foregroundStyle(
                Color.white.opacity(0.42)
            )
            .padding(.horizontal, 9)
            .frame(height: 25)
            .background {
                Capsule()
                    .fill(
                        Color.white.opacity(0.05)
                    )
            }
            .overlay {
                Capsule()
                    .stroke(
                        Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            }
    }

    private var footerText: String {
        let availableCount =
            game.supportedModes.count

        if availableCount == 3 {
            return "Choose the way you want to play this round."
        }

        return "More ways to play are already planned for \(game.title)."
    }
}

// MARK: - Theme

private enum GameModeSelectionTheme {
    static let backgroundTop = Color(
        red: 11.0 / 255.0,
        green: 15.0 / 255.0,
        blue: 21.0 / 255.0
    )

    static let backgroundBottom = Color(
        red: 7.0 / 255.0,
        green: 16.0 / 255.0,
        blue: 24.0 / 255.0
    )

    static let cyan = Color(
        red: 0.05,
        green: 0.72,
        blue: 1.00
    )

    static let blue = Color(
        red: 0.24,
        green: 0.36,
        blue: 1.00
    )

    static let purple = Color(
        red: 0.66,
        green: 0.25,
        blue: 1.00
    )

    static let primaryGradient =
        LinearGradient(
            colors: [
                cyan,
                blue,
                purple
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

    static let background =
        LinearGradient(
            colors: [
                backgroundTop,
                backgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )

    static let cardBackground =
        Color.white.opacity(0.028)
}
