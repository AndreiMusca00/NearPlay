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

    @State private var isLifetimePassPresented = false

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
                        VStack(spacing: 10) {
                            if shouldShowBundleOffer {
                                bundleOfferBanner
                                    .padding(.horizontal, 16)
                                    .padding(.top, 10)
                            }

                            ZStack(alignment: .top) {
                                filterContent
                                    .id(selectedFilter)
                                    .transition(filterContentTransition)
                            }
                            .frame(maxWidth: .infinity)
                        }
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

                if game.supportedModes == [.nearby] {

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

            .sheet(isPresented: $isLifetimePassPresented) {
                AllGamesBundlePurchaseSheet()
                    .environmentObject(purchaseManager)
                    .presentationDetents([.large])
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

    // MARK: - Premium Bundle

    private var shouldShowBundleOffer: Bool {
        !purchaseManager.ownsLifetimePass &&
        purchaseManager.lifetimePassProduct != nil
    }

    private var bundleOfferBanner: some View {
        Button {
            isLifetimePassPresented = true
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.white.opacity(0.095))
                        .frame(width: 52, height: 52)

                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        .frame(width: 52, height: 52)

                    Image(systemName: "infinity")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .white, .pink.opacity(0.92)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text("LIFETIME PASS")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(Color.cyan.opacity(0.95))

                        Text("ONE PAYMENT")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .frame(height: 17)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }

                    Text("All games now + future releases")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(purchaseManager.lifetimePassDisplayPrice ?? "")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.52))
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.025, green: 0.38, blue: 0.68),
                        Color(red: 0.38, green: 0.16, blue: 0.78),
                        Color(red: 0.68, green: 0.16, blue: 0.62)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.purple.opacity(0.28), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .top).combined(with: .opacity))
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

        LazyVGrid(

            columns: [

                GridItem(.flexible(), spacing: 11),

                GridItem(.flexible(), spacing: 11)

            ],

            spacing: 11

        ) {

            ForEach(filteredGames) { game in

                compactGameCard(game)

            }

        }

        .padding(.horizontal, 16)

        .padding(.top, 14)

    }

    private func compactGameCard(_ game: Game) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if purchaseManager.isUnlocked(game) {
                    NavigationLink(value: game) {
                        compactGameCardContent(game)
                    }
                } else {
                    Button {
                        selectedGameForPurchase = game
                    } label: {
                        compactGameCardContent(game)
                    }
                }
            }
            .buttonStyle(.plain)

            compactFavoriteButton(game)
                .padding(10)
        }
    }

    private func compactGameCardContent(
        _ game: Game
    ) -> some View {
        VStack(spacing: 13) {
            Spacer(minLength: 6)

            GameIconView(
                game: game,
                size: 72,
                cornerRadius: 21,
                symbolSize: 29
            )

            Text(game.title)
                .font(
                    .system(
                        size: 16,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)

            HStack(spacing: 6) {
                ForEach(orderedModes(for: game)) { mode in
                    compactModeBadge(
                        mode,
                        accent: game.accentColor
                    )
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 5)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 188)
        .background {
            compactCardBackground(game)
        }
        .contentShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
    }

    private func compactCardBackground(
        _ game: Game
    ) -> some View {
        RoundedRectangle(
            cornerRadius: 22,
            style: .continuous
        )
        .fill(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.065),
                    game.accentColor.opacity(0.065),
                    Color.white.opacity(0.022)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                LinearGradient(
                    colors: [
                        game.accentColor.opacity(0.34),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
        .shadow(
            color: game.accentColor.opacity(0.08),
            radius: 16,
            y: 8
        )
    }

    private func compactFavoriteButton(
        _ game: Game
    ) -> some View {
        Button {
            toggleFavorite(game)
        } label: {
            Image(
                systemName:
                    isFavorite(game)
                    ? "heart.fill"
                    : "heart"
            )
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(
                isFavorite(game)
                ? game.accentColor
                : Color.white.opacity(0.56)
            )
            .frame(width: 34, height: 34)
            .background {
                Circle()
                    .fill(Color.black.opacity(0.26))
            }
            .overlay {
                Circle()
                    .stroke(
                        isFavorite(game)
                        ? game.accentColor.opacity(0.46)
                        : Color.white.opacity(0.10),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isFavorite(game)
            ? "Remove from liked games"
            : "Add to liked games"
        )
    }

    private func orderedModes(
        for game: Game
    ) -> [GamePlayMode] {
        GamePlayMode.allCases.filter {
            game.supportedModes.contains($0)
        }
    }

    private func compactModeBadge(
        _ mode: GamePlayMode,
        accent: Color
    ) -> some View {
        Image(systemName: modeIcon(mode))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(accent)
            .frame(width: 27, height: 27)
            .background {
                Circle()
                    .fill(accent.opacity(0.11))
            }
            .overlay {
                Circle()
                    .stroke(accent.opacity(0.24), lineWidth: 1)
            }
            .accessibilityLabel(modeTitle(mode))
    }

    private func modeIcon(
        _ mode: GamePlayMode
    ) -> String {
        switch mode {
        case .nearby:
            return "antenna.radiowaves.left.and.right"
        case .local:
            return "person.2.fill"
        case .computer:
            return "cpu"
        }
    }

    private func modeTitle(
        _ mode: GamePlayMode
    ) -> String {
        switch mode {
        case .nearby:
            return "Nearby"
        case .local:
            return "Local"
        case .computer:
            return "CPU"
        }
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
