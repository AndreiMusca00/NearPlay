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
    @EnvironmentObject private var nearbyPermissions: NearbyPermissionsManager

    @State private var isEditingName = false
    @State private var selectedLanguage = "English"
    @State private var isRestoringPurchases = false
    @State private var restoreMessage: String?

    // MARK: - Legal URLs

    private let privacyPolicyURL = URL(
        string: "https://sites.google.com/view/nearplay-privacypolicy/home"
    )!

    private let termsOfUseURL = URL(
        string: "https://sites.google.com/view/nearplay-termsofuse/home"
    )!

    private let supportURL = URL(
        string: "https://sites.google.com/view/nearplay-contact/home"
    )!

    var body: some View {
        ZStack {
            appBackground

            VStack(spacing: 0) {

                List {

                    // MARK: - Profile

                    Section("Profile") {
                        Button {
                            isEditingName = true
                        } label: {
                            SettingsRow(
                                icon: "person.fill",
                                title: "Player name",
                                value: playerName.isEmpty
                                    ? "Player"
                                    : playerName
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // MARK: - Nearby Play

                    Section {
                        NearbyPermissionRow(
                            icon: "antenna.radiowaves.left.and.right",
                            iconColor: .blue,
                            title: "Bluetooth",
                            status: bluetoothStatusText,
                            isAllowed: nearbyPermissions.bluetoothPermission == .allowed,
                            isChecking: nearbyPermissions.bluetoothPermission == .checking
                        )

                        NearbyPermissionRow(
                            icon: "network",
                            iconColor: .cyan,
                            title: "Local Network",
                            status: nearbyPermissions.localNetworkPermissionTitle,
                            isAllowed: nearbyPermissions.localNetworkPermission == .allowed,
                            isChecking: nearbyPermissions.localNetworkPermission == .checking
                        )

                        if nearbyPermissions.bluetoothNeedsPowerAttention {
                            Label(
                                "Bluetooth access is allowed, but Bluetooth is currently turned off.",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(.orange)
                        }

                        if nearbyPermissions.bluetoothPermission == .notRequested {
                            Button {
                                nearbyPermissions.requestBluetoothAccess()
                            } label: {
                                NearbySettingsActionRow(
                                    icon: "wave.3.right.circle.fill",
                                    title: "Request Bluetooth Access"
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if nearbyPermissions.localNetworkPermission == .unknown ||
                            nearbyPermissions.localNetworkPermission == .notRequested {
                            Button {
                                nearbyPermissions.checkLocalNetworkAccess()
                            } label: {
                                NearbySettingsActionRow(
                                    icon: "network.badge.shield.half.filled",
                                    title: "Check Local Network Access"
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if hasDeniedNearbyPermission {
                            Button {
                                nearbyPermissions.openAppSettings()
                            } label: {
                                NearbySettingsActionRow(
                                    icon: "gearshape.fill",
                                    title: "Open iOS Settings"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Nearby Play")
                    } footer: {
                        Text(
                            "Bluetooth and Local Network access are used to discover nearby players. The phones do not need to be connected to the same Wi-Fi network."
                        )
                    }

                    // MARK: - Purchases

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

                    // MARK: - Preferences

                    Section("Preferences") {
                        Picker(selection: $selectedLanguage) {
                            Text("English")
                                .tag("English")

                            Text("Română")
                                .tag("Română")
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

                    // MARK: - Legal & Support

                    Section("Legal & Support") {

                        Link(destination: privacyPolicyURL) {
                            SettingsLinkRow(
                                icon: "hand.raised.fill",
                                iconColor: .blue,
                                title: "Privacy Policy"
                            )
                        }
                        .buttonStyle(.plain)

                        Link(destination: termsOfUseURL) {
                            SettingsLinkRow(
                                icon: "doc.text.fill",
                                iconColor: .purple,
                                title: "Terms of Use"
                            )
                        }
                        .buttonStyle(.plain)

                        Link(destination: supportURL) {
                            SettingsLinkRow(
                                icon: "questionmark.circle.fill",
                                iconColor: .cyan,
                                title: "Support"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollContentBackground(.hidden)

                // MARK: - Footer

                settingsFooter
            }
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
        .toolbarBackground(
            .visible,
            for: .navigationBar
        )
        .sheet(isPresented: $isEditingName) {
            EditNameSheet(name: $playerName)
                .presentationDetents([.medium])
                .preferredColorScheme(.dark)
        }
        .onAppear {
            // Refresh already-known states without forcing a new permission prompt.
            nearbyPermissions.refreshKnownStatuses()
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Nearby permissions

    private var bluetoothStatusText: String {
        guard nearbyPermissions.bluetoothPermission == .allowed else {
            return nearbyPermissions.bluetoothPermissionTitle
        }

        switch nearbyPermissions.bluetoothPower {
        case .on:
            return "Allowed • On"
        case .off:
            return "Allowed • Off"
        case .resetting:
            return "Allowed • Resetting…"
        case .unsupported:
            return "Allowed • Unavailable"
        case .unknown:
            return "Allowed"
        }
    }

    private var hasDeniedNearbyPermission: Bool {
        nearbyPermissions.bluetoothPermission == .denied ||
        nearbyPermissions.bluetoothPermission == .restricted ||
        nearbyPermissions.localNetworkPermission == .denied ||
        nearbyPermissions.localNetworkPermission == .restricted
    }

    // MARK: - Background

    private var appBackground: some View {
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
    }

    // MARK: - Footer

    private var settingsFooter: some View {
        VStack(spacing: 6) {
            Text("Version \(appVersion) (\(buildNumber))")
                .font(
                    .system(
                        size: 12,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.32)
                )

            Text("Powered by Fly Technology & Innovation")
                .font(
                    .system(
                        size: 12,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.48)
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    // MARK: - App Version

    private var appVersion: String {
        Bundle.main
            .infoDictionary?["CFBundleShortVersionString"]
            as? String ?? "1.0"
    }

    // MARK: - Build Number

    private var buildNumber: String {
        Bundle.main
            .infoDictionary?["CFBundleVersion"]
            as? String ?? "1"
    }

    // MARK: - Restore Purchases

    private func restorePurchases() {
        isRestoringPurchases = true
        restoreMessage = nil

        Task {
            do {
                try await purchaseManager.restorePurchases()

                if purchaseManager.purchasedGameCount > 0 {
                    restoreMessage =
                        "Purchases restored successfully."
                } else {
                    restoreMessage =
                        "No previous purchases were found."
                }

            } catch {
                restoreMessage =
                    "Could not restore purchases. Please try again."
            }

            isRestoringPurchases = false
        }
    }
}

// MARK: - Nearby Permission Row

private struct NearbyPermissionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let status: String
    let isAllowed: Bool
    let isChecking: Bool

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(
                systemName: icon,
                color: iconColor
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.white)

                Text(status)
                    .font(.caption)
                    .foregroundStyle(
                        isAllowed
                            ? Color.green.opacity(0.9)
                            : Color.white.opacity(0.5)
                    )
            }

            Spacer()

            if isChecking {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(
                    systemName: isAllowed
                        ? "checkmark.circle.fill"
                        : "exclamationmark.circle.fill"
                )
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isAllowed ? .green : .orange)
            }
        }
    }
}

// MARK: - Nearby Settings Action Row

private struct NearbySettingsActionRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(
                systemName: icon,
                color: .blue
            )

            Text(title)
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Color.white.opacity(0.3))
        }
    }
}

// MARK: - Settings Row

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
                .foregroundStyle(
                    Color.white.opacity(0.3)
                )
        }
    }
}

// MARK: - Link Row

private struct SettingsLinkRow: View {
    let icon: String
    let iconColor: Color
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(
                systemName: icon,
                color: iconColor
            )

            Text(title)
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.3)
                )
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Settings Icon

private struct SettingsIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(
                .system(
                    size: 15,
                    weight: .semibold
                )
            )
            .foregroundStyle(color)
            .frame(
                width: 30,
                height: 30
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
                .fill(
                    color.opacity(0.13)
                )
            )
    }
}
