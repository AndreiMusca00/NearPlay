import MultipeerConnectivity
import Combine

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
        // Optionally validate the invitation context or peer. For now, accept if we have a session and gameID.
        guard self.session != nil else {
            invitationHandler(false, nil)
            return
        }

        // If discovery info included a gameID, it's not available here directly; you could encode it in context.
        // For now, accept all invitations and rely on filtering during discovery.
        invitationHandler(true, self.session)
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
        // Handle incoming data if needed. For now, no-op.
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
