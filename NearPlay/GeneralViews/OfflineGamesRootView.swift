import SwiftUI

struct OfflineGamesRootView: View {
    @AppStorage(PlayerProfile.nameKey)
    private var playerName: String = ""

    @AppStorage(NearbyOnboardingStorage.completedKey)
    private var hasCompletedNearbyOnboarding = false

    var body: some View {
        Group {
            if playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                FirstRunView()
            } else if !hasCompletedNearbyOnboarding {
                NearbyPermissionsOnboardingView()
            } else {
                GamesListView()
            }
        }
        .withPlayerNameStorage()
    }
}
