import Foundation

// Keep this struct defined only once in the whole project.
// If you already have GameQuitPayload in another file, do not add this file.
struct GameQuitPayload: Codable, Equatable {
    let playerName: String
    let reason: String
}
