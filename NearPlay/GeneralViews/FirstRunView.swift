import SwiftUI

struct FirstRunView: View {
    @AppStorage(PlayerProfile.nameKey) private var storedName: String = ""
    @State private var name: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Welcome!")
                    .font(.largeTitle).bold()
                Text("Choose a player name to use in games. You can change it later from the main screen.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                TextField("Your name", text: $name)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)

                Button(action: saveName) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
            .navigationTitle("Set Name")
            .onAppear {
                name = storedName
                focused = true
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        storedName = trimmed
    }
}

#Preview {
    FirstRunView()
}
