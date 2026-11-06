import SwiftUI

struct TicTacToeTutorialView: View {
    let onDismiss: () -> Void
    let onNeverShowAgain: () -> Void

    @State
    private var selectedPage = 0

    @State
    private var isPulsing = false

    private let pageCount = 3

    var body: some View {
        ZStack {
            TicTacToeTheme.background
                .ignoresSafeArea()

            Circle()
                .fill(TicTacToeTheme.xBlue.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -150, y: -300)

            Circle()
                .fill(TicTacToeTheme.oPurple.opacity(0.13))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 170, y: 310)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                TabView(selection: $selectedPage) {
                    tutorialPage(
                        title: "Claim a square",
                        subtitle:
                            "Tap any empty square to place your mark. X always plays against O."
                    ) {
                        tutorialBoard(
                            marks: [
                                0: .x,
                                4: .o
                            ],
                            highlightedIndex: 8,
                            winningIndexes: []
                        )
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "hand.tap.fill")
                                .font(
                                    .system(
                                        size: 34,
                                        weight: .semibold
                                    )
                                )
                                .foregroundStyle(.white)
                                .padding(13)
                                .background {
                                    Circle()
                                        .fill(
                                            TicTacToeTheme
                                                .xBlue
                                                .opacity(0.92)
                                        )
                                }
                                .shadow(
                                    color:
                                        TicTacToeTheme
                                            .xBlue
                                            .opacity(0.65),
                                    radius: 18
                                )
                                .scaleEffect(
                                    isPulsing ? 1.06 : 0.92
                                )
                                .offset(x: 10, y: 10)
                        }
                    }
                    .tag(0)

                    tutorialPage(
                        title: "Take turns",
                        subtitle:
                            "Players alternate after every valid move. Watch the player card to see whose turn it is."
                    ) {
                        VStack(spacing: 20) {
                            tutorialBoard(
                                marks: [
                                    0: .x,
                                    1: .o,
                                    4: .x,
                                    7: .o
                                ],
                                highlightedIndex: 8,
                                winningIndexes: []
                            )

                            HStack(spacing: 10) {
                                playerPill(
                                    mark: .x,
                                    title: "Your turn",
                                    isActive: true
                                )

                                playerPill(
                                    mark: .o,
                                    title: "Waiting",
                                    isActive: false
                                )
                            }
                        }
                    }
                    .tag(1)

                    tutorialPage(
                        title: "Connect three",
                        subtitle:
                            "Place three of your marks in a row — horizontally, vertically, or diagonally — to win."
                    ) {
                        VStack(spacing: 20) {
                            tutorialBoard(
                                marks: [
                                    0: .x,
                                    1: .o,
                                    4: .x,
                                    5: .o,
                                    8: .x
                                ],
                                highlightedIndex: nil,
                                winningIndexes: [0, 4, 8]
                            )

                            Label(
                                "Three in a row wins!",
                                systemImage: "sparkles"
                            )
                            .font(
                                .system(
                                    size: 14,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(
                                TicTacToeTheme.xBlue
                            )
                            .padding(.horizontal, 16)
                            .frame(height: 38)
                            .background {
                                Capsule()
                                    .fill(
                                        TicTacToeTheme
                                            .xBlue
                                            .opacity(0.12)
                                    )
                            }
                        }
                    }
                    .tag(2)
                }
                .tabViewStyle(
                    .page(indexDisplayMode: .never)
                )

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
            ZStack {
                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
                .fill(TicTacToeTheme.cardBackground)

                Image(systemName: "xmark.circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        TicTacToeTheme.primaryGradient
                    )
            }
            .frame(width: 48, height: 48)
            .overlay {
                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
            }

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
                    .foregroundStyle(TicTacToeTheme.xBlue)

                Text("Tic Tac Toe")
                    .font(
                        .system(
                            size: 22,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
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

    private func tutorialPage<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 560

            ScrollView {
                VStack(spacing: compact ? 16 : 24) {
                    Spacer(minLength: compact ? 8 : 22)

                    content()
                        .frame(
                            maxWidth: .infinity,
                            minHeight: compact ? 250 : 310
                        )

                    VStack(spacing: 9) {
                        Text(title)
                            .font(
                                .system(
                                    size: compact ? 25 : 29,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(.white)

                        Text(subtitle)
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
                            .frame(maxWidth: 340)
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

    private func tutorialBoard(
        marks: [Int: TicTacToeMark],
        highlightedIndex: Int?,
        winningIndexes: [Int]
    ) -> some View {
        let side: CGFloat = 236
        let spacing: CGFloat = 8
        let cellSide = (side - spacing * 2) / 3

        return ZStack {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(
                        .fixed(cellSide),
                        spacing: spacing
                    ),
                    count: 3
                ),
                spacing: spacing
            ) {
                ForEach(0..<9, id: \.self) { index in
                    let mark = marks[index]
                    let isHighlighted =
                        highlightedIndex == index
                    let isWinning =
                        winningIndexes.contains(index)

                    ZStack {
                        RoundedRectangle(
                            cornerRadius: 18,
                            style: .continuous
                        )
                        .fill(
                            Color.white.opacity(
                                isHighlighted || isWinning
                                ? 0.075
                                : 0.035
                            )
                        )

                        RoundedRectangle(
                            cornerRadius: 18,
                            style: .continuous
                        )
                        .stroke(
                            cellStrokeColor(
                                mark: mark,
                                isHighlighted: isHighlighted,
                                isWinning: isWinning
                            ),
                            lineWidth:
                                isHighlighted || isWinning
                                ? 1.6
                                : 1
                        )

                        if let mark {
                            TicTacToeMarkIcon(
                                mark: mark,
                                size: 36
                            )
                        } else if isHighlighted {
                            Circle()
                                .fill(
                                    TicTacToeTheme
                                        .xBlue
                                        .opacity(0.16)
                                )
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Circle()
                                        .stroke(
                                            TicTacToeTheme
                                                .xBlue
                                                .opacity(0.70),
                                            lineWidth: 1
                                        )
                                }
                                .scaleEffect(
                                    isPulsing ? 1.08 : 0.84
                                )
                        }
                    }
                    .frame(width: cellSide, height: cellSide)
                }
            }
            .frame(width: side, height: side)

            if winningIndexes == [0, 4, 8] {
                Capsule()
                    .fill(TicTacToeTheme.xBlue)
                    .frame(width: side * 1.08, height: 4)
                    .rotationEffect(.degrees(45))
                    .shadow(
                        color:
                            TicTacToeTheme
                                .xBlue
                                .opacity(0.95),
                        radius: 8
                    )
                    .allowsHitTesting(false)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(
                cornerRadius: 30,
                style: .continuous
            )
            .fill(TicTacToeTheme.cardBackground)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 30,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.09), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.28), radius: 24, y: 14)
    }

    private func cellStrokeColor(
        mark: TicTacToeMark?,
        isHighlighted: Bool,
        isWinning: Bool
    ) -> Color {
        if isWinning, let mark {
            return TicTacToeTheme.color(for: mark).opacity(0.85)
        }

        if isHighlighted {
            return TicTacToeTheme.xBlue.opacity(0.76)
        }

        return Color.white.opacity(0.09)
    }

    private func playerPill(
        mark: TicTacToeMark,
        title: String,
        isActive: Bool
    ) -> some View {
        HStack(spacing: 9) {
            TicTacToeMarkIcon(mark: mark, size: 18)

            Text(title)
                .font(
                    .system(
                        size: 13,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    isActive
                    ? Color.white
                    : Color.white.opacity(0.48)
                )
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background {
            Capsule()
                .fill(
                    TicTacToeTheme
                        .color(for: mark)
                        .opacity(isActive ? 0.15 : 0.055)
                )
        }
        .overlay {
            Capsule()
                .stroke(
                    isActive
                    ? TicTacToeTheme
                        .color(for: mark)
                        .opacity(0.65)
                    : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 7) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(
                        index == selectedPage
                        ? TicTacToeTheme.xBlue
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
            "Page \(selectedPage + 1) of \(pageCount)"
        )
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Button {
                if selectedPage < pageCount - 1 {
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
                        selectedPage == pageCount - 1
                        ? "Start Playing"
                        : "Next"
                    )

                    Image(
                        systemName:
                            selectedPage == pageCount - 1
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
                        .fill(TicTacToeTheme.primaryGradient)
                }
                .shadow(
                    color:
                        TicTacToeTheme
                            .xBlue
                            .opacity(0.26),
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
