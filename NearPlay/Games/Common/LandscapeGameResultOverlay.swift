import SwiftUI

/// A wide result card that keeps the winner, score and actions visible together.
struct LandscapeGameResultOverlay: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let accentColor: Color
    let buttonGradient: LinearGradient
    let cardBackground: LinearGradient
    var usesGradientBorder = false
    let firstPlayerName: String
    let secondPlayerName: String
    let sessionScore: GameSessionScore
    let firstPlayerColor: Color
    let secondPlayerColor: Color
    let onPlayAgain: () -> Void
    let onQuit: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = max(1, min(720, geometry.size.width - 32))
            let cardHeight = max(1, min(272, geometry.size.height - 24))

            ZStack {
                Color.black.opacity(0.76).ignoresSafeArea()

                ScrollView(.vertical) {
                    HStack(spacing: 24) {
                        winnerSection
                            .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.clear, accentColor.opacity(0.4), .clear],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .frame(width: 1, height: 160)
                            .accessibilityHidden(true)

                        VStack(spacing: 16) {
                            SessionScoreView(
                                firstPlayerName: firstPlayerName,
                                secondPlayerName: secondPlayerName,
                                firstPlayerScore: sessionScore.firstPlayerWins,
                                secondPlayerScore: sessionScore.secondPlayerWins,
                                draws: sessionScore.draws,
                                firstPlayerColor: firstPlayerColor,
                                secondPlayerColor: secondPlayerColor
                            )
                            actions
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(minHeight: max(0, cardHeight - 40))
                    .padding(20)
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(width: cardWidth, height: cardHeight)
                .background {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color(red: 0.035, green: 0.055, blue: 0.085))
                        .overlay {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(cardBackground)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(
                            usesGradientBorder ? AnyShapeStyle(buttonGradient) : AnyShapeStyle(.white.opacity(0.15)),
                            lineWidth: 1.25
                        )
                }
                .shadow(color: accentColor.opacity(0.16), radius: 24)
                .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var winnerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(accentColor)
                .frame(width: 64, height: 64)
                .background(Circle().fill(accentColor.opacity(0.12)))
                .overlay(Circle().strokeBorder(accentColor.opacity(0.55), lineWidth: 1.25))
                .shadow(color: accentColor.opacity(0.25), radius: 12)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: onQuit) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12), lineWidth: 1))
            }
            .accessibilityLabel("Quit game")

            Button(action: onPlayAgain) {
                Label("Play Again", systemImage: "arrow.clockwise")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 14).fill(buttonGradient))
            }
        }
        .buttonStyle(.plain)
    }
}
