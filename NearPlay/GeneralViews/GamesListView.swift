import SwiftUI

struct GamesListView: View {

    @EnvironmentObject private var appUpdateManager: AppUpdateManager

    @Environment(\._playerNameBinding)

    private var playerName: Binding<String>

    @Environment(\._favoriteGameIDsBinding)

    private var favoriteGameIDs: Binding<Set<String>>

    @EnvironmentObject private var purchaseManager: PurchaseManager

    @EnvironmentObject private var nearbyPermissions: NearbyPermissionsManager

    @State private var isEditingName = false

    @State private var selectedFilter: GamesFilter = .popular

    @State private var filterMovesForward = true

    @Namespace private var filterSelectionNamespace

    @State private var navigationPath = NavigationPath()

    @State private var selectedGameForPurchase: Game?

    var body: some View {

        NavigationStack(path: $navigationPath) {

            ZStack {

                appBackground

                VStack(spacing: 0) {

                    // MARK: Fixed Header

                    topHeader

                        .padding(.horizontal, 16)

                        .padding(.top, 8)

                    // MARK: Fixed Filters

                    filterButtons

                        .padding(.horizontal, 16)

                        .padding(.top, 18)

                        .padding(.bottom, 12)

                    Divider()

                        .overlay(Color.white.opacity(0.08))

                        .padding(.horizontal, 16)

                    // MARK: Scrollable Games Area

                    ScrollView {

                        ZStack(alignment: .top) {

                            filterContent

                                .id(selectedFilter)

                                .transition(filterContentTransition)

                        }

                        .frame(maxWidth: .infinity)

                    }

                    .scrollIndicators(.hidden)

                    .padding(.bottom, 20)

                }

                .frame(

                    maxWidth: .infinity,

                    maxHeight: .infinity,

                    alignment: .top

                )

            }

            .toolbar(.hidden, for: .navigationBar)

            .navigationDestination(for: Game.self) { game in

                if game.id == Game.ricochet.id {

                    GameLobbyView(

                        game: game,

                        onExitToHome: {

                            navigationPath = NavigationPath()

                        }

                    )

                } else {

                    GameEntryView(

                        game: game,

                        onExitToHome: {

                            navigationPath = NavigationPath()

                        }

                    )

                }

            }

            .sheet(isPresented: $isEditingName) {

                EditNameSheet(name: playerName)

                    .presentationDetents([.medium])

                    .preferredColorScheme(.dark)

            }

            .sheet(item: $selectedGameForPurchase) { game in

                GamePurchaseSheet(game: game) {

                    selectedGameForPurchase = nil

                    navigationPath.append(game)

                }

                .environmentObject(purchaseManager)

                .presentationDetents([.medium])

                .presentationDragIndicator(.visible)

                .preferredColorScheme(.dark)

            }

            // MARK: - App Update Check

            .task {
                await appUpdateManager.checkForUpdate()
            }

            .alert(
                "Update Available",
                isPresented: $appUpdateManager.isUpdateAlertPresented
            ) {
                Button("Later", role: .cancel) {
                    appUpdateManager.dismissUpdateAlert()
                }

                Button("Update") {
                    appUpdateManager.openAppStore()
                }
            } message: {
                if let version = appUpdateManager.latestVersion {
                    Text(
                        "A new version of NearPlay (\(version)) is available on the App Store."
                    )
                } else {
                    Text(
                        "A new version of NearPlay is available on the App Store."
                    )
                }
            }

            .preferredColorScheme(.dark)

        }

    }

    // MARK: - Header

    private var topHeader: some View {

        HStack(alignment: .center, spacing: 16) {

            VStack(alignment: .leading, spacing: 5) {

                Text("NearPlay")

                    .font(

                        .system(

                            size: 38,

                            weight: .bold,

                            design: .rounded

                        )

                    )

                    .foregroundStyle(

                        LinearGradient(

                            colors: [

                                Color(

                                    red: 0.05,

                                    green: 0.72,

                                    blue: 1.00

                                ),

                                Color(

                                    red: 0.35,

                                    green: 0.40,

                                    blue: 1.00

                                ),

                                Color(

                                    red: 0.66,

                                    green: 0.25,

                                    blue: 1.00

                                )

                            ],

                            startPoint: .leading,

                            endPoint: .trailing

                        )

                    )

                Button {

                    isEditingName = true

                } label: {

                    HStack(spacing: 6) {

                        Text(greetingText)

                            .font(

                                .system(

                                    size: 15,

                                    weight: .medium

                                )

                            )

                            .foregroundStyle(

                                Color.white.opacity(0.68)

                            )

                        Image(systemName: "pencil")

                            .font(

                                .system(

                                    size: 11,

                                    weight: .semibold

                                )

                            )

                            .foregroundStyle(

                                Color.white.opacity(0.4)

                            )

                    }

                }

                .buttonStyle(.plain)

            }

            Spacer()

            NavigationLink {

                SettingsView(playerName: playerName)

            } label: {

                ZStack(alignment: .topTrailing) {

                    Image(systemName: "gearshape.fill")

                        .font(

                            .system(

                                size: 19,

                                weight: .semibold

                            )

                        )

                        .foregroundStyle(.white)

                        .frame(width: 46, height: 46)

                        .background {

                            Circle()

                                .fill(Color.white.opacity(0.065))

                        }

                        .overlay {

                            Circle()

                                .stroke(

                                    Color.white.opacity(0.13),

                                    lineWidth: 1

                                )

                        }

                    if nearbyPermissions.needsPermissionAttention {

                        Image(systemName: "exclamationmark.circle.fill")

                            .font(

                                .system(

                                    size: 15,

                                    weight: .bold

                                )

                            )

                            .symbolRenderingMode(.palette)

                            .foregroundStyle(.white, .red)

                            .background(

                                Circle()

                                    .fill(Color.red)

                                    .frame(width: 12, height: 12)

                            )

                            .offset(x: 2, y: -2)

                            .accessibilityHidden(true)

                    }

                }

            }

            .buttonStyle(.plain)

            .accessibilityLabel("Settings")

        }

    }

    private var greetingText: String {

        let trimmedName = playerName.wrappedValue

            .trimmingCharacters(

                in: .whitespacesAndNewlines

            )

        if trimmedName.isEmpty {

            return "Hi, Player 👋"

        }

        return "Hi, \(trimmedName) 👋"

    }

    // MARK: - Filters

    private var filterButtons: some View {

        HStack(spacing: 4) {

            filterButton(

                title: "Popular",

                icon: selectedFilter == .popular

                    ? "flame.fill"

                    : "flame",

                filter: .popular

            )

            filterButton(

                title: "Liked",

                icon: selectedFilter == .liked

                    ? "heart.fill"

                    : "heart",

                filter: .liked

            )

            filterButton(

                title: "All Games",

                icon: "gamecontroller.fill",

                filter: .all

            )

        }

        .padding(4)

        .background(

            RoundedRectangle(cornerRadius: 17, style: .continuous)

                .fill(Color.white.opacity(0.045))

        )

        .overlay(

            RoundedRectangle(cornerRadius: 17, style: .continuous)

                .stroke(Color.white.opacity(0.08), lineWidth: 1)

        )

    }

    private func filterButton(

        title: String,

        icon: String,

        filter: GamesFilter

    ) -> some View {

        let isSelected = selectedFilter == filter

        return Button {

            guard selectedFilter != filter else {

                return

            }

            filterMovesForward = filter.order > selectedFilter.order

            withAnimation(

                .spring(response: 0.42, dampingFraction: 0.82)

            ) {

                selectedFilter = filter

            }

        } label: {

            HStack(spacing: 6) {

                Image(systemName: icon)

                    .font(

                        .system(

                            size: 14,

                            weight: .semibold

                        )

                    )

                    .contentTransition(.symbolEffect(.replace))

                    .scaleEffect(isSelected ? 1.05 : 0.94)

                Text(title)

                    .font(

                        .system(

                            size: 13,

                            weight: .semibold

                        )

                    )

                    .scaleEffect(isSelected ? 1 : 0.97)

            }

            .foregroundStyle(

                isSelected

                    ? Color.white

                    : Color.white.opacity(0.5)

            )

            .frame(maxWidth: .infinity)

            .frame(height: 38)

            .background {

                if isSelected {

                    ZStack {

                        RoundedRectangle(cornerRadius: 13, style: .continuous)

                            .fill(

                                LinearGradient(

                                    colors: [

                                        Color(red: 0.06, green: 0.57, blue: 0.94),

                                        Color(red: 0.48, green: 0.28, blue: 0.98)

                                    ],

                                    startPoint: .topLeading,

                                    endPoint: .bottomTrailing

                                )

                            )

                            .shadow(

                                color: Color(red: 0.20, green: 0.50, blue: 1.0).opacity(0.26),

                                radius: 8,

                                y: 3

                            )

                        RoundedRectangle(cornerRadius: 13, style: .continuous)

                            .stroke(Color.white.opacity(0.18), lineWidth: 1)

                    }

                    .matchedGeometryEffect(

                        id: "selected-game-filter",

                        in: filterSelectionNamespace

                    )

                }

            }

            .animation(

                .spring(response: 0.36, dampingFraction: 0.76),

                value: isSelected

            )

        }

        .buttonStyle(.plain)

        .zIndex(isSelected ? 1 : 0)

    }

    @ViewBuilder

    private var filterContent: some View {

        if filteredGames.isEmpty {

            emptyFilterView

                .padding(.top, 70)

        } else {

            gamesList

        }

    }

    private var filterContentTransition: AnyTransition {

        let insertionEdge: Edge = filterMovesForward ? .trailing : .leading

        let removalEdge: Edge = filterMovesForward ? .leading : .trailing

        return .asymmetric(

            insertion: .move(edge: insertionEdge).combined(with: .opacity),

            removal: .move(edge: removalEdge).combined(with: .opacity)

        )

    }

    // MARK: - Games List

    private var gamesList: some View {

        LazyVStack(spacing: 0) {

            ForEach(

                Array(filteredGames.enumerated()),

                id: \.element.id

            ) { index, game in

                gameRow(game)

                if index < filteredGames.count - 1 {

                    Divider()

                        .overlay(

                            Color.white.opacity(0.07)

                        )

                        .padding(.leading, 82)

                        .padding(.trailing, 16)

                }

            }

        }

    }

    private func gameRow(_ game: Game) -> some View {

        HStack(spacing: 8) {

            Group {

                if purchaseManager.isUnlocked(game) {

                    NavigationLink(value: game) {

                        gameMainContent(game)

                    }

                } else {

                    Button {

                        selectedGameForPurchase = game

                    } label: {

                        gameMainContent(game)

                    }

                }

            }

            .buttonStyle(.plain)

            Button {

                toggleFavorite(game)

            } label: {

                Image(

                    systemName: isFavorite(game)

                        ? "heart.fill"

                        : "heart"

                )

                .font(

                    .system(

                        size: 19,

                        weight: .medium

                    )

                )

                .foregroundStyle(

                    isFavorite(game)

                        ? Color(

                            red: 0.35,

                            green: 0.66,

                            blue: 1.00

                        )

                        : Color.white.opacity(0.45)

                )

                .frame(width: 36, height: 36)

                .contentShape(Rectangle())

            }

            .buttonStyle(.plain)

            .accessibilityLabel(

                isFavorite(game)

                    ? "Remove from liked games"

                    : "Add to liked games"

            )

            accessIndicator(for: game)

        }

        .padding(.leading, 16)

        .padding(.trailing, 14)

        .padding(.vertical, 8)

    }

    private func gameMainContent(_ game: Game) -> some View {

        HStack(spacing: 12) {

            GameIconView(

                game: game,

                size: 54,

                cornerRadius: 15,

                symbolSize: 22

            )

            VStack(

                alignment: .leading,

                spacing: 4

            ) {

                HStack(spacing: 7) {

                    Text(game.title)

                        .font(

                            .system(

                                size: 17,

                                weight: .semibold

                            )

                        )

                        .foregroundStyle(.white)

                        .lineLimit(1)

                    if let badge = game.badge {

                        gameBadge(badge, color: game.accentColor)

                    }

                }

                Text(playerText(for: game))

                    .font(.system(size: 13))

                    .foregroundStyle(

                        Color.white.opacity(0.5)

                    )

            }

            Spacer()

        }

        .contentShape(Rectangle())

    }

    private func gameBadge(

        _ badge: GameBadge,

        color: Color

    ) -> some View {

        Text(badge.rawValue)

            .font(.system(size: 9, weight: .black, design: .rounded))

            .tracking(0.7)

            .foregroundStyle(color)

            .padding(.horizontal, 7)

            .frame(height: 19)

            .background(

                Capsule()

                    .fill(color.opacity(0.13))

            )

            .overlay(

                Capsule()

                    .stroke(color.opacity(0.38), lineWidth: 1)

            )

            .fixedSize()

    }

    @ViewBuilder

    private func accessIndicator(

        for game: Game

    ) -> some View {

        if purchaseManager.isUnlocked(game) {

            Image(systemName: "chevron.right")

                .font(

                    .system(

                        size: 15,

                        weight: .semibold

                    )

                )

                .foregroundStyle(

                    Color.white.opacity(0.3)

                )

        } else {

            VStack(

                alignment: .trailing,

                spacing: 4

            ) {

                if let price =

                    purchaseManager.displayPrice(for: game) {

                    Text(price)

                        .font(

                            .system(

                                size: 12,

                                weight: .semibold

                            )

                        )

                        .foregroundStyle(

                            Color.white.opacity(0.62)

                        )

                }

                Image(systemName: "lock.fill")

                    .font(

                        .system(

                            size: 13,

                            weight: .semibold

                        )

                    )

                    .foregroundStyle(

                        Color.white.opacity(0.34)

                    )

            }

            .frame(

                minWidth: 34,

                alignment: .trailing

            )

        }

    }

    // MARK: - Game Metadata

    private func playerText(
        for game: Game
    ) -> String {
        game.playerCountText
    }

    // MARK: - Favorites

    private var filteredGames: [Game] {

        let games: [Game]

        switch selectedFilter {

        case .all:

            games = Game.all

        case .popular:

            games = Game.all.filter(\.isPopular)

        case .liked:

            games = Game.all.filter { game in

                isFavorite(game)

            }

        }

        return games.sorted { firstGame, secondGame in

            let firstIsNew = firstGame.badge == .new

            let secondIsNew = secondGame.badge == .new

            if firstIsNew != secondIsNew {

                return firstIsNew

            }

            // Alphabetical order inside the NEW and regular groups.

            return firstGame.title

                .localizedCaseInsensitiveCompare(

                    secondGame.title

                ) == .orderedAscending

        }

    }

    private func isFavorite(

        _ game: Game

    ) -> Bool {

        favoriteGameIDs.wrappedValue.contains(

            gameKey(for: game)

        )

    }

    private func toggleFavorite(

        _ game: Game

    ) {

        var updatedIDs = favoriteGameIDs.wrappedValue

        let key = gameKey(for: game)

        withAnimation(

            .easeInOut(duration: 0.18)

        ) {

            if updatedIDs.contains(key) {

                updatedIDs.remove(key)

            } else {

                updatedIDs.insert(key)

            }

            favoriteGameIDs.wrappedValue = updatedIDs

        }

    }

    private func gameKey(

        for game: Game

    ) -> String {

        String(describing: game.id)

    }

    // MARK: - Empty Filter

    private var emptyFilterView: some View {

        VStack(spacing: 14) {

            Image(systemName: selectedFilter == .popular ? "flame" : "heart.slash")

                .font(

                    .system(

                        size: 38,

                        weight: .light

                    )

                )

                .foregroundStyle(

                    LinearGradient(

                        colors: [

                            .cyan,

                            .purple

                        ],

                        startPoint: .topLeading,

                        endPoint: .bottomTrailing

                    )

                )

            Text(selectedFilter == .popular ? "No popular games yet" : "No liked games")

                .font(

                    .system(

                        size: 20,

                        weight: .semibold

                    )

                )

                .foregroundStyle(.white)

            Text(selectedFilter == .popular
                 ? "Games selected for this collection\nwill appear here."
                 : "Tap the heart next to a game\nto find it here.")

            .font(.system(size: 15))

            .foregroundStyle(

                Color.white.opacity(0.5)

            )

            .multilineTextAlignment(.center)

            Button {

                withAnimation(

                    .easeInOut(duration: 0.2)

                ) {

                    selectedFilter = .all

                }

            } label: {

                Text("View all games")

                    .font(

                        .system(

                            size: 15,

                            weight: .semibold

                        )

                    )

                    .foregroundStyle(

                        Color(

                            red: 0.35,

                            green: 0.66,

                            blue: 1.00

                        )

                    )

            }

            .buttonStyle(.plain)

            .padding(.top, 4)

        }

        .frame(maxWidth: .infinity)

    }

    // MARK: - Background

    private var appBackground: some View {

        LinearGradient(

            colors: [

                Color(

                    red: 11.0 / 255.0,

                    green: 15.0 / 255.0,

                    blue: 21.0 / 255.0

                ),

                Color(

                    red: 7.0 / 255.0,

                    green: 16.0 / 255.0,

                    blue: 24.0 / 255.0

                )

            ],

            startPoint: .top,

            endPoint: .bottom

        )

        .ignoresSafeArea()

    }

}

private enum GamesFilter {

    case all

    case popular

    case liked

    var order: Int {

        switch self {

        case .popular:

            return 0

        case .liked:

            return 1

        case .all:

            return 2

        }

    }

}

#Preview {

    GamesListView()

        .withPlayerNameStorage()

        .environmentObject(PurchaseManager())

        .environmentObject(NearbyPermissionsManager())

        .environmentObject(AppUpdateManager())

}
