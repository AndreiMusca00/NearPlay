import SwiftUI

struct EditNameSheet: View {
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

struct EditNameSheet_Previews: PreviewProvider {
    static var previews: some View {
        EditNameSheet(name: .constant("Player"))
    }
}
