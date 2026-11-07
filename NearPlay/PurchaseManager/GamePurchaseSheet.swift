import StoreKit
import SwiftUI

struct GamePurchaseSheet: View {
    let game: Game
    let onPlay: () -> Void
    let onJoinFriend: (() -> Void)?

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var activePurchase: PurchaseChoice?
    @State private var purchaseCompleted = false
    @State private var statusMessage: String?
    @State private var showsTutorial = false

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

                        if let onJoinFriend {
                            guestActions(onJoinFriend: onJoinFriend)
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
        .fullScreenCover(isPresented: $showsTutorial) {
            GameTutorialView(
                game: game,
                onDismiss: { showsTutorial = false },
                onNeverShowAgain: {
                    GameTutorialPreference.dismiss(for: game.id)
                    showsTutorial = false
                }
            )
            .interactiveDismissDisabled()
        }
        .task {
            if purchaseManager.product(for: game) == nil ||
                purchaseManager.lifetimePassProduct == nil {
                await purchaseManager.loadProducts()
            }
        }
    }

    private func guestActions(onJoinFriend: @escaping () -> Void) -> some View {
        VStack(spacing: 5) {
            Button(action: onJoinFriend) {
                HStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .frame(width: 44, height: 44)
                        .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Join a friend")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Play for free with someone who has unlocked this game.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.cyan)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.cyan.opacity(0.065), in: RoundedRectangle(cornerRadius: 19))
                .overlay {
                    RoundedRectangle(cornerRadius: 19)
                        .strokeBorder(.cyan.opacity(0.24))
                }
            }
            .buttonStyle(.plain)

            Button {
                showsTutorial = true
            } label: {
                Label("How to play", systemImage: "info.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .disabled(activePurchase != nil)
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
