import Foundation
import MultipeerConnectivity
import Combine

final class NearbyService: NSObject, ObservableObject {
    @Published var connectionState: NearbyConnectionState = .idle
    @Published var discoveredPeers: [NearbyPeer] = []
    @Published var connectedPeers: [NearbyPeer] = []
    @Published var errorMessage: String?

    @Published var lastReceivedMessage: NearbyMessage?

    /// The invitation currently displayed on the receiver's device.
    @Published private(set) var pendingInvitation: NearbyInvitation?

    /// The invitation currently displayed on the sender's device.
    @Published private(set) var outgoingInvitation: NearbyOutgoingInvitation?

    /// Used for the short state between accepting and becoming connected.
    @Published private(set) var connectingPeer: NearbyPeer?

    /// A short, one-second result shown after the remote player explicitly declines.
    @Published private(set) var invitationFeedback: NearbyInvitationFeedback?

    /// Shared lobby identity. The inviter is always the host/coordinator.
    @Published private(set) var lobbySession: LobbySessionContext?

    let localPlayerID: String = NearPlayIdentity.playerID

    var isLocalHost: Bool {
        lobbySession?.hostPlayerID == localPlayerID
    }

    let invitationDuration: TimeInterval = 5

    private let serviceType = "nearplay"

    private var peerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private var currentGameID: String?
    private var currentPlayerName: String?
    private var currentMaxPlayers: Int = 2

    /// Keyed by the persistent NearPlay player ID.
    private var discoveredMCPeersByID: [String: MCPeerID] = [:]
    private var connectedMCPeersByID: [String: MCPeerID] = [:]

    /// Keyed by MCPeerID.displayName, the transport identifier used by MPC.
    private var knownPeersByTransportID: [String: NearbyPeer] = [:]

    private var storedInvitationHandler: ((Bool, MCSession?) -> Void)?

    private var incomingInvitationExpiryWorkItem: DispatchWorkItem?
    private var outgoingInvitationExpiryWorkItem: DispatchWorkItem?
    private var invitationFeedbackExpiryWorkItem: DispatchWorkItem?

    // MARK: - Start / Stop

    func start(
        gameID: String,
        playerName: String,
        maxPlayers: Int
    ) {
        stop()

        let safeName = playerName.isEmpty ? "Player" : playerName
        let peerID = NearPlayIdentity.peerID

        let session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )

        session.delegate = self

        self.peerID = peerID
        self.session = session
        self.currentGameID = gameID
        self.currentPlayerName = safeName
        self.currentMaxPlayers = maxPlayers

        let discoveryInfo: [String: String] = [
            "gameID": gameID,
            "playerID": localPlayerID,
            "playerName": safeName,
            "maxPlayers": String(maxPlayers)
        ]

        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: discoveryInfo,
            serviceType: serviceType
        )
        advertiser.delegate = self

        let browser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: serviceType
        )
        browser.delegate = self

        self.advertiser = advertiser
        self.browser = browser

        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()

        publishOnMain {
            self.connectionState = .searching
            self.errorMessage = nil
        }
    }

    func stop() {
        incomingInvitationExpiryWorkItem?.cancel()
        outgoingInvitationExpiryWorkItem?.cancel()
        invitationFeedbackExpiryWorkItem?.cancel()

        incomingInvitationExpiryWorkItem = nil
        outgoingInvitationExpiryWorkItem = nil
        invitationFeedbackExpiryWorkItem = nil

        if let handler = storedInvitationHandler {
            handler(false, nil)
        }

        storedInvitationHandler = nil

        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()

        advertiser = nil
        browser = nil
        session = nil
        peerID = nil

        currentGameID = nil
        currentPlayerName = nil
        currentMaxPlayers = 2

        discoveredMCPeersByID.removeAll()
        connectedMCPeersByID.removeAll()
        knownPeersByTransportID.removeAll()

        publishOnMain {
            self.connectionState = .idle
            self.discoveredPeers.removeAll()
            self.connectedPeers.removeAll()
            self.pendingInvitation = nil
            self.outgoingInvitation = nil
            self.connectingPeer = nil
            self.invitationFeedback = nil
            self.lobbySession = nil
            self.lastReceivedMessage = nil
            self.errorMessage = nil
        }
    }

    /// Kept for the future reconnect implementation.
    func restoreLobbySession(
        _ context: LobbySessionContext
    ) {
        guard context.contains(playerID: localPlayerID) else {
            return
        }

        publishOnMain {
            self.lobbySession = context
        }
    }

    func clearLobbySession() {
        publishOnMain {
            self.lobbySession = nil
        }
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

        guard let browser,
              let session,
              let currentGameID,
              let currentPlayerName else {
            publishOnMain {
                self.errorMessage =
                    "Nearby service is not ready."
            }
            return
        }

        guard let targetPeerID =
                discoveredMCPeersByID[peer.id] else {
            publishOnMain {
                self.errorMessage =
                    "Could not find real peer for \(peer.displayName)."
            }
            return
        }

        let context = InvitationContext(
            kind: .request,
            sessionID: UUID().uuidString,
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
            gameID: context.gameID,
            hostPlayerID: context.inviterPlayerID,
            guestPlayerID: peer.id
        )

        do {
            let contextData = try JSONEncoder()
                .encode(context)

            browser.invitePeer(
                targetPeerID,
                to: session,
                withContext: contextData,
                timeout: invitationDuration
            )

            publishOnMain {
                self.outgoingInvitation = outgoing
                self.connectingPeer = peer
                self.lobbySession = sessionContext
                self.connectionState = .inviting
                self.errorMessage = nil
            }

            scheduleOutgoingInvitationExpiry(
                sessionID: context.sessionID
            )
        } catch {
            publishOnMain {
                self.errorMessage =
                    "Failed to encode invitation: \(error.localizedDescription)"
                self.connectionState = .failed(
                    error.localizedDescription
                )
            }
        }
    }

    func acceptInvitation() {
        guard let invitation = pendingInvitation,
              let handler = storedInvitationHandler,
              let session else {
            publishOnMain {
                self.errorMessage =
                    "No invitation to accept."
            }
            return
        }

        incomingInvitationExpiryWorkItem?.cancel()
        incomingInvitationExpiryWorkItem = nil
        storedInvitationHandler = nil

        let sessionContext = LobbySessionContext(
            sessionID: invitation.context.sessionID,
            gameID: invitation.context.gameID,
            hostPlayerID:
                invitation.context.inviterPlayerID,
            guestPlayerID: localPlayerID
        )

        publishOnMain {
            self.pendingInvitation = nil
            self.connectingPeer = invitation.fromPeer
            self.lobbySession = sessionContext
            self.connectionState = .connecting
            self.errorMessage = nil
        }

        handler(true, session)
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

        let handler = storedInvitationHandler
        storedInvitationHandler = nil

        publishOnMain {
            self.pendingInvitation = nil
            self.connectingPeer = nil

            if self.connectedPeers.isEmpty {
                self.connectionState =
                    self.browser != nil
                    ? .searching
                    : .idle
            }
        }

        handler?(false, nil)

        if sendsDeclineResponse {
            sendDeclineResponse(for: invitation)
        }
    }

    /// Before the peers are connected there is no NearbyMessage channel.
    /// A tiny reverse MPC invitation is therefore used only as a decline response.
    /// The receiver handles it automatically and never presents it as a game invitation.
    private func sendDeclineResponse(
        for invitation: NearbyInvitation
    ) {
        guard let browser,
              let session,
              let targetPeerID =
                discoveredMCPeersByID[invitation.fromPeer.id] else {
            return
        }

        let response = invitation.context.response(
            kind: .declined
        )

        guard let data = try? JSONEncoder().encode(response) else {
            return
        }

        browser.invitePeer(
            targetPeerID,
            to: session,
            withContext: data,
            timeout: 1.5
        )
    }

    // MARK: - Messaging

    func send(_ message: NearbyMessage) {
        guard let session else {
            publishOnMain {
                self.errorMessage = "No active session."
            }
            return
        }

        send(
            message,
            toMCPeers: session.connectedPeers
        )
    }

    func send(
        _ message: NearbyMessage,
        to peers: [NearbyPeer]
    ) {
        guard session != nil else {
            publishOnMain {
                self.errorMessage = "No active session."
            }
            return
        }

        let targetPeerIDs: [MCPeerID]

        if peers.isEmpty {
            targetPeerIDs = session?.connectedPeers ?? []
        } else {
            targetPeerIDs = peers.compactMap {
                connectedMCPeersByID[$0.id]
            }
        }

        send(
            message,
            toMCPeers: targetPeerIDs
        )
    }

    private func send(
        _ message: NearbyMessage,
        toMCPeers peers: [MCPeerID]
    ) {
        guard let session else {
            return
        }

        guard !peers.isEmpty else {
            publishOnMain {
                self.errorMessage =
                    "No connected peers to send message."
            }
            return
        }

        do {
            let data = try JSONEncoder()
                .encode(message)

            try session.send(
                data,
                toPeers: peers,
                with: .reliable
            )

            publishOnMain {
                self.errorMessage = nil
            }
        } catch {
            publishOnMain {
                self.errorMessage =
                    "Send failed: \(error.localizedDescription)"
            }
        }
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
        sessionID: String
    ) {
        outgoingInvitationExpiryWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  let outgoing = self.outgoingInvitation,
                  outgoing.context.sessionID == sessionID else {
                return
            }

            // Dacă MPC a intrat în connecting,
            // invitația a fost acceptată.
            guard self.connectionState == .inviting else {
                return
            }

            // Afișează același mesaj ca la un Decline manual.
            self.showInvitationDeclinedFeedback(
                for: outgoing.toPeer
            )
        }

        outgoingInvitationExpiryWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline:
                .now() +
                invitationDuration +
                0.15,
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
        connectionState = browser != nil ? .searching : .idle

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
        storedInvitationHandler = nil
    }

    // MARK: - Helpers

    private func upsertDiscoveredPeer(
        _ peerID: MCPeerID,
        info: [String: String]?
    ) {
        guard let currentGameID else {
            return
        }

        guard info?["gameID"] == currentGameID else {
            return
        }

        let persistentPlayerID =
            info?["playerID"] ?? fallbackPlayerID(
                for: peerID
            )

        guard persistentPlayerID != localPlayerID else {
            return
        }

        let peer = NearbyPeer(
            id: persistentPlayerID,
            displayName:
                info?["playerName"] ?? peerID.displayName,
            gameID: info?["gameID"],
            maxPlayers:
                Int(info?["maxPlayers"] ?? "")
        )

        publishOnMain {
            self.discoveredMCPeersByID[peer.id] = peerID
            self.knownPeersByTransportID[
                peerID.displayName
            ] = peer

            let alreadyDiscovered =
                self.discoveredPeers.contains {
                    $0.id == peer.id
                }

            let alreadyConnected =
                self.connectedPeers.contains {
                    $0.id == peer.id
                }

            if !alreadyDiscovered &&
                !alreadyConnected {
                self.discoveredPeers.append(peer)
            }
        }
    }

    private func removeDiscoveredPeer(
        _ peerID: MCPeerID
    ) {
        publishOnMain {
            guard let peer =
                    self.knownPeersByTransportID[
                        peerID.displayName
                    ] else {
                return
            }

            self.discoveredMCPeersByID
                .removeValue(forKey: peer.id)

            self.discoveredPeers.removeAll {
                $0.id == peer.id
            }

            let isStillConnected =
                self.connectedPeers.contains {
                    $0.id == peer.id
                }

            if !isStillConnected {
                self.knownPeersByTransportID
                    .removeValue(
                        forKey: peerID.displayName
                    )
            }
        }
    }

    private func fallbackPlayerID(
        for peerID: MCPeerID
    ) -> String {
        let prefix = "NearPlay-"

        if peerID.displayName.hasPrefix(prefix) {
            return String(
                peerID.displayName.dropFirst(
                    prefix.count
                )
            )
        }

        return peerID.displayName
    }

    private func fallbackPeer(
        for peerID: MCPeerID
    ) -> NearbyPeer {
        NearbyPeer(
            id: fallbackPlayerID(for: peerID),
            displayName: peerID.displayName,
            gameID: currentGameID,
            maxPlayers: currentMaxPlayers
        )
    }

    private func sessionContext(
        from invitation: InvitationContext,
        remotePlayerID: String
    ) -> LobbySessionContext {
        LobbySessionContext(
            sessionID: invitation.sessionID,
            gameID: invitation.gameID,
            hostPlayerID: invitation.inviterPlayerID,
            guestPlayerID: remotePlayerID
        )
    }

    private func publishOnMain(
        _ block: @escaping () -> Void
    ) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension NearbyService: MCNearbyServiceBrowserDelegate {
    func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        upsertDiscoveredPeer(
            peerID,
            info: info
        )
    }

    func browser(
        _ browser: MCNearbyServiceBrowser,
        lostPeer peerID: MCPeerID
    ) {
        removeDiscoveredPeer(peerID)
    }

    func browser(
        _ browser: MCNearbyServiceBrowser,
        didNotStartBrowsingForPeers error: Error
    ) {
        publishOnMain {
            let message =
                "Browser failed: \(error.localizedDescription)"

            self.errorMessage = message
            self.connectionState = .failed(message)
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension NearbyService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didNotStartAdvertisingPeer error: Error
    ) {
        publishOnMain {
            let message =
                "Advertiser failed: \(error.localizedDescription)"

            self.errorMessage = message
            self.connectionState = .failed(message)
        }
    }

    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler:
            @escaping (Bool, MCSession?) -> Void
    ) {
        let decodedContext: InvitationContext?

        if let context {
            decodedContext = try? JSONDecoder().decode(
                InvitationContext.self,
                from: context
            )
        } else {
            decodedContext = nil
        }

        guard let decodedContext,
              decodedContext.gameID == currentGameID else {
            invitationHandler(false, nil)
            return
        }

        // A decline arrives as a lightweight reverse invitation because the
        // real MCSession connection has not been established yet.
        if decodedContext.kind == .declined {
            invitationHandler(false, nil)

            publishOnMain {
                guard let outgoing = self.outgoingInvitation,
                      outgoing.context.sessionID ==
                        decodedContext.sessionID else {
                    return
                }

                self.showInvitationDeclinedFeedback(
                    for: outgoing.toPeer
                )
            }
            return
        }

        guard decodedContext.kind == .request,
              decodedContext.inviterPlayerID != localPlayerID else {
            invitationHandler(false, nil)
            return
        }

        let invitingPeer = NearbyPeer(
            id: decodedContext.inviterPlayerID,
            displayName:
                decodedContext.inviterPlayerName,
            gameID: decodedContext.gameID,
            maxPlayers: decodedContext.maxPlayers
        )

        publishOnMain {
            guard self.connectedPeers.isEmpty,
                  self.pendingInvitation == nil else {
                invitationHandler(false, nil)
                return
            }

            // Resolve the rare case where both players invite each other
            // at practically the same moment. The smaller persistent ID wins.
            if let outgoing = self.outgoingInvitation {
                guard outgoing.toPeer.id == invitingPeer.id else {
                    invitationHandler(false, nil)
                    return
                }

                if self.localPlayerID < invitingPeer.id {
                    invitationHandler(false, nil)
                    return
                }

                self.outgoingInvitationExpiryWorkItem?.cancel()
                self.outgoingInvitationExpiryWorkItem = nil
                self.outgoingInvitation = nil
                self.connectingPeer = nil
                self.lobbySession = nil
            }

            self.knownPeersByTransportID[
                peerID.displayName
            ] = invitingPeer

            self.discoveredMCPeersByID[
                invitingPeer.id
            ] = peerID

            let now = Date()
            let invitation = NearbyInvitation(
                fromPeer: invitingPeer,
                context: decodedContext,
                receivedAt: now,
                expiresAt: now.addingTimeInterval(
                    self.invitationDuration
                )
            )

            self.storedInvitationHandler =
                invitationHandler
            self.pendingInvitation = invitation
            self.connectingPeer = invitingPeer
            self.connectionState = .invited
            self.errorMessage = nil

            self.scheduleIncomingInvitationExpiry(
                invitationID: invitation.id
            )
        }
    }
}

// MARK: - MCSessionDelegate

extension NearbyService: MCSessionDelegate {
    func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        guard session === self.session else {
            return
        }

        publishOnMain {
            let peer =
                self.knownPeersByTransportID[
                    peerID.displayName
                ] ?? self.fallbackPeer(
                    for: peerID
                )

            self.knownPeersByTransportID[
                peerID.displayName
            ] = peer

            switch state {
            case .connected:
                self.discoveredPeers.removeAll {
                    $0.id == peer.id
                }

                self.discoveredMCPeersByID
                    .removeValue(forKey: peer.id)

                self.connectedMCPeersByID[
                    peer.id
                ] = peerID

                if !self.connectedPeers.contains(
                    where: { $0.id == peer.id }
                ) {
                    self.connectedPeers.append(peer)
                }

                // Once a player is connected, this two-player lobby is closed
                // to any additional invitations.
                self.advertiser?.stopAdvertisingPeer()
                self.browser?.stopBrowsingForPeers()
                self.discoveredPeers.removeAll()

                self.clearInvitationStateAfterConnection()
                self.connectionState = .connected
                self.errorMessage = nil

            case .connecting:
                self.outgoingInvitationExpiryWorkItem?.cancel()
                self.outgoingInvitationExpiryWorkItem = nil
                self.connectingPeer = peer
                self.connectionState = .connecting

            case .notConnected:
                self.connectedPeers.removeAll {
                    $0.id == peer.id
                }

                self.connectedMCPeersByID
                    .removeValue(forKey: peer.id)

                if self.connectedPeers.isEmpty {
                    if self.outgoingInvitation != nil {
                        // Rejection and invitation timeout both report
                        // `.notConnected`. Keep the outgoing card alive until
                        // the explicit decline response or the five-second timer.
                        self.connectionState = .inviting
                    } else {
                        self.connectionState =
                            self.browser != nil
                            ? .searching
                            : .disconnected
                    }
                }

            @unknown default:
                break
            }
        }
    }

    func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {
        guard session === self.session else {
            return
        }

        do {
            let message = try JSONDecoder().decode(
                NearbyMessage.self,
                from: data
            )

            publishOnMain {
                self.lastReceivedMessage = message
                self.errorMessage = nil
            }
        } catch {
            publishOnMain {
                self.errorMessage =
                    "Failed to decode message from \(peerID.displayName): \(error.localizedDescription)"
            }
        }
    }

    func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}

    #if os(iOS) || os(tvOS)
    func session(
        _ session: MCSession,
        didReceiveCertificate certificate: [Any]?,
        fromPeer peerID: MCPeerID,
        certificateHandler: @escaping (Bool) -> Void
    ) {
        certificateHandler(true)
    }
    #endif
}
