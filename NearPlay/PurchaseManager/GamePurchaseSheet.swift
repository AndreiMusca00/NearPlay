import StoreKit
import SwiftUI

struct GamePurchaseSheet: View {
    let game: Game
    let onPlay: () -> Void

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var activePurchase: PurchaseChoice?
    @State private var purchaseCompleted = false
    @State private var statusMessage: String?

    var body: some View {
        ZStack {
            purchaseBackground

            ScrollView {
                VStack(spacing: 18) {
                    closeRow

                    GameIconView(
                        game: game,
                        size: 82,
                        cornerRadius: 21,
                        symbolSize: 32
                    )

                    VStack(spacing: 7) {
                        Text(purchaseCompleted ? "Unlocked" : "Unlock \(game.title)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("One-time purchase. No subscription.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.56))
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }

                    if purchaseCompleted {
                        playNowButton
                    } else {
                        VStack(spacing: 12) {
                            individualPurchaseButton

                            if purchaseManager.lifetimePassProduct != nil {
                                bundlePurchaseButton
                            }
                        }
                    }

                    Text("Purchases are processed by the App Store and can be restored with the same Apple Account.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.38))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            if purchaseManager.product(for: game) == nil ||
                purchaseManager.lifetimePassProduct == nil {
                await purchaseManager.loadProducts()
            }
        }
    }

    private var closeRow: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
    }

    private var individualPurchaseButton: some View {
        purchaseOption(
            title: "Unlock \(game.title)",
            subtitle: "Get this game only",
            price: purchaseManager.product(for: game)?.displayPrice,
            icon: "gamecontroller.fill",
            accent: game.accentColor,
            badge: nil,
            choice: .individual
        )
    }

    private var bundlePurchaseButton: some View {
        purchaseOption(
            title: "NearPlay Lifetime Pass",
            subtitle: "Every game now and in the future",
            price: purchaseManager.lifetimePassDisplayPrice,
            icon: "infinity",
            accent: Color(red: 0.52, green: 0.32, blue: 1.0),
            badge: "BEST VALUE",
            choice: .bundle
        )
    }

    private func purchaseOption(
        title: String,
        subtitle: String,
        price: String?,
        icon: String,
        accent: Color,
        badge: String?,
        choice: PurchaseChoice
    ) -> some View {
        Button {
            startPurchase(choice)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(accent.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.48))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 4)

                if activePurchase == choice {
                    ProgressView().tint(.white)
                } else {
                    VStack(alignment: .trailing, spacing: 5) {
                        if let badge {
                            Text(badge)
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .tracking(0.4)
                                .foregroundStyle(accent)
                                .padding(.horizontal, 6)
                                .frame(height: 17)
                                .background(Capsule().fill(accent.opacity(0.14)))
                        }

                        Text(price ?? "Unavailable")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(price == nil ? Color.white.opacity(0.32) : .white)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(Color.white.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(accent.opacity(choice == .bundle ? 0.52 : 0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(activePurchase != nil || price == nil)
        .opacity(price == nil ? 0.58 : 1)
    }

    private var playNowButton: some View {
        Button {
            dismiss()
            onPlay()
        } label: {
            Label("Play now", systemImage: "play.fill")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [.cyan, Color(red: 0.52, green: 0.28, blue: 1.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func startPurchase(_ choice: PurchaseChoice) {
        guard activePurchase == nil else { return }
        activePurchase = choice
        statusMessage = nil

        Task {
            do {
                let outcome: PurchaseManager.PurchaseOutcome
                switch choice {
                case .individual:
                    outcome = try await purchaseManager.purchase(game)
                case .bundle:
                    outcome = try await purchaseManager.purchaseLifetimePass()
                }

                switch outcome {
                case .purchased:
                    purchaseCompleted = true
                    statusMessage = choice == .bundle
                        ? "Lifetime access is active. Current and future premium games are unlocked."
                        : "\(game.title) is now unlocked."
                case .pending:
                    statusMessage = "Purchase pending approval. Access will unlock automatically when it completes."
                case .cancelled:
                    statusMessage = nil
                }
            } catch {
                statusMessage = error.localizedDescription
            }

            activePurchase = nil
        }
    }

    private var purchaseBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 11.0 / 255.0, green: 15.0 / 255.0, blue: 21.0 / 255.0),
                Color(red: 7.0 / 255.0, green: 16.0 / 255.0, blue: 24.0 / 255.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private enum PurchaseChoice: Equatable {
    case individual
    case bundle
}
