import Foundation
import CoreBluetooth
import CryptoKit

/// CoreBluetooth implementation of NearbyTransport.
///
/// Architecture:
/// - Every device advertises a NearPlay BLE service for the current game.
/// - Every device scans for the same game-specific service UUID.
/// - The player who taps Invite becomes the BLE central for that connection.
/// - The invited player remains the BLE peripheral.
/// - Central -> Peripheral traffic uses characteristic writes with response.
/// - Peripheral -> Central traffic uses characteristic notifications.
/// - NearbyMessage remains transport-agnostic and is simply encoded as JSON.
final class BluetoothTransport: NSObject, NearbyTransport {
    weak var delegate: NearbyTransportDelegate?

    // MARK: - BLE constants

    /// One characteristic is enough for NearPlay's bidirectional protocol:
    /// central writes to it; peripheral notifies subscribed centrals from it.
    private let characteristicUUID = CBUUID(
        string: "F41E9E11-4C82-4E80-9A21-72E0D63D8F7B"
    )

    private let maximumFrameSize = 1_048_576 // 1 MB safety cap
    private let discoveryExpiry: TimeInterval = 6

    // MARK: - Configuration

    private var configuration: NearbyTransportConfiguration?
    private var serviceUUID: CBUUID?

    // MARK: - CoreBluetooth managers

    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?

    private var mutableService: CBMutableService?
    private var mutableCharacteristic: CBMutableCharacteristic?

    // MARK: - Discovery

    /// Temporary BLE discovery peer ID -> CBPeripheral.
    ///
    /// Before a real NearPlay connection exists, CoreBluetooth does not expose
    /// our app-level player ID in advertisements, so discovery temporarily uses
    /// CBPeripheral.identifier. After invitation acceptance, the transport
    /// replaces it with the real NearPlay player ID received in the handshake.
    private var peripheralsByDiscoveryPeerID: [String: CBPeripheral] = [:]
    private var discoveryPeerByPeripheralID: [UUID: NearbyPeer] = [:]
    private var lastSeenByPeripheralID: [UUID: Date] = [:]
    private var discoveryCleanupTimer: Timer?

    // MARK: - Outgoing invitation / central role

    private struct OutgoingInvitationRecord {
        let discoveryPeer: NearbyPeer
        let peripheral: CBPeripheral
        let context: InvitationContext
        let expiresAt: Date
    }

    private var outgoingInvitation: OutgoingInvitationRecord?
    private var outgoingTimeoutWorkItem: DispatchWorkItem?

    /// The real NearPlay identity of the peer on our outgoing BLE connection.
    /// Discovery initially only gives us a temporary CBPeripheral identifier,
    /// so we resolve the app-level playerID with HELLO / HELLO_ACK before
    /// sending the actual invitation.
    private var outgoingResolvedIdentity: BluetoothPeerIdentity?
    private var helloSentSessionID: String?
    private var invitationSentSessionID: String?

    private struct DeferredIncomingInvitation {
        let envelope: BluetoothEnvelope
        let central: CBCentral
    }

    /// If both players tap Invite at the same time, the incoming invitation can
    /// arrive before our outgoing HELLO_ACK. Keep it until the remote NearPlay
    /// playerID is known, then resolve the collision deterministically.
    private var deferredIncomingInvitations: [UUID: DeferredIncomingInvitation] = [:]

    private var connectedPeripheral: CBPeripheral?
    private var remoteCharacteristic: CBCharacteristic?

    // MARK: - Incoming invitation / peripheral role

    private struct IncomingInvitationRecord {
        let central: CBCentral
        let peer: NearbyPeer
        let context: InvitationContext
    }

    private var incomingInvitations: [String: IncomingInvitationRecord] = [:]
    private var subscribedCentralsByID: [UUID: CBCentral] = [:]

    // MARK: - Active NearPlay connection

    private enum ActiveRole {
        case central
        case peripheral
    }

    private var activeRole: ActiveRole?
    private var activeRemotePeer: NearbyPeer?
    private var activeSessionID: String?
    private var activePeripheralCentralID: UUID?

    // MARK: - Framing buffers

    /// Incoming stream when this device acts as a central.
    private var incomingBufferFromPeripheral = Data()

    /// Incoming stream per remote central when this device acts as a peripheral.
    private var incomingBuffersFromCentrals: [UUID: Data] = [:]

    // MARK: - Central write queue

    private struct PendingCentralWrite {
        let data: Data
        let completion: (() -> Void)?
    }

    private var centralWriteQueue: [PendingCentralWrite] = []
    private var centralWriteInFlight: PendingCentralWrite?

    // MARK: - Peripheral notification queue

    private struct PendingNotification {
        let data: Data
        let centralID: UUID
    }

    private var peripheralNotificationQueue: [PendingNotification] = []

    // MARK: - NearbyTransport lifecycle

    func start(configuration: NearbyTransportConfiguration) {
        stop()

        self.configuration = configuration
        self.serviceUUID = makeServiceUUID(gameID: configuration.gameID)

        // Use the main queue for both managers. This keeps all transport state
        // serialized and avoids fighting SwiftUI / NearbyService state updates.
        centralManager = CBCentralManager(
            delegate: self,
            queue: .main
        )

        peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: .main
        )

        startDiscoveryCleanupTimer()
    }

    func stop() {
        outgoingTimeoutWorkItem?.cancel()
        outgoingTimeoutWorkItem = nil

        discoveryCleanupTimer?.invalidate()
        discoveryCleanupTimer = nil

        centralManager?.stopScan()

        if let connectedPeripheral {
            centralManager?.cancelPeripheralConnection(
                connectedPeripheral
            )
        }

        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()

        centralManager?.delegate = nil
        peripheralManager?.delegate = nil

        centralManager = nil
        peripheralManager = nil
        mutableService = nil
        mutableCharacteristic = nil

        peripheralsByDiscoveryPeerID.removeAll()
        discoveryPeerByPeripheralID.removeAll()
        lastSeenByPeripheralID.removeAll()

        outgoingInvitation = nil
        outgoingResolvedIdentity = nil
        helloSentSessionID = nil
        invitationSentSessionID = nil
        deferredIncomingInvitations.removeAll()

        connectedPeripheral = nil
        remoteCharacteristic = nil

        incomingInvitations.removeAll()
        subscribedCentralsByID.removeAll()

        activeRole = nil
        activeRemotePeer = nil
        activeSessionID = nil
        activePeripheralCentralID = nil

        incomingBufferFromPeripheral.removeAll(keepingCapacity: false)
        incomingBuffersFromCentrals.removeAll()

        centralWriteQueue.removeAll()
        centralWriteInFlight = nil
        peripheralNotificationQueue.removeAll()

        configuration = nil
        serviceUUID = nil
    }

    // MARK: - Invitation flow

    func invite(
        _ peer: NearbyPeer,
        context: InvitationContext,
        timeout: TimeInterval
    ) {
        guard activeRemotePeer == nil else {
            return
        }

        guard let peripheral = peripheralsByDiscoveryPeerID[peer.id],
              let centralManager else {
            reportFailure(
                BluetoothTransportError.peerUnavailable(
                    peer.displayName
                )
            )
            return
        }

        outgoingTimeoutWorkItem?.cancel()

        outgoingResolvedIdentity = nil
        helloSentSessionID = nil
        invitationSentSessionID = nil

        outgoingInvitation = OutgoingInvitationRecord(
            discoveryPeer: peer,
            peripheral: peripheral,
            context: context,
            expiresAt: Date().addingTimeInterval(timeout)
        )

        connectedPeripheral = peripheral
        peripheral.delegate = self

        if peripheral.state == .connected {
            beginServiceDiscovery(on: peripheral)
        } else {
            centralManager.connect(
                peripheral,
                options: nil
            )
        }

        let workItem = DispatchWorkItem { [weak self, weak peripheral] in
            guard let self,
                  let peripheral,
                  let outgoing = self.outgoingInvitation,
                  outgoing.context.sessionID == context.sessionID else {
                return
            }

            self.outgoingInvitation = nil
            self.outgoingResolvedIdentity = nil
            self.helloSentSessionID = nil
            self.invitationSentSessionID = nil

            self.centralManager?.cancelPeripheralConnection(
                peripheral
            )
        }

        outgoingTimeoutWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + timeout,
            execute: workItem
        )
    }

    func acceptInvitation(sessionID: String) {
        guard let record = incomingInvitations.removeValue(
            forKey: sessionID
        ) else {
            reportFailure(
                BluetoothTransportError.invitationUnavailable
            )
            return
        }

        guard subscribedCentralsByID[record.central.identifier] != nil else {
            reportFailure(
                BluetoothTransportError.centralNotSubscribed
            )
            return
        }

        activeRole = .peripheral
        activeRemotePeer = record.peer
        activeSessionID = sessionID
        activePeripheralCentralID = record.central.identifier

        let envelope = BluetoothEnvelope(
            kind: .invitationAccepted,
            sessionID: sessionID,
            identity: localIdentity,
            invitationContext: nil,
            message: nil
        )

        sendEnvelopeToCentral(
            envelope,
            centralID: record.central.identifier
        )

        // We intentionally do NOT publish `.connected` yet.
        // The inviter must send `.readyAck` back first. This prevents the two
        // phones from entering the game at different moments.
    }

    func rejectInvitation(
        sessionID: String,
        sendDeclineResponse: Bool
    ) {
        guard let record = incomingInvitations.removeValue(
            forKey: sessionID
        ) else {
            return
        }

        let envelope: BluetoothEnvelope

        if sendDeclineResponse {
            envelope = BluetoothEnvelope(
                kind: .invitationDeclined,
                sessionID: sessionID,
                identity: localIdentity,
                invitationContext: record.context,
                message: nil
            )
        } else {
            // Internal close: tells the central to tear down the provisional
            // BLE connection without showing a "Declined" UI.
            envelope = BluetoothEnvelope(
                kind: .close,
                sessionID: sessionID,
                identity: nil,
                invitationContext: nil,
                message: nil
            )
        }

        sendEnvelopeToCentral(
            envelope,
            centralID: record.central.identifier
        )
    }

    // MARK: - Messaging

    func send(
        _ message: NearbyMessage,
        to peers: [NearbyPeer]?
    ) {
        guard let activeRemotePeer else {
            reportFailure(
                BluetoothTransportError.noConnectedPeer
            )
            return
        }

        if let peers,
           !peers.isEmpty,
           !peers.contains(where: { $0.id == activeRemotePeer.id }) {
            return
        }

        let envelope = BluetoothEnvelope(
            kind: .nearbyMessage,
            sessionID: activeSessionID,
            identity: nil,
            invitationContext: nil,
            message: message
        )

        switch activeRole {
        case .central:
            sendEnvelopeToPeripheral(envelope)

        case .peripheral:
            guard let centralID = activePeripheralCentralID else {
                reportFailure(
                    BluetoothTransportError.noConnectedPeer
                )
                return
            }

            sendEnvelopeToCentral(
                envelope,
                centralID: centralID
            )

        case .none:
            reportFailure(
                BluetoothTransportError.noConnectedPeer
            )
        }
    }

    // MARK: - Discovery setup

    private func startScanningIfPossible() {
        guard activeRemotePeer == nil,
              outgoingInvitation == nil,
              let centralManager,
              centralManager.state == .poweredOn,
              let serviceUUID else {
            return
        }

        centralManager.stopScan()
        centralManager.scanForPeripherals(
            withServices: [serviceUUID],
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true
            ]
        )
    }

    private func setupPeripheralServiceIfPossible() {
        guard let peripheralManager,
              peripheralManager.state == .poweredOn,
              let serviceUUID else {
            return
        }

        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()

        let characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.write, .indicate],
            value: nil,
            permissions: [.writeable]
        )

        let service = CBMutableService(
            type: serviceUUID,
            primary: true
        )
        service.characteristics = [characteristic]

        mutableCharacteristic = characteristic
        mutableService = service

        peripheralManager.add(service)
    }

    private func startAdvertisingIfPossible() {
        guard activeRemotePeer == nil,
              let peripheralManager,
              peripheralManager.state == .poweredOn,
              !peripheralManager.isAdvertising,
              let serviceUUID,
              let configuration else {
            return
        }

        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey:
                advertisementName(configuration.playerName)
        ])
    }

    private func stopDiscoveryWhileConnected() {
        centralManager?.stopScan()
        peripheralManager?.stopAdvertising()
    }

    private func resumeDiscoveryAfterDisconnect() {
        guard activeRemotePeer == nil else {
            return
        }

        startScanningIfPossible()
        startAdvertisingIfPossible()
    }

    // MARK: - Discovery expiry

    private func startDiscoveryCleanupTimer() {
        discoveryCleanupTimer?.invalidate()

        discoveryCleanupTimer = Timer.scheduledTimer(
            withTimeInterval: 2,
            repeats: true
        ) { [weak self] _ in
            self?.removeExpiredDiscoveredPeers()
        }
    }

    private func removeExpiredDiscoveredPeers() {
        let now = Date()

        let expiredPeripheralIDs = lastSeenByPeripheralID.compactMap {
            peripheralID, lastSeen -> UUID? in

            guard now.timeIntervalSince(lastSeen) > discoveryExpiry else {
                return nil
            }

            // Never expire the peer currently used for an invitation/connection.
            if connectedPeripheral?.identifier == peripheralID {
                return nil
            }

            return peripheralID
        }

        for peripheralID in expiredPeripheralIDs {
            lastSeenByPeripheralID.removeValue(forKey: peripheralID)

            guard let peer = discoveryPeerByPeripheralID.removeValue(
                forKey: peripheralID
            ) else {
                continue
            }

            peripheralsByDiscoveryPeerID.removeValue(
                forKey: peer.id
            )

            delegate?.nearbyTransport(
                self,
                didLose: peer
            )
        }
    }

    // MARK: - Central-side GATT setup

    private func beginServiceDiscovery(on peripheral: CBPeripheral) {
        guard let serviceUUID else {
            return
        }

        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    private func sendHelloIfReady() {
        guard let outgoingInvitation,
              let peripheral = connectedPeripheral,
              peripheral.state == .connected,
              let characteristic = remoteCharacteristic,
              characteristic.isNotifying else {
            return
        }

        let sessionID = outgoingInvitation.context.sessionID

        guard helloSentSessionID != sessionID else {
            return
        }

        helloSentSessionID = sessionID

        let envelope = BluetoothEnvelope(
            kind: .hello,
            sessionID: sessionID,
            identity: localIdentity,
            invitationContext: nil,
            message: nil
        )

        sendEnvelopeToPeripheral(envelope)
    }

    private func sendLogicalInvitationIfReady() {
        guard let outgoingInvitation,
              let resolvedIdentity = outgoingResolvedIdentity,
              resolvedIdentity.gameID == configuration?.gameID else {
            return
        }

        let sessionID = outgoingInvitation.context.sessionID

        guard invitationSentSessionID != sessionID else {
            return
        }

        invitationSentSessionID = sessionID

        let envelope = BluetoothEnvelope(
            kind: .invitation,
            sessionID: sessionID,
            identity: localIdentity,
            invitationContext: outgoingInvitation.context,
            message: nil
        )

        sendEnvelopeToPeripheral(envelope)
    }

    /// Handles one incoming logical invitation after the BLE identity handshake.
    /// If both players invited each other, the smaller persistent playerID keeps
    /// its outgoing invitation. The other device silently yields and shows the
    /// winning incoming invitation.
    private func processIncomingInvitation(
        _ envelope: BluetoothEnvelope,
        central: CBCentral
    ) {
        guard let configuration,
              let context = envelope.invitationContext,
              let identity = envelope.identity,
              context.kind == .request,
              context.gameID == configuration.gameID,
              identity.gameID == configuration.gameID,
              identity.playerID != configuration.playerID else {
            return
        }

        let peer = identity.nearbyPeer

        guard let outgoing = outgoingInvitation else {
            publishIncomingInvitation(
                peer: peer,
                context: context,
                central: central
            )
            return
        }

        // Until HELLO_ACK arrives we do not know whether the temporary BLE peer
        // we invited is this same NearPlay player. Defer the reverse invite.
        guard let resolvedOutgoingIdentity = outgoingResolvedIdentity else {
            deferredIncomingInvitations[central.identifier] =
                DeferredIncomingInvitation(
                    envelope: envelope,
                    central: central
                )
            return
        }

        // Different person invited us while we were already inviting someone.
        // NearbyService will reject that invitation as busy.
        guard resolvedOutgoingIdentity.playerID == identity.playerID else {
            publishIncomingInvitation(
                peer: peer,
                context: context,
                central: central
            )
            return
        }

        // Same two players invited each other.
        if configuration.playerID < identity.playerID {
            // Our outgoing invite wins. Ignore the reverse logical invite.
            // Do not tear down the reverse BLE path from here; the losing
            // device will deterministically yield its own outgoing connection
            // when it processes our winning invitation. This avoids a race
            // where a transport-level close arrives before its lobby UI has
            // cleared the outgoing invitation state.
            return
        }

        // Their invite wins. Silently yield our outgoing invitation and keep the
        // incoming peripheral-side path alive.
        outgoingTimeoutWorkItem?.cancel()
        outgoingTimeoutWorkItem = nil

        let yieldedContext = outgoing.context

        outgoingInvitation = nil
        outgoingResolvedIdentity = nil
        helloSentSessionID = nil
        invitationSentSessionID = nil

        delegate?.nearbyTransport(
            self,
            didYieldOutgoingInvitation: yieldedContext,
            to: peer
        )

        if let connectedPeripheral {
            centralManager?.cancelPeripheralConnection(
                connectedPeripheral
            )
        }

        publishIncomingInvitation(
            peer: peer,
            context: context,
            central: central
        )
    }

    private func publishIncomingInvitation(
        peer: NearbyPeer,
        context: InvitationContext,
        central: CBCentral
    ) {
        incomingInvitations[context.sessionID] =
            IncomingInvitationRecord(
                central: central,
                peer: peer,
                context: context
            )

        delegate?.nearbyTransport(
            self,
            didReceiveInvitationFrom: peer,
            context: context
        )
    }

    private func processDeferredIncomingInvitations() {
        guard outgoingResolvedIdentity != nil,
              !deferredIncomingInvitations.isEmpty else {
            return
        }

        let deferred = Array(
            deferredIncomingInvitations.values
        )
        deferredIncomingInvitations.removeAll()

        for item in deferred {
            processIncomingInvitation(
                item.envelope,
                central: item.central
            )
        }
    }

    // MARK: - Envelopes

    private var localIdentity: BluetoothPeerIdentity? {
        guard let configuration else {
            return nil
        }

        return BluetoothPeerIdentity(
            playerID: configuration.playerID,
            playerName: configuration.playerName,
            gameID: configuration.gameID,
            maxPlayers: configuration.maxPlayers
        )
    }

    private func sendEnvelopeToPeripheral(
        _ envelope: BluetoothEnvelope,
        completion: (() -> Void)? = nil
    ) {
        guard let peripheral = connectedPeripheral,
              let characteristic = remoteCharacteristic else {
            reportFailure(
                BluetoothTransportError.channelNotReady
            )
            return
        }

        do {
            let payload = try JSONEncoder().encode(envelope)
            let framed = frame(payload)

            let maximumLength = max(
                20,
                peripheral.maximumWriteValueLength(
                    for: .withResponse
                )
            )

            let chunks = framed.chunked(
                maximumLength: maximumLength
            )

            for (index, chunk) in chunks.enumerated() {
                centralWriteQueue.append(
                    PendingCentralWrite(
                        data: chunk,
                        completion:
                            index == chunks.count - 1
                            ? completion
                            : nil
                    )
                )
            }

            pumpCentralWriteQueue()
        } catch {
            reportFailure(error)
        }
    }

    private func pumpCentralWriteQueue() {
        guard centralWriteInFlight == nil,
              !centralWriteQueue.isEmpty,
              let peripheral = connectedPeripheral,
              peripheral.state == .connected,
              let characteristic = remoteCharacteristic else {
            return
        }

        let next = centralWriteQueue.removeFirst()
        centralWriteInFlight = next

        peripheral.writeValue(
            next.data,
            for: characteristic,
            type: .withResponse
        )
    }

    private func sendEnvelopeToCentral(
        _ envelope: BluetoothEnvelope,
        centralID: UUID
    ) {
        guard let central = subscribedCentralsByID[centralID],
              let characteristic = mutableCharacteristic else {
            reportFailure(
                BluetoothTransportError.centralNotSubscribed
            )
            return
        }

        do {
            let payload = try JSONEncoder().encode(envelope)
            let framed = frame(payload)

            let maximumLength = max(
                20,
                central.maximumUpdateValueLength
            )

            let chunks = framed.chunked(
                maximumLength: maximumLength
            )

            for chunk in chunks {
                peripheralNotificationQueue.append(
                    PendingNotification(
                        data: chunk,
                        centralID: centralID
                    )
                )
            }

            pumpPeripheralNotificationQueue()
        } catch {
            reportFailure(error)
        }
    }

    private func pumpPeripheralNotificationQueue() {
        guard let peripheralManager,
              let characteristic = mutableCharacteristic else {
            return
        }

        while !peripheralNotificationQueue.isEmpty {
            let next = peripheralNotificationQueue[0]

            guard let central = subscribedCentralsByID[next.centralID] else {
                peripheralNotificationQueue.removeFirst()
                continue
            }

            let accepted = peripheralManager.updateValue(
                next.data,
                for: characteristic,
                onSubscribedCentrals: [central]
            )

            guard accepted else {
                // CoreBluetooth will call peripheralManagerIsReady(toUpdateSubscribers:)
                // when its transmit queue has room again.
                return
            }

            peripheralNotificationQueue.removeFirst()
        }
    }

    // MARK: - Incoming frame handling

    private func appendIncomingFromPeripheral(_ data: Data) {
        incomingBufferFromPeripheral.append(data)

        do {
            let payloads = try extractFrames(
                from: &incomingBufferFromPeripheral
            )

            for payload in payloads {
                let envelope = try JSONDecoder().decode(
                    BluetoothEnvelope.self,
                    from: payload
                )

                handleEnvelopeFromPeripheral(envelope)
            }
        } catch {
            reportFailure(error)
        }
    }

    private func appendIncomingFromCentral(
        _ data: Data,
        central: CBCentral
    ) {
        var buffer = incomingBuffersFromCentrals[
            central.identifier
        ] ?? Data()

        buffer.append(data)

        do {
            let payloads = try extractFrames(from: &buffer)
            incomingBuffersFromCentrals[central.identifier] = buffer

            for payload in payloads {
                let envelope = try JSONDecoder().decode(
                    BluetoothEnvelope.self,
                    from: payload
                )

                handleEnvelopeFromCentral(
                    envelope,
                    central: central
                )
            }
        } catch {
            incomingBuffersFromCentrals[central.identifier] = Data()
            reportFailure(error)
        }
    }

    private func handleEnvelopeFromPeripheral(
        _ envelope: BluetoothEnvelope
    ) {
        switch envelope.kind {
        case .helloAck:
            guard let outgoingInvitation,
                  envelope.sessionID == outgoingInvitation.context.sessionID,
                  let identity = envelope.identity,
                  identity.gameID == configuration?.gameID else {
                return
            }

            outgoingResolvedIdentity = identity

            // A reverse invite may have arrived before HELLO_ACK. Resolve it
            // now, before sending our own logical invitation.
            processDeferredIncomingInvitations()

            guard self.outgoingInvitation != nil else {
                return
            }

            sendLogicalInvitationIfReady()

        case .invitationAccepted:
            guard let outgoingInvitation,
                  envelope.sessionID == outgoingInvitation.context.sessionID,
                  let identity = envelope.identity else {
                return
            }

            outgoingTimeoutWorkItem?.cancel()
            outgoingTimeoutWorkItem = nil

            let remotePeer = identity.nearbyPeer
            activeRole = .central
            activeRemotePeer = remotePeer
            activeSessionID = outgoingInvitation.context.sessionID

            // The final BLE-level handshake. The peripheral only publishes
            // `.connected` after processing this write; the central publishes
            // `.connected` after CoreBluetooth confirms the write response.
            let readyAck = BluetoothEnvelope(
                kind: .readyAck,
                sessionID: outgoingInvitation.context.sessionID,
                identity: nil,
                invitationContext: nil,
                message: nil
            )

            sendEnvelopeToPeripheral(readyAck) { [weak self] in
                guard let self,
                      let peer = self.activeRemotePeer else {
                    return
                }

                self.outgoingInvitation = nil
                self.outgoingResolvedIdentity = nil
                self.helloSentSessionID = nil
                self.invitationSentSessionID = nil
                self.deferredIncomingInvitations.removeAll()

                self.stopDiscoveryWhileConnected()

                self.delegate?.nearbyTransport(
                    self,
                    peer: peer,
                    didChange: .connected
                )
            }

        case .invitationDeclined:
            guard let context = envelope.invitationContext else {
                return
            }

            let peer = envelope.identity?.nearbyPeer
                ?? outgoingInvitation?.discoveryPeer

            outgoingTimeoutWorkItem?.cancel()
            outgoingTimeoutWorkItem = nil
            outgoingInvitation = nil
            outgoingResolvedIdentity = nil
            helloSentSessionID = nil
            invitationSentSessionID = nil
            deferredIncomingInvitations.removeAll()

            delegate?.nearbyTransport(
                self,
                didReceiveDeclineFor: context,
                from: peer
            )

            if let connectedPeripheral {
                centralManager?.cancelPeripheralConnection(
                    connectedPeripheral
                )
            }

        case .close:
            if let connectedPeripheral {
                centralManager?.cancelPeripheralConnection(
                    connectedPeripheral
                )
            }

        case .nearbyMessage:
            guard let message = envelope.message,
                  let peer = activeRemotePeer else {
                return
            }

            delegate?.nearbyTransport(
                self,
                didReceive: message,
                from: peer
            )

        case .hello,
             .invitation,
             .readyAck:
            // These directions are invalid for the central side.
            break
        }
    }

    private func handleEnvelopeFromCentral(
        _ envelope: BluetoothEnvelope,
        central: CBCentral
    ) {
        switch envelope.kind {
        case .hello:
            guard let configuration,
                  let identity = envelope.identity,
                  identity.gameID == configuration.gameID,
                  identity.playerID != configuration.playerID,
                  let sessionID = envelope.sessionID else {
                return
            }

            let helloAck = BluetoothEnvelope(
                kind: .helloAck,
                sessionID: sessionID,
                identity: localIdentity,
                invitationContext: nil,
                message: nil
            )

            sendEnvelopeToCentral(
                helloAck,
                centralID: central.identifier
            )

        case .invitation:
            processIncomingInvitation(
                envelope,
                central: central
            )

        case .readyAck:
            guard envelope.sessionID == activeSessionID,
                  activeRole == .peripheral,
                  activePeripheralCentralID == central.identifier,
                  let peer = activeRemotePeer else {
                return
            }

            stopDiscoveryWhileConnected()

            delegate?.nearbyTransport(
                self,
                peer: peer,
                didChange: .connected
            )

        case .nearbyMessage:
            guard let message = envelope.message,
                  let peer = activeRemotePeer,
                  activePeripheralCentralID == central.identifier else {
                return
            }

            delegate?.nearbyTransport(
                self,
                didReceive: message,
                from: peer
            )

        case .helloAck,
             .invitationAccepted,
             .invitationDeclined,
             .close:
            // These directions are invalid for the peripheral side.
            break
        }
    }

    // MARK: - Framing

    private func frame(_ payload: Data) -> Data {
        var length = UInt32(payload.count).bigEndian
        var data = Data(
            bytes: &length,
            count: MemoryLayout<UInt32>.size
        )
        data.append(payload)
        return data
    }

    private func extractFrames(
        from buffer: inout Data
    ) throws -> [Data] {
        var frames: [Data] = []

        while buffer.count >= 4 {
            let lengthBytes = buffer.prefix(4)

            let length = lengthBytes.reduce(UInt32(0)) {
                ($0 << 8) | UInt32($1)
            }

            guard length <= maximumFrameSize else {
                throw BluetoothTransportError.invalidFrameLength(
                    Int(length)
                )
            }

            let totalLength = 4 + Int(length)

            guard buffer.count >= totalLength else {
                break
            }

            let payloadRange = 4..<totalLength
            frames.append(buffer.subdata(in: payloadRange))
            buffer.removeSubrange(0..<totalLength)
        }

        return frames
    }

    // MARK: - Helpers

    private func makeServiceUUID(gameID: String) -> CBUUID {
        let seed = Data("NearPlay.BLE.\(gameID)".utf8)
        let digest = SHA256.hash(data: seed)
        var bytes = Array(digest.prefix(16))

        // RFC 4122-style variant/version bits. The hash algorithm is SHA-256,
        // but all that matters here is a stable 128-bit UUID per gameID.
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        let hex = bytes.map { String(format: "%02X", $0) }.joined()

        let part1 = String(hex.prefix(8))
        let part2Start = hex.index(hex.startIndex, offsetBy: 8)
        let part2End = hex.index(part2Start, offsetBy: 4)
        let part2 = String(hex[part2Start..<part2End])

        let part3Start = part2End
        let part3End = hex.index(part3Start, offsetBy: 4)
        let part3 = String(hex[part3Start..<part3End])

        let part4Start = part3End
        let part4End = hex.index(part4Start, offsetBy: 4)
        let part4 = String(hex[part4Start..<part4End])

        let part5 = String(hex[part4End...])

        let uuidString = "\(part1)-\(part2)-\(part3)-\(part4)-\(part5)"

        return CBUUID(string: uuidString)
    }

    private func advertisementName(_ name: String) -> String {
        let fallback = name.isEmpty ? "Player" : name
        var result = ""

        // iOS reserves only a small scan-response area for local name when a
        // 128-bit service UUID is also advertised. Keep it <= 10 UTF-8 bytes.
        for character in fallback {
            let candidate = result + String(character)
            guard candidate.utf8.count <= 10 else {
                break
            }
            result = candidate
        }

        return result.isEmpty ? "Player" : result
    }

    private func discoveryPeerID(for peripheral: CBPeripheral) -> String {
        "ble:\(peripheral.identifier.uuidString)"
    }

    private func reportFailure(_ error: Error) {
        delegate?.nearbyTransport(
            self,
            didFail: error
        )
    }

    private func clearActiveConnection(
        notifyDisconnect: Bool,
        fallbackPeer: NearbyPeer? = nil
    ) {
        let peer = activeRemotePeer ?? fallbackPeer

        activeRole = nil
        activeRemotePeer = nil
        activeSessionID = nil
        activePeripheralCentralID = nil

        incomingBufferFromPeripheral.removeAll(keepingCapacity: false)
        centralWriteQueue.removeAll()
        centralWriteInFlight = nil

        if notifyDisconnect,
           let peer {
            delegate?.nearbyTransport(
                self,
                peer: peer,
                didChange: .disconnected
            )
        }

        resumeDiscoveryAfterDisconnect()
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothTransport: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(
        _ central: CBCentralManager
    ) {
        switch central.state {
        case .poweredOn:
            startScanningIfPossible()

        case .poweredOff:
            reportFailure(
                BluetoothTransportError.bluetoothPoweredOff
            )

        case .unauthorized:
            reportFailure(
                BluetoothTransportError.bluetoothUnauthorized
            )

        case .unsupported:
            reportFailure(
                BluetoothTransportError.bluetoothUnsupported
            )

        case .resetting,
             .unknown:
            break

        @unknown default:
            break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard let configuration else {
            return
        }

        let peerID = discoveryPeerID(for: peripheral)

        let advertisedName =
            advertisementData[CBAdvertisementDataLocalNameKey]
            as? String

        let displayName = {
            let trimmed = advertisedName?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let trimmed,
               !trimmed.isEmpty {
                return trimmed
            }

            return "Nearby Player"
        }()

        let peer = NearbyPeer(
            id: peerID,
            displayName: displayName,
            gameID: configuration.gameID,
            maxPlayers: configuration.maxPlayers
        )

        peripheralsByDiscoveryPeerID[peerID] = peripheral
        discoveryPeerByPeripheralID[peripheral.identifier] = peer
        lastSeenByPeripheralID[peripheral.identifier] = Date()

        delegate?.nearbyTransport(
            self,
            didDiscover: peer
        )
    }

    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        connectedPeripheral = peripheral
        beginServiceDiscovery(on: peripheral)
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        let fallbackPeer = discoveryPeerByPeripheralID[
            peripheral.identifier
        ]

        outgoingInvitation = nil
        outgoingResolvedIdentity = nil
        helloSentSessionID = nil
        invitationSentSessionID = nil
        deferredIncomingInvitations.removeAll()

        connectedPeripheral = nil
        remoteCharacteristic = nil

        if let error {
            reportFailure(error)
        } else {
            reportFailure(
                BluetoothTransportError.connectionFailed
            )
        }

        clearActiveConnection(
            notifyDisconnect: true,
            fallbackPeer: fallbackPeer
        )
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        let fallbackPeer = discoveryPeerByPeripheralID[
            peripheral.identifier
        ]

        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
            remoteCharacteristic = nil
            outgoingInvitation = nil
            outgoingResolvedIdentity = nil
            helloSentSessionID = nil
            invitationSentSessionID = nil
            deferredIncomingInvitations.removeAll()

            outgoingTimeoutWorkItem?.cancel()
            outgoingTimeoutWorkItem = nil
        }

        clearActiveConnection(
            notifyDisconnect: activeRemotePeer != nil,
            fallbackPeer: fallbackPeer
        )
    }
}

// MARK: - CBPeripheralDelegate (this device is Central)

extension BluetoothTransport: CBPeripheralDelegate {
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        if let error {
            reportFailure(error)
            return
        }

        guard let serviceUUID,
              let service = peripheral.services?.first(
                where: { $0.uuid == serviceUUID }
              ) else {
            reportFailure(
                BluetoothTransportError.serviceUnavailable
            )
            return
        }

        peripheral.discoverCharacteristics(
            [characteristicUUID],
            for: service
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            reportFailure(error)
            return
        }

        guard let characteristic = service.characteristics?.first(
            where: { $0.uuid == characteristicUUID }
        ) else {
            reportFailure(
                BluetoothTransportError.characteristicUnavailable
            )
            return
        }

        remoteCharacteristic = characteristic
        peripheral.setNotifyValue(
            true,
            for: characteristic
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            reportFailure(error)
            return
        }

        guard characteristic.uuid == characteristicUUID,
              characteristic.isNotifying else {
            return
        }

        sendHelloIfReady()
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            reportFailure(error)
            return
        }

        guard characteristic.uuid == characteristicUUID,
              let value = characteristic.value else {
            return
        }

        appendIncomingFromPeripheral(value)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == characteristicUUID,
              let completedWrite = centralWriteInFlight else {
            return
        }

        centralWriteInFlight = nil

        if let error {
            centralWriteQueue.removeAll()
            reportFailure(error)
            return
        }

        completedWrite.completion?()
        pumpCentralWriteQueue()
    }
}

// MARK: - CBPeripheralManagerDelegate (this device is Peripheral)

extension BluetoothTransport: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(
        _ peripheral: CBPeripheralManager
    ) {
        switch peripheral.state {
        case .poweredOn:
            setupPeripheralServiceIfPossible()

        case .poweredOff:
            reportFailure(
                BluetoothTransportError.bluetoothPoweredOff
            )

        case .unauthorized:
            reportFailure(
                BluetoothTransportError.bluetoothUnauthorized
            )

        case .unsupported:
            reportFailure(
                BluetoothTransportError.bluetoothUnsupported
            )

        case .resetting,
             .unknown:
            break

        @unknown default:
            break
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didAdd service: CBService,
        error: Error?
    ) {
        if let error {
            reportFailure(error)
            return
        }

        startAdvertisingIfPossible()
    }

    func peripheralManagerDidStartAdvertising(
        _ peripheral: CBPeripheralManager,
        error: Error?
    ) {
        if let error {
            reportFailure(error)
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        guard characteristic.uuid == characteristicUUID else {
            return
        }

        subscribedCentralsByID[central.identifier] = central
        pumpPeripheralNotificationQueue()
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        guard characteristic.uuid == characteristicUUID else {
            return
        }

        subscribedCentralsByID.removeValue(
            forKey: central.identifier
        )
        incomingBuffersFromCentrals.removeValue(
            forKey: central.identifier
        )

        if activePeripheralCentralID == central.identifier {
            clearActiveConnection(
                notifyDisconnect: activeRemotePeer != nil
            )
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveWrite requests: [CBATTRequest]
    ) {
        guard let firstRequest = requests.first else {
            return
        }

        // Apple documents a batch of ATT writes as one transaction: validate
        // the whole batch and respond exactly once, using the first request.
        for request in requests {
            guard request.characteristic.uuid == characteristicUUID,
                  request.offset == 0,
                  request.value != nil else {
                peripheral.respond(
                    to: firstRequest,
                    withResult: .invalidOffset
                )
                return
            }
        }

        for request in requests {
            guard let value = request.value else {
                continue
            }

            appendIncomingFromCentral(
                value,
                central: request.central
            )
        }

        peripheral.respond(
            to: firstRequest,
            withResult: .success
        )
    }

    func peripheralManagerIsReady(
        toUpdateSubscribers peripheral: CBPeripheralManager
    ) {
        pumpPeripheralNotificationQueue()
    }
}

// MARK: - Bluetooth protocol models

private struct BluetoothPeerIdentity: Codable, Equatable {
    let playerID: String
    let playerName: String
    let gameID: String
    let maxPlayers: Int

    var nearbyPeer: NearbyPeer {
        NearbyPeer(
            id: playerID,
            displayName: playerName,
            gameID: gameID,
            maxPlayers: maxPlayers
        )
    }
}

private enum BluetoothEnvelopeKind: String, Codable {
    case hello
    case helloAck
    case invitation
    case invitationAccepted
    case invitationDeclined
    case readyAck
    case nearbyMessage
    case close
}

private struct BluetoothEnvelope: Codable {
    let kind: BluetoothEnvelopeKind
    let sessionID: String?
    let identity: BluetoothPeerIdentity?
    let invitationContext: InvitationContext?
    let message: NearbyMessage?
}

// MARK: - Errors

private enum BluetoothTransportError: LocalizedError {
    case peerUnavailable(String)
    case invitationUnavailable
    case centralNotSubscribed
    case noConnectedPeer
    case channelNotReady
    case connectionFailed
    case serviceUnavailable
    case characteristicUnavailable
    case bluetoothPoweredOff
    case bluetoothUnauthorized
    case bluetoothUnsupported
    case invalidFrameLength(Int)

    var errorDescription: String? {
        switch self {
        case .peerUnavailable(let name):
            return "Could not find Bluetooth peer for \(name)."

        case .invitationUnavailable:
            return "No Bluetooth invitation is available to accept."

        case .centralNotSubscribed:
            return "The nearby Bluetooth connection is not ready yet."

        case .noConnectedPeer:
            return "No Bluetooth player is connected."

        case .channelNotReady:
            return "The Bluetooth data channel is not ready."

        case .connectionFailed:
            return "Could not establish the Bluetooth connection."

        case .serviceUnavailable:
            return "The NearPlay Bluetooth service could not be found."

        case .characteristicUnavailable:
            return "The NearPlay Bluetooth data channel could not be found."

        case .bluetoothPoweredOff:
            return "Bluetooth is turned off."

        case .bluetoothUnauthorized:
            return "NearPlay does not have Bluetooth access."

        case .bluetoothUnsupported:
            return "Bluetooth is not supported on this device."

        case .invalidFrameLength(let length):
            return "Received an invalid Bluetooth frame (\(length) bytes)."
        }
    }
}

// MARK: - Data chunking

private extension Data {
    func chunked(maximumLength: Int) -> [Data] {
        guard maximumLength > 0,
              !isEmpty else {
            return isEmpty ? [Data()] : []
        }

        var result: [Data] = []
        var offset = 0

        while offset < count {
            let end = Swift.min(
                offset + maximumLength,
                count
            )

            result.append(
                subdata(in: offset..<end)
            )

            offset = end
        }

        return result
    }
}
