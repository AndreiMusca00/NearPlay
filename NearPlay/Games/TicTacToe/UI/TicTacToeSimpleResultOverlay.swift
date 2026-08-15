import SwiftUI

struct TicTacToeSimpleResultOverlay: View {
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
                        .frame(width: 76, height: 76)

                    Circle()
                        .stroke(
                            accentColor.opacity(0.58),
                            lineWidth: 1.4
                        )
                        .frame(width: 76, height: 76)

                    Image(systemName: symbolName)
                        .font(
                            .system(
                                size: 31,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(accentColor)
                        .shadow(
                            color: accentColor.opacity(0.60),
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
                            .fill(TicTacToeTheme.primaryGradient)
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
                .fill(TicTacToeTheme.cardBackground)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
                .stroke(
                    Color.white.opacity(0.12),
                    lineWidth: 1
                )
            }
            .padding(.horizontal, 24)
        }
    }
}
