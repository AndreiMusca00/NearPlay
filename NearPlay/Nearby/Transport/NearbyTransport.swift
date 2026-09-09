import Foundation

/// Everything the game/lobby layer needs from a nearby transport.
///
/// NearbyService talks only to this protocol. The concrete transport can be
/// MultipeerConnectivity today, CoreBluetooth next, and Network.framework later.
protocol NearbyTransport: AnyObject {
    var delegate: NearbyTransportDelegate? { get set }

    func start(configuration: NearbyTransportConfiguration)
    func stop()

    func invite(
        _ peer: NearbyPeer,
        context: InvitationContext,
        timeout: TimeInterval
    )

    func acceptInvitation(sessionID: String)

    func rejectInvitation(
        sessionID: String,
        sendDeclineResponse: Bool
    )

    func send(
        _ message: NearbyMessage,
        to peers: [NearbyPeer]?
    )
}

struct NearbyTransportConfiguration: Equatable {
    let gameID: String
    let playerID: String
    let playerName: String
    let maxPlayers: Int
}

enum NearbyTransportPeerState: Equatable {
    case connecting
    case connected
    case disconnected
}

protocol NearbyTransportDelegate: AnyObject {
    func nearbyTransport(
        _ transport: NearbyTransport,
        didDiscover peer: NearbyPeer
    )

    func nearbyTransport(
        _ transport: NearbyTransport,
        didLose peer: NearbyPeer
    )

    func nearbyTransport(
        _ transport: NearbyTransport,
        didReceiveInvitationFrom peer: NearbyPeer,
        context: InvitationContext
    )

    func nearbyTransport(
        _ transport: NearbyTransport,
        didReceiveDeclineFor context: InvitationContext,
        from peer: NearbyPeer?
    )

    /// The transport detected a simultaneous-invite collision and this
    /// device deterministically lost the outgoing side. NearbyService should
    /// clear the outgoing UI state silently and allow the incoming invite to
    /// become the single winning invitation.
    func nearbyTransport(
        _ transport: NearbyTransport,
        didYieldOutgoingInvitation context: InvitationContext,
        to peer: NearbyPeer
    )

    func nearbyTransport(
        _ transport: NearbyTransport,
        peer: NearbyPeer,
        didChange state: NearbyTransportPeerState
    )

    func nearbyTransport(
        _ transport: NearbyTransport,
        didReceive message: NearbyMessage,
        from peer: NearbyPeer
    )

    func nearbyTransport(
        _ transport: NearbyTransport,
        didFail error: Error
    )
}
