//
//  NearbyService.swift
//  NearPlay
//
//  Created by Andrei Musca on 30/06/2026.
//

import Foundation
import MultipeerConnectivity
import Combine

/// Generic, reusable nearby connectivity service.
/// This first version sets up core properties and lifecycle without full invite/browse/advertise logic.
final class NearbyService: NSObject, ObservableObject {
    // MARK: - Published state
    @Published private(set) var connectionState: NearbyConnectionState = .idle
    @Published private(set) var discoveredPeers: [NearbyPeer] = []
    @Published private(set) var connectedPeers: [NearbyPeer] = []
    @Published private(set) var pendingInvitation: NearbyInvitation?
    @Published private(set) var lastReceivedMessage: NearbyMessage?
    @Published private(set) var errorMessage: String?

    // MARK: - Configuration
    private let serviceType = "nearplay"
    private var currentGameID: String?
    private var currentPlayerName: String = ""
    private var currentMaxPlayers: Int = 2

    // MARK: - Multipeer components
    private var myPeerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // MARK: - Public API
    func start(gameID: String, playerName: String, maxPlayers: Int) {
        // Reset any existing state
        stop()

        // Store configuration
        currentGameID = gameID
        currentPlayerName = playerName
        currentMaxPlayers = maxPlayers

        // Initialize peer and session
        let peerID = MCPeerID(displayName: playerName)
        myPeerID = peerID
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        // Delegates will be set up in a later step
        self.session = session

        // TODO: In a later step, set up advertiser and browser with discoveryInfo and delegates
        // advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        // browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)

        // Move to a searching state for now (placeholder)
        publishOnMain { self.connectionState = .searching }
    }

    func stop() {
        // Disconnect and clean up
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()

        advertiser = nil
        browser = nil
        session = nil
        myPeerID = nil
        currentGameID = nil
        currentPlayerName = ""
        currentMaxPlayers = 2

        publishOnMain {
            self.connectionState = .idle
            self.discoveredPeers = []
            self.connectedPeers = []
            self.pendingInvitation = nil
            self.lastReceivedMessage = nil
            self.errorMessage = nil
        }
    }

    func invite(_ peer: NearbyPeer) {
        // TODO: Implement invite flow in a later step
        // For now, set state to inviting as a placeholder
        publishOnMain { self.connectionState = .inviting }
    }

    func acceptInvitation() {
        // TODO: Implement accept flow in a later step
        publishOnMain { self.pendingInvitation = nil }
    }

    func rejectInvitation() {
        // TODO: Implement reject flow in a later step
        publishOnMain { self.pendingInvitation = nil }
    }

    func send(_ message: NearbyMessage) {
        // TODO: Implement broadcast send in a later step
        // Placeholder: no-op
    }

    func send(_ message: NearbyMessage, to peers: [NearbyPeer]) {
        // TODO: Implement targeted send in a later step
        // Placeholder: no-op
    }

    // MARK: - Helpers
    private func publishOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }
}
