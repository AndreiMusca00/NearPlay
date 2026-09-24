import SwiftUI

struct BackgammonGameScreen: View {
    let gameTitle: String

    let state: BackgammonGameState

    let playerOneID: String
    let playerOneName: String
    let playerTwoID: String
    let playerTwoName: String

    let selectedSource: BackgammonSelectedSource?
    let legalMoves: [BackgammonMove]
    let interactionPlayer: BackgammonPlayer?
    let isInteractionEnabled: Bool
    let showsProgress: Bool

    let statusTitle: String
    let statusSubtitle: String

    let onRoll: () -> Void
    let onPointTap: (Int) -> Void
    let onBarTap: () -> Void
    let onMove: (_ source: Int?, _ destination: Int?) -> Void
    let onBearOff: () -> Void
    let onQuitRequested: () -> Void

    var body: some View {
        ZStack {
            BackgammonTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 15) {
                    header
                    players
                    statusCard

                    BackgammonBoardView(
                        state: state,
                        selectedSource: selectedSource,
                        legalMoves: legalMoves,
                        interactionPlayer: interactionPlayer,
                        isInteractionEnabled: isInteractionEnabled,
                        onPointTap: onPointTap,
                        onBarTap: onBarTap,
                        onMove: onMove
                    )
                    .padding(.horizontal, 1)

                    controlCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 22)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(gameTitle)
                    .font(
                        .system(
                            size: 28,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)

                Text("First to bear off all 15 checkers wins")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.42))
            }

            Spacer()

            Button(action: onQuitRequested) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.055))
                    }
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var players: some View {
        HStack(spacing: 10) {
            playerCard(
                name: playerOneName,
                playerID: playerOneID,
                player: .playerOne,
                borneOff: state.playerOneBorneOff
            )

            Text("VS")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(Color.white.opacity(0.28))

            playerCard(
                name: playerTwoName,
                playerID: playerTwoID,
                player: .playerTwo,
                borneOff: state.playerTwoBorneOff
            )
        }
    }

    private func playerCard(
        name: String,
        playerID: String,
        player: BackgammonPlayer,
        borneOff: Int
    ) -> some View {
        let active = state.activePlayerID == playerID && !state.isFinished
        let color = BackgammonTheme.checkerColor(for: player)

        return HStack(spacing: 9) {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .shadow(color: color.opacity(0.55), radius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(borneOff) off")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.42))
            }

            Spacer(minLength: 0)

            if active {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .shadow(color: color, radius: 5)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(active ? 0.075 : 0.035))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(
                    active ? color.opacity(0.45) : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        }
    }

    private var statusCard: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }

                Text(statusTitle)
                    .font(
                        .system(
                            size: 17,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
            }

            Text(statusSubtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.035))
        }
    }

    private var controlCard: some View {
        HStack(spacing: 12) {
            diceArea

            Spacer(minLength: 4)

            if canBearOff {
                Button(action: onBearOff) {
                    Label("Bear Off", systemImage: "arrow.up.right.square.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black.opacity(0.80))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                        .background {
                            Capsule()
                                .fill(BackgammonTheme.gold)
                        }
                }
                .buttonStyle(.plain)
            } else if canRoll {
                Button(action: onRoll) {
                    Label("Roll Dice", systemImage: "die.face.5.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .frame(height: 44)
                        .background {
                            Capsule()
                                .fill(BackgammonTheme.primaryGradient)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var diceArea: some View {
        HStack(spacing: 8) {
            if state.dice.isEmpty {
                Image(systemName: "die.face.1")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.white.opacity(0.28))

                Text("Waiting to roll")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.42))
            } else {
                ForEach(Array(state.remainingDice.enumerated()), id: \.offset) { _, die in
                    dieView(die)
                }
            }
        }
    }

    private func dieView(_ value: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .frame(width: 36, height: 36)

            Image(systemName: "die.face.\(value).fill")
                .font(.system(size: 25))
                .foregroundStyle(.white)
        }
    }

    private var canRoll: Bool {
        isInteractionEnabled &&
        !state.isFinished &&
        state.dice.isEmpty
    }

    private var canBearOff: Bool {
        guard isInteractionEnabled,
              let selectedSource else {
            return false
        }

        switch selectedSource {
        case .bar:
            return false

        case .point(let index):
            return legalMoves.contains {
                $0.source == index && $0.destination == nil
            }
        }
    }
}
