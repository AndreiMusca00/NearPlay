import Foundation
import Combine

/// The single nearby-play API used by the rest of NearPlay.
///
/// This class owns application/lobby state only. It does not know whether the
/// underlying connection is MultipeerConnectivity, Bluetooth, Wi-Fi, etc.
@MainActor
final class NearbyService: ObservableObject {
    @Published var connectionState: NearbyConnectionState = .idle
    @Published var discoveredPeers: [NearbyPeer] = []
    @Published var connectedPeers: [NearbyPeer] = []
    @Published var errorMessage: String?

    @Published var lastReceivedMessage: NearbyMessage?

    @Published private(set) var pendingInvitation: NearbyInvitation?
    @Published private(set) var outgoingInvitation: NearbyOutgoingInvitation?
    @Published private(set) var connectingPeer: NearbyPeer?
    @Published private(set) var invitationFeedback: NearbyInvitationFeedback?
    @Published private(set) var lobbySession: LobbySessionContext?

    let localPlayerID: String = NearPlayIdentity.playerID

    var isLocalHost: Bool {
        lobbySession?.hostPlayerID == localPlayerID
    }

    let invitationDuration: TimeInterval = 15

    private let transport: NearbyTransport

    private var currentGameID: String?
    private var currentPlayerName: String?
    private var currentMaxPlayers: Int = 2

    private var incomingInvitationExpiryWorkItem: DispatchWorkItem?
    private var outgoingInvitationExpiryWorkItem: DispatchWorkItem?
    private var invitationFeedbackExpiryWorkItem: DispatchWorkItem?
    private var nextSessionGeneration: UInt64 = 0

    init(
        transport: NearbyTransport? = nil
    ) {
        self.transport = transport ?? BluetoothTransport()
        self.transport.delegate = self
    }

    // MARK: - Start / Stop

    func start(
        gameID: String,
        playerName: String,
        maxPlayers: Int
    ) {
        stop()

        let safeName = playerName.isEmpty
            ? "Player"
            : playerName

        currentGameID = gameID
        currentPlayerName = safeName
        currentMaxPlayers = maxPlayers

        let configuration = NearbyTransportConfiguration(
            gameID: gameID,
            playerID: localPlayerID,
            playerName: safeName,
            maxPlayers: maxPlayers
        )

        transport.start(configuration: configuration)

        connectionState = .searching
        errorMessage = nil
    }

    func stop() {
        incomingInvitationExpiryWorkItem?.cancel()
        outgoingInvitationExpiryWorkItem?.cancel()
        invitationFeedbackExpiryWorkItem?.cancel()

        incomingInvitationExpiryWorkItem = nil
        outgoingInvitationExpiryWorkItem = nil
        invitationFeedbackExpiryWorkItem = nil

        transport.stop()

        currentGameID = nil
        currentPlayerName = nil
        currentMaxPlayers = 2

        connectionState = .idle
        discoveredPeers.removeAll()
        connectedPeers.removeAll()
        pendingInvitation = nil
        outgoingInvitation = nil
        connectingPeer = nil
        invitationFeedback = nil
        lobbySession = nil
        lastReceivedMessage = nil
        errorMessage = nil
    }

    /// Kept for the future reconnect implementation.
    func restoreLobbySession(
        _ context: LobbySessionContext
    ) {
        guard context.contains(playerID: localPlayerID) else {
            return
        }

        lobbySession = context
    }

    func clearLobbySession() {
        lobbySession = nil
    }

    // MARK: - Invite flow

    func invite(_ peer: NearbyPeer) {
        guard connectedPeers.isEmpty else {
            return
        }

        guard pendingInvitation == nil,
              outgoingInvitation == nil,
              invitationFeedback == nil else {
            return
        }

        guard let currentGameID,
              let currentPlayerName else {
            errorMessage = "Nearby service is not ready."
            return
        }

        nextSessionGeneration &+= 1
        if nextSessionGeneration == 0 {
            nextSessionGeneration = 1
        }

        let context = InvitationContext(
            kind: .request,
            sessionID: UUID().uuidString,
            generation: nextSessionGeneration,
            gameID: currentGameID,
            inviterPlayerID: localPlayerID,
            inviterPlayerName: currentPlayerName,
            maxPlayers: currentMaxPlayers
        )

        let now = Date()
        let outgoing = NearbyOutgoingInvitation(
            toPeer: peer,
            context: context,
            sentAt: now,
            expiresAt: now.addingTimeInterval(
                invitationDuration
            )
        )

        let sessionContext = LobbySessionContext(
            sessionID: context.sessionID,
            generation: context.generation,
            gameID: context.gameID,
            hostPlayerID: context.inviterPlayerID,
            guestPlayerID: peer.id
        )

        // Publish the attempt before entering CoreBluetooth. Some failures can
        // be reported synchronously and must not be overwritten by `.inviting`.
        outgoingInvitation = outgoing
        connectingPeer = peer
        lobbySession = sessionContext
        connectionState = .inviting
        errorMessage = nil

        transport.invite(
            peer,
            context: context,
            timeout: invitationDuration
        )

        scheduleOutgoingInvitationExpiry(
            session: context.sessionToken
        )
    }

    func acceptInvitation() {
        guard let invitation = pendingInvitation else {
            errorMessage = "No invitation to accept."
            return
        }

        incomingInvitationExpiryWorkItem?.cancel()
        incomingInvitationExpiryWorkItem = nil

        let sessionContext = LobbySessionContext(
            sessionID: invitation.context.sessionID,
            generation: invitation.context.generation,
            gameID: invitation.context.gameID,
            hostPlayerID:
                invitation.context.inviterPlayerID,
            guestPlayerID: localPlayerID
        )

        pendingInvitation = nil
        connectingPeer = invitation.fromPeer
        lobbySession = sessionContext
        connectionState = .connecting
        errorMessage = nil

        transport.acceptInvitation(
            sessionID: invitation.context.sessionID
        )
    }

    func rejectInvitation() {
        rejectCurrentInvitation(
            sendsDeclineResponse: true
        )
    }

    private func expireIncomingInvitation() {
        rejectCurrentInvitation(
            sendsDeclineResponse: false
        )
    }

    private func rejectCurrentInvitation(
        sendsDeclineResponse: Bool
    ) {
        guard let invitation = pendingInvitation else {
            return
        }

        incomingInvitationExpiryWorkItem?.cancel()
        incomingInvitationExpiryWorkItem = nil

        transport.rejectInvitation(
            sessionID: invitation.context.sessionID,
            sendDeclineResponse: sendsDeclineResponse
        )

        pendingInvitation = nil
        connectingPeer = nil

        if connectedPeers.isEmpty {
            connectionState = .searching
        }
    }

    // MARK: - Messaging

    func send(_ message: NearbyMessage) {
        transport.send(
            message,
            to: nil
        )
    }

    func send(
        _ message: NearbyMessage,
        to peers: [NearbyPeer]
    ) {
        transport.send(
            message,
            to: peers.isEmpty ? nil : peers
        )
    }

    // MARK: - Invitation timers

    private func scheduleIncomingInvitationExpiry(
        invitationID: UUID
    ) {
        incomingInvitationExpiryWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.pendingInvitation?.id == invitationID else {
                return
            }

            self.expireIncomingInvitation()
        }

        incomingInvitationExpiryWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + invitationDuration,
            execute: workItem
        )
    }

    private func scheduleOutgoingInvitationExpiry(
        session: NearbySessionToken
    ) {
        outgoingInvitationExpiryWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  let outgoing = self.outgoingInvitation,
                  outgoing.context.sessionToken == session else {
                return
            }

            guard self.connectionState == .inviting else {
                return
            }

            self.showInvitationDeclinedFeedback(
                for: outgoing.toPeer
            )
        }

        outgoingInvitationExpiryWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline:
                .now() + invitationDuration + 0.15,
            execute: workItem
        )
    }

    private func showInvitationDeclinedFeedback(
        for peer: NearbyPeer
    ) {
        outgoingInvitationExpiryWorkItem?.cancel()
        outgoingInvitationExpiryWorkItem = nil

        let now = Date()
        let feedback = NearbyInvitationFeedback(
            peer: peer,
            kind: .declined,
            shownAt: now,
            expiresAt: now.addingTimeInterval(1)
        )

        outgoingInvitation = nil
        connectingPeer = nil
        lobbySession = nil
        invitationFeedback = feedback
        connectionState = .searching

        scheduleInvitationFeedbackExpiry(
            feedbackID: feedback.id
        )
    }

    private func scheduleInvitationFeedbackExpiry(
        feedbackID: UUID
    ) {
        invitationFeedbackExpiryWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.invitationFeedback?.id == feedbackID else {
                return
            }

            self.invitationFeedback = nil
        }

        invitationFeedbackExpiryWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1,
            execute: workItem
        )
    }

    private func clearInvitationStateAfterConnection() {
        incomingInvitationExpiryWorkItem?.cancel()
        outgoingInvitationExpiryWorkItem?.cancel()

        incomingInvitationExpiryWorkItem = nil
        outgoingInvitationExpiryWorkItem = nil

        pendingInvitation = nil
        outgoingInvitation = nil
        connectingPeer = nil
    }

    /// All service entry points and transport callbacks are main-actor isolated.
    /// Keeping this helper avoids noisy UI diff churn while making execution
    /// synchronous and deterministic.
    private func publishOnMain(_ block: () -> Void) {
        block()
    }

}

// MARK: - NearbyTransportDelegate

extension NearbyService: NearbyTransportDelegate {
    func nearbyTransport(
        _ transport: NearbyTransport,
        didDiscover peer: NearbyPeer
    ) {
        publishOnMain {
            guard peer.id != self.localPlayerID,
                  peer.gameID == self.currentGameID else {
                return
            }

            let alreadyDiscovered =
                self.discoveredPeers.contains {
                    $0.id == peer.id
                }

            let alreadyConnected =
                self.connectedPeers.contains {
                    $0.id == peer.id
                }

            guard !alreadyDiscovered,
                  !alreadyConnected else {
                return
            }

            self.discoveredPeers.append(peer)

            if self.connectedPeers.isEmpty,
               self.pendingInvitation == nil,
               self.outgoingInvitation == nil {
                self.connectionState = .searching
                self.errorMessage = nil
            }
        }
    }

    func nearbyTransport(
        _ transport: NearbyTransport,
        didLose peer: NearbyPeer
    ) {
        publishOnMain {
            self.discoveredPeers.removeAll {
                $0.id == peer.id
            }
        }
    }

    func nearbyTransport(
        _ transport: NearbyTransport,
        didReceiveInvitationFrom peer: NearbyPeer,
        context: InvitationContext
    ) {
        publishOnMain {
            guard context.gameID == self.currentGameID,
                  context.kind == .request,
                  context.generation > 0,
                  peer.id == context.inviterPlayerID,
                  context.inviterPlayerID != self.localPlayerID else {
                transport.rejectInvitation(
                    sessionID: context.sessionID,
                    sendDeclineResponse: false
                )
                return
            }

            guard self.connectedPeers.isEmpty,
                  self.lobbySession?.sessionToken == nil ||
                    self.lobbySession?.sessionToken == context.sessionToken,
                  self.pendingInvitation == nil ||
                    self.pendingInvitation?.context.sessionToken == context.sessionToken else {
                transport.rejectInvitation(
                    sessionID: context.sessionID,
                    sendDeclineResponse: false
                )
                return
            }

            // Replayed delivery of the same invitation is idempotent.
            if self.pendingInvitation?.context.sessionToken == context.sessionToken {
                return
            }

            // Simultaneous invitation collision resolution stays at the
            // NearPlay/lobby layer because it is transport-independent.
            if let outgoing = self.outgoingInvitation {
                guard outgoing.toPeer.id == peer.id else {
                    transport.rejectInvitation(
                        sessionID: context.sessionID,
                        sendDeclineResponse: false
                    )
                    return
                }

                // Smaller persistent NearPlay ID keeps its outgoing invite.
                if self.localPlayerID < peer.id {
                    transport.rejectInvitation(
                        sessionID: context.sessionID,
                        sendDeclineResponse: false
                    )
                    return
                }

                self.outgoingInvitationExpiryWorkItem?.cancel()
                self.outgoingInvitationExpiryWorkItem = nil
                self.outgoingInvitation = nil
                self.connectingPeer = nil
                self.lobbySession = nil
            }

            let now = Date()
            let invitation = NearbyInvitation(
                fromPeer: peer,
                context: context,
                receivedAt: now,
                expiresAt: now.addingTimeInterval(
                    self.invitationDuration
                )
            )

            self.pendingInvitation = invitation
            self.connectingPeer = peer
            self.connectionState = .invited
            self.errorMessage = nil

            self.scheduleIncomingInvitationExpiry(
                invitationID: invitation.id
            )
        }
    }

    func nearbyTransport(
        _ transport: NearbyTransport,
        didReceiveDeclineFor context: InvitationContext,
        from peer: NearbyPeer?
    ) {
        publishOnMain {
            guard let outgoing = self.outgoingInvitation,
                  outgoing.context.sessionID == context.sessionID else {
                return
            }

            self.showInvitationDeclinedFeedback(
                for: outgoing.toPeer
            )
        }
    }

    func nearbyTransport(
        _ transport: NearbyTransport,
        didYieldOutgoingInvitation context: InvitationContext,
        to peer: NearbyPeer
    ) {
        publishOnMain {
            guard let outgoing = self.outgoingInvitation,
                  outgoing.context.sessionID == context.sessionID else {
                return
            }

            self.outgoingInvitationExpiryWorkItem?.cancel()
            self.outgoingInvitationExpiryWorkItem = nil

            // This is not a decline. Both users tapped Invite at the same time
            // and the transport selected the other invite as the deterministic
            // winner. Clear our outgoing state silently; the winning incoming
            // invitation is delivered immediately afterwards.
            self.outgoingInvitation = nil
            self.connectingPeer = nil
            self.lobbySession = nil
            self.invitationFeedback = nil

            if self.connectedPeers.isEmpty {
                self.connectionState = .searching
            }

            self.errorMessage = nil
        }
    }

    func nearbyTransport(
        _ transport: NearbyTransport,
        didCancelInvitation context: InvitationContext,
        with peer: NearbyPeer?,
        reason: NearbyTransportInvitationCancellationReason
    ) {
        publishOnMain {
            let session = context.sessionToken
            let matchesOutgoing =
                self.outgoingInvitation?.context.sessionToken == session
            let matchesIncoming =
                self.pendingInvitation?.context.sessionToken == session
            let matchesConnectingSession =
                self.connectedPeers.isEmpty &&
                self.lobbySession?.sessionToken == session

            guard matchesOutgoing || matchesIncoming ||
                    matchesConnectingSession else {
                return
            }

            self.incomingInvitationExpiryWorkItem?.cancel()
            self.outgoingInvitationExpiryWorkItem?.cancel()
            self.incomingInvitationExpiryWorkItem = nil
            self.outgoingInvitationExpiryWorkItem = nil
            self.pendingInvitation = nil
            self.outgoingInvitation = nil
            self.connectingPeer = nil
            self.lobbySession = nil

            if self.connectedPeers.isEmpty {
                self.connectionState = .searching
            }

#if DEBUG
            let peerID = peer?.id ?? "unknown"
            print("[NearbyService] Invitation \(session.sessionID)#\(session.generation) cancelled: \(reason.rawValue), peer=\(peerID)")
#endif
        }
    }

    func nearbyTransport(
        _ transport: NearbyTransport,
        peer: NearbyPeer,
        didChange state: NearbyTransportPeerState,
        session: NearbySessionToken
    ) {
        publishOnMain {
            guard self.lobbySession?.sessionToken == session else {
#if DEBUG
                print("[NearbyService] Ignored stale peer state \(state) for \(session.sessionID)#\(session.generation)")
#endif
                return
            }

            switch state {
            case .connected:
                self.discoveredPeers.removeAll {
                    $0.id == peer.id
                }

                if !self.connectedPeers.contains(
                    where: { $0.id == peer.id }
                ) {
                    self.connectedPeers.append(peer)
                }

                self.discoveredPeers.removeAll()

                // A Bluetooth discovery peer initially uses a temporary BLE
                // identifier. After the invitation handshake, the transport
                // reports the real NearPlay player ID. Rebuild the lobby
                // context here so both phones share the same player IDs.
                if let session = self.lobbySession {
                    if session.hostPlayerID == self.localPlayerID,
                       session.guestPlayerID != peer.id {
                        self.lobbySession = LobbySessionContext(
                            sessionID: session.sessionID,
                            generation: session.generation,
                            gameID: session.gameID,
                            hostPlayerID: self.localPlayerID,
                            guestPlayerID: peer.id
                        )
                    } else if session.guestPlayerID == self.localPlayerID,
                              session.hostPlayerID != peer.id {
                        self.lobbySession = LobbySessionContext(
                            sessionID: session.sessionID,
                            generation: session.generation,
                            gameID: session.gameID,
                            hostPlayerID: peer.id,
                            guestPlayerID: self.localPlayerID
                        )
                    }
                }

                self.clearInvitationStateAfterConnection()
                self.connectionState = .connected
                self.errorMessage = nil

            case .connecting:
                self.outgoingInvitationExpiryWorkItem?.cancel()
                self.outgoingInvitationExpiryWorkItem = nil
                self.connectingPeer = peer
                self.connectionState = .connecting

            case .disconnected:
                self.connectedPeers.removeAll {
                    $0.id == peer.id
                }

                if self.connectedPeers.isEmpty {
                    self.incomingInvitationExpiryWorkItem?.cancel()
                    self.outgoingInvitationExpiryWorkItem?.cancel()
                    self.incomingInvitationExpiryWorkItem = nil
                    self.outgoingInvitationExpiryWorkItem = nil
                    self.pendingInvitation = nil
                    self.outgoingInvitation = nil
                    self.connectingPeer = nil
                    self.lobbySession = nil
                    self.connectionState = .searching
                }
            }
        }
    }

    func nearbyTransport(
        _ transport: NearbyTransport,
        didReceive message: NearbyMessage,
        from peer: NearbyPeer,
        session: NearbySessionToken
    ) {
        publishOnMain {
            guard self.connectionState == .connected,
                  self.lobbySession?.sessionToken == session,
                  message.gameID == self.currentGameID,
                  self.connectedPeers.contains(where: { $0.id == peer.id }) else {
#if DEBUG
                print("[NearbyService] Ignored stale message \(message.id) for \(session.sessionID)#\(session.generation)")
#endif
                return
            }

            self.lastReceivedMessage = message
            self.errorMessage = nil
        }
    }

    func nearbyTransport(
        _ transport: NearbyTransport,
        didFail error: Error
    ) {
        publishOnMain {
            let message = error.localizedDescription
            self.errorMessage = message
            self.connectionState = .failed(message)
        }
    }
}
