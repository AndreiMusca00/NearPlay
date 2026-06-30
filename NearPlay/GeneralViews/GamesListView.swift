import SwiftUI

struct GamesListView: View {
    @Environment(\._playerNameBinding) private var playerName: Binding<String>
    @State private var isEditingName = false

    private let games: [String] = [
        "Tic-Tac-Toe",
        "Backgammon",
        "Minesweeper",
        "Snake"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(games, id: \.self) { title in
                        NavigationLink(value: title) {
                            HStack {
                                Image(systemName: icon(for: title))
                                    
                                Text(title)
                            }
                        }
                    }
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
            }
            .navigationTitle("Offline Games")
            .navigationDestination(for: String.self) { title in
                PlaceholderGameView(title: title)
            }
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
