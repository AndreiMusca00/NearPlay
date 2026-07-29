//
//  GamesListView.swift
//  NearPlay
//

import SwiftUI
import UIKit

struct GamesListView: View {
    @Environment(\._playerNameBinding)
    private var playerName: Binding<String>

    @Environment(\._favoriteGameIDsBinding)
    private var favoriteGameIDs: Binding<Set<String>>

    @State private var isEditingName = false
    @State private var selectedFilter: GamesFilter = .all

    var body: some View {
        NavigationStack {
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
                GameLobbyView(game: game)
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
            withAnimation(.easeInOut(duration: 0.2)) {
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
                    GameArtworkView(game: game)

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

                        Text(game.playerCountText)
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

    private func isFavorite(_ game: Game) -> Bool {
        favoriteGameIDs.wrappedValue.contains(game.id)
    }

    private func toggleFavorite(_ game: Game) {
        var updatedIDs = favoriteGameIDs.wrappedValue

        withAnimation(.easeInOut(duration: 0.18)) {
            if updatedIDs.contains(game.id) {
                updatedIDs.remove(game.id)
            } else {
                updatedIDs.insert(game.id)
            }

            favoriteGameIDs.wrappedValue = updatedIDs
        }
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
                withAnimation(.easeInOut(duration: 0.2)) {
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

// MARK: - Game artwork

private struct GameArtworkView: View {
    let game: Game

    private var accentColor: Color {
        Color(hex: game.accentHex)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.18),
                        accentColor.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            if let uiImage = UIImage(named: game.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: game.fallbackSystemImage)
                    .font(
                        .system(
                            size: 27,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                accentColor,
                                accentColor.opacity(0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(14)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .stroke(
                accentColor.opacity(0.28),
                lineWidth: 1
            )
        }
    }
}

// MARK: - Filters

private enum GamesFilter {
    case all
    case liked
}

// MARK: - Hex colors

private extension Color {
    init(hex: String) {
        let cleanedHex = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )

        var hexValue: UInt64 = 0
        Scanner(string: cleanedHex).scanHexInt64(&hexValue)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch cleanedHex.count {
        case 3:
            red = Double((hexValue >> 8) * 17) / 255
            green = Double((hexValue >> 4 & 0xF) * 17) / 255
            blue = Double((hexValue & 0xF) * 17) / 255
            alpha = 1

        case 6:
            red = Double(hexValue >> 16) / 255
            green = Double(hexValue >> 8 & 0xFF) / 255
            blue = Double(hexValue & 0xFF) / 255
            alpha = 1

        case 8:
            red = Double(hexValue >> 24) / 255
            green = Double(hexValue >> 16 & 0xFF) / 255
            blue = Double(hexValue >> 8 & 0xFF) / 255
            alpha = Double(hexValue & 0xFF) / 255

        default:
            red = 0
            green = 0
            blue = 0
            alpha = 1
        }

        self.init(
            red: red,
            green: green,
            blue: blue,
            opacity: alpha
        )
    }
}

#Preview {
    GamesListView()
        .withPlayerNameStorage()
}
