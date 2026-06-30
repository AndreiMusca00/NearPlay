import SwiftUI

struct GamesListView: View {
    @Environment(\._playerNameBinding) private var playerName: Binding<String>
    @State private var isEditingName = false

    var body: some View {
        NavigationStack {
            List {
                // Header with player name and edit button
                Section {
                    EmptyView()
                } header: {
                    HStack(spacing: 8) {
                        Text("Player:")
                            .foregroundStyle(.secondary)
                        Text(playerName.wrappedValue.isEmpty ? "—" : playerName.wrappedValue)
                            .bold()
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Button("Edit") { isEditingName = true }
                            .buttonStyle(.borderless)
                    }
                }

                // Games list
                Section {
                    ForEach(Game.all) { game in
                        NavigationLink(value: game) {
                            VStack(alignment: .leading) {
                                Text(game.title).font(.headline)
                                Text("Players: \(game.minPlayers)-\(game.maxPlayers)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: Game.self) { game in
                GameLobbyView(game: game)
            }
            .navigationTitle("NearPlay")
            .sheet(isPresented: $isEditingName) {
                EditNameSheet(name: playerName)
                    .presentationDetents([.medium])
            }
        }
    }

    private func icon(for title: String) -> String {
        switch title {
        case "Tic-Tac-Toe": return "grid"
        case "Backgammon": return "die.face.5"
        case "Minesweeper": return "flag"
        case "Snake": return "point.topleft.down.curvedto.point.bottomright.up"
        default: return "gamecontroller"
        }
    }
}

private struct PlaceholderGameView: View {
    let title: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title).bold()
            Text("This game will be implemented soon.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    GamesListView().withPlayerNameStorage()
}
