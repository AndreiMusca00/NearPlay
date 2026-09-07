import Foundation
import Combine
import CoreBluetooth
import Network
import UIKit

/// Shared configuration used by MultipeerConnectivity and the permission monitor.
enum NearbyConfiguration {
    static let serviceType = "nearplay"
    static let bonjourServiceType = "_nearplay._tcp"
}

/// Monitors the permissions and system state NearPlay needs for nearby play.
///
/// Important:
/// - This class does NOT replace MultipeerConnectivity.
/// - `NearbyService` continues to handle discovery, invitations, sessions and messages.
/// - CoreBluetooth is used here only to request/read Bluetooth authorization and power state.
/// - iOS has no general Local Network authorization API, so Local Network access is checked
///   with a Bonjour `NWBrowser`, following Apple's recommended approach.
final class NearbyPermissionsManager: NSObject, ObservableObject {

    enum PermissionState: String, Equatable {
        case unknown
        case checking
        case notRequested
        case allowed
        case denied
        case restricted
    }

    enum BluetoothPowerState: Equatable {
        case unknown
        case on
        case off
        case resetting
        case unsupported
    }

    @Published private(set) var bluetoothPermission: PermissionState = .unknown
    @Published private(set) var bluetoothPower: BluetoothPowerState = .unknown
    @Published private(set) var localNetworkPermission: PermissionState = .unknown

    /// Use this for the exclamation badge on the Settings icon.
    /// It intentionally represents permission problems, not a temporarily switched-off radio.
    var needsPermissionAttention: Bool {
        // The Settings badge stays visible until both permissions are known to be allowed.
        // Bluetooth power being off is intentionally handled separately.
        bluetoothPermission != .allowed ||
        localNetworkPermission != .allowed
    }

    /// Useful inside the Nearby lobby if you also want to warn that Bluetooth is switched off.
    var bluetoothNeedsPowerAttention: Bool {
        bluetoothPermission == .allowed && bluetoothPower == .off
    }

    private var bluetoothManager: CBCentralManager?
    private var localNetworkBrowser: NWBrowser?

    /// `kDNSServiceErr_PolicyDenied`.
    private static let localNetworkPolicyDeniedCode = -65570
    private static let localNetworkPermissionStorageKey =
        "nearplay.localNetworkPermission"

    override init() {
        super.init()

        restorePersistedLocalNetworkPermission()
        refreshBluetoothAuthorizationWithoutPrompt()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        localNetworkBrowser?.cancel()
    }

    // MARK: - Public API

    /// Call this when the user enters the Nearby/Multiplayer lobby.
    /// Creating `CBCentralManager` is what gives iOS the opportunity to show the
    /// Bluetooth permission alert when authorization is still undetermined.
    func requestBluetoothAccess() {
        refreshBluetoothAuthorizationWithoutPrompt()

        if bluetoothManager == nil {
            bluetoothManager = CBCentralManager(
                delegate: self,
                queue: .main,
                options: [CBCentralManagerOptionShowPowerAlertKey: false]
            )
        }
    }

    /// Checks Local Network access using Bonjour.
    ///
    /// If Local Network access is still undetermined, this operation can cause iOS to
    /// display the Local Network permission alert. If you already start MPC in the lobby,
    /// that MPC operation can be the thing that triggers the alert instead.
    func checkLocalNetworkAccess() {
        localNetworkBrowser?.cancel()
        localNetworkPermission = .checking

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let browser = NWBrowser(
            for: .bonjour(
                type: NearbyConfiguration.bonjourServiceType,
                domain: nil
            ),
            using: parameters
        )

        localNetworkBrowser = browser

        browser.stateUpdateHandler = { [weak self, weak browser] state in
            guard let self else { return }

            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self.setLocalNetworkPermission(.allowed)
                    browser?.cancel()

                case .waiting(let error):
                    if self.isLocalNetworkPolicyDenied(error) {
                        self.setLocalNetworkPermission(.denied)
                        browser?.cancel()
                    } else {
                        // A temporary network condition is not the same as a denied permission.
                        // Keep the last known permission state while the browser waits.
                        self.restorePersistedLocalNetworkPermission()
                    }

                case .failed(let error):
                    if self.isLocalNetworkPolicyDenied(error) {
                        self.setLocalNetworkPermission(.denied)
                    } else {
                        self.restorePersistedLocalNetworkPermission()
                    }
                    browser?.cancel()

                case .cancelled:
                    break

                case .setup:
                    break

                @unknown default:
                    self.localNetworkPermission = .unknown
                    browser?.cancel()
                }
            }
        }

        browser.start(queue: DispatchQueue(label: "nearplay.local-network-permission"))
    }

    /// Convenience method for a permissions/settings screen.
    /// Calling this may show the system permission prompts if they have never been answered.
    func requestAndCheckNearbyAccess() {
        requestBluetoothAccess()
        checkLocalNetworkAccess()
    }

    /// Refreshes states that are already known. This does not intentionally trigger a new
    /// Local Network prompt when its state is still unknown.
    func refreshKnownStatuses() {
        refreshBluetoothAuthorizationWithoutPrompt()
        refreshBluetoothPowerState()

        if localNetworkPermission != .unknown &&
            localNetworkPermission != .checking {
            checkLocalNetworkAccess()
        }
    }

    /// Opens NearPlay's page in the iOS Settings app.
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Display helpers

    var bluetoothPermissionTitle: String {
        switch bluetoothPermission {
        case .unknown:
            return "Unknown"
        case .checking:
            return "Checking…"
        case .notRequested:
            return "Not Requested"
        case .allowed:
            return "Allowed"
        case .denied:
            return "Not Allowed"
        case .restricted:
            return "Restricted"
        }
    }

    var bluetoothPowerTitle: String {
        switch bluetoothPower {
        case .unknown:
            return "Unknown"
        case .on:
            return "On"
        case .off:
            return "Off"
        case .resetting:
            return "Resetting…"
        case .unsupported:
            return "Unavailable"
        }
    }

    var localNetworkPermissionTitle: String {
        switch localNetworkPermission {
        case .unknown:
            return "Unknown"
        case .checking:
            return "Checking…"
        case .notRequested:
            return "Not Requested"
        case .allowed:
            return "Allowed"
        case .denied:
            return "Not Allowed"
        case .restricted:
            return "Restricted"
        }
    }

    // MARK: - Internal state refresh

    private func refreshBluetoothAuthorizationWithoutPrompt() {
        switch CBManager.authorization {
        case .notDetermined:
            bluetoothPermission = .notRequested

        case .allowedAlways:
            bluetoothPermission = .allowed

        case .denied:
            bluetoothPermission = .denied

        case .restricted:
            bluetoothPermission = .restricted

        @unknown default:
            bluetoothPermission = .unknown
        }
    }

    private func refreshBluetoothPowerState() {
        guard let bluetoothManager else {
            bluetoothPower = .unknown
            return
        }

        switch bluetoothManager.state {
        case .unknown:
            bluetoothPower = .unknown
        case .resetting:
            bluetoothPower = .resetting
        case .unsupported:
            bluetoothPower = .unsupported
        case .unauthorized:
            bluetoothPower = .unknown
        case .poweredOff:
            bluetoothPower = .off
        case .poweredOn:
            bluetoothPower = .on
        @unknown default:
            bluetoothPower = .unknown
        }
    }


    private func setLocalNetworkPermission(_ state: PermissionState) {
        localNetworkPermission = state

        switch state {
        case .allowed, .denied, .restricted:
            UserDefaults.standard.set(
                state.rawValue,
                forKey: Self.localNetworkPermissionStorageKey
            )

        case .unknown, .checking, .notRequested:
            break
        }
    }

    private func restorePersistedLocalNetworkPermission() {
        guard let rawValue = UserDefaults.standard.string(
            forKey: Self.localNetworkPermissionStorageKey
        ),
        let storedState = PermissionState(rawValue: rawValue),
        storedState == .allowed ||
            storedState == .denied ||
            storedState == .restricted else {
            localNetworkPermission = .unknown
            return
        }

        localNetworkPermission = storedState
    }

    private func isLocalNetworkPolicyDenied(_ error: NWError) -> Bool {
        guard case .dns(let code) = error else {
            return false
        }

        return Int(code) == Self.localNetworkPolicyDeniedCode
    }

    @objc private func appDidBecomeActive() {
        refreshKnownStatuses()
    }
}

// MARK: - CBCentralManagerDelegate

extension NearbyPermissionsManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        refreshBluetoothAuthorizationWithoutPrompt()
        refreshBluetoothPowerState()
    }
}
