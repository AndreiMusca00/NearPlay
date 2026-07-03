//
//  TicTacToeView.swift
//  NearPlay
//
//  Created by Andrei Musca on 01/07/2026.
//

import SwiftUI

struct TicTacToeView: View {
    let game: Game
    @ObservedObject var nearbyService: NearbyService
    let localPlayerName: String
    let localMark: TicTacToeMark
    let startPayload: TicTacToeStartPayload

    @Environment(\.dismiss) private var dismiss

    @State private var ticTacToeGame = TicTacToeGame()
    @State private var localWantsPlayAgain: Bool = false
    @State private var remoteWantsPlayAgain: Bool = false
    @State private var showQuitConfirmation: Bool = false
    @State private var isQuitting: Bool = false

    var onExitToHome: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            // Title and player info
            VStack(spacing: 4) {
                Text(game.title)
                    .font(.title).bold()
                Text("You: \(localPlayerName) (\(localMarkDisplay))")
                    .font(.subheadline)
                Text(statusText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            // 3x3 Board
            boardView
                .disabled(!isLocalTurn || ticTacToeGame.winner != nil || ticTacToeGame.isDraw)

            if let winner = ticTacToeGame.winner {
                Text("Winner: \(winner == .x ? "X" : "O")")
                    .font(.headline)
                    .foregroundStyle(.primary)
            } else if ticTacToeGame.isDraw {
                Text("It's a draw")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            if ticTacToeGame.winner != nil || ticTacToeGame.isDraw {
                VStack(spacing: 8) {
                    if localWantsPlayAgain && remoteWantsPlayAgain {
                        Text("Starting next round…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if localWantsPlayAgain {
                        Text("Waiting for opponent…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if remoteWantsPlayAgain {
                        Text("Opponent wants to play again")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button("Play Again") {
                        requestPlayAgain()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(localWantsPlayAgain)
                }
            }

            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .padding()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showQuitConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Quit game")
            }
        }
        .overlay {
            if isQuitting {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView("Leaving game…")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .alert("Quit game?", isPresented: $showQuitConfirmation) {
            Button("Quit Game", role: .destructive) {
                quitGame()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You and your opponent will return to the main screen.")
        }
        .onChange(of: nearbyService.lastReceivedMessage) { oldValue, newValue in
            handleIncoming(newValue)
        }
    }

    private var isLocalTurn: Bool {
        ticTacToeGame.currentTurn == localMark
    }

    private var localMarkDisplay: String {
        localMark == .x ? "X" : "O"
    }

    private var statusText: String {
        if let winner = ticTacToeGame.winner {
            return "Winner: \(winner == .x ? "X" : "O")"
        } else if ticTacToeGame.isDraw {
            return "Draw"
        } else {
            return "Turn: \(ticTacToeGame.currentTurn == .x ? "X" : "O")"
        }
    }

    private var boardView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(0..<9, id: \.self) { index in
                Button(action: { cellTapped(index) }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 80)
                        Text(cellText(at: index))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cellText(at index: Int) -> String {
        if let mark = ticTacToeGame.board[index] {
            return mark == .x ? "X" : "O"
        } else {
            return ""
        }
    }

    private func cellTapped(_ index: Int) {
        guard isLocalTurn else { return }
        let moved = ticTacToeGame.makeMove(at: index, by: localMark)
        guard moved else { return }

        // Send move to peers
        let payload = TicTacToeMovePayload(index: index, mark: localMark)
        do {
            let data = try JSONEncoder().encode(payload)
            let message = NearbyMessage(gameID: game.id, senderName: localPlayerName, type: .gameAction, payload: data)
            nearbyService.send(message)
        } catch {
            // For now, silently ignore encoding errors
            print("Failed to encode move: \(error)")
        }
    }

    private func requestPlayAgain() {
        // Only request a new round if current game is over
        guard ticTacToeGame.winner != nil || ticTacToeGame.isDraw else { return }
        guard !localWantsPlayAgain else { return }

        localWantsPlayAgain = true

        let payload = TicTacToePlayAgainPayload(requestedBy: localPlayerName)
        do {
            let data = try JSONEncoder().encode(payload)
            let message = NearbyMessage(
                gameID: game.id,
                senderName: localPlayerName,
                type: .gameState,
                payload: data
            )
            nearbyService.send(message)
        } catch {
            // Ignore encoding errors for now
            print("Failed to encode play again payload: \(error)")
        }

        tryStartNextRoundIfReady()
    }

    private func tryStartNextRoundIfReady() {
        guard localWantsPlayAgain && remoteWantsPlayAgain else { return }
        // Reset board and clear flags
        ticTacToeGame.reset()
        localWantsPlayAgain = false
        remoteWantsPlayAgain = false
    }

    private func quitGame() {
        isQuitting = true
        let payload = GameQuitPayload(playerName: localPlayerName, reason: "quit")
        let data = try? JSONEncoder().encode(payload)
        let message = NearbyMessage(
            gameID: game.id,
            senderName: localPlayerName,
            type: .gameQuit,
            payload: data
        )
        nearbyService.send(message)

        // Give the reliable message a brief moment to send before disconnecting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // First, stop the session
            nearbyService.stop()
            // Pop this view off the navigation stack
            dismiss()
            // Then ask parent (lobby) to dismiss itself to go home
            onExitToHome()
            isQuitting = false
        }
    }

    private func handleIncoming(_ message: NearbyMessage?) {
        guard let message = message else { return }
        // Only handle messages for this game
        guard message.gameID == game.id else { return }

        switch message.type {
        case .gameAction:
            guard let payload = message.payload else {
                // No payload to decode; ignore this message
                return
            }
            do {
                let move = try JSONDecoder().decode(TicTacToeMovePayload.self, from: payload)
                // Apply the move if it's from the opponent and valid under current rules
                _ = ticTacToeGame.makeMove(at: move.index, by: move.mark)
            } catch {
                // Ignore decoding errors for now
                print("Failed to decode move: \(error)")
            }
        case .gameState:
            guard let payload = message.payload else { return }
            if let _ = try? JSONDecoder().decode(TicTacToePlayAgainPayload.self, from: payload) {
                remoteWantsPlayAgain = true
                tryStartNextRoundIfReady()
            }
        case .custom:
            // Not used yet
            break
        case .gameQuit:
            // Opponent quit: stop service and exit to home
            nearbyService.stop()
            // Pop this view
            dismiss()
            // Dismiss lobby to go home
            onExitToHome()
        default:
            break
        }
    }
}

#Preview {
    // Placeholder preview; NearbyService is not instantiated here since it's owned by lobby in the app.
    Text("TicTacToeView Preview")
}
