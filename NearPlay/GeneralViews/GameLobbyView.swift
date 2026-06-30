import SwiftUI

struct GameLobbyView: View {
    let game: Game

    @StateObject private var nearbyService = NearbyService()
    @AppStorage(PlayerProfile.nameKey) private var playerName: String = ""

    @State private var progress: Double = 0
    @State private var isSearching: Bool = false

    private var safePlayerName: String {
        playerName.isEmpty ? "Player" : playerName
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
            statusSection

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
                debugSection
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
            nearbyService.stop()
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
    }

    private var statusSection: some View {
        VStack(spacing: 8) {
            Text("Your name: \(safePlayerName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Status: \(String(describing: nearbyService.connectionState))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var discoveredPeersSection: some View {
        VStack(spacing: 12) {
            Text("Discovered devices")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

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
    private var debugSection: some View {
        if !nearbyService.connectedPeers.isEmpty {
            VStack(spacing: 12) {
                Button("Send Ping") {
                    sendPing()
                }
                .buttonStyle(.borderedProminent)

                if let last = nearbyService.lastReceivedMessage {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last received:")
                            .font(.headline)

                        Text("\(last.type.rawValue) from \(last.senderName)")
                            .font(.subheadline)

                        if let data = last.payload,
                           let text = String(data: data, encoding: .utf8) {
                            Text("Payload: \(text)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
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

    private func sendPing() {
        let payload = "ping".data(using: .utf8)

        let message = NearbyMessage(
            gameID: game.id,
            senderName: safePlayerName,
            type: .custom,
            payload: payload
        )

        nearbyService.send(message)
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
