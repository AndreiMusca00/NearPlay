import SwiftUI

enum GameTutorialPreference {
    static func dismissedVersionKey(
        for gameID: String
    ) -> String {
        "tutorial.\(gameID).dismissedVersion"
    }

    static func currentVersion(
        for gameID: String
    ) -> Int {
        1
    }

    static func isDismissed(
        for gameID: String
    ) -> Bool {
        UserDefaults.standard.integer(
            forKey: dismissedVersionKey(for: gameID)
        ) >= currentVersion(for: gameID)
    }

    static func dismiss(
        for gameID: String
    ) {
        UserDefaults.standard.set(
            currentVersion(for: gameID),
            forKey: dismissedVersionKey(for: gameID)
        )
    }
}

struct GameTutorialView: View {
    let game: Game
    let onDismiss: () -> Void
    let onNeverShowAgain: () -> Void

    var body: some View {
        if game.id == Game.ticTacToe.id {
            TicTacToeTutorialView(
                onDismiss: onDismiss,
                onNeverShowAgain: onNeverShowAgain
            )
        } else if let descriptor =
                    GameTutorialDescriptor.descriptor(for: game) {
            StandardGameTutorialView(
                game: game,
                descriptor: descriptor,
                onDismiss: onDismiss,
                onNeverShowAgain: onNeverShowAgain
            )
        }
    }
}

private struct GameTutorialPage {
    let title: String
    let subtitle: String
    let artwork: TutorialArtworkKind
}

private enum TutorialArtworkKind {
    case numberRush(Int)
    case battleship(Int)
    case connectFour(Int)
    case backgammon(Int)
    case dotsAndBoxes(Int)
    case ricochet(Int)
    case tiltRace(Int)
    case tapFrenzy(Int)
    case laserDuel(Int)
}

private struct GameTutorialDescriptor {
    let accent: Color
    let secondary: Color
    let pages: [GameTutorialPage]

    var gradient: LinearGradient {
        LinearGradient(
            colors: [accent, secondary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func descriptor(
        for game: Game
    ) -> GameTutorialDescriptor? {
        switch game.id {
        case Game.numberRush.id:
            return GameTutorialDescriptor(
                accent: Color(red: 0.05, green: 0.72, blue: 1.00),
                secondary: Color(red: 0.66, green: 0.25, blue: 1.00),
                pages: [
                    GameTutorialPage(
                        title: "Find the next number",
                        subtitle:
                            "Watch the target, then locate that number in the shuffled grid before your opponent does.",
                        artwork: .numberRush(0)
                    ),
                    GameTutorialPage(
                        title: "Beat the clock",
                        subtitle:
                            "A correct answer adds a little time. A wrong answer or an expired timer passes the turn.",
                        artwork: .numberRush(1)
                    ),
                    GameTutorialPage(
                        title: "Own the grid",
                        subtitle:
                            "Every correct number scores a point and keeps your color on the board. Highest score wins.",
                        artwork: .numberRush(2)
                    )
                ]
            )

        case Game.battleship.id:
            return GameTutorialDescriptor(
                accent: Color(red: 0.03, green: 0.78, blue: 1.00),
                secondary: Color(red: 0.66, green: 0.23, blue: 1.00),
                pages: [
                    GameTutorialPage(
                        title: "Deploy your fleet",
                        subtitle:
                            "Place every ship on your grid. Tap a placed ship to rotate it, then lock in your fleet.",
                        artwork: .battleship(0)
                    ),
                    GameTutorialPage(
                        title: "Choose a target",
                        subtitle:
                            "On your turn, tap one square on the enemy grid. Hits glow red; misses remain marked.",
                        artwork: .battleship(1)
                    ),
                    GameTutorialPage(
                        title: "Sink them all",
                        subtitle:
                            "Track your hits and uncover every section of every enemy ship to win the battle.",
                        artwork: .battleship(2)
                    )
                ]
            )

        case Game.connectFour.id:
            return GameTutorialDescriptor(
                accent: Color(red: 0.03, green: 0.78, blue: 1.00),
                secondary: Color(red: 0.66, green: 0.23, blue: 1.00),
                pages: [
                    GameTutorialPage(
                        title: "Drop a disc",
                        subtitle:
                            "Choose a column. Your disc falls into the lowest open space, then the turn changes.",
                        artwork: .connectFour(0)
                    ),
                    GameTutorialPage(
                        title: "Build and block",
                        subtitle:
                            "Grow your own line while watching for threats. One smart block can save the round.",
                        artwork: .connectFour(1)
                    ),
                    GameTutorialPage(
                        title: "Connect four",
                        subtitle:
                            "Make a line of four discs horizontally, vertically, or diagonally before your opponent.",
                        artwork: .connectFour(2)
                    )
                ]
            )

        case Game.backgammon.id:
            return GameTutorialDescriptor(
                accent: Color(red: 0.85, green: 0.64, blue: 0.37),
                secondary: Color(red: 0.49, green: 0.22, blue: 0.12),
                pages: [
                    GameTutorialPage(
                        title: "Roll and move",
                        subtitle:
                            "Move your checkers using each die. A double gives you four moves of the same value.",
                        artwork: .backgammon(0)
                    ),
                    GameTutorialPage(
                        title: "Hit and re-enter",
                        subtitle:
                            "Land on a lone enemy checker to send it to the bar. Bar checkers must re-enter first.",
                        artwork: .backgammon(1)
                    ),
                    GameTutorialPage(
                        title: "Race them home",
                        subtitle:
                            "Bring all your checkers into your home board, then bear every checker off to win.",
                        artwork: .backgammon(2)
                    )
                ]
            )

        case Game.dotsAndBoxes.id:
            return GameTutorialDescriptor(
                accent: Color(red: 0.08, green: 0.78, blue: 1.00),
                secondary: Color(red: 0.60, green: 0.27, blue: 1.00),
                pages: [
                    GameTutorialPage(
                        title: "Draw one edge",
                        subtitle:
                            "Connect two neighboring dots with one horizontal or vertical line on each turn.",
                        artwork: .dotsAndBoxes(0)
                    ),
                    GameTutorialPage(
                        title: "Close a box",
                        subtitle:
                            "Draw the fourth edge around a square to claim it in your color and score a point.",
                        artwork: .dotsAndBoxes(1)
                    ),
                    GameTutorialPage(
                        title: "Keep the turn",
                        subtitle:
                            "Completing a box lets you play again. Claim more boxes than your opponent to win.",
                        artwork: .dotsAndBoxes(2)
                    )
                ]
            )

        case Game.ricochet.id:
            return GameTutorialDescriptor(
                accent: Color(red: 0.15, green: 0.90, blue: 0.95),
                secondary: Color(red: 0.66, green: 0.25, blue: 1.00),
                pages: [
                    GameTutorialPage(
                        title: "Move your shield",
                        subtitle:
                            "Tilt the iPhone — or drag in Touch mode — to keep your shield under the incoming pulse.",
                        artwork: .ricochet(0)
                    ),
                    GameTutorialPage(
                        title: "Deflect the pulse",
                        subtitle:
                            "Meet the pulse with your shield to send it onto your opponent’s screen. Long rallies speed up.",
                        artwork: .ricochet(1)
                    ),
                    GameTutorialPage(
                        title: "Protect your link",
                        subtitle:
                            "If the pulse passes your shield, you lose a life. Create three breaches to win the match.",
                        artwork: .ricochet(2)
                    )
                ]
            )

        case Game.tiltRace.id:
            return GameTutorialDescriptor(
                accent: Color(red: 0.62, green: 1.00, blue: 0.18),
                secondary: Color(red: 0.07, green: 0.82, blue: 1.00),
                pages: [
                    GameTutorialPage(
                        title: "Tilt like a tray",
                        subtitle:
                            "Hold the iPhone flat and tilt it naturally. The glowing orb rolls in the direction you lean.",
                        artwork: .tiltRace(0)
                    ),
                    GameTutorialPage(
                        title: "Follow the numbers",
                        subtitle:
                            "Guide the orb into the glowing gate. Once you reach it, it disappears and the next numbered gate is revealed.",
                        artwork: .tiltRace(1)
                    ),
                    GameTutorialPage(
                        title: "Clear all ten",
                        subtitle:
                            "Race live on two iPhones, or take turns on the same track and compare times. First through gate ten — or the fastest time — wins.",
                        artwork: .tiltRace(2)
                    )
                ]
            )

        case Game.tapFrenzy.id:
            return GameTutorialDescriptor(
                accent: Color(red: 1.00, green: 0.27, blue: 0.52),
                secondary: Color(red: 0.12, green: 0.88, blue: 0.95),
                pages: [
                    GameTutorialPage(
                        title: "Tap in order",
                        subtitle:
                            "Five numbered targets appear together. Tap 1, 2, 3, 4, then 5 — a correct target disappears as you advance.",
                        artwork: .tapFrenzy(0)
                    ),
                    GameTutorialPage(
                        title: "Build a fast score",
                        subtitle:
                            "Every completed sequence gives 10 points plus a speed bonus. A target tapped out of order costs 2 points.",
                        artwork: .tapFrenzy(1)
                    ),
                    GameTutorialPage(
                        title: "Two ways to duel",
                        subtitle:
                            "Play live on two nearby iPhones, or take turns on one device. Both players receive the same target sequences; highest score wins.",
                        artwork: .tapFrenzy(2)
                    )
                ]
            )

        case Game.laserDuel.id:
            return GameTutorialDescriptor(
                accent: Color(red: 1.00, green: 0.21, blue: 0.37),
                secondary: Color(red: 0.52, green: 0.25, blue: 1.00),
                pages: [
                    GameTutorialPage(
                        title: "Line up your cannon",
                        subtitle:
                            "Tilt the iPhone — or use Touch mode — to slide your cannon and dodge incoming fire.",
                        artwork: .laserDuel(0)
                    ),
                    GameTutorialPage(
                        title: "Fire across screens",
                        subtitle:
                            "Tap FIRE when the weapon is ready. Your projectile travels directly onto the rival screen.",
                        artwork: .laserDuel(1)
                    ),
                    GameTutorialPage(
                        title: "Break their shields",
                        subtitle:
                            "Each player starts with three lives. Land three hits before your opponent does to win.",
                        artwork: .laserDuel(2)
                    )
                ]
            )

        default:
            return nil
        }
    }
}

private struct StandardGameTutorialView: View {
    let game: Game
    let descriptor: GameTutorialDescriptor
    let onDismiss: () -> Void
    let onNeverShowAgain: () -> Void

    @State
    private var selectedPage = 0

    @State
    private var isPulsing = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.043, green: 0.059, blue: 0.082),
                    Color(red: 0.027, green: 0.063, blue: 0.094)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(descriptor.accent.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -150, y: -300)

            Circle()
                .fill(descriptor.secondary.opacity(0.13))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 170, y: 310)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                TabView(selection: $selectedPage) {
                    ForEach(
                        Array(descriptor.pages.enumerated()),
                        id: \.offset
                    ) { index, page in
                        tutorialPage(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator
                    .padding(.top, 6)

                controls
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.9)
                .repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            GameIconView(
                game: game,
                size: 48,
                cornerRadius: 15,
                symbolSize: 23
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("HOW TO PLAY")
                    .font(
                        .system(
                            size: 11,
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .tracking(1.3)
                    .foregroundStyle(descriptor.accent)

                Text(game.title)
                    .font(
                        .system(
                            size: 22,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                    }
                    .overlay {
                        Circle()
                            .stroke(
                                Color.white.opacity(0.11),
                                lineWidth: 1
                            )
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close tutorial")
        }
    }

    private func tutorialPage(
        _ page: GameTutorialPage
    ) -> some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 560

            ScrollView {
                VStack(spacing: compact ? 16 : 24) {
                    Spacer(minLength: compact ? 8 : 22)

                    TutorialArtworkView(
                        kind: page.artwork,
                        accent: descriptor.accent,
                        secondary: descriptor.secondary,
                        isPulsing: isPulsing
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: compact ? 250 : 310
                    )

                    VStack(spacing: 9) {
                        Text(page.title)
                            .font(
                                .system(
                                    size: compact ? 25 : 29,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text(page.subtitle)
                            .font(
                                .system(
                                    size: 15,
                                    weight: .medium,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(
                                Color.white.opacity(0.58)
                            )
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: 350)
                    }

                    Spacer(minLength: 10)
                }
                .frame(
                    minHeight: geometry.size.height,
                    alignment: .center
                )
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 7) {
            ForEach(
                descriptor.pages.indices,
                id: \.self
            ) { index in
                Capsule()
                    .fill(
                        index == selectedPage
                        ? descriptor.accent
                        : Color.white.opacity(0.15)
                    )
                    .frame(
                        width: index == selectedPage ? 26 : 7,
                        height: 7
                    )
            }
        }
        .animation(
            .spring(response: 0.34, dampingFraction: 0.82),
            value: selectedPage
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Page \(selectedPage + 1) of \(descriptor.pages.count)"
        )
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Button {
                if selectedPage < descriptor.pages.count - 1 {
                    withAnimation(
                        .spring(
                            response: 0.38,
                            dampingFraction: 0.86
                        )
                    ) {
                        selectedPage += 1
                    }
                } else {
                    onDismiss()
                }
            } label: {
                HStack(spacing: 9) {
                    Text(
                        selectedPage == descriptor.pages.count - 1
                        ? "Start Playing"
                        : "Next"
                    )

                    Image(
                        systemName:
                            selectedPage == descriptor.pages.count - 1
                            ? "play.fill"
                            : "arrow.right"
                    )
                }
                .font(
                    .system(
                        size: 17,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background {
                    Capsule()
                        .fill(descriptor.gradient)
                }
                .shadow(
                    color: descriptor.accent.opacity(0.26),
                    radius: 16,
                    y: 8
                )
            }
            .buttonStyle(.plain)

            Button(action: onNeverShowAgain) {
                HStack(spacing: 7) {
                    Image(systemName: "eye.slash")
                    Text("Never Show Again")
                }
                .font(
                    .system(
                        size: 13,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(Color.white.opacity(0.48))
                .frame(height: 32)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct TutorialArtworkView: View {
    let kind: TutorialArtworkKind
    let accent: Color
    let secondary: Color
    let isPulsing: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: 30,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.047, green: 0.078, blue: 0.137),
                        Color(red: 0.027, green: 0.051, blue: 0.098)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            RoundedRectangle(
                cornerRadius: 30,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.09), lineWidth: 1)

            artwork
                .padding(22)
        }
        .frame(width: 292, height: 300)
        .shadow(color: Color.black.opacity(0.28), radius: 24, y: 14)
    }

    @ViewBuilder
    private var artwork: some View {
        switch kind {
        case .numberRush(let phase):
            NumberRushTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary,
                isPulsing: isPulsing
            )

        case .battleship(let phase):
            BattleshipTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary,
                isPulsing: isPulsing
            )

        case .connectFour(let phase):
            ConnectFourTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary,
                isPulsing: isPulsing
            )

        case .backgammon(let phase):
            BackgammonTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary,
                isPulsing: isPulsing
            )

        case .dotsAndBoxes(let phase):
            DotsAndBoxesTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary,
                isPulsing: isPulsing
            )

        case .ricochet(let phase):
            RicochetTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary,
                isPulsing: isPulsing
            )

        case .tiltRace(let phase):
            TiltRaceTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary,
                isPulsing: isPulsing
            )

        case .tapFrenzy(let phase):
            TapFrenzyTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary,
                isPulsing: isPulsing
            )

        case .laserDuel(let phase):
            LaserDuelTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary,
                isPulsing: isPulsing
            )
        }
    }
}

private struct NumberRushTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color
    let isPulsing: Bool

    private let values = [
        18, 3, 24, 7, 13,
        21, 9, 1, 16, 5,
        14, 22, 11, 2, 19,
        6, 17, 25, 10, 4,
        12, 8, 20, 15, 23
    ]

    var body: some View {
        if phase == 0 {
            VStack(spacing: 13) {
                Label("FIND 7", systemImage: "scope")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(accent)

                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.fixed(38), spacing: 6),
                        count: 5
                    ),
                    spacing: 6
                ) {
                    ForEach(values, id: \.self) { value in
                        Text("\(value)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        value == 7
                                        ? accent.opacity(0.22)
                                        : Color.white.opacity(0.045)
                                    )
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        value == 7
                                        ? accent
                                        : Color.white.opacity(0.08),
                                        lineWidth: value == 7 ? 2 : 1
                                    )
                            }
                            .scaleEffect(
                                value == 7 && isPulsing ? 1.08 : 1
                            )
                    }
                }
            }
        } else if phase == 1 {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(
                            accent,
                            style: StrokeStyle(
                                lineWidth: 14,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: accent.opacity(0.55), radius: 10)

                    VStack(spacing: 2) {
                        Text("3.6")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                        Text("SECONDS")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(1.3)
                            .foregroundStyle(.white.opacity(0.46))
                    }
                    .foregroundStyle(.white)
                }
                .frame(width: 148, height: 148)

                Label("CORRECT  +1 SEC", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(accent)
            }
        } else {
            VStack(spacing: 22) {
                HStack(spacing: 12) {
                    scoreCard(title: "YOU", score: 12, color: accent)
                    scoreCard(title: "RIVAL", score: 9, color: secondary)
                }

                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { index in
                        Circle()
                            .stroke(
                                index < 4 ? accent : secondary,
                                lineWidth: 3
                            )
                            .frame(width: 24, height: 24)
                            .shadow(
                                color: (index < 4 ? accent : secondary).opacity(0.55),
                                radius: 5
                            )
                    }
                }

                Label("EVERY NUMBER COUNTS", systemImage: "trophy.fill")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(accent)
            }
        }
    }

    private func scoreCard(
        title: String,
        score: Int,
        color: Color
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text("\(score)")
                .font(.system(size: 29, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 96, height: 76)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(color.opacity(0.11))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(color.opacity(0.52), lineWidth: 1)
        }
    }
}

private struct BattleshipTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color
    let isPulsing: Bool

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                battleGrid

                if phase == 0 {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accent, secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 108, height: 23)
                        .offset(x: -28, y: -54)

                    Capsule()
                        .fill(accent.opacity(0.82))
                        .frame(width: 74, height: 23)
                        .rotationEffect(.degrees(90))
                        .offset(x: 55, y: 35)
                } else {
                    ForEach(0..<5, id: \.self) { index in
                        let positions: [CGSize] = [
                            CGSize(width: -72, height: -70),
                            CGSize(width: 36, height: -36),
                            CGSize(width: 72, height: 0),
                            CGSize(width: -36, height: 36),
                            CGSize(width: 0, height: 72)
                        ]

                        Circle()
                            .fill(index < (phase == 1 ? 2 : 5) ? Color.red : Color.white.opacity(0.35))
                            .frame(width: 16, height: 16)
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
                            }
                            .shadow(
                                color: index < (phase == 1 ? 2 : 5)
                                    ? Color.red.opacity(0.8)
                                    : .clear,
                                radius: 7
                            )
                            .offset(positions[index])
                    }

                    if phase == 1 {
                        Image(systemName: "scope")
                            .font(.system(size: 52, weight: .medium))
                            .foregroundStyle(accent)
                            .shadow(color: accent.opacity(0.65), radius: 12)
                            .scaleEffect(isPulsing ? 1.06 : 0.94)
                    }
                }
            }
            .frame(width: 220, height: 220)

            Label(
                phase == 0
                    ? "PLACE & ROTATE"
                    : (phase == 1 ? "SELECT A SQUARE" : "FLEET DESTROYED"),
                systemImage:
                    phase == 0
                    ? "arrow.triangle.2.circlepath"
                    : (phase == 1 ? "scope" : "flame.fill")
            )
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(phase == 2 ? Color.red : accent)
        }
    }

    private var battleGrid: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.fixed(26), spacing: 4),
                count: 7
            ),
            spacing: 4
        ) {
            ForEach(0..<49, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(red: 0.05, green: 0.16, blue: 0.24))
                    .frame(width: 26, height: 26)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(accent.opacity(0.14), lineWidth: 0.7)
                    }
            }
        }
    }
}

private struct ConnectFourTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color
    let isPulsing: Bool

    private var cyanIndexes: Set<Int> {
        switch phase {
        case 0: return [35, 36, 37]
        case 1: return [28, 35, 36, 37]
        default: return [14, 22, 30, 38]
        }
    }

    private var purpleIndexes: Set<Int> {
        switch phase {
        case 0: return [38, 39]
        case 1: return [29, 38, 39]
        default: return [35, 36, 37]
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: phase == 0 ? "arrow.down" : "circle.grid.3x3.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(accent)
                .offset(x: phase == 0 ? -61 : 0)
                .scaleEffect(isPulsing && phase == 0 ? 1.12 : 1)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.fixed(26), spacing: 5),
                    count: 7
                ),
                spacing: 5
            ) {
                ForEach(0..<42, id: \.self) { index in
                    Circle()
                        .fill(discColor(for: index))
                        .frame(width: 26, height: 26)
                        .overlay {
                            Circle()
                                .stroke(
                                    winningIndexes.contains(index)
                                    ? Color.white.opacity(0.85)
                                    : Color.white.opacity(0.07),
                                    lineWidth:
                                        winningIndexes.contains(index)
                                        ? 2
                                        : 1
                                )
                        }
                        .shadow(
                            color:
                                winningIndexes.contains(index)
                                ? accent.opacity(0.75)
                                : .clear,
                            radius: 7
                        )
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.22),
                                secondary.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(
                phase == 0
                ? "CHOOSE A COLUMN"
                : (phase == 1 ? "WATCH THE THREAT" : "FOUR CONNECTED")
            )
            .font(.system(size: 11, weight: .black, design: .rounded))
            .tracking(1.1)
            .foregroundStyle(accent)
        }
    }

    private var winningIndexes: Set<Int> {
        phase == 2 ? cyanIndexes : []
    }

    private func discColor(
        for index: Int
    ) -> Color {
        if cyanIndexes.contains(index) {
            return accent
        }

        if purpleIndexes.contains(index) {
            return secondary
        }

        return Color.black.opacity(0.34)
    }
}

private struct BackgammonTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color
    let isPulsing: Bool

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(red: 0.24, green: 0.11, blue: 0.065))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(accent.opacity(0.55), lineWidth: 2)
                    }

                HStack(spacing: 5) {
                    ForEach(0..<8, id: \.self) { index in
                        VStack(spacing: 0) {
                            TriangleShape()
                                .fill(index.isMultiple(of: 2) ? accent.opacity(0.72) : secondary.opacity(0.75))
                            TriangleShape()
                                .fill(index.isMultiple(of: 2) ? secondary.opacity(0.75) : accent.opacity(0.72))
                                .rotationEffect(.degrees(180))
                        }
                    }
                }
                .padding(12)

                checkerStack

                if phase == 0 {
                    HStack(spacing: 9) {
                        die(5)
                        die(3)
                    }
                } else if phase == 1 {
                    VStack(spacing: 4) {
                        Text("BAR")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Circle()
                            .fill(.white)
                            .frame(width: 30, height: 30)
                            .overlay {
                                Circle().stroke(secondary, lineWidth: 3)
                            }
                    }
                    .scaleEffect(isPulsing ? 1.07 : 0.95)
                } else {
                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { _ in
                            Circle()
                                .fill(accent)
                                .frame(width: 25, height: 25)
                        }
                    }
                    .padding(8)
                    .background {
                        Capsule()
                            .fill(Color.black.opacity(0.45))
                    }
                    .offset(y: 72)
                }
            }
            .frame(width: 238, height: 196)

            Label(
                phase == 0
                ? "USE BOTH DICE"
                : (phase == 1 ? "RE-ENTER FIRST" : "BEAR THEM OFF"),
                systemImage:
                    phase == 0
                    ? "dice.fill"
                    : (phase == 1 ? "arrow.uturn.down" : "flag.checkered")
            )
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(accent)
        }
    }

    private var checkerStack: some View {
        HStack {
            VStack(spacing: -8) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(accent)
                        .frame(width: 27, height: 27)
                        .overlay {
                            Circle().stroke(.white.opacity(0.35), lineWidth: 1)
                        }
                }
            }

            Spacer()

            VStack(spacing: -8) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(.white)
                        .frame(width: 27, height: 27)
                        .overlay {
                            Circle().stroke(secondary, lineWidth: 2)
                        }
                }
            }
        }
        .padding(.horizontal, 22)
        .offset(y: -52)
    }

    private func die(
        _ value: Int
    ) -> some View {
        Text("\(value)")
            .font(.system(size: 22, weight: .black, design: .rounded))
            .foregroundStyle(Color(red: 0.18, green: 0.08, blue: 0.04))
            .frame(width: 43, height: 43)
            .background {
                RoundedRectangle(cornerRadius: 11)
                    .fill(accent)
            }
            .shadow(color: accent.opacity(0.55), radius: 10)
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}

private struct DotsAndBoxesTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color
    let isPulsing: Bool

    var body: some View {
        VStack(spacing: 17) {
            Canvas { context, size in
                let inset: CGFloat = 18
                let step = (size.width - inset * 2) / 3

                if phase >= 1 {
                    let boxRect = CGRect(
                        x: inset + step,
                        y: inset + step,
                        width: step,
                        height: step
                    )
                    context.fill(
                        Path(boxRect),
                        with: .color(accent.opacity(0.18))
                    )
                }

                for row in 0..<4 {
                    for column in 0..<4 {
                        let point = CGPoint(
                            x: inset + CGFloat(column) * step,
                            y: inset + CGFloat(row) * step
                        )
                        let dot = Path(
                            ellipseIn: CGRect(
                                x: point.x - 5,
                                y: point.y - 5,
                                width: 10,
                                height: 10
                            )
                        )
                        context.fill(dot, with: .color(.white))
                    }
                }

                let edges = edgesForPhase(step: step, inset: inset)
                for (start, end, color) in edges {
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(
                        path,
                        with: .color(color),
                        style: StrokeStyle(
                            lineWidth: 7,
                            lineCap: .round
                        )
                    )
                }
            }
            .frame(width: 220, height: 220)
            .scaleEffect(isPulsing && phase == 0 ? 1.025 : 1)

            Label(
                phase == 0
                ? "ONE EDGE PER TURN"
                : (phase == 1 ? "BOX CLAIMED" : "SCORE + PLAY AGAIN"),
                systemImage:
                    phase == 0
                    ? "line.diagonal"
                    : (phase == 1 ? "square.fill" : "plus.circle.fill")
            )
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(accent)
        }
    }

    private func edgesForPhase(
        step: CGFloat,
        inset: CGFloat
    ) -> [(CGPoint, CGPoint, Color)] {
        func point(_ row: Int, _ column: Int) -> CGPoint {
            CGPoint(
                x: inset + CGFloat(column) * step,
                y: inset + CGFloat(row) * step
            )
        }

        if phase == 0 {
            return [
                (point(1, 1), point(1, 2), accent)
            ]
        }

        var edges: [(CGPoint, CGPoint, Color)] = [
            (point(1, 1), point(1, 2), accent),
            (point(1, 1), point(2, 1), accent),
            (point(1, 2), point(2, 2), secondary),
            (point(2, 1), point(2, 2), accent)
        ]

        if phase == 2 {
            edges.append(contentsOf: [
                (point(0, 0), point(0, 1), secondary),
                (point(0, 1), point(1, 1), secondary),
                (point(2, 2), point(2, 3), accent),
                (point(2, 3), point(3, 3), accent)
            ])
        }

        return edges
    }
}

private struct RicochetTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color
    let isPulsing: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                arena(isLocal: true)

                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(accent)
                    .scaleEffect(isPulsing && phase == 1 ? 1.14 : 1)

                arena(isLocal: false)
            }

            if phase == 2 {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        Image(systemName: "shield.fill")
                            .foregroundStyle(accent)
                    }
                }
                .font(.system(size: 20))
            } else {
                Label(
                    phase == 0 ? "TILT TO MOVE" : "CROSS-SCREEN RALLY",
                    systemImage: phase == 0 ? "gyroscope" : "bolt.fill"
                )
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(accent)
            }
        }
    }

    private func arena(
        isLocal: Bool
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.black.opacity(0.32))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            (isLocal ? accent : secondary).opacity(0.5),
                            lineWidth: 1.4
                        )
                }

            Capsule()
                .fill(isLocal ? accent : secondary)
                .frame(width: 58, height: 8)
                .offset(y: 72)
                .offset(x: phase == 0 && isLocal ? (isPulsing ? 12 : -12) : 0)

            if phase != 2 || isLocal {
                Circle()
                    .fill(.white)
                    .frame(width: 17, height: 17)
                    .shadow(color: accent.opacity(0.9), radius: 9)
                    .offset(
                        x: isLocal ? -18 : 20,
                        y: phase == 1 ? (isLocal ? -48 : 38) : 8
                    )
            }

            if phase == 2 && !isLocal {
                Image(systemName: "burst.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.red)
                    .shadow(color: Color.red.opacity(0.8), radius: 10)
            }
        }
        .frame(width: 90, height: 190)
    }
}

private struct TiltRaceTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color
    let isPulsing: Bool

    private let points: [CGPoint] = [
        CGPoint(x: 0.50, y: 0.88),
        CGPoint(x: 0.22, y: 0.68),
        CGPoint(x: 0.76, y: 0.51),
        CGPoint(x: 0.31, y: 0.31),
        CGPoint(x: 0.68, y: 0.13)
    ]

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.28))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(accent.opacity(0.35), lineWidth: 1)
                    }

                Canvas { context, size in
                    var route = Path()
                    for (index, point) in points.enumerated() {
                        let position = CGPoint(
                            x: point.x * size.width,
                            y: point.y * size.height
                        )
                        if index == 0 {
                            route.move(to: position)
                        } else {
                            route.addLine(to: position)
                        }
                    }
                    context.stroke(
                        route,
                        with: .linearGradient(
                            Gradient(colors: [accent, secondary]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: 0)
                        ),
                        style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round,
                            dash: [6, 8]
                        )
                    )
                }
                .padding(8)

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.72))
                        Circle()
                            .stroke(
                                index == min(phase + 1, 4)
                                ? accent
                                : Color.white.opacity(0.28),
                                lineWidth: index == min(phase + 1, 4) ? 3 : 1.5
                            )
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 30, height: 30)
                    .scaleEffect(
                        index == min(phase + 1, 4) && isPulsing
                        ? 1.12
                        : 1
                    )
                    .position(
                        x: point.x * 220,
                        y: point.y * 220
                    )
                }

                Circle()
                    .fill(accent)
                    .frame(width: 22, height: 22)
                    .shadow(color: accent.opacity(0.85), radius: 10)
                    .position(
                        x: points[min(phase, 2)].x * 220,
                        y: points[min(phase, 2)].y * 220
                    )
            }
            .frame(width: 220, height: 220)
            .rotation3DEffect(
                .degrees(phase == 0 && isPulsing ? 3 : 0),
                axis: (x: 1, y: -1, z: 0)
            )

            Label(
                phase == 0
                ? "MOVE BY TILTING"
                : (phase == 1 ? "GATES IN ORDER" : "FIRST TO GATE 10"),
                systemImage:
                    phase == 0
                    ? "gyroscope"
                    : (phase == 1 ? "point.topleft.down.to.point.bottomright.curvepath" : "flag.checkered")
            )
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(accent)
        }
    }
}

private struct TapFrenzyTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color
    let isPulsing: Bool

    private let points: [CGPoint] = [
        CGPoint(x: 0.24, y: 0.25),
        CGPoint(x: 0.72, y: 0.19),
        CGPoint(x: 0.49, y: 0.49),
        CGPoint(x: 0.22, y: 0.76),
        CGPoint(x: 0.75, y: 0.72)
    ]

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.28))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(accent.opacity(0.30), lineWidth: 1)
                    }

                ForEach(0..<5, id: \.self) { index in
                    let number = index + 1
                    let isNext = phase == 0 && number == (isPulsing ? 2 : 1)

                    ZStack {
                        if isNext {
                            Circle()
                                .stroke(targetColor(number).opacity(0.45), lineWidth: 2)
                                .frame(width: 52, height: 52)
                        }
                        Circle()
                            .fill(targetColor(number))
                            .frame(width: phase == 1 ? 39 : 44, height: phase == 1 ? 39 : 44)
                            .shadow(color: targetColor(number).opacity(0.55), radius: 8)
                        Text("\(number)")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.72))
                    }
                    .position(
                        x: points[index].x * 220,
                        y: points[index].y * 220
                    )
                }

                if phase == 1 {
                    Text(isPulsing ? "+16" : "+10")
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .frame(height: 44)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(secondary.opacity(0.55), lineWidth: 1))
                }

                if phase == 2 {
                    HStack(spacing: 13) {
                        scoreCard(name: "P1", score: 124, color: accent)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white.opacity(0.42))
                        scoreCard(name: "P2", score: 138, color: secondary)
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .frame(width: 220, height: 220)

            Label(
                phase == 0
                    ? "TAP 1 → 5"
                    : (phase == 1 ? "SPEED BUILDS SCORE" : "60 SECONDS EACH"),
                systemImage:
                    phase == 0
                    ? "hand.tap.fill"
                    : (phase == 1 ? "bolt.fill" : "person.2.fill")
            )
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(accent)
        }
    }

    private func targetColor(_ number: Int) -> Color {
        switch number {
        case 1: return accent
        case 2: return Color.orange
        case 3: return secondary
        case 4: return Color.purple
        default: return Color.green
        }
    }

    private func scoreCard(name: String, score: Int, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(name)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text("\(score)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

private struct LaserDuelTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color
    let isPulsing: Bool

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.30))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }

                if phase == 1 {
                    Capsule()
                        .fill(accent)
                        .frame(width: 5, height: 140)
                        .shadow(color: accent.opacity(0.9), radius: 10)
                        .offset(y: isPulsing ? -8 : 8)
                }

                cannon(color: secondary, pointsDown: true)
                    .offset(x: phase == 0 && isPulsing ? 24 : -24, y: -72)

                cannon(color: accent, pointsDown: false)
                    .offset(x: phase == 0 && isPulsing ? -22 : 22, y: 72)

                if phase == 2 {
                    HStack(spacing: 16) {
                        lives(color: accent, remaining: 3)
                        Image(systemName: "bolt.horizontal.fill")
                            .foregroundStyle(.white.opacity(0.42))
                        lives(color: secondary, remaining: 1)
                    }
                }
            }
            .frame(width: 220, height: 220)

            Label(
                phase == 0
                ? "MOVE & DODGE"
                : (phase == 1 ? "FIRE WHEN READY" : "THREE HITS WIN"),
                systemImage:
                    phase == 0
                    ? "move.3d"
                    : (phase == 1 ? "scope" : "heart.fill")
            )
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(accent)
        }
    }

    private func cannon(
        color: Color,
        pointsDown: Bool
    ) -> some View {
        VStack(spacing: -2) {
            Capsule()
                .fill(color)
                .frame(width: 9, height: 34)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.95))
                    .frame(width: 54, height: 25)
                Circle()
                    .fill(.black.opacity(0.65))
                    .frame(width: 14, height: 14)
            }
        }
        .rotationEffect(.degrees(pointsDown ? 180 : 0))
        .shadow(color: color.opacity(0.7), radius: 9)
    }

    private func lives(
        color: Color,
        remaining: Int
    ) -> some View {
        VStack(spacing: 6) {
            Text("\(remaining)")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            index < remaining
                            ? color
                            : Color.white.opacity(0.10)
                        )
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.10))
        }
    }
}
