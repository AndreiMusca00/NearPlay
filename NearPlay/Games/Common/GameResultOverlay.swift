import SwiftUI

/// Overlay comun pentru rezultatul unei runde NearPlay.
/// Jocul furnizează rezultatul, textele și simbolul; componenta controlează
/// layout-ul, designul și stările comune de rematch.
struct GameResultOverlay: View {
    let result: GameRoundResult
    let title: String
    let subtitle: String
    let symbolName: String
    let accentColor: Color
    let rematchState: RematchState
    let onPrimaryAction: () -> Void
    let onQuit: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.68)
                    .ignoresSafeArea()

                if geometry.size.width > geometry.size.height {
                    landscapeCard
                        .frame(maxWidth: 720)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 20)
                } else {
                    portraitCard
                        .frame(maxWidth: 430)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 30)
                }
            }
        }
        .transition(
            .opacity.combined(
                with: .scale(scale: 0.95)
            )
        )
        .animation(
            .spring(
                response: 0.38,
                dampingFraction: 0.84
            ),
            value: rematchState
        )
    }

    private var portraitCard: some View {
        VStack(spacing: 22) {
            closeRow
            resultVisual
            resultText
            rematchInformation
            actionButtons
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .resultCardStyle(accentColor: accentColor)
    }

    private var landscapeCard: some View {
        HStack(spacing: 28) {
            VStack(spacing: 15) {
                resultVisual
                resultText
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 18) {
                HStack {
                    Spacer()
                    quitIconButton
                }

                rematchInformation
                actionButtons
            }
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .resultCardStyle(accentColor: accentColor)
    }

    private var closeRow: some View {
        HStack {
            Spacer()
            quitIconButton
        }
        .frame(height: 22)
    }

    private var quitIconButton: some View {
        Button(action: onQuit) {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.68))
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.045))
                }
                .overlay {
                    Circle()
                        .stroke(
                            Color.white.opacity(0.10),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quit game")
    }

    private var resultVisual: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.12))
                .frame(width: 94, height: 94)

            Circle()
                .stroke(
                    accentColor.opacity(0.70),
                    lineWidth: 1.5
                )
                .frame(width: 94, height: 94)
                .shadow(
                    color: accentColor.opacity(0.56),
                    radius: 15
                )

            Image(systemName: symbolName)
                .font(
                    .system(
                        size: 42,
                        weight: result == .draw
                            ? .bold
                            : .semibold
                    )
                )
                .foregroundStyle(accentColor)
                .shadow(
                    color: accentColor.opacity(0.70),
                    radius: 9
                )
        }
    }

    private var resultText: some View {
        VStack(spacing: 7) {
            Text(title)
                .font(
                    .system(
                        size: 30,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.52))
                .multilineTextAlignment(.center)
        }
    }

    private var rematchInformation: some View {
        HStack(spacing: 13) {
            Image(systemName: rematchInformationIcon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(ResultOverlayTheme.primaryGradient)
                .frame(width: 42, height: 42)
                .background {
                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .fill(
                        ResultOverlayTheme.purple.opacity(0.10)
                    )
                }

            Text(rematchInformationText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.66))
                .multilineTextAlignment(.leading)
                .contentTransition(.interpolate)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(Color.black.opacity(0.16))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onQuit) {
                Text("Quit")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background {
                        RoundedRectangle(
                            cornerRadius: 18,
                            style: .continuous
                        )
                        .fill(Color.white.opacity(0.035))
                    }
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: 18,
                            style: .continuous
                        )
                        .stroke(
                            Color.white.opacity(0.16),
                            lineWidth: 1
                        )
                    }
            }
            .buttonStyle(.plain)

            Button(action: onPrimaryAction) {
                HStack(spacing: 9) {
                    if isPrimaryButtonBusy {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.85)
                    }

                    Text(primaryButtonTitle)
                        .contentTransition(.interpolate)
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background {
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .fill(
                        isPrimaryButtonBusy
                            ? ResultOverlayTheme.disabledGradient
                            : ResultOverlayTheme.primaryGradient
                    )
                }
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 18,
                        style: .continuous
                    )
                    .stroke(
                        Color.white.opacity(
                            isPrimaryButtonBusy ? 0.14 : 0.40
                        ),
                        lineWidth: 1
                    )
                }
                .shadow(
                    color: isPrimaryButtonBusy
                        ? .clear
                        : ResultOverlayTheme.blue.opacity(0.34),
                    radius: 12,
                    x: -3
                )
                .shadow(
                    color: isPrimaryButtonBusy
                        ? .clear
                        : ResultOverlayTheme.purple.opacity(0.34),
                    radius: 12,
                    x: 3
                )
            }
            .buttonStyle(.plain)
            .disabled(isPrimaryButtonBusy)
        }
    }

    private var primaryButtonTitle: String {
        switch rematchState {
        case .available:
            return "Play Again"
        case .waitingForOpponent:
            return "Waiting…"
        case .opponentRequested:
            return "Accept"
        case .starting:
            return "Starting…"
        }
    }

    private var isPrimaryButtonBusy: Bool {
        switch rematchState {
        case .waitingForOpponent, .starting:
            return true
        case .available, .opponentRequested:
            return false
        }
    }

    private var rematchInformationText: String {
        switch rematchState {
        case .available:
            return "Would you like to play another round?"

        case .waitingForOpponent:
            return "Waiting for your opponent to accept."

        case .opponentRequested(let playerName):
            return "\(playerName) wants to play another round."

        case .starting:
            return "Both players accepted. Starting the next round…"
        }
    }

    private var rematchInformationIcon: String {
        switch rematchState {
        case .available:
            return "arrow.clockwise"
        case .waitingForOpponent:
            return "clock.fill"
        case .opponentRequested:
            return "person.crop.circle.badge.checkmark"
        case .starting:
            return "bolt.fill"
        }
    }
}

private extension View {
    func resultCardStyle(
        accentColor: Color
    ) -> some View {
        self
            .background {
                RoundedRectangle(
                    cornerRadius: 30,
                    style: .continuous
                )
                .fill(ResultOverlayTheme.cardBackground)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 30,
                    style: .continuous
                )
                .stroke(
                    ResultOverlayTheme.primaryGradient,
                    lineWidth: 1.5
                )
            }
            .shadow(
                color: ResultOverlayTheme.blue.opacity(0.25),
                radius: 22,
                x: -5
            )
            .shadow(
                color: ResultOverlayTheme.purple.opacity(0.25),
                radius: 22,
                x: 5
            )
            .shadow(
                color: accentColor.opacity(0.10),
                radius: 28
            )
    }
}

private enum ResultOverlayTheme {
    static let blue = Color(
        red: 0.05,
        green: 0.70,
        blue: 1.00
    )

    static let purple = Color(
        red: 0.66,
        green: 0.25,
        blue: 1.00
    )

    static let primaryGradient = LinearGradient(
        colors: [
            blue,
            Color(red: 0.27, green: 0.36, blue: 1.00),
            purple
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let disabledGradient = LinearGradient(
        colors: [
            blue.opacity(0.46),
            purple.opacity(0.46)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cardBackground = LinearGradient(
        colors: [
            Color(
                red: 12.0 / 255.0,
                green: 20.0 / 255.0,
                blue: 35.0 / 255.0
            ),
            Color(
                red: 7.0 / 255.0,
                green: 13.0 / 255.0,
                blue: 25.0 / 255.0
            )
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
