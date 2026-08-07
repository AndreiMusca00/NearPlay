import SwiftUI

struct GamesListView: View {
    @Environment(\._playerNameBinding)
    private var playerName: Binding<String>

    @Environment(\._favoriteGameIDsBinding)
    private var favoriteGameIDs: Binding<Set<String>>

    @State private var isEditingName = false
    @State private var selectedFilter: GamesFilter = .all
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                appBackground

                ScrollView {
                    LazyVStack(spacing: 0) {
                        topHeader
                            .padding(.horizontal, 20)
                            .padding(.top, 12)

                        filterButtons
                            .padding(.horizontal, 20)
                            .padding(.top, 28)
                            .padding(.bottom, 16)

                        Divider()
                            .overlay(Color.white.opacity(0.08))
                            .padding(.horizontal, 20)

                        if filteredGames.isEmpty {
                            emptyFavoritesView
                                .padding(.top, 70)
                        } else {
                            gamesList
                        }
                    }
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Game.self) { game in
                GameEntryView(
                    game: game,
                    onExitToHome: {
                        navigationPath = NavigationPath()
                    }
                )
            }
            .sheet(isPresented: $isEditingName) {
                EditNameSheet(name: playerName)
                    .presentationDetents([.medium])
                    .preferredColorScheme(.dark)
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
                            size: 42,
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
                                    size: 17,
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
                Image(systemName: "gearshape.fill")
                    .font(
                        .system(
                            size: 21,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
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
        HStack(spacing: 14) {
            filterButton(
                title: "All Games",
                icon: "gamecontroller.fill",
                filter: .all
            )

            filterButton(
                title: "Liked",
                icon: selectedFilter == .liked
                    ? "heart.fill"
                    : "heart",
                filter: .liked
            )

            Spacer()
        }
    }

    private func filterButton(
        title: String,
        icon: String,
        filter: GamesFilter
    ) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            withAnimation(
                .easeInOut(duration: 0.2)
            ) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(
                        .system(
                            size: 17,
                            weight: .semibold
                        )
                    )

                Text(title)
                    .font(
                        .system(
                            size: 16,
                            weight: .semibold
                        )
                    )
            }
            .foregroundStyle(
                isSelected
                    ? Color(
                        red: 0.35,
                        green: 0.66,
                        blue: 1.00
                    )
                    : Color.white.opacity(0.5)
            )
            .padding(.horizontal, 18)
            .frame(height: 48)
            .background {
                if isSelected {
                    Capsule()
                        .fill(
                            Color(
                                red: 0.05,
                                green: 0.30,
                                blue: 0.50
                            )
                            .opacity(0.22)
                        )
                }
            }
            .overlay {
                if isSelected {
                    Capsule()
                        .stroke(
                            Color(
                                red: 0.20,
                                green: 0.58,
                                blue: 1.00
                            )
                            .opacity(0.45),
                            lineWidth: 1
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Games list

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
                        .padding(.leading, 98)
                        .padding(.trailing, 20)
                }
            }
        }
    }

    private func gameRow(_ game: Game) -> some View {
        HStack(spacing: 12) {
            NavigationLink(value: game) {
                HStack(spacing: 14) {
                    gameIcon(for: game)

                    VStack(
                        alignment: .leading,
                        spacing: 6
                    ) {
                        Text(game.title)
                            .font(
                                .system(
                                    size: 19,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(playerText(for: game))
                            .font(.system(size: 15))
                            .foregroundStyle(
                                Color.white.opacity(0.5)
                            )
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
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
                        size: 22,
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
                .frame(width: 42, height: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isFavorite(game)
                    ? "Remove from liked games"
                    : "Add to liked games"
            )

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
        }
        .padding(.leading, 20)
        .padding(.trailing, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Game icon

    private func gameIcon(
        for game: Game
    ) -> some View {
        let color = iconColor(for: game.title)

        return Image(
            systemName: icon(for: game.title)
        )
        .font(
            .system(
                size: 25,
                weight: .semibold
            )
        )
        .foregroundStyle(color)
        .frame(width: 64, height: 64)
        .background {
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .fill(color.opacity(0.09))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .stroke(
                color.opacity(0.25),
                lineWidth: 1
            )
        }
    }

    private func icon(
        for title: String
    ) -> String {
        switch title {
        case "Tic-Tac-Toe":
            return "grid"

        case "Connect Four":
            return "circle.grid.3x3.fill"

        case "Rock Paper Scissors":
            return "hand.raised.fill"

        case "Backgammon":
            return "die.face.5.fill"

        case "Minesweeper":
            return "flag.fill"

        case "Snake":
            return "point.topleft.down.curvedto.point.bottomright.up"

        default:
            return "gamecontroller.fill"
        }
    }

    private func iconColor(
        for title: String
    ) -> Color {
        switch title {
        case "Tic-Tac-Toe":
            return .cyan

        case "Connect Four":
            return .yellow

        case "Rock Paper Scissors":
            return .purple

        case "Backgammon":
            return .red

        case "Minesweeper":
            return .green

        case "Snake":
            return Color(
                red: 0.25,
                green: 0.95,
                blue: 0.25
            )

        default:
            return .blue
        }
    }

    private func playerText(
        for game: Game
    ) -> String {
        if game.minPlayers == game.maxPlayers {
            if game.minPlayers == 1 {
                return "1 player"
            }

            return "\(game.minPlayers) players"
        }

        return "\(game.minPlayers)–\(game.maxPlayers) players"
    }

    // MARK: - Favorites

    private var filteredGames: [Game] {
        switch selectedFilter {
        case .all:
            return Game.all

        case .liked:
            return Game.all.filter { game in
                isFavorite(game)
            }
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

    // MARK: - Empty favorites

    private var emptyFavoritesView: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.slash")
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

            Text("No liked games")
                .font(
                    .system(
                        size: 20,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)

            Text(
                "Tap the heart next to a game\nto find it here."
            )
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
    case liked
}

#Preview {
    GamesListView()
        .withPlayerNameStorage()
}
