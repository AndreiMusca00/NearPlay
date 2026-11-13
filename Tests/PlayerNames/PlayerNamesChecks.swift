import Foundation

// Exercise the production discovery/name logic without Bluetooth hardware.
enum NearPlayIdentity {
    static let playerID = "local-player"
}

@MainActor
final class RecordingTransport: NearbyTransport {
    weak var delegate: NearbyTransportDelegate?
    var configuration: NearbyTransportConfiguration?
    var invitations: [InvitationContext] = []

    func start(configuration: NearbyTransportConfiguration) { self.configuration = configuration }
    func stop() { configuration = nil }
    func invite(_ peer: NearbyPeer, context: InvitationContext, timeout: TimeInterval) {
        invitations.append(context)
    }
    func acceptInvitation(sessionID: String) {}
    func rejectInvitation(sessionID: String, sendDeclineResponse: Bool) {}
    func send(_ message: NearbyMessage, to peers: [NearbyPeer]?) {}
}

typealias BluetoothTransport = RecordingTransport

@main
struct PlayerNamesChecks {
    @MainActor
    static func main() {
        precondition(PlayerProfile.maximumNameLength == 10)
        precondition(PlayerProfile.normalizedName(" \n Ana\t Maria  ") == "Ana Maria")
        precondition(PlayerProfile.normalizedName("ABCDEFGHIJKLMNO") == "ABCDEFGHIJ")
        precondition(PlayerProfile.normalizedName("123456789 ABC") == "123456789")
        precondition(PlayerProfile.displayName(for: " \n ") == "Player")
        let unicodeName = "Șțé🇷🇴👨‍👩‍👧‍👦abcdefghi"
        precondition(PlayerProfile.limitedNameInput(unicodeName).count == 10)
        precondition(PlayerProfile.normalizedName(unicodeName) == String(unicodeName.prefix(10)))

        let gameID = "backgammon"
        let firstID = "ble:00000000-0000-0000-0000-00000000ABCD"
        let secondID = "ble:00000000-0000-0000-0000-000000001234"
        func discovery(_ name: String?, _ previous: NearbyPeer? = nil, id: String = firstID) -> NearbyPeer {
            NearbyPeer.discovered(
                id: id, advertisedName: name, previous: previous,
                gameID: gameID, maxPlayers: 2
            )
        }

        let unnamed = discovery(nil)
        let otherUnnamed = discovery(nil, id: secondID)
        precondition(unnamed.displayName == "Guest ABCD")
        precondition(unnamed.displayName != otherUnnamed.displayName)
        let named = discovery("Andrei", unnamed)
        precondition(named.id == unnamed.id && named.displayName == "Andrei")
        precondition(discovery(nil, named) == named)
        precondition(discovery(" \n ", named) == named)
        let renamed = discovery("  Alexandra  ", named)
        precondition(renamed.displayName == "Alexandra")
        precondition(discovery(nil, named, id: secondID) == otherUnnamed)
        let wrongGameCache = NearbyPeer(id: firstID, displayName: "Old name", gameID: "other")
        precondition(discovery(nil, wrongGameCache) == unnamed)

        let transport = RecordingTransport()
        let service = NearbyService(transport: transport)
        service.start(gameID: gameID, playerName: "  WWWWWWWWWWWW  ", maxPlayers: 2)
        precondition(transport.configuration?.playerName == "WWWWWWWWWW")
        func emit(_ peer: NearbyPeer) { service.nearbyTransport(transport, didDiscover: peer) }

        // Reproduce both orders: nameless first, and named first followed by
        // advertisements that omit the local-name field.
        emit(unnamed)
        emit(named)
        emit(discovery(nil, named))
        precondition(service.discoveredPeers == [named])
        emit(discovery("Andrei", id: secondID))
        precondition(service.discoveredPeers.count == 2, "Never merge peers by name")
        emit(NearbyPeer(id: "wrong-game", displayName: "Other", gameID: "other"))
        emit(NearbyPeer(id: service.localPlayerID, displayName: "Me", gameID: gameID))
        precondition(service.discoveredPeers.count == 2)

        // An updated row must not restart an invitation or extend its timeout.
        service.invite(named)
        let invitation = service.outgoingInvitation!
        let session = service.lobbySession
        service.errorMessage = "unchanged"
        emit(renamed)
        precondition(service.discoveredPeers[0] == renamed)
        precondition(service.connectingPeer == renamed)
        precondition(service.outgoingInvitation?.toPeer == renamed)
        precondition(service.outgoingInvitation?.id == invitation.id)
        precondition(service.outgoingInvitation?.context == invitation.context)
        precondition(service.outgoingInvitation?.expiresAt == invitation.expiresAt)
        precondition(service.connectionState == .inviting)
        precondition(service.lobbySession == session && service.errorMessage == "unchanged")
        precondition(transport.invitations.count == 1)

        let connected = NearbyPeer(id: "real-player-id", displayName: "ȘtefănuțAAAB", gameID: gameID)
        service.nearbyTransport(
            transport, peer: connected, didChange: .connected,
            session: invitation.context.sessionToken
        )
        precondition(connected.displayName.count == 10)
        precondition(service.connectedPeers == [connected])
        precondition(service.lobbySession?.guestPlayerID == connected.id)
        emit(connected)
        precondition(service.discoveredPeers.isEmpty)
        precondition(service.connectionState == .connected)
        service.stop()

        service.start(gameID: gameID, playerName: " ", maxPlayers: 2)
        precondition(transport.configuration?.playerName == "Player")
        emit(named)
        emit(discovery("Andrei", id: secondID))
        service.nearbyTransport(transport, didLose: named)
        precondition(service.discoveredPeers.map(\.id) == [secondID])
        service.stop()
        print("PASS: name limits, Unicode, delayed/missing names, multiple players, invitation stability, connection identity and rediscovery")
    }
}
