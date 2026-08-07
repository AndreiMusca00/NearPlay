//
//  ConnectFourModeSelectionView.swift
//  NearPlay
//

import SwiftUI

struct ConnectFourModeSelectionView: View {
    let gameTitle: String

    let onBack: () -> Void
    let onNearby: () -> Void
    let onLocal: () -> Void
    let onComputer: (ConnectFourDifficulty) -> Void

    @State
    private var difficulty:
        ConnectFourDifficulty = .medium

    var body: some View {
        ZStack {
            ConnectFourTheme.background
                .ignoresSafeArea()

            GeometryReader { geometry in
                let compact =
                    geometry.size.height < 690

                VStack(spacing: compact ? 13 : 17) {
                    header

                    VStack(spacing: compact ? 10 : 13) {
                        modeButton(
                            title: "Nearby Player",
                            subtitle:
                                "Play wirelessly with another iPhone.",
                            systemName:
                                "antenna.radiowaves.left.and.right",
                            accent:
                                ConnectFourTheme.cyan,
                            action: onNearby
                        )

                        modeButton(
                            title: "Two Players",
                            subtitle:
                                "Take turns on the same iPhone.",
                            systemName:
                                "person.2.fill",
                            accent:
                                ConnectFourTheme.blue,
                            action: onLocal
                        )

                        computerCard(
                            compact: compact
                        )
                    }

                    Spacer(minLength: 0)

                    Text(
                        "The board, animations and rules are shared by every mode."
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

    private var header: some View {
        HStack(spacing: 14) {
            Button(action: onBack) {
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

                Text("Choose how to play")
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        ConnectFourTheme.cyan
                    )
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(
                        Color.white.opacity(0.055)
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
        .padding(.bottom, 5)
    }

    private func modeButton(
        title: String,
        subtitle: String,
        systemName: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.13))
                        .frame(width: 50, height: 50)

                    Image(systemName: systemName)
                        .font(
                            .system(
                                size: 21,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(accent)
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
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(
                            .system(
                                size: 12,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(
                            Color.white.opacity(0.47)
                        )
                        .multilineTextAlignment(.leading)
                }

                Spacer()

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
            }
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity)
            .frame(height: 82)
            .background {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .fill(ConnectFourTheme.cardBackground)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(
                    accent.opacity(0.28),
                    lineWidth: 1
                )
            }
        }
        .buttonStyle(.plain)
    }

    private func computerCard(
        compact: Bool
    ) -> some View {
        VStack(spacing: compact ? 11 : 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            ConnectFourTheme
                                .purple
                                .opacity(0.13)
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
                            ConnectFourTheme.purple
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
                        .foregroundStyle(.white)

                    Text(difficulty.subtitle)
                        .font(
                            .system(
                                size: 12,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(
                            Color.white.opacity(0.47)
                        )
                }

                Spacer()
            }

            HStack(spacing: 7) {
                ForEach(
                    ConnectFourDifficulty.allCases
                ) { option in
                    Button {
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
                                difficulty == option
                                ? Color.white
                                : Color.white.opacity(0.45)
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 35)
                            .background {
                                Capsule()
                                    .fill(
                                        difficulty == option
                                        ? ConnectFourTheme
                                            .purple
                                            .opacity(0.28)
                                        : Color.white
                                            .opacity(0.035)
                                    )
                            }
                            .overlay {
                                Capsule()
                                    .stroke(
                                        difficulty == option
                                        ? ConnectFourTheme.purple
                                        : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                onComputer(difficulty)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start vs \(difficulty.title)")
                }
                .font(
                    .system(
                        size: 15,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background {
                    RoundedRectangle(
                        cornerRadius: 15,
                        style: .continuous
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                ConnectFourTheme.blue,
                                ConnectFourTheme.purple
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                }
            }
            .buttonStyle(.plain)
        }
        .padding(15)
        .background {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(ConnectFourTheme.cardBackground)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                ConnectFourTheme
                    .purple
                    .opacity(0.30),
                lineWidth: 1
            )
        }
    }
}
