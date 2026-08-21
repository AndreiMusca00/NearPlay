//
//  SettingsView.swift
//  NearPlay
//
//  Created by Andrei Musca on 29/07/2026.
//
import SwiftUI
import Foundation

struct SettingsView: View {
    @Binding var playerName: String
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var isEditingName = false
    @State private var selectedLanguage = "English"
    @State private var isRestoringPurchases = false
    @State private var restoreMessage: String?

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

            List {
                Section("Profile") {
                    Button {
                        isEditingName = true
                    } label: {
                        SettingsRow(
                            icon: "person.fill",
                            title: "Player name",
                            value: playerName.isEmpty ? "Player" : playerName
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section("Purchases") {
                    Button {
                        restorePurchases()
                    } label: {
                        HStack(spacing: 14) {
                            SettingsIcon(
                                systemName: "arrow.clockwise",
                                color: .purple
                            )

                            Text(
                                isRestoringPurchases
                                ? "Restoring..."
                                : "Restore Purchases"
                            )
                            .foregroundStyle(.white)

                            Spacer()

                            if isRestoringPurchases {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(
                                        Color.white.opacity(0.3)
                                    )
                            }
                        }
                    }
                    .disabled(isRestoringPurchases)

                    if let restoreMessage {
                        Text(restoreMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Preferences") {
                    Picker(selection: $selectedLanguage) {
                        Text("English").tag("English")
                        Text("Română").tag("Română")
                    } label: {
                        HStack(spacing: 14) {
                            SettingsIcon(
                                systemName: "globe",
                                color: .cyan
                            )

                            Text("Language")
                                .foregroundStyle(.white)
                        }
                    }
                }

                Section("About") {
                    SettingsRow(
                        icon: "info.circle.fill",
                        title: "Version",
                        value: appVersion
                    )
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(
            Color(
                red: 11.0 / 255.0,
                green: 15.0 / 255.0,
                blue: 21.0 / 255.0
            ),
            for: .navigationBar
        )
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $isEditingName) {
            EditNameSheet(name: $playerName)
                .presentationDetents([.medium])
                .preferredColorScheme(.dark)
        }
        .preferredColorScheme(.dark)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String ?? "1.0"
    }

    private func restorePurchases() {
        isRestoringPurchases = true
        restoreMessage = nil

        Task {
            do {
                try await purchaseManager.restorePurchases()

                if purchaseManager.purchasedGameCount > 0 {
                    restoreMessage = "Purchases restored successfully."
                } else {
                    restoreMessage = "No previous purchases were found."
                }
            } catch {
                restoreMessage = "Could not restore purchases. Please try again."
            }

            isRestoringPurchases = false
        }
    }
}
private struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(
                systemName: icon,
                color: .blue
            )

            Text(title)
                .foregroundStyle(.white)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Color.white.opacity(0.3))
        }
    }
}

private struct SettingsIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
                .fill(color.opacity(0.13))
            )
    }
}
