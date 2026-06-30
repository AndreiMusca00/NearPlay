import Foundation
import MultipeerConnectivity
import Combine

struct InvitationContext: Codable {
    let gameID: String
    let playerName: String
    let maxPlayers: Int
}

final class NearbyService: NSObject, ObservableObject {
    enum ConnectionState {
        case idle
        case searching
        case connecting
        case connected
    }

    @Published var connectionState: ConnectionState = .idle
    @Published var discoveredPeers: [NearbyPeer] = []
    @Published var connectedPeers: [NearbyPeer] = []
    @Published var errorMessage: String?

    @Published var lastReceivedMessage: NearbyMessage?

    // For UI alert
    @Published var pendingInvitation: (from: NearbyPeer, context: InvitationContext)?

    private let serviceType = "nearplay"

    private var peerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private var currentGameID: String?
    private var currentMaxPlayers: Int = 2

    // Important: keep the real MCPeerID objects discovered by the browser.
    // Do NOT recreate MCPeerID from displayName when inviting.
    private var discoveredMCPeersByID: [String: MCPeerID] = [:]

    private var storedInvitationHandler: ((Bool, MCSession?) -> Void)?

    // MARK: - Start / Stop

    func start(gameID: String, playerName: String, maxPlayers: Int) {
        stop()

        let safeName = playerName.isEmpty ? "Player" : playerName

        let peerID = MCPeerID(displayName: safeName)
        let session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )

        session.delegate = self

        self.peerID = peerID
        self.session = session
        self.currentGameID = gameID
        self.currentMaxPlayers = maxPlayers

        let discoveryInfo: [String: String] = [
            "gameID": gameID,
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
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()

        advertiser = nil
        browser = nil
        session = nil
        peerID = nil

        currentGameID = nil
        currentMaxPlayers = 2

        discoveredMCPeersByID.removeAll()
        storedInvitationHandler = nil

        publishOnMain {
            self.connectionState = .idle
            self.discoveredPeers.removeAll()
            self.connectedPeers.removeAll()
            self.pendingInvitation = nil
            self.lastReceivedMessage = nil
            self.errorMessage = nil
        }
    }

    // MARK: - Invite Flow

    func invite(_ peer: NearbyPeer, timeout: TimeInterval = 30) {
        guard let browser = browser,
              let session = session,
              let peerID = peerID,
              let currentGameID = currentGameID else {
            publishOnMain {
                self.errorMessage = "Nearby service is not ready."
            }
            return
        }

        guard let targetPeerID = discoveredMCPeersByID[peer.id] else {
            publishOnMain {
                self.errorMessage = "Could not find real peer for \(peer.displayName)."
            }
            return
        }

        let context = InvitationContext(
            gameID: currentGameID,
            playerName: peerID.displayName,
            maxPlayers: currentMaxPlayers
        )

        do {
            let contextData = try JSONEncoder().encode(context)

            browser.invitePeer(
                targetPeerID,
                to: session,
                withContext: contextData,
                timeout: timeout
            )

            publishOnMain {
                self.connectionState = .connecting
                self.errorMessage = nil
            }
        } catch {
            publishOnMain {
                self.errorMessage = "Failed to encode invitation: \(error.localizedDescription)"
            }
        }
    }

    func acceptInvitation() {
        guard let handler = storedInvitationHandler,
              let session = session else {
            publishOnMain {
                self.errorMessage = "No invitation to accept."
            }
            return
        }

        storedInvitationHandler = nil

        publishOnMain {
            self.pendingInvitation = nil
            self.connectionState = .connecting
        }

        handler(true, session)
    }

    func rejectInvitation() {
        guard let handler = storedInvitationHandler else {
            publishOnMain {
                self.pendingInvitation = nil
            }
            return
        }

        storedInvitationHandler = nil

        publishOnMain {
            self.pendingInvitation = nil
            self.connectionState = self.browser != nil ? .searching : .idle
        }

        handler(false, nil)
    }

    // MARK: - Messaging

    func send(_ message: NearbyMessage) {
        guard let session = session else {
            publishOnMain {
                self.errorMessage = "No active session."
            }
            return
        }

        send(message, toMCPeers: session.connectedPeers)
    }

    func send(_ message: NearbyMessage, to peers: [NearbyPeer]) {
        guard let session = session else {
            publishOnMain {
                self.errorMessage = "No active session."
            }
            return
        }

        let targetPeerIDs: [MCPeerID]

        if peers.isEmpty {
            targetPeerIDs = session.connectedPeers
        } else {
            targetPeerIDs = session.connectedPeers.filter { mcPeer in
                peers.contains { nearbyPeer in
                    nearbyPeer.id == mcPeer.displayName
                }
            }
        }

        send(message, toMCPeers: targetPeerIDs)
    }

    private func send(_ message: NearbyMessage, toMCPeers peers: [MCPeerID]) {
        guard let session = session else { return }

        guard !peers.isEmpty else {
            publishOnMain {
                self.errorMessage = "No connected peers to send message."
            }
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: peers, with: .reliable)

            publishOnMain {
                self.errorMessage = nil
            }
        } catch {
            publishOnMain {
                self.errorMessage = "Send failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Helpers

    private func upsertDiscoveredPeer(_ peerID: MCPeerID, info: [String: String]?) {
        guard let currentGameID = currentGameID else { return }

        guard info?["gameID"] == currentGameID else { return }

        let peer = NearbyPeer(
            id: peerID.displayName,
            displayName: info?["playerName"] ?? peerID.displayName,
            gameID: info?["gameID"],
            maxPlayers: Int(info?["maxPlayers"] ?? "")
        )

        publishOnMain {
            self.discoveredMCPeersByID[peer.id] = peerID

            let alreadyDiscovered = self.discoveredPeers.contains { $0.id == peer.id }
            let alreadyConnected = self.connectedPeers.contains { $0.id == peer.id }

            if !alreadyDiscovered && !alreadyConnected {
                self.discoveredPeers.append(peer)
            }
        }
    }

    private func removeDiscoveredPeer(_ peerID: MCPeerID) {
        publishOnMain {
            self.discoveredMCPeersByID.removeValue(forKey: peerID.displayName)
            self.discoveredPeers.removeAll { $0.id == peerID.displayName }
        }
    }

    private func publishOnMain(_ block: @escaping () -> Void) {
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
        upsertDiscoveredPeer(peerID, info: info)
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
            self.errorMessage = "Browser failed: \(error.localizedDescription)"
            self.connectionState = .idle
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
            self.errorMessage = "Advertiser failed: \(error.localizedDescription)"
            self.connectionState = .idle
        }
    }

    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        let decodedContext: InvitationContext?

        if let context = context {
            decodedContext = try? JSONDecoder().decode(InvitationContext.self, from: context)
        } else {
            decodedContext = nil
        }

        let finalContext = decodedContext ?? InvitationContext(
            gameID: currentGameID ?? "",
            playerName: peerID.displayName,
            maxPlayers: currentMaxPlayers
        )

        let invitingPeer = NearbyPeer(
            id: peerID.displayName,
            displayName: finalContext.playerName,
            gameID: finalContext.gameID,
            maxPlayers: finalContext.maxPlayers
        )

        storedInvitationHandler = invitationHandler

        publishOnMain {
            self.pendingInvitation = (
                from: invitingPeer,
                context: finalContext
            )
            self.connectionState = .connecting
            self.errorMessage = nil
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
        let peer = NearbyPeer(
            id: peerID.displayName,
            displayName: peerID.displayName
        )

        switch state {
        case .connected:
            publishOnMain {
                self.discoveredPeers.removeAll { $0.id == peer.id }
                self.discoveredMCPeersByID.removeValue(forKey: peer.id)

                if !self.connectedPeers.contains(where: { $0.id == peer.id }) {
                    self.connectedPeers.append(peer)
                }

                self.connectionState = .connected
                self.errorMessage = nil
            }

        case .connecting:
            publishOnMain {
                self.connectionState = .connecting
            }

        case .notConnected:
            publishOnMain {
                self.connectedPeers.removeAll { $0.id == peer.id }

                if self.connectedPeers.isEmpty {
                    self.connectionState = self.browser != nil ? .searching : .idle
                }
            }

        @unknown default:
            break
        }
    }

    func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {
        do {
            let message = try JSONDecoder().decode(NearbyMessage.self, from: data)

            publishOnMain {
                self.lastReceivedMessage = message
                self.errorMessage = nil
            }
        } catch {
            publishOnMain {
                self.errorMessage = "Failed to decode message from \(peerID.displayName): \(error.localizedDescription)"
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
