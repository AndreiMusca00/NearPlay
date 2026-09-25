import Foundation

enum InvitationContextKind: String, Codable, Equatable {
    case request
    case declined
}

/// Context sent through MultipeerConnectivity invitations.
/// A normal game invitation uses `.request`.
/// A decline is sent back as a lightweight reverse invitation using `.declined`,
/// because the two devices are not connected yet and cannot exchange NearbyMessage values.
struct InvitationContext: Codable, Equatable {
    let kind: InvitationContextKind
    let sessionID: String
    /// Monotonically increasing on the device that owns the invitation.
    /// Together with `sessionID`, this prevents delayed packets from an older
    /// attempt from being accepted by a newer connection.
    let generation: UInt64
    let gameID: String
    let inviterPlayerID: String
    let inviterPlayerName: String
    let maxPlayers: Int

    func response(
        kind: InvitationContextKind
    ) -> InvitationContext {
        InvitationContext(
            kind: kind,
            sessionID: sessionID,
            generation: generation,
            gameID: gameID,
            inviterPlayerID: inviterPlayerID,
            inviterPlayerName: inviterPlayerName,
            maxPlayers: maxPlayers
        )
    }
}

/// Immutable identity for one logical nearby session.
///
/// A UUID protects sessions across launches while `generation` orders attempts
/// created during the same process lifetime. Every handshake packet carries
/// both values and must match exactly before it can mutate connection state.
struct NearbySessionToken: Codable, Equatable, Hashable {
    let sessionID: String
    let generation: UInt64
}

extension InvitationContext {
    var sessionToken: NearbySessionToken {
        NearbySessionToken(
            sessionID: sessionID,
            generation: generation
        )
    }
}

/// Shared identity of the current lobby connection.
/// This can later be persisted and reused by the reconnect flow.
struct LobbySessionContext: Codable, Equatable {
    let sessionID: String
    let generation: UInt64
    let gameID: String
    let hostPlayerID: String
    let guestPlayerID: String

    var sessionToken: NearbySessionToken {
        NearbySessionToken(
            sessionID: sessionID,
            generation: generation
        )
    }

    func contains(playerID: String) -> Bool {
        playerID == hostPlayerID ||
        playerID == guestPlayerID
    }

    func matches(
        gameID: String,
        firstPlayerID: String,
        secondPlayerID: String
    ) -> Bool {
        guard self.gameID == gameID else {
            return false
        }

        return Set([hostPlayerID, guestPlayerID]) ==
        Set([firstPlayerID, secondPlayerID])
    }
}

/// Sent by the host after the connection is established.
/// Both devices display the same 3, 2, 1 countdown, but only the host sends gameStart.
struct LobbyCountdownPayload: Codable, Equatable {
    let sessionID: String
    let seconds: Int
}
