import Foundation
import Combine
import CoreBluetooth
import UIKit

/// Shared NearPlay configuration.
/// `serviceType` is kept only so the legacy Multipeer transport can still compile
/// while it remains in the project as a rollback option.
enum NearbyConfiguration {
    static let serviceType = "nearplay"
}

/// Monitors the Bluetooth permission and radio state required by Nearby Play.
///
/// Nearby Play is Bluetooth-only at the moment, so Local Network / Bonjour
/// permissions are intentionally not part of this manager anymore.
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

    /// Used by the exclamation badge on the Settings icon.
    var needsPermissionAttention: Bool {
        bluetoothPermission != .allowed ||
        bluetoothPower == .off ||
        bluetoothPower == .unsupported
    }

    /// Hard gate used by Nearby Play before discovery starts.
    /// `.unknown` / `.resetting` are not treated as failures because CoreBluetooth
    /// may briefly report them while its manager is initializing.
    var hasRequiredNearbyPermissions: Bool {
        guard bluetoothPermission == .allowed else {
            return false
        }

        switch bluetoothPower {
        case .off, .unsupported:
            return false
        case .unknown, .on, .resetting:
            return true
        }
    }

    var bluetoothNeedsPowerAttention: Bool {
        bluetoothPermission == .allowed && bluetoothPower == .off
    }

    private var bluetoothManager: CBCentralManager?

    override init() {
        super.init()

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
    }

    // MARK: - Public API

    /// Requests Bluetooth access when authorization has not yet been decided.
    /// Creating CBCentralManager is what allows iOS to present the system prompt.
    func requestBluetoothAccess() {
        refreshBluetoothAuthorizationWithoutPrompt()
        ensureBluetoothManagerExists()
    }

    /// Refreshes already-known Bluetooth state without intentionally triggering
    /// a brand-new permission prompt.
    func refreshKnownStatuses() {
        refreshBluetoothAuthorizationWithoutPrompt()

        // Once authorization has already been granted, creating the manager is safe
        // and lets us know whether Bluetooth is currently powered on or off.
        if bluetoothPermission == .allowed {
            ensureBluetoothManagerExists()
        } else {
            refreshBluetoothPowerState()
        }
    }

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

    // MARK: - Internal state

    private func ensureBluetoothManagerExists() {
        if bluetoothManager == nil {
            bluetoothManager = CBCentralManager(
                delegate: self,
                queue: .main,
                options: [
                    CBCentralManagerOptionShowPowerAlertKey: false
                ]
            )
        } else {
            refreshBluetoothPowerState()
        }
    }

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
