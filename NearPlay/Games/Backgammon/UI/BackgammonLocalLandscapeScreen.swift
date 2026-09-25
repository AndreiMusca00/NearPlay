import SwiftUI

/// Shared landscape presentation. `boardPerspective` controls only how the
/// canonical board is displayed; it never changes game state or move indices.
struct BackgammonLocalLandscapeScreen: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State private var tableDice: [Int] = []
    @State private var diceAreVisible = false
    @State private var diceAreDocked = false
    @State private var diceLandingOffsets: [CGSize] = [.zero, .zero]
    @State private var diceAnimationID = UUID()

    let gameTitle: String
    let state: BackgammonGameState

    let playerOneID: String
    let playerOneName: String
    let playerTwoID: String
    let playerTwoName: String

    var boardPerspective: BackgammonBoardPerspective = .samePhone

    let selectedSource: BackgammonSelectedSource?
    let legalMoves: [BackgammonMove]
    let moveOptions: [BackgammonMoveOption]
    let interactionPlayer: BackgammonPlayer?
    let isInteractionEnabled: Bool
    let automaticMove: BackgammonMove?
    let onAutomaticMoveFinished: (BackgammonMove) -> Void
    let onDiceSettled: (UUID) -> Void

    let statusTitle: String
    let statusSubtitle: String

    let onRoll: () -> Void
    let onPointTap: (Int) -> Void
    let onBarTap: () -> Void
    let onMove: (_ source: Int?, _ destination: Int?) -> Void

    let canUndo: Bool
    let canReady: Bool
    let onUndo: () -> Void
    let onReady: () -> Void

    let onQuitRequested: () -> Void

    var body: some View {
        GeometryReader { geometry in
            // Equal physical margins, including the asymmetric home-indicator inset.
            let insets = geometry.safeAreaInsets
            let fullWidth = geometry.size.width + insets.leading + insets.trailing
            let fullHeight = geometry.size.height + insets.top + insets.bottom
            let boardWidth = max(1, fullWidth - 2 * (max(insets.leading, insets.trailing) + 3))
            let boardHeight = max(1, fullHeight - 2 * (max(insets.top, insets.bottom) + 3))

            ZStack {
                BackgammonTheme.background
                    .ignoresSafeArea()

                boardArea(
                    width: boardWidth,
                    height: boardHeight
                )
                .position(
                    x: geometry.size.width / 2 + (insets.trailing - insets.leading) / 2,
                    y: geometry.size.height / 2 + (insets.bottom - insets.top) / 2
                )

            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .onAppear {
            if !state.dice.isEmpty {
                tableDice = Array(state.dice.prefix(2))
                diceAreVisible = true
                diceAreDocked = true
            }
        }
        .onDisappear {
            diceAnimationID = UUID()
        }
        .onChange(of: state.dice) { newDice in
            handleDiceChange(newDice)
        }
    }

    // MARK: - Board

    private func boardArea(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        ZStack {
            BackgammonLocalBoardView(
                state: state,
                playerOneID: playerOneID,
                playerOneName: playerOneName,
                playerTwoID: playerTwoID,
                playerTwoName: playerTwoName,
                boardPerspective: boardPerspective,
                selectedSource: selectedSource,
                legalMoves: legalMoves,
                moveOptions: moveOptions,
                interactionPlayer: interactionPlayer,
                isInteractionEnabled: isInteractionEnabled,
                automaticMove: automaticMove,
                onAutomaticMoveFinished: onAutomaticMoveFinished,
                onPointTap: onPointTap,
                onBarTap: onBarTap,
                onMove: onMove
            )
            .frame(
                width: width,
                height: height
            )

            tableDiceLayer(
                width: width,
                height: height
            )
            .zIndex(20)

            centerControls
                .zIndex(30)

            Button(action: onQuitRequested) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 1, green: 0.91, blue: 0.73))
                    .frame(width: 36, height: 36)
                    .background {
                        Circle().fill(LinearGradient(
                            colors: [Color(red: 0.32, green: 0.22, blue: 0.16), .black.opacity(0.85)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                    }
                    .overlay {
                        Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quit game")
            .position(x: 30, y: 28)
            .zIndex(30)

        }
        .frame(
            width: width,
            height: height
        )
    }

    private var centerControls: some View {
        VStack(spacing: 6) {
            if state.hasRolled {
                // The animated dice settle into these two reserved slots.
                Color.clear
                    .frame(width: 36, height: 78)
                    .allowsHitTesting(false)

                Button(action: onReady) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(BackgammonWoodButtonStyle(isPrimary: true))
                .accessibilityLabel("Ready")
                .disabled(!canReady || !diceAreDocked)

                Button(action: onUndo) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(BackgammonWoodButtonStyle(isPrimary: false))
                .accessibilityLabel("Revert last move")
                .disabled(!canUndo || !diceAreDocked)
            } else {
                Circle()
                    .fill(activePlayerColor)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)

                Button(action: onRoll) {
                    BackgammonIvoryDie(value: 5)
                        .scaleEffect(0.65)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(BackgammonWoodButtonStyle(isPrimary: true))
                .disabled(!canRoll)
                .accessibilityLabel("Roll dice")
            }
        }
        .buttonStyle(.plain)
        .frame(width: 64)
        .accessibilityValue(statusSubtitle)
    }

    // MARK: - Dice Throw

    private func tableDiceLayer(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let viewerPlayerID = boardPerspective.viewerPlayer == .playerOne
            ? playerOneID
            : playerTwoID
        let localUserRolled =
            state.activePlayerID == viewerPlayerID

        // Per the Same Phone UX:
        // local user rolls into the left half,
        // Guest rolls into the right half.
        let landingCenterX =
            localUserRolled
                ? width * 0.34
                : width * 0.66

        let landingCenterY = height * 0.51

        return ZStack {
            ForEach(
                Array(tableDice.enumerated()),
                id: \.offset
            ) { index, value in
                let sideOffset: CGFloat =
                    index == 0 ? -24 : 24

                let variation =
                    diceLandingOffsets.indices.contains(index)
                        ? diceLandingOffsets[index]
                        : .zero

                BackgammonIvoryDie(
                    value: value,
                    isShaded: diceAreDocked && state.isDieShaded(at: index)
                )
                .scaleEffect(
                    diceAreVisible ? 1 : 0.58
                )
                .rotationEffect(
                    .degrees(
                        diceAreVisible
                            ? (diceAreDocked ? 0 : finalRotation(for: index))
                            : finalRotation(for: index) - 520
                    )
                )
                .rotation3DEffect(
                    .degrees(
                        diceAreVisible
                            ? 0
                            : (index == 0 ? 220 : -220)
                    ),
                    axis: (
                        x: 1,
                        y: index == 0 ? 0.7 : -0.7,
                        z: 0
                    ),
                    perspective: 0.55
                )
                .opacity(
                    diceAreVisible ? 1 : 0
                )
                .position(
                    x:
                        diceAreDocked
                            ? width / 2
                            : landingCenterX + sideOffset + variation.width,
                    y:
                        diceAreDocked
                            ? height / 2 - 71 + CGFloat(index) * 42
                            : landingCenterY + variation.height
                )
                .offset(
                    x:
                        diceAreVisible
                            ? 0
                            : (localUserRolled ? -34 : 34),
                    y:
                        diceAreVisible
                            ? 0
                            : -height * 0.34
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func finalRotation(
        for index: Int
    ) -> Double {
        index == 0 ? -9 : 13
    }

    private func handleDiceChange(
        _ newDice: [Int]
    ) {
        let animationID = UUID()
        let turnID = state.turnID
        diceAnimationID = animationID

        guard !newDice.isEmpty else {
            withAnimation(
                .easeOut(duration: 0.16)
            ) {
                diceAreVisible = false
            }

            Task { @MainActor in
                try? await Task.sleep(
                    nanoseconds: 180_000_000
                )

                guard diceAnimationID == animationID else {
                    return
                }

                tableDice = []
            }

            return
        }

        diceAreDocked = false
        let finalDice = Array(newDice.prefix(2))

        diceLandingOffsets = [
            CGSize(
                width: CGFloat.random(in: -9...5),
                height: CGFloat.random(in: -14...10)
            ),
            CGSize(
                width: CGFloat.random(in: -5...9),
                height: CGFloat.random(in: -8...15)
            )
        ]

        if reduceMotion {
            tableDice = finalDice
            diceAreVisible = true
            diceAreDocked = true
            onDiceSettled(turnID)
            return
        }

        // Start with changing faces while the dice are airborne.
        tableDice = [
            Int.random(in: 1...6),
            Int.random(in: 1...6)
        ]
        diceAreVisible = false

        Task { @MainActor in
            // Allow SwiftUI to commit the launch position first.
            await Task.yield()

            guard diceAnimationID == animationID else {
                return
            }

            withAnimation(
                .interpolatingSpring(
                    mass: 0.78,
                    stiffness: 118,
                    damping: 10.5,
                    initialVelocity: 5.2
                )
            ) {
                diceAreVisible = true
            }

            // Rapidly changing faces gives the impression of tumbling.
            for _ in 0..<4 {
                try? await Task.sleep(
                    nanoseconds: 85_000_000
                )

                guard diceAnimationID == animationID else {
                    return
                }

                tableDice = [
                    Int.random(in: 1...6),
                    Int.random(in: 1...6)
                ]
            }

            try? await Task.sleep(
                nanoseconds: 130_000_000
            )

            guard diceAnimationID == animationID else {
                return
            }

            withAnimation(
                .easeOut(duration: 0.12)
            ) {
                tableDice = finalDice
            }

            try? await Task.sleep(nanoseconds: 250_000_000)
            guard diceAnimationID == animationID else { return }

            withAnimation(.easeInOut(duration: 0.35), completionCriteria: .removed) {
                diceAreDocked = true
            } completion: {
                guard diceAnimationID == animationID else { return }
                onDiceSettled(turnID)
            }
        }
    }

    // MARK: - Dice / State

    private var activePlayerColor: Color {
        state.activePlayerID == playerOneID
            ? BackgammonTheme.cyan
            : BackgammonTheme.purple
    }

    private var canRoll: Bool {
        isInteractionEnabled &&
        !state.isFinished &&
        state.dice.isEmpty
    }

}

/// Ivory faces and recessed pips keep the dice legible against the dark wood.
private struct BackgammonIvoryDie: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Int
    var isShaded = false

    private var pipSlots: [Int] {
        switch value {
        case 1: return [4]
        case 2: return [0, 8]
        case 3: return [0, 4, 8]
        case 4: return [0, 2, 6, 8]
        case 5: return [0, 2, 4, 6, 8]
        default: return [0, 2, 3, 5, 6, 8]
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(red: 0.56, green: 0.55, blue: 0.51))
                .offset(y: 3)

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.98, green: 0.98, blue: 0.95),
                             Color(red: 0.79, green: 0.80, blue: 0.77)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(0.75), lineWidth: 1)
                        .padding(1)
                }

            ForEach(pipSlots, id: \.self) { slot in
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.12, green: 0.08, blue: 0.06),
                                 Color(red: 0.30, green: 0.22, blue: 0.16)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 5.5, height: 5.5)
                    .shadow(color: .white.opacity(0.8), radius: 0.3, y: 0.8)
                    .offset(x: CGFloat(slot % 3 - 1) * 9,
                            y: CGFloat(slot / 3 - 1) * 9)
            }
        }
        .frame(width: 36, height: 36)
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.black.opacity(isShaded ? 0.64 : 0))
                .allowsHitTesting(false)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isShaded)
        .shadow(color: .black.opacity(0.4), radius: 4, x: 1, y: 5)
        .accessibilityLabel("Die, \(value)")
        .accessibilityValue(isShaded ? "Shaded" : "Ivory")
    }
}

private struct BackgammonWoodButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        let gold = Color(red: 0.92, green: 0.69, blue: 0.34)
        let cream = Color(red: 1, green: 0.91, blue: 0.73)
        let dark = Color(red: 0.18, green: 0.11, blue: 0.075)

        configuration.label
            .foregroundStyle(isPrimary && isEnabled ? dark : cream.opacity(isEnabled ? 0.95 : 0.4))
            .background {
                Circle()
                    .fill(LinearGradient(
                        colors: isPrimary && isEnabled
                            ? [cream, gold]
                            : [Color(red: 0.29, green: 0.20, blue: 0.14), dark],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .shadow(color: .black.opacity(isEnabled ? 0.4 : 0.15),
                            radius: 2, y: configuration.isPressed ? 1 : 3)
            }
            .overlay {
                Circle()
                    .strokeBorder(LinearGradient(
                        colors: [cream.opacity(isEnabled ? 0.6 : 0.14), gold.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
