import SwiftUI

enum NearbyOnboardingStorage {
    static let completedKey = "nearplay.hasCompletedNearbyPermissionsOnboarding"
}

struct NearbyPermissionsOnboardingView: View {
    @EnvironmentObject private var nearbyPermissions: NearbyPermissionsManager

    @AppStorage(NearbyOnboardingStorage.completedKey)
    private var hasCompletedOnboarding = false

    private enum SetupStage: Equatable {
        case idle
        case requestingBluetooth
        case readyToProceed
    }

    @State private var setupStage: SetupStage = .idle

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 28) {
                    header
                    permissionsCard
                    actions
                }
                .padding(.horizontal, 24)
                .padding(.top, 44)
                .padding(.bottom, 30)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            nearbyPermissions.refreshKnownStatuses()
        }
        .onChange(of: nearbyPermissions.bluetoothPermission) { _, newValue in
            guard setupStage == .requestingBluetooth,
                  bluetoothDecisionReached(newValue) else {
                return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                setupStage = .readyToProceed
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.055))
                    .frame(width: 108, height: 108)

                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 108, height: 108)

                Image(systemName: "wave.3.right")
                    .font(.system(size: 43, weight: .medium))
                    .foregroundStyle(primaryGradient)
            }

            VStack(spacing: 9) {
                Text("Play Together Nearby")
                    .font(
                        .system(
                            size: 31,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(
                    "NearPlay connects nearby devices directly over Bluetooth. No internet connection or Wi-Fi network is required."
                )
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.60))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            }
        }
    }

    // MARK: - Permission

    private var permissionsCard: some View {
        permissionRow(
            icon: "wave.3.right",
            title: "Bluetooth",
            text: "Allows NearPlay to discover, connect to, and play with people close to you.",
            state: bluetoothDisplayState
        )
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.045))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        }
    }

    private func permissionRow(
        icon: String,
        title: String,
        text: String,
        state: PermissionDisplayState
    ) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.cyan)
                .frame(width: 34, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.cyan.opacity(0.10))
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)

                Text(state.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(state.textColor)
                    .padding(.top, 2)
            }

            Spacer(minLength: 12)

            permissionStatusView(state)
                .frame(width: 28, height: 34)
        }
        .padding(18)
    }

    @ViewBuilder
    private func permissionStatusView(
        _ state: PermissionDisplayState
    ) -> some View {
        switch state {
        case .waiting:
            Image(systemName: "circle")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.20))

        case .requesting:
            ProgressView()
                .tint(.cyan)
                .controlSize(.small)

        case .allowed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.green)

        case .denied, .restricted:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.orange)

        case .unknown:
            Image(systemName: "questionmark.circle")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.35))
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 14) {
            Button {
                primaryButtonTapped()
            } label: {
                HStack(spacing: 10) {
                    if setupStage == .requestingBluetooth {
                        ProgressView()
                            .tint(.white)
                            .controlSize(.small)
                    }

                    Text(primaryButtonTitle)
                        .font(.system(size: 17, weight: .semibold))

                    if setupStage == .readyToProceed {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(primaryGradient)
                }
                .opacity(setupStage == .requestingBluetooth ? 0.78 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(setupStage == .requestingBluetooth)

            if setupStage == .idle {
                Button("Not Now") {
                    completeOnboarding()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            if setupStage == .readyToProceed {
                Text(completionMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(
                        nearbyPermissions.bluetoothPermission == .allowed
                            ? Color.green.opacity(0.80)
                            : Color.orange.opacity(0.82)
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .transition(.opacity)
            } else {
                Text(
                    setupStage == .requestingBluetooth
                        ? "Please answer the iOS Bluetooth permission prompt to finish setup."
                        : "You can review or change Bluetooth access later from NearPlay Settings."
                )
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.32))
                .multilineTextAlignment(.center)
                .padding(.top, 2)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: setupStage)
    }

    private var primaryButtonTitle: String {
        switch setupStage {
        case .idle:
            return "Enable Nearby Play"
        case .requestingBluetooth:
            return "Waiting for Bluetooth…"
        case .readyToProceed:
            return "Proceed"
        }
    }

    private var completionMessage: String {
        if nearbyPermissions.bluetoothPermission == .allowed {
            if nearbyPermissions.bluetoothPower == .off {
                return "Bluetooth access is allowed. Turn Bluetooth on before using Nearby Play."
            }

            return "Nearby Play is ready. You can continue."
        }

        return "Setup is complete, but Nearby Play will remain unavailable until Bluetooth access is enabled in Settings."
    }

    // MARK: - Permission flow

    private func primaryButtonTapped() {
        switch setupStage {
        case .idle:
            startPermissionFlow()
        case .requestingBluetooth:
            break
        case .readyToProceed:
            completeOnboarding()
        }
    }

    private func startPermissionFlow() {
        guard setupStage == .idle else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            setupStage = .requestingBluetooth
        }

        nearbyPermissions.requestBluetoothAccess()

        // If authorization had already been decided on a previous run,
        // there may be no state transition callback to wait for.
        if bluetoothDecisionReached(nearbyPermissions.bluetoothPermission) {
            withAnimation(.easeInOut(duration: 0.2)) {
                setupStage = .readyToProceed
            }
        }
    }

    private func bluetoothDecisionReached(
        _ state: NearbyPermissionsManager.PermissionState
    ) -> Bool {
        switch state {
        case .allowed, .denied, .restricted:
            return true
        case .unknown, .checking, .notRequested:
            return false
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    // MARK: - Display state

    private enum PermissionDisplayState: Equatable {
        case waiting
        case requesting
        case allowed
        case denied
        case restricted
        case unknown

        var title: String {
            switch self {
            case .waiting:
                return "Waiting"
            case .requesting:
                return "Waiting for your response…"
            case .allowed:
                return "Allowed"
            case .denied:
                return "Not Allowed"
            case .restricted:
                return "Restricted"
            case .unknown:
                return "Not checked"
            }
        }

        var textColor: Color {
            switch self {
            case .allowed:
                return .green
            case .denied, .restricted:
                return .orange
            case .requesting:
                return .cyan
            case .waiting, .unknown:
                return Color.white.opacity(0.36)
            }
        }
    }

    private var bluetoothDisplayState: PermissionDisplayState {
        if setupStage == .requestingBluetooth {
            return .requesting
        }

        switch nearbyPermissions.bluetoothPermission {
        case .allowed:
            return .allowed
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .checking:
            return .requesting
        case .notRequested:
            return .waiting
        case .unknown:
            return .unknown
        }
    }

    // MARK: - Theme

    private var background: some View {
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

    private var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.72, blue: 1.00),
                Color(red: 0.35, green: 0.40, blue: 1.00),
                Color(red: 0.66, green: 0.25, blue: 1.00)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

#Preview {
    NearbyPermissionsOnboardingView()
        .environmentObject(NearbyPermissionsManager())
}
