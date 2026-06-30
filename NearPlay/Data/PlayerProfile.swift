import SwiftUI

struct PlayerProfile {
    // Key used for UserDefaults via @AppStorage
    static let nameKey = "player_name"
}

// A wrapper view modifier to inject the player's name binding via @AppStorage where needed
struct PlayerNameStorage: ViewModifier {
    @AppStorage(PlayerProfile.nameKey) var playerName: String = ""
    func body(content: Content) -> some View {
        content.environment(\._playerNameBinding, $playerName)
    }
}

// Internal environment key to pass a Binding<String> for the player name
private struct PlayerNameBindingKey: EnvironmentKey {
    static let defaultValue: Binding<String> = .constant("")
}

extension EnvironmentValues {
    var _playerNameBinding: Binding<String> {
        get { self[PlayerNameBindingKey.self] }
        set { self[PlayerNameBindingKey.self] = newValue }
    }
}

extension View {
    func withPlayerNameStorage() -> some View {
        modifier(PlayerNameStorage())
    }
}
