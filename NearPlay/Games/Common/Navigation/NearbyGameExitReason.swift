import Foundation

enum NearbyGameExitReason {
    case localPlayerQuit
    case opponentQuit(playerName: String)

    var opponentName: String? {
        guard case let .opponentQuit(playerName) = self else {
            return nil
        }
        return playerName
    }
}
