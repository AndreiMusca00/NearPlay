import SwiftUI

struct AllGamesBundlePurchaseSheet: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var purchaseCompleted = false
    @State private var statusMessage: String?
    @State private var glowIsExpanded = false

    private var premiumGames: [Game] {
        Game.all.filter { $0.productID != nil }
    }

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 0) {
                    topBar
                    hero
                        .padding(.top, 8)

                    VStack(spacing: 8) {
                        Text(purchaseCompleted ? "Lifetime Access Active" : "NearPlay Lifetime Pass")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text(
                            purchaseCompleted
                                ? "Every premium game is yours — now and in the future."
                                : "One purchase. Every premium game today, plus every premium game we add later."
                        )
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 10)
                    }
                    .padding(.top, 17)

                    gameCollectionPreview
                        .padding(.top, 20)

                    benefitsCard
                        .padding(.top, 22)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .padding(.top, 16)
                    }

                    priceCard
                        .padding(.top, 18)

                    purchaseButton
                        .padding(.top, 12)

                    Text("Individual games remain available separately. Purchases can be restored with the same Apple Account.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.36))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 12)
                        .padding(.top, 13)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            if purchaseManager.lifetimePassProduct == nil {
                await purchaseManager.loadProducts()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                glowIsExpanded = true
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.018, green: 0.032, blue: 0.075),
                    Color(red: 0.055, green: 0.027, blue: 0.115),
                    Color(red: 0.018, green: 0.025, blue: 0.052)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.cyan.opacity(glowIsExpanded ? 0.20 : 0.11))
                .frame(width: glowIsExpanded ? 270 : 220, height: glowIsExpanded ? 270 : 220)
                .blur(radius: 58)
                .offset(x: -150, y: -260)

            Circle()
                .fill(Color.purple.opacity(glowIsExpanded ? 0.22 : 0.12))
                .frame(width: glowIsExpanded ? 320 : 250, height: glowIsExpanded ? 320 : 250)
                .blur(radius: 68)
                .offset(x: 155, y: 180)
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Text("LIFETIME ACCESS")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(Color.cyan.opacity(0.92))
                .padding(.horizontal, 11)
                .frame(height: 28)
                .background(Capsule().fill(Color.cyan.opacity(0.10)))
                .overlay(Capsule().stroke(Color.cyan.opacity(0.22), lineWidth: 1))

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.075)))
                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
    }

    private var hero: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.18), Color.purple.opacity(0.04), .clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 72
                    )
                )
                .frame(width: 144, height: 144)
                .scaleEffect(glowIsExpanded ? 1.07 : 0.94)

            Circle()
                .fill(Color.white.opacity(0.045))
                .frame(width: 104, height: 104)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.85), .purple.opacity(0.78), .pink.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.cyan.opacity(0.22), radius: 18)

            Image(systemName: purchaseCompleted ? "checkmark" : "infinity")
                .font(.system(size: purchaseCompleted ? 38 : 47, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, Color(red: 0.57, green: 0.34, blue: 1.0), .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .frame(height: 132)
    }

    private var gameCollectionPreview: some View {
        VStack(spacing: 10) {
            HStack(spacing: -9) {
                ForEach(premiumGames) { game in
                    GameIconView(
                        game: game,
                        size: 46,
                        cornerRadius: 13,
                        symbolSize: 19
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color(red: 0.03, green: 0.04, blue: 0.09), lineWidth: 3)
                    )
                    .shadow(color: game.accentColor.opacity(0.18), radius: 7)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Color.white.opacity(0.24))
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.60))
                }
                .frame(width: 46, height: 46)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color(red: 0.03, green: 0.04, blue: 0.09), lineWidth: 3)
                )
            }

            Text("Your collection keeps growing")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.48))
        }
    }

    private var benefitsCard: some View {
        VStack(spacing: 0) {
            benefitRow(
                icon: "gamecontroller.fill",
                color: .cyan,
                title: "Every premium game available now",
                subtitle: "Play the entire current collection"
            )

            Divider().overlay(Color.white.opacity(0.07)).padding(.leading, 52)

            benefitRow(
                icon: "sparkles",
                color: .purple,
                title: "Every future premium release",
                subtitle: "New games unlock after they arrive"
            )

            Divider().overlay(Color.white.opacity(0.07)).padding(.leading, 52)

            benefitRow(
                icon: "nosign",
                color: .pink,
                title: "No subscription",
                subtitle: "Pay once and keep lifetime access"
            )
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.052))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }

    private func benefitRow(
        icon: String,
        color: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(Circle().fill(color.opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.43))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 64)
    }

    private var priceCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ONE-TIME PURCHASE")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Color.cyan.opacity(0.84))

                Text("Yours forever")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            if let price = purchaseManager.lifetimePassDisplayPrice {
                Text(price)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                ProgressView().tint(.white)
            }
        }
        .padding(.horizontal, 17)
        .frame(height: 70)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.105), Color.purple.opacity(0.14)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.34), Color.purple.opacity(0.34)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var purchaseButton: some View {
        Button(action: primaryAction) {
            HStack(spacing: 9) {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: purchaseCompleted ? "checkmark" : "infinity")
                        .font(.system(size: 17, weight: .black))
                }

                Text(primaryButtonTitle)
                    .font(.system(size: 17, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.00, green: 0.65, blue: 0.95),
                        Color(red: 0.46, green: 0.26, blue: 0.98),
                        Color(red: 0.82, green: 0.20, blue: 0.70)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .shadow(color: Color.purple.opacity(0.30), radius: 16, y: 7)
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing || (!purchaseCompleted && purchaseManager.lifetimePassProduct == nil))
        .opacity(purchaseManager.lifetimePassProduct == nil && !purchaseCompleted ? 0.58 : 1)
    }

    private var primaryButtonTitle: String {
        if purchaseCompleted { return "Done" }
        if isPurchasing { return "Completing purchase…" }
        guard let price = purchaseManager.lifetimePassDisplayPrice else {
            return "Loading price…"
        }
        return "Get lifetime access · \(price)"
    }

    private func primaryAction() {
        if purchaseCompleted {
            dismiss()
            return
        }

        isPurchasing = true
        statusMessage = nil

        Task {
            do {
                let outcome = try await purchaseManager.purchaseLifetimePass()
                switch outcome {
                case .purchased:
                    purchaseCompleted = true
                    statusMessage = "Lifetime access is active. Welcome to the full collection."
                case .pending:
                    statusMessage = "Purchase pending approval. Lifetime access will activate automatically."
                case .cancelled:
                    statusMessage = nil
                }
            } catch {
                statusMessage = error.localizedDescription
            }
            isPurchasing = false
        }
    }
}
