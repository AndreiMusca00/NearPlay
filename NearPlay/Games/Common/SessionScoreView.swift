import SwiftUI

struct SessionScoreView: View {
    let firstPlayerName: String
    let secondPlayerName: String

    let firstPlayerScore: Int
    let secondPlayerScore: Int
    let draws: Int

    let firstPlayerColor: Color
    let secondPlayerColor: Color

    var body: some View {
        VStack(spacing: 10) {
            Text("SESSION")
                .font(
                    .system(
                        size: 11,
                        weight: .black,
                        design: .rounded
                    )
                )
                .tracking(1.2)
                .foregroundStyle(
                    Color.white.opacity(0.36)
                )

            HStack(spacing: 14) {
                playerColumn(
                    name: firstPlayerName,
                    score: firstPlayerScore,
                    color: firstPlayerColor
                )

                Text("–")
                    .font(
                        .system(
                            size: 22,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.30)
                    )

                playerColumn(
                    name: secondPlayerName,
                    score: secondPlayerScore,
                    color: secondPlayerColor
                )
            }

            if draws > 0 {
                Text(
                    draws == 1
                    ? "1 draw"
                    : "\(draws) draws"
                )
                .font(
                    .system(
                        size: 12,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.42)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(Color.white.opacity(0.045))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.09),
                lineWidth: 1
            )
        }
    }

    private func playerColumn(
        name: String,
        score: Int,
        color: Color
    ) -> some View {
        VStack(spacing: 4) {
            Text("\(score)")
                .font(
                    .system(
                        size: 30,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(color)
                .contentTransition(.numericText())

            Text(name)
                .font(
                    .system(
                        size: 12,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.60)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }
}
