import SwiftUI

struct EditNameSheet: View {

    @Binding var name: String

    @State private var working: String

    @Environment(\.dismiss)
    private var dismiss

    @FocusState
    private var focused: Bool

    private let maxNameLength = 10

    init(name: Binding<String>) {
        self._name = name
        self._working = State(
            initialValue: String(
                name.wrappedValue.prefix(10)
            )
        )
    }

    var body: some View {

        NavigationStack {

            ZStack {

                appBackground

                VStack(spacing: 24) {

                    // MARK: - Header

                    VStack(spacing: 10) {

                        ZStack {

                            Circle()
                                .fill(
                                    Color.white.opacity(0.05)
                                )
                                .frame(
                                    width: 72,
                                    height: 72
                                )

                            Image(
                                systemName: "person.fill"
                            )
                            .font(
                                .system(
                                    size: 28,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(
                                brandGradient
                            )
                        }

                        Text("Player Name")
                            .font(
                                .system(
                                    size: 24,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(.white)

                        Text(
                            "This is the name other nearby players will see."
                        )
                        .font(
                            .system(
                                size: 14,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(
                            Color.white.opacity(0.48)
                        )
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    }

                    // MARK: - Input Card

                    VStack(
                        alignment: .leading,
                        spacing: 12
                    ) {

                        Text("PLAYER NAME")
                            .font(
                                .system(
                                    size: 12,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(
                                Color.white.opacity(0.38)
                            )
                            .tracking(0.8)

                        HStack(spacing: 12) {

                            Image(
                                systemName: "person.crop.circle.fill"
                            )
                            .font(
                                .system(
                                    size: 18,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(
                                Color.white.opacity(0.42)
                            )

                            TextField(
                                "Your name",
                                text: $working
                            )
                            .font(
                                .system(
                                    size: 17,
                                    weight: .medium
                                )
                            )
                            .foregroundStyle(.white)
                            .tint(
                                Color(
                                    red: 0.35,
                                    green: 0.66,
                                    blue: 1.0
                                )
                            )
                            .textInputAutocapitalization(
                                .words
                            )
                            .disableAutocorrection(true)
                            .focused($focused)
                            .submitLabel(.done)
                            .onSubmit {
                                if isValid {
                                    save()
                                }
                            }
                            .onChange(
                                of: working
                            ) { _, newValue in

                                if newValue.count >
                                    maxNameLength {

                                    working = String(
                                        newValue.prefix(
                                            maxNameLength
                                        )
                                    )
                                }
                            }

                            if !working.isEmpty {

                                Button {
                                    working = ""
                                    focused = true
                                } label: {

                                    Image(
                                        systemName:
                                            "xmark.circle.fill"
                                    )
                                    .font(
                                        .system(
                                            size: 18
                                        )
                                    )
                                    .foregroundStyle(
                                        Color.white.opacity(
                                            0.25
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background {

                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                            .fill(
                                Color.white.opacity(
                                    0.055
                                )
                            )
                        }
                        .overlay {

                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                            .stroke(
                                focused
                                    ? Color(
                                        red: 0.35,
                                        green: 0.58,
                                        blue: 1.0
                                    )
                                    .opacity(0.7)
                                    : Color.white.opacity(
                                        0.10
                                    ),
                                lineWidth: 1
                            )
                        }

                        HStack {

                            Text(
                                "Maximum \(maxNameLength) characters"
                            )
                            .font(
                                .system(
                                    size: 12,
                                    weight: .medium
                                )
                            )
                            .foregroundStyle(
                                Color.white.opacity(0.30)
                            )

                            Spacer()

                            Text(
                                "\(working.count) / \(maxNameLength)"
                            )
                            .font(
                                .system(
                                    size: 12,
                                    weight: .semibold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(
                                working.count ==
                                    maxNameLength
                                    ? Color.white.opacity(
                                        0.75
                                    )
                                    : Color.white.opacity(
                                        0.32
                                    )
                            )
                        }
                    }
                    .padding(20)
                    .background {

                        RoundedRectangle(
                            cornerRadius: 24,
                            style: .continuous
                        )
                        .fill(
                            Color.white.opacity(0.035)
                        )
                    }
                    .overlay {

                        RoundedRectangle(
                            cornerRadius: 24,
                            style: .continuous
                        )
                        .stroke(
                            Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .padding(.top, 28)
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)

            // MARK: - Toolbar

            .toolbar {

                ToolbarItem(
                    placement: .cancellationAction
                ) {

                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(
                        Color.white.opacity(0.72)
                    )
                }

                ToolbarItem(
                    placement: .confirmationAction
                ) {

                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }

            .onAppear {

                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 0.25
                ) {
                    focused = true
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Validation

    private var isValid: Bool {

        !working
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
    }

    // MARK: - Save

    private func save() {

        let trimmed = working
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmed.isEmpty else {
            return
        }

        name = String(
            trimmed.prefix(maxNameLength)
        )

        dismiss()
    }

    // MARK: - Styling

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

    private var brandGradient: LinearGradient {

        LinearGradient(
            colors: [
                Color(
                    red: 0.05,
                    green: 0.72,
                    blue: 1.0
                ),
                Color(
                    red: 0.35,
                    green: 0.40,
                    blue: 1.0
                ),
                Color(
                    red: 0.66,
                    green: 0.25,
                    blue: 1.0
                )
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

#Preview {

    EditNameSheet(
        name: .constant("Player")
    )
}
