import Foundation

/// Starea comună afișată de toate jocurile la finalul unei runde.
enum RematchState: Equatable {
    case available
    case waitingForOpponent
    case opponentRequested(playerName: String)
    case starting
}

/// Acțiunile schimbate între dispozitive pentru o revanșă.
enum RematchAction: String, Codable {
    case request
    case accept
    case confirmed
    case cancel
}

/// Payload comun pentru toate jocurile NearPlay.
/// `roundNumber` identifică runda care tocmai s-a terminat.
struct RematchPayload: Codable, Equatable {
    let sessionID: String
    let roundNumber: Int
    let playerID: String
    let playerName: String
    let action: RematchAction
}

/// Rezultatul local afișat de componenta comună.
enum GameRoundResult: Equatable {
    case win
    case loss
    case draw
}
