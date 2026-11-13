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
    case swipeRush(Int)
    case laserDuel(Int)

    var screenshotAspectRatio: CGFloat? {
        switch self {
        case .numberRush:
            1170.0 / 1710.0
        case .battleship(let phase):
            switch phase {
            case 0: 1142.0 / 1425.0
            case 1: 1142.0 / 1335.0
            default: 1142.0 / 1212.0
            }
        case .connectFour:
            1142.0 / 1200.0
        case .backgammon:
            2030.0 / 1038.0
        case .tiltRace(let phase):
            phase == 2 ? 1126.0 / 1480.0 : 1126.0 / 1136.0
        case .tapFrenzy(let phase):
            switch phase {
            case 0: 1126.0 / 1838.0
            case 1: 1126.0 / 2038.0
            case 2: 1126.0 / 1888.0
            default: 1126.0 / 1553.0
            }
        case .swipeRush(let phase):
            switch phase {
            case 0: 1126.0 / 1818.0
            case 1: 1126.0 / 1768.0
            case 2: 1126.0 / 1666.0
            default: 1126.0 / 2108.0
            }
        case .dotsAndBoxes(let phase):
            phase == 2 ? 1042.0 / 1250.0 : 1
        default:
            nil
        }
    }
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
                            "Read the target above the grid, then tap that number. Start at 1 and work your way up to 100.",
                        artwork: .numberRush(0)
                    ),
                    GameTutorialPage(
                        title: "Beat the clock",
                        subtitle:
                            "A correct number earns a point, adds one second, and keeps your turn. A wrong tap or an empty timer passes the turn.",
                        artwork: .numberRush(1)
                    ),
                    GameTutorialPage(
                        title: "Own the grid",
                        subtitle:
                            "Cyan marks Player 1’s numbers and purple marks Player 2’s. After all 100 numbers are found, the highest score wins.",
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
                            "Drag all five ships from the dock onto your grid. Each ship must fit inside the board without overlapping another ship.",
                        artwork: .battleship(0)
                    ),
                    GameTutorialPage(
                        title: "Rotate and get ready",
                        subtitle:
                            "Tap a placed ship to rotate it. When all five ships are in position, tap Ready for Battle.",
                        artwork: .battleship(1)
                    ),
                    GameTutorialPage(
                        title: "Attack enemy waters",
                        subtitle:
                            "Tap one enemy square per turn, even after a hit. Orange means a hit and a gray dot means a miss. Sink every enemy ship to win.",
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
                        title: "Tap a column",
                        subtitle:
                            "Tap any column with space. Your disc drops into its lowest empty slot. Cyan is Player 1 and purple is Player 2.",
                        artwork: .connectFour(0)
                    ),
                    GameTutorialPage(
                        title: "Take turns",
                        subtitle:
                            "Players take turns dropping one disc. The ACTIVE card shows who plays next. On one iPhone, pass it after each move.",
                        artwork: .connectFour(1)
                    ),
                    GameTutorialPage(
                        title: "Connect four to win",
                        subtitle:
                            "Join four of your discs horizontally, vertically, or diagonally. Here, Player 2 wins with four purple discs in a column.",
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
                        title: "Roll the dice",
                        subtitle:
                            "Tap the dice button in the middle of the board. Each dice gives one move. A double gives four moves of the same value.",
                        artwork: .backgammon(0)
                    ),
                    GameTutorialPage(
                        title: "Move your checkers",
                        subtitle:
                            "Drag a checker to a highlighted destination. A point with two opposing checkers is blocked. Checkers on the bar must re-enter first.",
                        artwork: .backgammon(1)
                    ),
                    GameTutorialPage(
                        title: "Confirm and bear off",
                        subtitle:
                            "Use both dice whenever possible. The checkmark confirms your turn and the circular arrow undoes moves. Bring all 15 checkers home, then bear them off to win.",
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
                            "Tap an unused line between two neighboring dots. Add one horizontal or vertical edge on your turn.",
                        artwork: .dotsAndBoxes(0)
                    ),
                    GameTutorialPage(
                        title: "Close a box",
                        subtitle:
                            "Complete the fourth side of a square to claim it and earn one point. Here, Player 2 has claimed the pink box.",
                        artwork: .dotsAndBoxes(1)
                    ),
                    GameTutorialPage(
                        title: "Claim a box, play again",
                        subtitle:
                            "Closing a box gives you another move. Cyan is Player 1 and pink is Player 2. When the board is full, the most boxes wins.",
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
                        title: "Tilt to steer",
                        subtitle:
                            "Hold the iPhone flat and tilt it naturally. The glowing orb rolls in the direction you lean.",
                        artwork: .tiltRace(0)
                    ),
                    GameTutorialPage(
                        title: "One gate at a time",
                        subtitle:
                            "Roll into the glowing ring. That gate disappears and the next one appears elsewhere. Keep going from 1 to 10.",
                        artwork: .tiltRace(1)
                    ),
                    GameTutorialPage(
                        title: "Race the clock",
                        subtitle:
                            "On one iPhone, finish all ten gates, then pass it to Player 2: the fastest time wins. Nearby, race live to gate ten.",
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
                            "Follow the number above the arena. Start with 1, then tap 2, 3, 4 and 5 in order.",
                        artwork: .tapFrenzy(0)
                    ),
                    GameTutorialPage(
                        title: "Follow the moving targets",
                        subtitle:
                            "Targets change position regularly. The glowing ring marks the next number to tap, even after the targets relocate.",
                        artwork: .tapFrenzy(1)
                    ),
                    GameTutorialPage(
                        title: "Finish the sequence",
                        subtitle:
                            "Correct targets disappear. Here, 1–3 are gone: tap 4, then 5. Finishing a sequence earns 10 points plus a speed bonus.",
                        artwork: .tapFrenzy(2)
                    ),
                    GameTutorialPage(
                        title: "Make every second count",
                        subtitle:
                            "You have 60 seconds. A wrong number costs 2 points. Play nearby or pass one iPhone between runs; the highest score wins.",
                        artwork: .tapFrenzy(3)
                    )
                ]
            )

        case Game.swipeRush.id:
            return GameTutorialDescriptor(
                accent: Color(red: 1.00, green: 0.24, blue: 0.62),
                secondary: Color(red: 0.08, green: 0.91, blue: 1.00),
                pages: [
                    GameTutorialPage(
                        title: "Start on the arrow",
                        subtitle:
                            "Put your finger inside the glowing circle, then swipe in the arrow’s direction. Here, swipe right.",
                        artwork: .swipeRush(0)
                    ),
                    GameTutorialPage(
                        title: "Follow each new arrow",
                        subtitle:
                            "The next target can point in a new direction. Here, swipe down. The outer ring shows the time left for that target.",
                        artwork: .swipeRush(1)
                    ),
                    GameTutorialPage(
                        title: "Avoid wrong swipes",
                        subtitle:
                            "A wrong direction, a late swipe, or starting outside the target costs 3 points and resets your combo.",
                        artwork: .swipeRush(2)
                    ),
                    GameTutorialPage(
                        title: "Build your combo",
                        subtitle:
                            "Fast correct swipes earn points and grow your combo. Both players get 60 seconds and the same sequence; highest score wins.",
                        artwork: .swipeRush(3)
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
            let maximumArtworkHeight = max(200, geometry.size.height - (compact ? 150 : 180))
            let aspectRatio = page.artwork.screenshotAspectRatio ?? 1
            let artworkWidth = max(0, min(
                geometry.size.width - 40,
                min(360, maximumArtworkHeight * aspectRatio)
            ))

            ScrollView {
                VStack(spacing: compact ? 16 : 24) {
                    Spacer(minLength: compact ? 8 : 22)

                    TutorialArtworkView(
                        kind: page.artwork,
                        accent: descriptor.accent,
                        secondary: descriptor.secondary,
                        isPulsing: isPulsing,
                        availableWidth: artworkWidth
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: page.artwork.screenshotAspectRatio == nil ? (compact ? 250 : 310) : nil
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
    let availableWidth: CGFloat

    private var usesScreenshot: Bool {
        kind.screenshotAspectRatio != nil
    }

    var body: some View {
        ZStack {
            if !usesScreenshot {
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
            }

            artwork
                .padding(usesScreenshot ? 0 : 22)
        }
        .frame(
            width: usesScreenshot ? availableWidth : 292,
            height: usesScreenshot ? nil : 300
        )
        .shadow(color: Color.black.opacity(0.28), radius: 24, y: 14)
    }

    @ViewBuilder
    private var artwork: some View {
        switch kind {
        case .numberRush(let phase):
            NumberRushTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary
            )

        case .battleship(let phase):
            BattleshipTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary
            )

        case .connectFour(let phase):
            ConnectFourTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary
            )

        case .backgammon(let phase):
            BackgammonTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary
            )

        case .dotsAndBoxes(let phase):
            DotsAndBoxesTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary
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
                secondary: secondary
            )

        case .tapFrenzy(let phase):
            TapFrenzyTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary
            )

        case .swipeRush(let phase):
            SwipeRushTutorialArtwork(
                phase: phase,
                accent: accent,
                secondary: secondary
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

private struct ConnectFourTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color

    private var imageName: String {
        switch phase {
        case 0: "tutorial_connect_four_drop"
        case 1: "tutorial_connect_four_turns"
        default: "tutorial_connect_four_win"
        }
    }

    private var imageDescription: String {
        switch phase {
        case 0:
            "Player 1 has placed a cyan disc in the first column. Player 2 is active. An arrow shows how a disc drops down the second column."
        case 1:
            "A cyan disc and a purple disc occupy the bottom row. An arrow points to Player 1's highlighted ACTIVE card."
        default:
            "Four purple discs form a vertical winning line in the first column. Player 2 wins."
        }
    }

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { geometry in
                    annotations(in: geometry.size)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .accessibilityLabel(imageDescription)
    }

    @ViewBuilder
    private func annotations(in size: CGSize) -> some View {
        let color = phase == 1 ? accent : secondary
        let lineWidth = max(2, size.width * 0.007)

        switch phase {
        case 0:
            RoundedRectangle(cornerRadius: size.width * 0.06)
                .fill(color.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: size.width * 0.06)
                        .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: lineWidth, dash: [5, 4]))
                }
                .frame(width: size.width * 0.13, height: size.height * 0.76)
                .position(x: size.width * 0.236, y: size.height * 0.415)

            TutorialArrow(
                start: CGPoint(x: 0.236, y: 0.19),
                control: CGPoint(x: 0.236, y: 0.40),
                end: CGPoint(x: 0.236, y: 0.67)
            )
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth + 1, lineCap: .round, lineJoin: .round))

            Image(systemName: "hand.tap.fill")
                .font(.system(size: size.width * 0.065, weight: .bold))
                .foregroundStyle(.white)
                .padding(8)
                .background(color, in: Circle())
                .position(x: size.width * 0.236, y: size.height * 0.10)

            callout("TAP A COLUMN", color: color, width: size.width * 0.48)
                .position(x: size.width * 0.61, y: size.height * 0.10)

        case 1:
            RoundedRectangle(cornerRadius: size.width * 0.055)
                .stroke(color, lineWidth: lineWidth)
                .shadow(color: color.opacity(0.65), radius: 8)
                .frame(width: size.width * 0.48, height: size.height * 0.158)
                .position(x: size.width * 0.245, y: size.height * 0.91)

            TutorialArrow(
                start: CGPoint(x: 0.70, y: 0.63),
                control: CGPoint(x: 0.69, y: 0.84),
                end: CGPoint(x: 0.48, y: 0.91)
            )
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth + 1, lineCap: .round, lineJoin: .round))

            callout("PLAYER 1 NEXT", color: color, width: size.width * 0.56)
                .position(x: size.width * 0.65, y: size.height * 0.56)

        default:
            Capsule()
                .fill(color.opacity(0.13))
                .overlay {
                    Capsule().stroke(.white.opacity(0.90), lineWidth: lineWidth)
                }
                .shadow(color: color.opacity(0.65), radius: 10)
                .frame(width: size.width * 0.14, height: size.height * 0.52)
                .position(x: size.width * 0.104, y: size.height * 0.535)

            TutorialArrow(
                start: CGPoint(x: 0.47, y: 0.32),
                control: CGPoint(x: 0.29, y: 0.27),
                end: CGPoint(x: 0.18, y: 0.37)
            )
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth + 1, lineCap: .round, lineJoin: .round))

            callout("4 IN A ROW", color: color, width: size.width * 0.48)
                .position(x: size.width * 0.63, y: size.height * 0.26)
        }
    }

    private func callout(_ text: String, color: Color, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(red: 0.035, green: 0.055, blue: 0.10), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.85), lineWidth: 1.5))
            .frame(maxWidth: width)
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
