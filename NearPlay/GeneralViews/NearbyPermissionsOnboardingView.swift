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
        case requestingLocalNetwork
        case readyToProceed
    }

    @State private var setupStage: SetupStage = .idle
    @State private var didStartLocalNetworkRequest = false

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
            // Refresh only already-known states. This does not intentionally
            // trigger a brand-new Local Network permission prompt.
            nearbyPermissions.refreshKnownStatuses()
        }
        .onChange(of: nearbyPermissions.bluetoothPermission) { _, newValue in
            guard setupStage == .requestingBluetooth,
                  bluetoothDecisionReached(newValue) else {
                return
            }

            requestLocalNetworkIfNeeded()
        }
        .onChange(of: nearbyPermissions.localNetworkPermission) { _, newValue in
            guard setupStage == .requestingLocalNetwork,
                  localNetworkDecisionReached(newValue) else {
                return
            }

            // IMPORTANT: do not complete/navigate the onboarding here.
            // We only unlock the Proceed button. The user decides when to leave.
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

                Image(systemName: "antenna.radiowaves.left.and.right")
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
                    "NearPlay connects nearby devices directly. No internet connection is required, and both players do not need to be connected to the same Wi-Fi network."
                )
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.60))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            }
        }
    }

    // MARK: - Permissions

    private var permissionsCard: some View {
        VStack(spacing: 0) {
            permissionRow(
                icon: "wave.3.right",
                title: "Bluetooth",
                text: "Helps NearPlay discover and connect to players close to you.",
                state: bluetoothDisplayState
            )

            Divider()
                .overlay(Color.white.opacity(0.08))
                .padding(.leading, 64)

            permissionRow(
                icon: "network",
                title: "Local Network",
                text: "Allows nearby devices to discover each other and communicate directly.",
                state: localNetworkDisplayState
            )
        }
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
                    if isRequestingPermissions {
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
                .opacity(isRequestingPermissions ? 0.78 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(isRequestingPermissions)

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
                        allPermissionsAllowed
                            ? Color.green.opacity(0.80)
                            : Color.orange.opacity(0.82)
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .transition(.opacity)
            } else {
                Text(
                    isRequestingPermissions
                        ? "Please answer both iOS permission prompts to finish setup."
                        : "You can review or change these permissions later from NearPlay Settings."
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
        case .requestingLocalNetwork:
            return "Waiting for Local Network…"
        case .readyToProceed:
            return "Proceed"
        }
    }

    private var isRequestingPermissions: Bool {
        setupStage == .requestingBluetooth ||
        setupStage == .requestingLocalNetwork
    }

    private var allPermissionsAllowed: Bool {
        nearbyPermissions.bluetoothPermission == .allowed &&
        nearbyPermissions.localNetworkPermission == .allowed
    }

    private var completionMessage: String {
        if allPermissionsAllowed {
            return "Nearby Play is ready. You can continue."
        }

        return "Setup is complete, but Nearby Play will remain unavailable until the missing permission is enabled in Settings."
    }

    // MARK: - Permission flow

    private func primaryButtonTapped() {
        switch setupStage {
        case .idle:
            startPermissionFlow()

        case .requestingBluetooth, .requestingLocalNetwork:
            break

        case .readyToProceed:
            completeOnboarding()
        }
    }

    private func startPermissionFlow() {
        guard setupStage == .idle else { return }

        didStartLocalNetworkRequest = false

        withAnimation(.easeInOut(duration: 0.2)) {
            setupStage = .requestingBluetooth
        }

        nearbyPermissions.requestBluetoothAccess()

        // If Bluetooth permission had already been decided before onboarding,
        // iOS will not show a new prompt and no authorization transition may occur.
        // In that case, continue immediately to Local Network.
        if bluetoothDecisionReached(nearbyPermissions.bluetoothPermission) {
            requestLocalNetworkIfNeeded()
        }
    }

    private func requestLocalNetworkIfNeeded() {
        guard setupStage == .requestingBluetooth,
              !didStartLocalNetworkRequest else {
            return
        }

        didStartLocalNetworkRequest = true

        withAnimation(.easeInOut(duration: 0.2)) {
            setupStage = .requestingLocalNetwork
        }

        nearbyPermissions.checkLocalNetworkAccess()
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

    private func localNetworkDecisionReached(
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
        // This is the ONLY place where onboarding is marked complete.
        // Therefore answering a system permission prompt can never navigate
        // the user away from this screen by itself.
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

    private var localNetworkDisplayState: PermissionDisplayState {
        if setupStage == .requestingLocalNetwork {
            return .requesting
        }

        // Before the setup reaches Local Network, keep the row visually waiting
        // unless we already know the permission from a previous app run.
        if setupStage == .idle || setupStage == .requestingBluetooth {
            switch nearbyPermissions.localNetworkPermission {
            case .allowed:
                return .allowed
            case .denied:
                return .denied
            case .restricted:
                return .restricted
            default:
                return .waiting
            }
        }

        switch nearbyPermissions.localNetworkPermission {
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
