import SwiftUI

struct GameLibraryCard: View {
    let game: Game
    let isLocked: Bool
    let price: String?
    let isLoadingPrice: Bool

    private let purchaseAccent = Color(red: 1.0, green: 0.77, blue: 0.44)

    var body: some View {
        VStack(spacing: 10) {
            GameIconView(
                game: game,
                size: isLocked ? 64 : 72,
                cornerRadius: isLocked ? 19 : 21,
                symbolSize: 29
            )

            Text(game.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)

            HStack(spacing: 6) {
                ForEach(GamePlayMode.allCases.filter { game.supportedModes.contains($0) }) { mode in
                    modeBadge(mode)
                }
            }
            .frame(maxWidth: .infinity)

            if isLocked {
                purchaseFooter
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 208)
        .background(cardBackground)
        .overlay(alignment: .topLeading) {
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(purchaseAccent)
                    .frame(width: 26, height: 26)
                    .background(Color(red: 0.13, green: 0.11, blue: 0.09), in: Circle())
                    .overlay(Circle().stroke(purchaseAccent.opacity(0.38), lineWidth: 1))
                    .padding(12)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var purchaseFooter: some View {
        HStack(spacing: 5) {
            Text("Unlock")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(purchaseAccent.opacity(0.85))

            Spacer(minLength: 0)

            if let price {
                Text(price)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(purchaseAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            } else if isLoadingPrice {
                ProgressView()
                    .controlSize(.mini)
                    .tint(purchaseAccent)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(purchaseAccent.opacity(0.70))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(purchaseAccent.opacity(0.10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(purchaseAccent.opacity(0.22), lineWidth: 1)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        isLocked ? purchaseAccent.opacity(0.10) : Color.white.opacity(0.065),
                        game.accentColor.opacity(isLocked ? 0.045 : 0.065),
                        Color.white.opacity(0.022)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                isLocked ? purchaseAccent.opacity(0.55) : game.accentColor.opacity(0.34),
                                isLocked ? purchaseAccent.opacity(0.12) : Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: isLocked ? purchaseAccent.opacity(0.06) : game.accentColor.opacity(0.08),
                radius: 16,
                y: 8
            )
    }

    private func modeBadge(_ mode: GamePlayMode) -> some View {
        Image(systemName: modeIcon(mode))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(game.accentColor)
            .frame(width: 27, height: 27)
            .background(game.accentColor.opacity(0.11), in: Circle())
            .overlay(Circle().stroke(game.accentColor.opacity(0.24), lineWidth: 1))
            .accessibilityLabel(modeTitle(mode))
    }

    private func modeIcon(_ mode: GamePlayMode) -> String {
        switch mode {
        case .nearby: "antenna.radiowaves.left.and.right"
        case .local: "person.2.fill"
        case .computer: "cpu"
        }
    }

    private func modeTitle(_ mode: GamePlayMode) -> String {
        switch mode {
        case .nearby: "Nearby"
        case .local: "Local"
        case .computer: "CPU"
        }
    }
}
