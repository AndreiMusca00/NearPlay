import SwiftUI

struct OfflineGamesRootView: View {
    @AppStorage(PlayerProfile.nameKey) private var playerName: String = ""

    var body: some View {
        Group {
            if playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                FirstRunView()
            } else {
                GamesListView()
            }
        }
        .withPlayerNameStorage()
    }
}

#Preview {
    OfflineGamesRootView()
}
