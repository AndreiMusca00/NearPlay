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

private struct EditNameSheet: View {
    @Binding var name: String
    @State private var working: String = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    init(name: Binding<String>) {
        self._name = name
        self._working = State(initialValue: name.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Player Name")) {
                    TextField("Name", text: $working)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .focused($focused)
                }
            }
            .navigationTitle("Edit Name")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!isValid)
                }
            }
            .onAppear { focused = true }
        }
    }

    private var isValid: Bool { !working.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private func save() {
        name = working.trimmingCharacters(in: .whitespacesAndNewlines)
        dismiss()
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
