import MultipeerConnectivity
import Combine

struct InvitationContext: Codable {
    let gameID: String
    let playerName: String
    let maxPlayers: Int
}

final class NearbyService: NSObject, ObservableObject, MCSessionDelegate {
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
    
    // Latest received message
    @Published var lastReceivedMessage: NearbyMessage?
    
    // Pending invitation information for UI to observe
    @Published var pendingInvitation: (from: NearbyPeer, context: InvitationContext)?

    // Stored invitation handler until user accepts or rejects
    private var storedInvitationHandler: ((Bool, MCSession?) -> Void)?

    private let serviceType = "nearplay"
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private var currentGameID: String?

    func start(gameID: String, playerName: String, maxPlayers: Int) {
        peerID = MCPeerID(displayName: playerName)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self

        currentGameID = gameID

        let discoveryInfo: [String: String] = [
            "gameID": gameID,
            "playerName": playerName,
            "maxPlayers": String(maxPlayers)
        ]

        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        advertiser.delegate = self
        self.advertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self
        self.browser = browser

        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()

        publishOnMain { self.connectionState = .searching }
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()

        advertiser = nil
        browser = nil
        session.disconnect()
        session = nil
        peerID = nil
        currentGameID = nil

        publishOnMain {
            self.connectionState = .idle
            self.discoveredPeers.removeAll()
            self.connectedPeers.removeAll()
            self.errorMessage = nil
        }
    }
    
    // MARK: - Messaging
    /// Send a NearbyMessage to all connected peers.
    func send(_ message: NearbyMessage) {
        send(message, to: connectedPeers)
    }

    /// Send a NearbyMessage to a subset of peers.
    func send(_ message: NearbyMessage, to peers: [NearbyPeer]) {
        guard let session = session else { return }
        do {
            let data = try JSONEncoder().encode(message)
            // Determine target MCPeerIDs
            let targetPeerIDs: [MCPeerID]
            if peers.isEmpty {
                targetPeerIDs = session.connectedPeers
            } else {
                targetPeerIDs = session.connectedPeers.filter { peer in peers.contains(where: { $0.displayName == peer.displayName }) }
            }
            for peer in targetPeerIDs {
                do {
                    try session.send(data, toPeers: [peer], with: .reliable)
                } catch {
                    publishOnMain { self.errorMessage = "Send failed to \(peer.displayName): \(error.localizedDescription)" }
                }
            }
        } catch {
            publishOnMain { self.errorMessage = "Encoding message failed: \(error.localizedDescription)" }
        }
    }
    
    /// Invite a discovered peer to join using the browser. The invitation carries a Codable context.
    func invite(_ peer: NearbyPeer, timeout: TimeInterval = 30) {
        guard let browser = browser, let session = session, let currentGameID = currentGameID else { return }
        // Build context
        let context = InvitationContext(gameID: currentGameID, playerName: peerID.displayName, maxPlayers: computeMaxPlayers())
        let encoder = JSONEncoder()
        let contextData = try? encoder.encode(context)
        // Find the MCPeerID in discovered list by matching displayName
        let targetPeerID = MCPeerID(displayName: peer.displayName)
        browser.invitePeer(targetPeerID, to: session, withContext: contextData, timeout: timeout)
        publishOnMain { self.connectionState = .connecting }
    }
    
    /// Accept the currently pending invitation if any.
    func acceptInvitation() {
        guard let handler = storedInvitationHandler else { return }
        storedInvitationHandler = nil
        publishOnMain { self.pendingInvitation = nil }
        handler(true, self.session)
        publishOnMain { self.connectionState = .connecting }
    }

    /// Reject the currently pending invitation if any.
    func rejectInvitation() {
        guard let handler = storedInvitationHandler else { return }
        storedInvitationHandler = nil
        publishOnMain { self.pendingInvitation = nil }
        handler(false, nil)
        // Return to searching if appropriate
        publishOnMain { self.connectionState = (self.browser != nil) ? .searching : .idle }
    }

    // Helpers

    private func publishOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
    
    // Determines the desired max players for the current session (between 2 and 6). Uses discovery info if available; defaults to 2.
    private func computeMaxPlayers() -> Int {
        // We don't persist maxPlayers separately; callers provide it at start(). Keep within 2...6.
        // Try to derive from discovered peers if any matching gameID, else default to 2.
        let advertised = discoveredPeers.compactMap { $0.maxPlayers }.first
        let value = advertised ?? 2
        return min(max(value, 2), 6)
    }

    private func upsertDiscoveredPeer(_ peerID: MCPeerID, info: [String: String]?) {
        guard let currentGameID = currentGameID else { return }
        // Only peers advertising the same gameID should appear
        guard info?["gameID"] == currentGameID else { return }
        let peer = NearbyPeer(id: peerID.displayName, displayName: peerID.displayName, gameID: info?["gameID"], maxPlayers: Int(info?["maxPlayers"] ?? ""))
        publishOnMain {
            if !self.discoveredPeers.contains(peer) && !self.connectedPeers.contains(peer) {
                self.discoveredPeers.append(peer)
            }
        }
    }

    private func removeDiscoveredPeer(_ peerID: MCPeerID) {
        let peer = NearbyPeer(id: peerID.displayName, displayName: peerID.displayName)
        publishOnMain {
            self.discoveredPeers.removeAll { $0.id == peer.id }
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension NearbyService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        upsertDiscoveredPeer(peerID, info: info)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        removeDiscoveredPeer(peerID)
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        publishOnMain { self.errorMessage = "Browser failed: \(error.localizedDescription)" }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension NearbyService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        publishOnMain { self.errorMessage = "Advertiser failed: \(error.localizedDescription)" }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Decode the invitation context if provided
        var decodedContext: InvitationContext? = nil
        if let context = context {
            decodedContext = try? JSONDecoder().decode(InvitationContext.self, from: context)
        }

        // Store the handler and publish a pending invitation for UI to decide
        self.storedInvitationHandler = invitationHandler
        let invitingPeer = NearbyPeer(id: peerID.displayName, displayName: peerID.displayName, gameID: decodedContext?.gameID, maxPlayers: decodedContext?.maxPlayers)
        publishOnMain {
            self.pendingInvitation = (from: invitingPeer, context: decodedContext ?? InvitationContext(gameID: self.currentGameID ?? "", playerName: peerID.displayName, maxPlayers: self.computeMaxPlayers()))
            self.connectionState = .connecting
        }
    }
}

// MARK: - MCSessionDelegate
extension NearbyService {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let peer = NearbyPeer(id: peerID.displayName, displayName: peerID.displayName)
        switch state {
        case .connected:
            publishOnMain {
                // Move from discovered to connected
                self.discoveredPeers.removeAll { $0.id == peer.id }
                if !self.connectedPeers.contains(peer) {
                    self.connectedPeers.append(peer)
                }
                self.connectionState = .connected
            }
        case .connecting:
            publishOnMain {
                self.connectionState = .connecting
            }
        case .notConnected:
            publishOnMain {
                // Remove from connected; may reappear via discovery
                self.connectedPeers.removeAll { $0.id == peer.id }
                if self.connectedPeers.isEmpty {
                    // If we were connected and lost all peers, return to searching if browser is running
                    if self.browser != nil { self.connectionState = .searching } else { self.connectionState = .idle }
                }
            }
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(NearbyMessage.self, from: data)
            publishOnMain {
                self.lastReceivedMessage = message
            }
        } catch {
            publishOnMain {
                self.errorMessage = "Failed to decode message from \(peerID.displayName): \(error.localizedDescription)"
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used in this app.
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used in this app.
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used in this app.
    }

    #if os(iOS) || os(tvOS)
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        // Accept all peers by default; in production, validate as needed.
        certificateHandler(true)
    }
    #endif
}

