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

    @State private var ticTacToeGame = TicTacToeGame()

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
                Button("Reset") {
                    ticTacToeGame.reset()
                    // Optionally send a reset message later; for now local only per requirements
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
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
        case .gameState, .custom:
            // Not used yet
            break
        default:
            break
        }
    }
}

#Preview {
    // Placeholder preview; NearbyService is not instantiated here since it's owned by lobby in the app.
    Text("TicTacToeView Preview")
}

