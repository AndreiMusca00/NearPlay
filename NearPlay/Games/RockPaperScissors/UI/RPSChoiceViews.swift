import SwiftUI

struct RPSChoiceIcon: View {
    let choice: RPSChoice
    let size: CGFloat

    var body: some View {
        Text(choice.emoji)
            .font(.system(size: size))
            .frame(width: size * 1.35, height: size * 1.35)
            .background {
                Circle()
                    .fill(
                        RPSTheme
                            .color(for: choice)
                            .opacity(0.12)
                    )
            }
            .overlay {
                Circle()
                    .stroke(
                        RPSTheme
                            .color(for: choice)
                            .opacity(0.42),
                        lineWidth: 1.2
                    )
            }
            .shadow(
                color:
                    RPSTheme
                    .color(for: choice)
                    .opacity(0.24),
                radius: 10
            )
    }
}

struct RPSSelectableChoiceCard: View {
    let choice: RPSChoice
    let subtitle: String
    let isEmphasized: Bool

    var body: some View {
        let accentColor =
            RPSTheme.color(for: choice)

        VStack(spacing: 12) {
            Text(choice.emoji)
                .font(
                    .system(
                        size: isEmphasized ? 52 : 40
                    )
                )
                .frame(
                    width: isEmphasized ? 92 : 76,
                    height: isEmphasized ? 92 : 76
                )
                .background {
                    Circle()
                        .fill(
                            accentColor
                                .opacity(
                                    isEmphasized
                                    ? 0.18
                                    : 0.10
                                )
                        )
                }

            Text(choice.title)
                .font(
                    .system(
                        size: isEmphasized ? 22 : 18,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)

            Text(subtitle)
                .font(
                    .system(
                        size: 13,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    isEmphasized
                    ? accentColor
                    : Color.white.opacity(0.40)
                )
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: isEmphasized ? 220 : 166)
        .background {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        accentColor.opacity(
                            isEmphasized ? 0.14 : 0.055
                        ),
                        Color.white.opacity(0.018)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                isEmphasized
                ? accentColor.opacity(0.88)
                : Color.white.opacity(0.10),
                lineWidth: isEmphasized ? 1.5 : 1
            )
        }
        .shadow(
            color:
                isEmphasized
                ? accentColor.opacity(0.28)
                : .clear,
            radius: 14
        )
    }
}

struct RPSDuelChoiceCard: View {
    let title: String
    let choice: RPSChoice
    let isWinner: Bool
    let isDimmed: Bool

    var body: some View {
        let accentColor =
            RPSTheme.color(for: choice)

        VStack(spacing: 14) {
            HStack {
                Text(title.uppercased())
                    .font(
                        .system(
                            size: 11,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.42)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)

                Spacer()

                if isWinner {
                    Image(systemName: "crown.fill")
                        .font(
                            .system(
                                size: 13,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.yellow)
                }
            }

            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 86, height: 86)

                Circle()
                    .stroke(
                        accentColor.opacity(0.72),
                        lineWidth: 1.5
                    )
                    .frame(width: 86, height: 86)
                    .shadow(
                        color: accentColor.opacity(0.36),
                        radius: 12
                    )

                Text(choice.emoji)
                    .font(.system(size: 50))
            }

            VStack(spacing: 4) {
                Text(choice.title)
                    .font(
                        .system(
                            size: 18,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)

                Text(isWinner ? "Winner" : "Revealed")
                    .font(
                        .system(
                            size: 13,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        isWinner
                        ? accentColor
                        : Color.white.opacity(0.40)
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 214)
        .background {
            RoundedRectangle(
                cornerRadius: 26,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        accentColor.opacity(
                            isWinner ? 0.12 : 0.06
                        ),
                        Color.white.opacity(0.016)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 26,
                style: .continuous
            )
            .stroke(
                isWinner
                ? accentColor.opacity(0.84)
                : Color.white.opacity(0.10),
                lineWidth: isWinner ? 1.5 : 1
            )
        }
        .opacity(isDimmed ? 0.72 : 1)
        .shadow(
            color:
                isWinner
                ? accentColor.opacity(0.24)
                : .clear,
            radius: 14
        )
    }
}
