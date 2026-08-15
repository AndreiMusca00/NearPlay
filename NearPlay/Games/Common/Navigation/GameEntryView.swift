import SwiftUI

struct GameEntryView: View {
    let game: Game

    // Used by Nearby games that explicitly quit back to the
    // main NearPlay games list.
    let onExitToHome: () -> Void

    @State
    private var showNearby = false

    @State
    private var showLocal = false

    @State
    private var showComputer = false

    @State
    private var selectedDifficulty:
        GameAIDifficulty = .medium

    var body: some View {
        GameModeSelectionView(
            game: game,
            onNearby: {
                guard game.supportedModes
                    .contains(.nearby) else {
                    return
                }

                showNearby = true
            },
            onLocal: {
                guard game.supportedModes
                    .contains(.local) else {
                    return
                }

                showLocal = true
            },
            onComputer: { difficulty in
                guard game.supportedModes
                    .contains(.computer) else {
                    return
                }

                selectedDifficulty = difficulty
                showComputer = true
            }
        )
        .navigationDestination(
            isPresented: $showNearby
        ) {
            GameLobbyView(
                game: game,
                onExitToHome:
                    onExitToHome
            )
        }
        .navigationDestination(
            isPresented: $showLocal
        ) {
            localDestination
        }
        .navigationDestination(
            isPresented: $showComputer
        ) {
            computerDestination
        }
    }

    // MARK: - Local routing

    @ViewBuilder
    private var localDestination: some View {
        switch game.id {
        case Game.ticTacToe.id:
            TicTacToeLocalView(
                game: game
            )

        case Game.rockPaperScissors.id:
            RPSLocalView(
                game: game
            )

        case Game.connectFour.id:
            ConnectFourLocalView(
                game: game
            )

        default:
            unavailableDestination(
                title: "Two Players"
            )
        }
    }

    // MARK: - Computer routing

    @ViewBuilder
    private var computerDestination: some View {
        switch game.id {
        case Game.ticTacToe.id:
            TicTacToeComputerView(
                game: game,
                difficulty:
                    selectedDifficulty
            )

        case Game.rockPaperScissors.id:
            RPSComputerView(
                game: game,
                difficulty:
                    selectedDifficulty
            )

        case Game.connectFour.id:
            ConnectFourComputerView(
                game: game,
                difficulty:
                    connectFourDifficulty
            )

        default:
            unavailableDestination(
                title: "Play vs Computer"
            )
        }
    }

    private var connectFourDifficulty:
        ConnectFourDifficulty {

        switch selectedDifficulty {
        case .easy:
            return .easy
        case .medium:
            return .medium
        case .hard:
            return .hard
        }
    }

    private func unavailableDestination(
        title: String
    ) -> some View {
        ZStack {
            Color(
                red: 7.0 / 255.0,
                green: 16.0 / 255.0,
                blue: 24.0 / 255.0
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "hammer.fill")
                    .font(
                        .system(
                            size: 30,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)

                Text(title)
                    .font(
                        .system(
                            size: 23,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)

                Text("Coming Soon")
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.48)
                    )
            }
        }
        .preferredColorScheme(.dark)
    }
}
