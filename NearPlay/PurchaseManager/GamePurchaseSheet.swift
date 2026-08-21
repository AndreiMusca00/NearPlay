//
//  GamePurchaseSheet.swift
//  NearPlay
//

import SwiftUI
import StoreKit

struct GamePurchaseSheet: View {
    let game: Game
    let onPlay: () -> Void

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var purchaseCompleted = false
    @State private var statusMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(
                        red: 11.0 / 255.0,
                        green: 15.0 / 255.0,
                        blue: 21.0 / 255.0
                    ),
                    Color(
                        red: 7.0 / 255.0,
                        green: 16.0 / 255.0,
                        blue: 24.0 / 255.0
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }

                GameIconView(
                    game: game,
                    size: 88,
                    cornerRadius: 22,
                    symbolSize: 34
                )

                VStack(spacing: 8) {
                    Text("Unlock \(game.title)")
                        .font(
                            .system(
                                size: 26,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("One-time purchase. No NearPlay account required.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                Button {
                    primaryButtonTapped()
                } label: {
                    HStack(spacing: 10) {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(primaryButtonTitle)
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(
                                    red: 0.05,
                                    green: 0.72,
                                    blue: 1.00
                                ),
                                Color(
                                    red: 0.52,
                                    green: 0.28,
                                    blue: 1.00
                                )
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 16,
                            style: .continuous
                        )
                    )
                }
                .buttonStyle(.plain)
                .disabled(primaryButtonDisabled)
                .opacity(primaryButtonDisabled ? 0.55 : 1.0)

                Text("Purchases are processed by the App Store and can be restored with the same Apple Account.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.38))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .task {
            if purchaseManager.product(for: game) == nil {
                await purchaseManager.loadProducts()
            }
        }
    }

    private var primaryButtonTitle: String {
        if purchaseCompleted {
            return "Play now"
        }

        if isPurchasing {
            return "Purchasing..."
        }

        if let product = purchaseManager.product(for: game) {
            return "Unlock for \(product.displayPrice)"
        }

        if purchaseManager.isLoadingProducts {
            return "Loading price..."
        }

        return "Purchase unavailable"
    }

    private var primaryButtonDisabled: Bool {
        if purchaseCompleted {
            return false
        }

        return isPurchasing || purchaseManager.product(for: game) == nil
    }

    private func primaryButtonTapped() {
        if purchaseCompleted {
            dismiss()
            onPlay()
            return
        }

        isPurchasing = true
        statusMessage = nil

        Task {
            do {
                let outcome = try await purchaseManager.purchase(game)

                switch outcome {
                case .purchased:
                    purchaseCompleted = true
                    statusMessage = "Purchase complete. The game is now unlocked."

                case .pending:
                    statusMessage = "Purchase pending approval. The game will unlock automatically when it completes."

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
