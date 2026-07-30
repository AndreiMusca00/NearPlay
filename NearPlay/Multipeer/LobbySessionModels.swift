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
            gameID: gameID,
            inviterPlayerID: inviterPlayerID,
            inviterPlayerName: inviterPlayerName,
            maxPlayers: maxPlayers
        )
    }
}

/// Shared identity of the current lobby connection.
/// This can later be persisted and reused by the reconnect flow.
struct LobbySessionContext: Codable, Equatable {
    let sessionID: String
    let gameID: String
    let hostPlayerID: String
    let guestPlayerID: String

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
