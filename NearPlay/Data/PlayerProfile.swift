import SwiftUI

struct PlayerProfile {
    // UserDefaults keys
    static let nameKey = "player_name"
    static let favoriteGameIDsKey = "favorite_game_ids"
}

// Injectează toate datele locale ale jucătorului în Environment
struct PlayerNameStorage: ViewModifier {
    @AppStorage(PlayerProfile.nameKey)
    private var playerName: String = ""

    @AppStorage(PlayerProfile.favoriteGameIDsKey)
    private var favoriteGameIDsJSON: String = "[]"

    func body(content: Content) -> some View {
        content
            .environment(\._playerNameBinding, $playerName)
            .environment(
                \._favoriteGameIDsBinding,
                favoriteGameIDsBinding
            )
    }

    private var favoriteGameIDsBinding: Binding<Set<String>> {
        Binding(
            get: {
                decodeFavoriteGameIDs()
            },
            set: { newValue in
                favoriteGameIDsJSON = encodeFavoriteGameIDs(newValue)
            }
        )
    }

    private func decodeFavoriteGameIDs() -> Set<String> {
        guard let data = favoriteGameIDsJSON.data(using: .utf8),
              let ids = try? JSONDecoder().decode(
                [String].self,
                from: data
              ) else {
            return []
        }

        return Set(ids)
    }

    private func encodeFavoriteGameIDs(
        _ ids: Set<String>
    ) -> String {
        let sortedIDs = Array(ids).sorted()

        guard let data = try? JSONEncoder().encode(sortedIDs),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return json
    }
}

// MARK: - Player name environment

private struct PlayerNameBindingKey: EnvironmentKey {
    static let defaultValue: Binding<String> = .constant("")
}

extension EnvironmentValues {
    var _playerNameBinding: Binding<String> {
        get {
            self[PlayerNameBindingKey.self]
        }
        set {
            self[PlayerNameBindingKey.self] = newValue
        }
    }
}

// MARK: - Favorite games environment

private struct FavoriteGameIDsBindingKey: EnvironmentKey {
    static let defaultValue: Binding<Set<String>> = .constant([])
}

extension EnvironmentValues {
    var _favoriteGameIDsBinding: Binding<Set<String>> {
        get {
            self[FavoriteGameIDsBindingKey.self]
        }
        set {
            self[FavoriteGameIDsBindingKey.self] = newValue
        }
    }
}

// MARK: - View modifier

extension View {
    func withPlayerNameStorage() -> some View {
        modifier(PlayerNameStorage())
    }
}
