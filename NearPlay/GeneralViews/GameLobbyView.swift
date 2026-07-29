import SwiftUI

struct GameLobbyView: View {
    let game: Game

    @StateObject private var nearbyService = NearbyService()
    @AppStorage(PlayerProfile.nameKey) private var playerName: String = ""
    @Environment(\.dismiss) private var dismiss

    @State private var progress: Double = 0
    @State private var isSearching: Bool = false
    @State private var shouldStartGame: Bool = false

    // Tic Tac Toe state
    @State private var localMark: TicTacToeMark?
    @State private var ticTacToeStartPayload: TicTacToeStartPayload?

    // Rock Paper Scissors state
    @State private var rpsStartPayload: RPSStartPayload?

    // Used so the lobby does not stop NearbyService when navigating into a game.
    @State private var isStartingGame: Bool = false

    private var safePlayerName: String {
        playerName.isEmpty ? "Player" : playerName
    }

    private var isSupportedGame: Bool {
        game.id == Game.ticTacToe.id ||
        game.id == Game.rockPaperScissors.id
    }

    private var canStartGame: Bool {
        isSupportedGame &&
        (nearbyService.connectedPeers.count + 1) >= game.minPlayers
    }

    private var invitationBinding: Binding<Bool> {
        Binding(
            get: {
                nearbyService.pendingInvitation != nil
            },
            set: { newValue in
                if !newValue && nearbyService.pendingInvitation != nil {
                    nearbyService.rejectInvitation()
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            if !isSearching {
                HoldToSearchButton(progress: $progress) {
                    startSearching()
                }
                .accessibilityLabel("Start searching for devices")
            } else {
                Text("Searching for devices…")
                    .font(.headline)
                    .transition(.opacity)

                discoveredPeersSection

                connectedPeersSection

                if canStartGame {
                    Button("Start Game") {
                        startSelectedGame()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let error = nearbyService.errorMessage, !error.isEmpty {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .navigationTitle(game.title)
        .onDisappear {
            if !isStartingGame {
                nearbyService.stop()
            }
        }
        .alert("Invitation", isPresented: invitationBinding) {
            Button("Accept") {
                nearbyService.acceptInvitation()
            }

            Button("Reject", role: .cancel) {
                nearbyService.rejectInvitation()
            }
        } message: {
            if let pending = nearbyService.pendingInvitation {
                Text("\(pending.from.displayName) wants to play \(pending.context.gameID)")
            } else {
                Text("")
            }
        }
        .onReceive(nearbyService.$lastReceivedMessage) { message in
            guard let message else { return }
            handleReceivedMessage(message)
        }
        .navigationDestination(isPresented: $shouldStartGame) {
            gameDestination
        }
    }

    private var discoveredPeersSection: some View {
        VStack(spacing: 12) {
            if nearbyService.discoveredPeers.isEmpty {
                Text("No devices found yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(nearbyService.discoveredPeers, id: \.id) { peer in
                    Button {
                        nearbyService.invite(peer)
                    } label: {
                        HStack {
                            Image(systemName: "dot.radiowaves.left.and.right")

                            VStack(alignment: .leading, spacing: 4) {
                                Text(peer.displayName)
                                    .font(.headline)

                                if let maxPlayers = peer.maxPlayers {
                                    Text("Max players: \(maxPlayers)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text("Invite")
                                .font(.subheadline.bold())
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var connectedPeersSection: some View {
        VStack(spacing: 12) {
            Text("Connected devices")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if nearbyService.connectedPeers.isEmpty {
                Text("No connected peers")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(nearbyService.connectedPeers, id: \.id) { peer in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)

                        Text(peer.displayName)

                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    @ViewBuilder
    private var gameDestination: some View {
        switch game.id {
        case Game.ticTacToe.id:
            TicTacToeView(
                game: game,
                nearbyService: nearbyService,
                localPlayerName: safePlayerName,
                localMark: localMark ?? .o,
                startPayload: ticTacToeStartPayload ?? TicTacToeStartPayload(
                    xPlayerName: safePlayerName,
                    oPlayerName: nearbyService.connectedPeers.first?.displayName ?? "Peer"
                ),
                onExitToHome: exitToHome
            )

        case Game.rockPaperScissors.id:
            RPSView(
                game: game,
                nearbyService: nearbyService,
                localPlayerName: safePlayerName,
                startPayload: rpsStartPayload ?? RPSStartPayload(
                    playerOneName: safePlayerName,
                    playerTwoName: nearbyService.connectedPeers.first?.displayName ?? "Peer"
                ),
                onExitToHome: exitToHome
            )

        default:
            Text("Game not implemented yet")
        }
    }

    private func startSearching() {
        nearbyService.start(
            gameID: game.id,
            playerName: safePlayerName,
            maxPlayers: game.maxPlayers
        )

        withAnimation(.spring()) {
            isSearching = true
        }
    }

    private func startSelectedGame() {
        switch game.id {
        case Game.ticTacToe.id:
            startTicTacToe()

        case Game.rockPaperScissors.id:
            startRockPaperScissors()

        default:
            break
        }
    }

    private func startTicTacToe() {
        guard let firstPeer = nearbyService.connectedPeers.first else { return }

        let xName = safePlayerName
        let oName = firstPeer.displayName

        let payload = TicTacToeStartPayload(
            xPlayerName: xName,
            oPlayerName: oName
        )

        do {
            let data = try JSONEncoder().encode(payload)

            let message = NearbyMessage(
                gameID: game.id,
                senderName: xName,
                type: .gameStart,
                payload: data
            )

            nearbyService.send(message)

            localMark = .x
            ticTacToeStartPayload = payload
            isStartingGame = true
            shouldStartGame = true
        } catch {
            nearbyService.errorMessage = "Failed to start Tic Tac Toe."
            print("Failed to encode TicTacToeStartPayload: \(error)")
        }
    }

    private func startRockPaperScissors() {
        guard let firstPeer = nearbyService.connectedPeers.first else { return }

        let payload = RPSStartPayload(
            playerOneName: safePlayerName,
            playerTwoName: firstPeer.displayName
        )

        do {
            let data = try JSONEncoder().encode(payload)

            let message = NearbyMessage(
                gameID: game.id,
                senderName: safePlayerName,
                type: .gameStart,
                payload: data
            )

            nearbyService.send(message)

            rpsStartPayload = payload
            isStartingGame = true
            shouldStartGame = true
        } catch {
            nearbyService.errorMessage = "Failed to start Rock Paper Scissors."
            print("Failed to encode RPSStartPayload: \(error)")
        }
    }

    private func handleReceivedMessage(_ message: NearbyMessage) {
        guard message.gameID == game.id else { return }
        guard message.type == .gameStart else { return }
        guard let data = message.payload else { return }

        switch game.id {
        case Game.ticTacToe.id:
            handleTicTacToeStart(data)

        case Game.rockPaperScissors.id:
            handleRockPaperScissorsStart(data)

        default:
            break
        }
    }

    private func handleTicTacToeStart(_ data: Data) {
        do {
            let payload = try JSONDecoder().decode(
                TicTacToeStartPayload.self,
                from: data
            )

            localMark = .o
            ticTacToeStartPayload = payload
            isStartingGame = true
            shouldStartGame = true
        } catch {
            nearbyService.errorMessage = "Failed to start Tic Tac Toe."
            print("Failed to decode TicTacToeStartPayload: \(error)")
        }
    }

    private func handleRockPaperScissorsStart(_ data: Data) {
        do {
            let payload = try JSONDecoder().decode(
                RPSStartPayload.self,
                from: data
            )

            rpsStartPayload = payload
            isStartingGame = true
            shouldStartGame = true
        } catch {
            nearbyService.errorMessage = "Failed to start Rock Paper Scissors."
            print("Failed to decode RPSStartPayload: \(error)")
        }
    }

    private func exitToHome() {
        nearbyService.stop()
        isStartingGame = false
        shouldStartGame = false
        dismiss()
    }
}

private struct HoldToSearchButton: View {
    @Binding var progress: Double

    var onComplete: () -> Void

    @State private var isHolding = false
    @State private var holdStartDate: Date?
    @State private var timer: Timer?

    private let holdDuration: TimeInterval = 2.0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 104, height: 104)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.blue,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 104, height: 104)

            VStack(spacing: 6) {
                Image(systemName: "bolt.horizontal.circle")
                    .font(.system(size: 40, weight: .regular))

                Text("Hold")
                    .font(.caption.bold())
            }
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    startHoldIfNeeded()
                }
                .onEnded { _ in
                    endHold()
                }
        )
    }

    private func startHoldIfNeeded() {
        guard !isHolding else { return }

        isHolding = true
        holdStartDate = Date()
        progress = 0

        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            guard let holdStartDate else { return }

            let elapsed = Date().timeIntervalSince(holdStartDate)
            let newProgress = min(elapsed / holdDuration, 1.0)

            progress = newProgress

            if newProgress >= 1.0 {
                timer.invalidate()
                self.timer = nil
                isHolding = false
                progress = 0
                onComplete()
            }
        }
    }

    private func endHold() {
        timer?.invalidate()
        timer = nil

        if progress < 1.0 {
            withAnimation(.easeOut(duration: 0.15)) {
                progress = 0
            }
        }

        isHolding = false
        holdStartDate = nil
    }
}

#Preview {
    NavigationStack {
        GameLobbyView(game: .ticTacToe)
    }
}
