import SwiftUI

struct FirstRunView: View {

    @AppStorage(PlayerProfile.nameKey)
    private var storedName: String = ""

    @State private var name: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            appBackground

            ScrollView {
                VStack(spacing: 0) {

                    Spacer()
                        .frame(height: 72)

                    // MARK: - Brand

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.045))
                            .frame(width: 88, height: 88)
                            .overlay {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.cyan.opacity(0.42),
                                                Color.purple.opacity(0.34)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            }

                        Image(systemName: "person.crop.circle.fill")
                            .font(
                                .system(
                                    size: 39,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(brandGradient)
                    }

                    Text("NearPlay")
                        .font(
                            .system(
                                size: 42,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(brandGradient)
                        .padding(.top, 22)

                    Text("Welcome 👋")
                        .font(
                            .system(
                                size: 24,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)
                        .padding(.top, 28)

                    Text(
                        "Choose the name other players will see when you play together."
                    )
                    .font(
                        .system(
                            size: 15,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.52)
                    )
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 34)
                    .padding(.top, 10)

                    // MARK: - Name Card

                    VStack(alignment: .leading, spacing: 12) {
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
                            Image(systemName: "person.fill")
                                .font(
                                    .system(
                                        size: 17,
                                        weight: .semibold
                                    )
                                )
                                .foregroundStyle(
                                    Color.white.opacity(0.46)
                                )

                            TextField(
                                "Your name",
                                text: $name
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
                                    blue: 1.00
                                )
                            )
                            .onChange(of: name) { _, newValue in
                                if newValue.count > 10 {
                                    name = String(newValue.prefix(10))
                                }
                            }
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .submitLabel(.continue)
                            .focused($focused)
                            .onSubmit {
                                if isValid {
                                    saveName()
                                }
                            }

                            if !name.isEmpty {
                                Button {
                                    name = ""
                                    focused = true
                                } label: {
                                    Image(
                                        systemName: "xmark.circle.fill"
                                    )
                                    .font(.system(size: 18))
                                    .foregroundStyle(
                                        Color.white.opacity(0.26)
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
                                Color.white.opacity(0.055)
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
                                        blue: 1.00
                                    ).opacity(0.65)
                                    : Color.white.opacity(0.10),
                                lineWidth: 1
                            )
                        }

                        Text(
                            "You can change this later from the main screen."
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
                    }
                    .padding(20)
                    .background {
                        RoundedRectangle(
                            cornerRadius: 24,
                            style: .continuous
                        )
                        .fill(Color.white.opacity(0.035))
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
                    .padding(.top, 32)

                    // MARK: - Continue

                    Button(action: saveName) {
                        HStack(spacing: 10) {
                            Text("Continue")
                                .font(
                                    .system(
                                        size: 17,
                                        weight: .bold
                                    )
                                )

                            Image(
                                systemName: "arrow.right"
                            )
                            .font(
                                .system(
                                    size: 15,
                                    weight: .bold
                                )
                            )
                        }
                        .foregroundStyle(.white)
                        .frame(
                            maxWidth: .infinity
                        )
                        .frame(height: 56)
                        .background {
                            RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                            .fill(
                                isValid
                                    ? brandGradient
                                    : LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.08),
                                            Color.white.opacity(0.08)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                            )
                        }
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: 18,
                                style: .continuous
                            )
                            .stroke(
                                Color.white.opacity(
                                    isValid ? 0.12 : 0.06
                                ),
                                lineWidth: 1
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!isValid)
                    .padding(.horizontal, 20)
                    .padding(.top, 22)

                    Spacer()
                        .frame(height: 36)
                }
                .frame(maxWidth: 520)
                .frame(
                    maxWidth: .infinity
                )
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            name = storedName

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.35
            ) {
                focused = true
            }
        }
    }

    // MARK: - State

    private var isValid: Bool {
        !name
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .isEmpty
    }

    // MARK: - Actions

    private func saveName() {
        let trimmed = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return
        }

        storedName = trimmed
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
    }
}

#Preview {
    FirstRunView()
        .preferredColorScheme(.dark)
}
