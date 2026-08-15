import SwiftUI

struct BattleshipSimpleResultOverlay: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let accentColor: Color

    let onPlayAgain: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 19) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 78, height: 78)

                    Circle()
                        .stroke(
                            accentColor.opacity(0.62),
                            lineWidth: 1.4
                        )
                        .frame(width: 78, height: 78)

                    Image(systemName: symbolName)
                        .font(
                            .system(
                                size: 32,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(accentColor)
                        .shadow(
                            color: accentColor.opacity(0.62),
                            radius: 10
                        )
                }

                VStack(spacing: 7) {
                    Text(title)
                        .font(
                            .system(
                                size: 27,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(
                            .system(
                                size: 14,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(
                            Color.white.opacity(0.56)
                        )
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Button(action: onPlayAgain) {
                        HStack(spacing: 9) {
                            Image(systemName: "arrow.clockwise")
                            Text("Play Again")
                        }
                        .font(
                            .system(
                                size: 16,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background {
                            RoundedRectangle(
                                cornerRadius: 17,
                                style: .continuous
                            )
                            .fill(BattleshipTheme.primaryGradient)
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: onQuit) {
                        Text("Quit")
                            .font(
                                .system(
                                    size: 15,
                                    weight: .semibold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(
                                Color.white.opacity(0.64)
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 45)
                            .background {
                                RoundedRectangle(
                                    cornerRadius: 15,
                                    style: .continuous
                                )
                                .fill(Color.white.opacity(0.045))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 27)
            .frame(maxWidth: 350)
            .background {
                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
                .fill(BattleshipTheme.cardBackground)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
                .stroke(
                    BattleshipTheme.primaryGradient,
                    lineWidth: 1.25
                )
            }
            .padding(.horizontal, 24)
        }
    }
}
