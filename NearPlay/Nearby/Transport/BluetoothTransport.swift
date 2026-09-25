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
@MainActor
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

        var session: NearbySessionToken {
            context.sessionToken
        }
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

    private struct ProvisionalHandshake {
        let session: NearbySessionToken
        let identity: BluetoothPeerIdentity
    }

    private var incomingInvitations: [NearbySessionToken: IncomingInvitationRecord] = [:]
    private var subscribedCentralsByID: [UUID: CBCentral] = [:]
    private var provisionalHandshakeByCentralID: [UUID: ProvisionalHandshake] = [:]

    // MARK: - Active NearPlay connection

    private enum ActiveRole {
        case central
        case peripheral
    }

    private enum ProtocolState: String {
        case idle
        case discovering
        case identityExchange
        case resolvingCollision
        case invitationPending
        case awaitingReady
        case awaitingReadyAck
        case connected
        case closing
        case unavailable
    }

    private var protocolState: ProtocolState = .idle
    private var activeRole: ActiveRole?
    private var activeRemotePeer: NearbyPeer?
    private var activeSession: NearbySessionToken?
    private var activePeripheralCentralID: UUID?
    private var semanticallyConnectedSession: NearbySessionToken?
    private var publishedConnectedSession: NearbySessionToken?
    private var receivedMessageIDs: Set<UUID> = []
    private var terminalInvitationSessions: Set<NearbySessionToken> = []

    /// Local epochs never move backwards during this transport object's life.
    /// They let timeout/completion closures prove that they still own the
    /// attempt they were created for.
    private var epochCounter: UInt64 = 0
    private var outgoingAttemptEpoch: UInt64?
    private var didReportBluetoothAvailabilityFailure = false

    // MARK: - Framing buffers

    /// Incoming stream when this device acts as a central.
    private var incomingBufferFromPeripheral = Data()

    /// Incoming stream per remote central when this device acts as a peripheral.
    private var incomingBuffersFromCentrals: [UUID: Data] = [:]

    // MARK: - Central write queue

    private struct PendingCentralWrite {
        let data: Data
        let session: NearbySessionToken?
        let completion: (() -> Void)?
    }

    private var centralWriteQueue: [PendingCentralWrite] = []
    private var centralWriteInFlight: PendingCentralWrite?

    // MARK: - Peripheral notification queue

    private struct PendingNotification {
        let data: Data
        let centralID: UUID
        let session: NearbySessionToken?
        let kind: BluetoothEnvelopeKind
        let completion: (() -> Void)?
    }

    private var peripheralNotificationQueue: [PendingNotification] = []

    // MARK: - NearbyTransport lifecycle

    func start(configuration: NearbyTransportConfiguration) {
        stop()

        advanceEpoch()

        self.configuration = configuration
        self.serviceUUID = makeServiceUUID(gameID: configuration.gameID)
        transition(to: .discovering, reason: "start")

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
        transition(to: .idle, reason: "stop")
        advanceEpoch()
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
        provisionalHandshakeByCentralID.removeAll()

        activeRole = nil
        activeRemotePeer = nil
        activeSession = nil
        activePeripheralCentralID = nil
        semanticallyConnectedSession = nil
        publishedConnectedSession = nil
        receivedMessageIDs.removeAll()
        terminalInvitationSessions.removeAll()
        outgoingAttemptEpoch = nil
        didReportBluetoothAvailabilityFailure = false

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
        guard protocolState == .discovering,
              activeRemotePeer == nil,
              incomingInvitations.isEmpty else {
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

        advanceEpoch()
        let attemptEpoch = epochCounter
        outgoingAttemptEpoch = attemptEpoch

#if DEBUG
        log(
            "outgoing invitation",
            session: context.sessionToken,
            remotePlayerID: peer.id
        )
#endif
        transition(
            to: .identityExchange,
            reason: "invite",
            session: context.sessionToken,
            remotePlayerID: peer.id
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
                  outgoing.session == context.sessionToken,
                  self.outgoingAttemptEpoch == attemptEpoch else {
                return
            }

#if DEBUG
            self.log("invitation timeout", session: outgoing.session)
#endif

            self.delegate?.nearbyTransport(
                self,
                didCancelInvitation: outgoing.context,
                with: self.outgoingResolvedIdentity?.nearbyPeer ??
                    outgoing.discoveryPeer,
                reason: .timedOut
            )

            self.outgoingInvitation = nil
            self.outgoingResolvedIdentity = nil
            self.helloSentSessionID = nil
            self.invitationSentSessionID = nil
            self.outgoingAttemptEpoch = nil
            self.transition(
                to: .closing,
                reason: "invitation timeout",
                session: outgoing.session
            )

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
        guard let entry = incomingInvitations.first(where: {
            $0.key.sessionID == sessionID
        }) else {
            if activeSession?.sessionID == sessionID,
               activeRole == .peripheral {
                // A repeated UI action or packet is harmless.
                return
            }

            reportFailure(
                BluetoothTransportError.invitationUnavailable
            )
            return
        }

        let session = entry.key
        let record = entry.value

        guard subscribedCentralsByID[record.central.identifier] != nil else {
            incomingInvitations.removeValue(forKey: session)
            delegate?.nearbyTransport(
                self,
                didCancelInvitation: record.context,
                with: record.peer,
                reason: .transportLost
            )
            reportFailure(
                BluetoothTransportError.centralNotSubscribed
            )
            return
        }

        incomingInvitations.removeValue(forKey: session)

        activeRole = .peripheral
        activeRemotePeer = record.peer
        activeSession = session
        activePeripheralCentralID = record.central.identifier
        semanticallyConnectedSession = nil
        publishedConnectedSession = nil
        receivedMessageIDs.removeAll()

#if DEBUG
        log(
            "accepted incoming invitation",
            session: session,
            remotePlayerID: record.peer.id
        )
#endif
        transition(
            to: .awaitingReady,
            reason: "invitation accepted locally",
            session: session,
            remotePlayerID: record.peer.id
        )

        let envelope = BluetoothEnvelope(
            kind: .invitationAccepted,
            sessionID: sessionID,
            generation: session.generation,
            identity: localIdentity,
            invitationContext: nil,
            message: nil
        )

        sendEnvelopeToCentral(
            envelope,
            centralID: record.central.identifier
        )

        // We intentionally do NOT publish `.connected` yet.
        // The inviter sends READY and this side answers READY_ACK first.
    }

    func rejectInvitation(
        sessionID: String,
        sendDeclineResponse: Bool
    ) {
        guard let entry = incomingInvitations.first(where: {
            $0.key.sessionID == sessionID
        }) else {
            return
        }

        let session = entry.key
        let record = entry.value
        incomingInvitations.removeValue(forKey: session)
        terminalInvitationSessions.insert(session)

        let envelope: BluetoothEnvelope

        if sendDeclineResponse {
            envelope = BluetoothEnvelope(
                kind: .invitationDeclined,
                sessionID: sessionID,
                generation: session.generation,
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
                generation: session.generation,
                identity: nil,
                invitationContext: nil,
                message: nil
            )
        }

        sendEnvelopeToCentral(
            envelope,
            centralID: record.central.identifier,
            reportsUnavailable: sendDeclineResponse
        )

        if activeSession == nil {
            let nextState: ProtocolState =
                outgoingInvitation != nil || !incomingInvitations.isEmpty
                ? .invitationPending
                : .discovering

            transition(
                to: nextState,
                reason: sendDeclineResponse ? "invitation declined" : "invitation closed",
                session: session,
                remotePlayerID: record.peer.id
            )
        }
    }

    // MARK: - Messaging

    func send(
        _ message: NearbyMessage,
        to peers: [NearbyPeer]?
    ) {
        guard protocolState == .connected,
              let activeRemotePeer,
              let activeSession,
              semanticallyConnectedSession == activeSession else {
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
            sessionID: activeSession.sessionID,
            generation: activeSession.generation,
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
            Task { @MainActor [weak self] in
                self?.removeExpiredDiscoveredPeers()
            }
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
            generation: outgoingInvitation.context.generation,
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
            generation: outgoingInvitation.context.generation,
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
              envelope.sessionToken == context.sessionToken,
              context.kind == .request,
              context.gameID == configuration.gameID,
              context.generation > 0,
              context.inviterPlayerID == identity.playerID,
              identity.gameID == configuration.gameID,
              identity.playerID != configuration.playerID else {
            return
        }

        let peer = identity.nearbyPeer
        let session = context.sessionToken

        guard let provisional = provisionalHandshakeByCentralID[central.identifier],
              provisional.session == session,
              provisional.identity.playerID == identity.playerID else {
#if DEBUG
            log("ignored invitation without matching HELLO", session: session)
#endif
            return
        }

        if terminalInvitationSessions.contains(session) {
            sendClose(
                session: session,
                centralID: central.identifier
            )
            return
        }

        if let activeSession {
            if activeSession == session,
               activeRole == .peripheral,
               activePeripheralCentralID == central.identifier {
                // The inviter may retry after a delayed ATT response. Re-send
                // ACCEPT without reopening or duplicating the session.
                sendInvitationAccepted(
                    session: session,
                    centralID: central.identifier
                )
            } else {
                sendClose(
                    session: session,
                    centralID: central.identifier
                )
            }
            return
        }

        if let existing = incomingInvitations[session] {
            guard existing.central.identifier == central.identifier,
                  existing.peer.id == peer.id else {
                sendClose(
                    session: session,
                    centralID: central.identifier
                )
                return
            }

            // Exact replay: the UI already owns this invitation.
            return
        }

        if !incomingInvitations.isEmpty {
            sendClose(
                session: session,
                centralID: central.identifier
            )
            return
        }

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
        transition(
            to: .resolvingCollision,
            reason: "simultaneous invitation",
            session: outgoing.session,
            remotePlayerID: identity.playerID
        )

        if configuration.playerID < identity.playerID {
#if DEBUG
            log(
                "collision: local playerID won; kept outgoing invitation",
                session: outgoing.session,
                remotePlayerID: identity.playerID
            )
#endif
            transition(
                to: .invitationPending,
                reason: "local playerID won collision",
                session: outgoing.session,
                remotePlayerID: identity.playerID
            )
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

#if DEBUG
        log(
            "collision: remote playerID won; yielded outgoing invitation",
            session: outgoing.session,
            remotePlayerID: identity.playerID
        )
#endif

        outgoingInvitation = nil
        outgoingResolvedIdentity = nil
        helloSentSessionID = nil
        invitationSentSessionID = nil
        outgoingAttemptEpoch = nil
        centralWriteQueue.removeAll()
        centralWriteInFlight = nil

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
        let session = context.sessionToken

        guard incomingInvitations[session] == nil else {
            return
        }

        incomingInvitations[session] =
            IncomingInvitationRecord(
                central: central,
                peer: peer,
                context: context
            )

        transition(
            to: .invitationPending,
            reason: "incoming invitation",
            session: session,
            remotePlayerID: peer.id
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
              remoteCharacteristic != nil else {
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
                        session: envelope.sessionToken,
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

        guard isCurrentSession(next.session) else {
#if DEBUG
            log("dropped stale central write", session: next.session)
#endif
            pumpCentralWriteQueue()
            return
        }

        centralWriteInFlight = next

        peripheral.writeValue(
            next.data,
            for: characteristic,
            type: .withResponse
        )
    }

    private func sendEnvelopeToCentral(
        _ envelope: BluetoothEnvelope,
        centralID: UUID,
        reportsUnavailable: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        guard let central = subscribedCentralsByID[centralID],
              mutableCharacteristic != nil else {
            if reportsUnavailable {
                reportFailure(
                    BluetoothTransportError.centralNotSubscribed
                )
            }
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

            for (index, chunk) in chunks.enumerated() {
                peripheralNotificationQueue.append(
                    PendingNotification(
                        data: chunk,
                        centralID: centralID,
                        session: envelope.sessionToken,
                        kind: envelope.kind,
                        completion:
                            index == chunks.count - 1
                            ? completion
                            : nil
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

            guard isCurrentSession(next.session) ||
                    next.kind == .close ||
                    next.kind == .invitationDeclined else {
#if DEBUG
                log("dropped stale peripheral notification", session: next.session)
#endif
                peripheralNotificationQueue.removeFirst()
                continue
            }

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
            next.completion?()
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
                  envelope.sessionToken == outgoingInvitation.session,
                  let identity = envelope.identity,
                  identity.gameID == configuration?.gameID,
                  identity.playerID != configuration?.playerID else {
                return
            }

            outgoingResolvedIdentity = identity
            transition(
                to: .invitationPending,
                reason: "identity resolved",
                session: outgoingInvitation.session,
                remotePlayerID: identity.playerID
            )

            // A reverse invite may have arrived before HELLO_ACK. Resolve it
            // now, before sending our own logical invitation.
            processDeferredIncomingInvitations()

            guard self.outgoingInvitation != nil else {
                return
            }

            sendLogicalInvitationIfReady()

        case .invitationAccepted:
            guard let outgoingInvitation,
                  envelope.sessionToken == outgoingInvitation.session,
                  let identity = envelope.identity,
                  identity.playerID == outgoingResolvedIdentity?.playerID else {
                return
            }

            let remotePeer = identity.nearbyPeer
            let session = outgoingInvitation.session
            let wasAlreadyConnecting =
                activeRole == .central && activeSession == session
            activeRole = .central
            activeRemotePeer = remotePeer
            activeSession = session
            semanticallyConnectedSession = nil
            publishedConnectedSession = nil
            receivedMessageIDs.removeAll()
            transition(
                to: .awaitingReadyAck,
                reason: "received ACCEPT",
                session: session,
                remotePlayerID: remotePeer.id
            )

            if !wasAlreadyConnecting {
                delegate?.nearbyTransport(
                    self,
                    peer: remotePeer,
                    didChange: .connecting,
                    session: session
                )
            }

            // ACCEPT confirms the invitation. READY asks the invitee to prove
            // it installed the exact same session before either side connects.
            let ready = BluetoothEnvelope(
                kind: .ready,
                sessionID: outgoingInvitation.context.sessionID,
                generation: outgoingInvitation.context.generation,
                identity: nil,
                invitationContext: nil,
                message: nil
            )

            sendEnvelopeToPeripheral(ready)

#if DEBUG
            log("sent READY", session: session)
#endif

        case .readyAck:
            guard let session = envelope.sessionToken,
                  session == activeSession,
                  activeRole == .central,
                  let peer = activeRemotePeer else {
                return
            }

            finishOutgoingHandshake(
                peer: peer,
                session: session
            )

        case .invitationDeclined:
            guard let context = envelope.invitationContext,
                  let currentOutgoing = outgoingInvitation,
                  envelope.sessionToken == currentOutgoing.session,
                  context.sessionToken == currentOutgoing.session else {
                return
            }

            let peer = envelope.identity?.nearbyPeer
                ?? currentOutgoing.discoveryPeer

            outgoingTimeoutWorkItem?.cancel()
            outgoingTimeoutWorkItem = nil
            outgoingInvitation = nil
            outgoingResolvedIdentity = nil
            helloSentSessionID = nil
            invitationSentSessionID = nil
            deferredIncomingInvitations.removeAll()
            outgoingAttemptEpoch = nil
            centralWriteQueue.removeAll()
            centralWriteInFlight = nil
            transition(
                to: .closing,
                reason: "invitation declined remotely",
                session: currentOutgoing.session,
                remotePlayerID: peer.id
            )

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
            guard let session = envelope.sessionToken else {
                return
            }

            if let outgoing = outgoingInvitation,
               outgoing.session == session {
                let remotePeer = outgoingResolvedIdentity?.nearbyPeer ??
                    outgoing.discoveryPeer
                outgoingTimeoutWorkItem?.cancel()
                outgoingTimeoutWorkItem = nil
                outgoingInvitation = nil
                outgoingResolvedIdentity = nil
                helloSentSessionID = nil
                invitationSentSessionID = nil
                deferredIncomingInvitations.removeAll()
                outgoingAttemptEpoch = nil
                centralWriteQueue.removeAll()
                centralWriteInFlight = nil
                transition(
                    to: .closing,
                    reason: "remote closed invitation",
                    session: session,
                    remotePlayerID: remotePeer.id
                )

                delegate?.nearbyTransport(
                    self,
                    didCancelInvitation: outgoing.context,
                    with: remotePeer,
                    reason: .remoteClosed
                )
            } else if session != activeSession {
                return
            }

            if let connectedPeripheral {
                centralManager?.cancelPeripheralConnection(
                    connectedPeripheral
                )
            }

        case .nearbyMessage:
            guard let message = envelope.message,
                  let session = envelope.sessionToken else {
                return
            }

            guard session == activeSession,
                  semanticallyConnectedSession == session,
                  let peer = activeRemotePeer else {
#if DEBUG
                log(
                    "ignored stale \(message.type.rawValue) message",
                    session: session
                )
#endif
                return
            }

            guard receivedMessageIDs.insert(message.id).inserted else {
#if DEBUG
                log(
                    "ignored duplicate \(message.type.rawValue) message",
                    session: session,
                    remotePlayerID: peer.id
                )
#endif
                return
            }

            delegate?.nearbyTransport(
                self,
                didReceive: message,
                from: peer,
                session: session
            )

        case .hello,
             .invitation,
             .ready:
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
                  let session = envelope.sessionToken else {
                return
            }

            if let existing = provisionalHandshakeByCentralID[central.identifier],
               existing.session != session,
               incomingInvitations.values.contains(where: {
                   $0.central.identifier == central.identifier
               }) || activePeripheralCentralID == central.identifier {
                sendClose(
                    session: session,
                    centralID: central.identifier
                )
                return
            }

            if let previous = provisionalHandshakeByCentralID[central.identifier],
               previous.session != session {
                terminalInvitationSessions.remove(previous.session)
            }

            provisionalHandshakeByCentralID[central.identifier] =
                ProvisionalHandshake(
                    session: session,
                    identity: identity
                )

            let helloAck = BluetoothEnvelope(
                kind: .helloAck,
                sessionID: session.sessionID,
                generation: session.generation,
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

        case .ready:
            guard let session = envelope.sessionToken,
                  session == activeSession,
                  activeRole == .peripheral,
                  activePeripheralCentralID == central.identifier,
                  let peer = activeRemotePeer else {
                return
            }

            let wasAlreadyConnected =
                semanticallyConnectedSession == session &&
                publishedConnectedSession == session

            if !wasAlreadyConnected {
                transition(
                    to: .awaitingReadyAck,
                    reason: "received READY",
                    session: session,
                    remotePlayerID: peer.id
                )
            }

            let readyAck = BluetoothEnvelope(
                kind: .readyAck,
                sessionID: session.sessionID,
                generation: session.generation,
                identity: nil,
                invitationContext: nil,
                message: nil
            )

            sendEnvelopeToCentral(
                readyAck,
                centralID: central.identifier
            ) { [weak self] in
                guard let self,
                      self.activeSession == session,
                      self.activeRole == .peripheral else {
                    return
                }

                self.publishConnectedIfNeeded(
                    peer: peer,
                    session: session
                )
            }

#if DEBUG
            log("queued READY_ACK", session: session)
#endif

        case .nearbyMessage:
            guard let message = envelope.message,
                  let session = envelope.sessionToken else {
                return
            }

            guard session == activeSession,
                  semanticallyConnectedSession == session,
                  let peer = activeRemotePeer,
                  activePeripheralCentralID == central.identifier else {
#if DEBUG
                log(
                    "ignored stale \(message.type.rawValue) message",
                    session: session
                )
#endif
                return
            }

            guard receivedMessageIDs.insert(message.id).inserted else {
#if DEBUG
                log(
                    "ignored duplicate \(message.type.rawValue) message",
                    session: session,
                    remotePlayerID: peer.id
                )
#endif
                return
            }

            delegate?.nearbyTransport(
                self,
                didReceive: message,
                from: peer,
                session: session
            )

        case .helloAck,
             .invitationAccepted,
             .invitationDeclined,
             .readyAck,
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

    private func handleBluetoothUnavailable(_ error: Error) {
        let cancelledOutgoing = outgoingInvitation
        let cancelledPeer = outgoingResolvedIdentity?.nearbyPeer ??
            cancelledOutgoing?.discoveryPeer
        let cancelledIncoming = Array(incomingInvitations.values)
        let active = activeSession
        let discoveredPeers = Array(discoveryPeerByPeripheralID.values)

        outgoingTimeoutWorkItem?.cancel()
        outgoingTimeoutWorkItem = nil
        outgoingInvitation = nil
        outgoingResolvedIdentity = nil
        helloSentSessionID = nil
        invitationSentSessionID = nil
        deferredIncomingInvitations.removeAll()
        outgoingAttemptEpoch = nil

        incomingInvitations.removeAll()
        provisionalHandshakeByCentralID.removeAll()
        terminalInvitationSessions.removeAll()
        subscribedCentralsByID.removeAll()

        connectedPeripheral = nil
        remoteCharacteristic = nil
        incomingBufferFromPeripheral.removeAll(keepingCapacity: false)
        incomingBuffersFromCentrals.removeAll()
        centralWriteQueue.removeAll()
        centralWriteInFlight = nil
        peripheralNotificationQueue.removeAll()

        peripheralsByDiscoveryPeerID.removeAll()
        discoveryPeerByPeripheralID.removeAll()
        lastSeenByPeripheralID.removeAll()

        for peer in discoveredPeers {
            delegate?.nearbyTransport(
                self,
                didLose: peer
            )
        }

        if let cancelledOutgoing {
            delegate?.nearbyTransport(
                self,
                didCancelInvitation: cancelledOutgoing.context,
                with: cancelledPeer,
                reason: .transportLost
            )
        }

        for invitation in cancelledIncoming {
            delegate?.nearbyTransport(
                self,
                didCancelInvitation: invitation.context,
                with: invitation.peer,
                reason: .transportLost
            )
        }

        if let active {
            clearActiveConnection(
                notifyDisconnect: true,
                expectedSession: active
            )
        } else {
            activeRole = nil
            activeRemotePeer = nil
            activeSession = nil
            activePeripheralCentralID = nil
            semanticallyConnectedSession = nil
            publishedConnectedSession = nil
            receivedMessageIDs.removeAll()
        }

        transition(
            to: .unavailable,
            reason: error.localizedDescription,
            session: active,
            remotePlayerID: cancelledPeer?.id
        )

        guard !didReportBluetoothAvailabilityFailure else {
            return
        }

        didReportBluetoothAvailabilityFailure = true
        reportFailure(error)
    }

    private func markBluetoothAvailableIfReady() {
        guard centralManager?.state == .poweredOn,
              peripheralManager?.state == .poweredOn else {
            return
        }

        didReportBluetoothAvailabilityFailure = false

        if protocolState == .unavailable {
            transition(
                to: .discovering,
                reason: "Bluetooth available"
            )
        }
    }

    private func advanceEpoch() {
        epochCounter &+= 1
        if epochCounter == 0 {
            epochCounter = 1
        }
    }

    private func transition(
        to newState: ProtocolState,
        reason: String,
        session: NearbySessionToken? = nil,
        remotePlayerID: String? = nil
    ) {
        let oldState = protocolState
        protocolState = newState

#if DEBUG
        guard oldState != newState else {
            return
        }

        log(
            "\(oldState.rawValue) -> \(newState.rawValue); \(reason)",
            session: session,
            remotePlayerID: remotePlayerID
        )
#endif
    }

    private func isCurrentSession(
        _ session: NearbySessionToken?
    ) -> Bool {
        guard let session else {
            return true
        }

        return session == activeSession ||
            session == outgoingInvitation?.session ||
            incomingInvitations[session] != nil ||
            provisionalHandshakeByCentralID.values.contains {
                $0.session == session
            }
    }

    private func sendInvitationAccepted(
        session: NearbySessionToken,
        centralID: UUID
    ) {
        let envelope = BluetoothEnvelope(
            kind: .invitationAccepted,
            sessionID: session.sessionID,
            generation: session.generation,
            identity: localIdentity,
            invitationContext: nil,
            message: nil
        )

        sendEnvelopeToCentral(
            envelope,
            centralID: centralID,
            reportsUnavailable: false
        )
    }

    private func sendClose(
        session: NearbySessionToken,
        centralID: UUID
    ) {
        terminalInvitationSessions.insert(session)

        let envelope = BluetoothEnvelope(
            kind: .close,
            sessionID: session.sessionID,
            generation: session.generation,
            identity: nil,
            invitationContext: nil,
            message: nil
        )

        sendEnvelopeToCentral(
            envelope,
            centralID: centralID,
            reportsUnavailable: false
        )
    }

    private func finishOutgoingHandshake(
        peer: NearbyPeer,
        session: NearbySessionToken
    ) {
        guard activeRole == .central,
              activeSession == session,
              outgoingInvitation?.session == session else {
            return
        }

        outgoingTimeoutWorkItem?.cancel()
        outgoingTimeoutWorkItem = nil
        outgoingInvitation = nil
        outgoingResolvedIdentity = nil
        helloSentSessionID = nil
        invitationSentSessionID = nil
        deferredIncomingInvitations.removeAll()
        outgoingAttemptEpoch = nil

        publishConnectedIfNeeded(
            peer: peer,
            session: session
        )
    }

    private func publishConnectedIfNeeded(
        peer: NearbyPeer,
        session: NearbySessionToken
    ) {
        guard activeSession == session,
              publishedConnectedSession != session else {
            return
        }

        semanticallyConnectedSession = session
        publishedConnectedSession = session
        transition(
            to: .connected,
            reason: "bilateral READY handshake complete",
            session: session,
            remotePlayerID: peer.id
        )
        stopDiscoveryWhileConnected()

#if DEBUG
        log("connected", session: session)
#endif

        delegate?.nearbyTransport(
            self,
            peer: peer,
            didChange: .connected,
            session: session
        )
    }

#if DEBUG
    private func log(
        _ event: String,
        session: NearbySessionToken? = nil,
        remotePlayerID: String? = nil
    ) {
        let localID = configuration?.playerID ?? "none"
        let remoteID = remotePlayerID ?? activeRemotePeer?.id ??
            outgoingResolvedIdentity?.playerID ?? "none"
        let suffix = session.map {
            " session=\($0.sessionID)#\($0.generation)"
        } ?? ""
        print(
            "[BLE] \(event) local=\(localID) remote=\(remoteID)\(suffix) epoch=\(epochCounter)"
        )
    }
#endif

    private func clearActiveConnection(
        notifyDisconnect: Bool,
        fallbackPeer: NearbyPeer? = nil,
        expectedSession: NearbySessionToken? = nil
    ) {
        if let expectedSession,
           activeSession != expectedSession {
#if DEBUG
            log("ignored stale disconnect", session: expectedSession)
#endif
            return
        }

        let peer = activeRemotePeer ?? fallbackPeer
        let disconnectedSession = activeSession
        let disconnectedCentralID = activePeripheralCentralID

        activeRole = nil
        activeRemotePeer = nil
        activeSession = nil
        activePeripheralCentralID = nil
        semanticallyConnectedSession = nil
        publishedConnectedSession = nil
        receivedMessageIDs.removeAll()
        transition(
            to: .discovering,
            reason: notifyDisconnect ? "active transport disconnected" : "connection cleared",
            session: disconnectedSession,
            remotePlayerID: peer?.id
        )

        incomingBufferFromPeripheral.removeAll(keepingCapacity: false)
        centralWriteQueue.removeAll()
        centralWriteInFlight = nil
        peripheralNotificationQueue.removeAll {
            $0.session == disconnectedSession
        }

        if let disconnectedCentralID,
           provisionalHandshakeByCentralID[disconnectedCentralID]?.session ==
            disconnectedSession {
            provisionalHandshakeByCentralID.removeValue(
                forKey: disconnectedCentralID
            )
        }

        if notifyDisconnect,
           let peer,
           let disconnectedSession {
#if DEBUG
            log("disconnected", session: disconnectedSession)
#endif
            delegate?.nearbyTransport(
                self,
                peer: peer,
                didChange: .disconnected,
                session: disconnectedSession
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
        guard central === centralManager else {
            return
        }

        switch central.state {
        case .poweredOn:
            markBluetoothAvailableIfReady()
            startScanningIfPossible()

        case .poweredOff:
            handleBluetoothUnavailable(
                BluetoothTransportError.bluetoothPoweredOff
            )

        case .unauthorized:
            handleBluetoothUnavailable(
                BluetoothTransportError.bluetoothUnauthorized
            )

        case .unsupported:
            handleBluetoothUnavailable(
                BluetoothTransportError.bluetoothUnsupported
            )

        case .resetting:
            handleBluetoothUnavailable(
                BluetoothTransportError.bluetoothResetting
            )

        case .unknown:
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
        guard central === centralManager,
              let configuration else {
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
        guard central === centralManager,
              connectedPeripheral === peripheral,
              outgoingInvitation?.peripheral === peripheral else {
#if DEBUG
            log("ignored stale didConnect")
#endif
            central.cancelPeripheralConnection(peripheral)
            return
        }

        beginServiceDiscovery(on: peripheral)
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        guard central === centralManager,
              connectedPeripheral === peripheral,
              outgoingInvitation?.peripheral === peripheral else {
#if DEBUG
            log("ignored stale didFailToConnect")
#endif
            return
        }

        let fallbackPeer = discoveryPeerByPeripheralID[
            peripheral.identifier
        ]
        let cancelledOutgoing = outgoingInvitation
        let cancelledPeer = outgoingResolvedIdentity?.nearbyPeer ?? fallbackPeer

        outgoingInvitation = nil
        outgoingResolvedIdentity = nil
        helloSentSessionID = nil
        invitationSentSessionID = nil
        deferredIncomingInvitations.removeAll()
        outgoingAttemptEpoch = nil

        connectedPeripheral = nil
        remoteCharacteristic = nil
        incomingBufferFromPeripheral.removeAll(keepingCapacity: false)
        centralWriteQueue.removeAll()
        centralWriteInFlight = nil

        if let cancelledOutgoing {
            delegate?.nearbyTransport(
                self,
                didCancelInvitation: cancelledOutgoing.context,
                with: cancelledPeer,
                reason: .transportLost
            )
        }

        if let error {
            reportFailure(error)
        } else {
            reportFailure(
                BluetoothTransportError.connectionFailed
            )
        }

        // A connection failure before ACCEPT has no active semantic session.
        // In particular, it must never clear a newer peripheral-role session.
        if activeRole == .central,
           let session = activeSession {
            clearActiveConnection(
                notifyDisconnect: true,
                fallbackPeer: fallbackPeer,
                expectedSession: session
            )
        } else {
            transition(
                to: .discovering,
                reason: "connection attempt failed",
                session: cancelledOutgoing?.session,
                remotePlayerID: cancelledPeer?.id
            )
            resumeDiscoveryAfterDisconnect()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        guard central === centralManager,
              connectedPeripheral === peripheral else {
#if DEBUG
            log("ignored stale didDisconnectPeripheral")
#endif
            return
        }

        let fallbackPeer = discoveryPeerByPeripheralID[
            peripheral.identifier
        ]
        let cancelledOutgoing = outgoingInvitation
        let cancelledPeer = outgoingResolvedIdentity?.nearbyPeer ?? fallbackPeer

        let disconnectedSession = activeRole == .central
            ? activeSession
            : nil

        connectedPeripheral = nil
        remoteCharacteristic = nil
        incomingBufferFromPeripheral.removeAll(keepingCapacity: false)
        outgoingInvitation = nil
        outgoingResolvedIdentity = nil
        helloSentSessionID = nil
        invitationSentSessionID = nil
        deferredIncomingInvitations.removeAll()
        outgoingAttemptEpoch = nil
        centralWriteQueue.removeAll()
        centralWriteInFlight = nil

        outgoingTimeoutWorkItem?.cancel()
        outgoingTimeoutWorkItem = nil

        if let cancelledOutgoing {
            delegate?.nearbyTransport(
                self,
                didCancelInvitation: cancelledOutgoing.context,
                with: cancelledPeer,
                reason: .transportLost
            )
        }

        if let disconnectedSession {
            clearActiveConnection(
                notifyDisconnect: true,
                fallbackPeer: fallbackPeer,
                expectedSession: disconnectedSession
            )
        } else {
            // This is commonly the losing central path after simultaneous
            // invitations. The winning peripheral session remains untouched.
            if activeRole == nil,
               incomingInvitations.isEmpty,
               outgoingInvitation == nil {
                transition(
                    to: .discovering,
                    reason: "provisional central disconnected",
                    session: cancelledOutgoing?.session,
                    remotePlayerID: cancelledPeer?.id
                )
            }
            resumeDiscoveryAfterDisconnect()
        }
    }
}

// MARK: - CBPeripheralDelegate (this device is Central)

extension BluetoothTransport: CBPeripheralDelegate {
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        guard peripheral === connectedPeripheral,
              outgoingInvitation?.peripheral === peripheral else {
            return
        }

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
        guard peripheral === connectedPeripheral,
              outgoingInvitation?.peripheral === peripheral else {
            return
        }

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
        guard peripheral === connectedPeripheral,
              outgoingInvitation?.peripheral === peripheral else {
            return
        }

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
        guard peripheral === connectedPeripheral,
              outgoingInvitation?.peripheral === peripheral ||
                activeRole == .central else {
            return
        }

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
        guard peripheral === connectedPeripheral,
              outgoingInvitation?.peripheral === peripheral ||
                activeRole == .central,
              characteristic.uuid == characteristicUUID,
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
        guard peripheral === peripheralManager else {
            return
        }

        switch peripheral.state {
        case .poweredOn:
            markBluetoothAvailableIfReady()
            setupPeripheralServiceIfPossible()

        case .poweredOff:
            handleBluetoothUnavailable(
                BluetoothTransportError.bluetoothPoweredOff
            )

        case .unauthorized:
            handleBluetoothUnavailable(
                BluetoothTransportError.bluetoothUnauthorized
            )

        case .unsupported:
            handleBluetoothUnavailable(
                BluetoothTransportError.bluetoothUnsupported
            )

        case .resetting:
            handleBluetoothUnavailable(
                BluetoothTransportError.bluetoothResetting
            )

        case .unknown:
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
        guard peripheral === peripheralManager else {
            return
        }

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
        guard peripheral === peripheralManager else {
            return
        }

        if let error {
            reportFailure(error)
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        guard peripheral === peripheralManager,
              characteristic.uuid == characteristicUUID else {
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
        guard peripheral === peripheralManager,
              characteristic.uuid == characteristicUUID else {
            return
        }

        let cancelledIncoming = incomingInvitations.values.filter {
            $0.central.identifier == central.identifier
        }
        let provisionalSession =
            provisionalHandshakeByCentralID[central.identifier]?.session

        subscribedCentralsByID.removeValue(
            forKey: central.identifier
        )
        incomingBuffersFromCentrals.removeValue(
            forKey: central.identifier
        )
        provisionalHandshakeByCentralID.removeValue(
            forKey: central.identifier
        )
        if let provisionalSession {
            terminalInvitationSessions.remove(provisionalSession)
        }
        incomingInvitations = incomingInvitations.filter {
            $0.value.central.identifier != central.identifier
        }
        peripheralNotificationQueue.removeAll {
            $0.centralID == central.identifier
        }

        for invitation in cancelledIncoming {
            delegate?.nearbyTransport(
                self,
                didCancelInvitation: invitation.context,
                with: invitation.peer,
                reason: .remoteClosed
            )
        }

        if activeRole == nil,
           incomingInvitations.isEmpty,
           outgoingInvitation == nil {
            transition(
                to: .discovering,
                reason: "provisional peripheral disconnected"
            )
        }

        if activeRole == .peripheral,
           activePeripheralCentralID == central.identifier,
           let session = activeSession {
            clearActiveConnection(
                notifyDisconnect: activeRemotePeer != nil,
                expectedSession: session
            )
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveWrite requests: [CBATTRequest]
    ) {
        guard peripheral === peripheralManager,
              let firstRequest = requests.first else {
            return
        }

        // Apple documents a batch of ATT writes as one transaction: validate
        // the whole batch and respond exactly once, using the first request.
        for request in requests {
            guard request.characteristic.uuid == characteristicUUID,
                  request.offset == 0,
                  request.value != nil,
                  subscribedCentralsByID[request.central.identifier] != nil else {
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
        guard peripheral === peripheralManager else {
            return
        }

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
    case ready
    case readyAck
    case nearbyMessage
    case close
}

private struct BluetoothEnvelope: Codable {
    let kind: BluetoothEnvelopeKind
    let sessionID: String?
    let generation: UInt64?
    let identity: BluetoothPeerIdentity?
    let invitationContext: InvitationContext?
    let message: NearbyMessage?

    var sessionToken: NearbySessionToken? {
        guard let sessionID,
              let generation else {
            return nil
        }

        return NearbySessionToken(
            sessionID: sessionID,
            generation: generation
        )
    }
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
    case bluetoothResetting
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

        case .bluetoothResetting:
            return "Bluetooth is restarting."

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
