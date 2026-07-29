//
//  RPSView.swift
//  NearPlay
//
//  Created by Andrei Musca on 29/07/2026.
//

import SwiftUI

struct RPSView: View {
    let game: Game
    @ObservedObject var nearbyService: NearbyService

    let localPlayerName: String
    let startPayload: RPSStartPayload
    let onExitToHome: () -> Void
    
    @Environment(\.dismiss) private var dismiss

    @State private var rpsGame = RPSGame()

    @State private var localWantsPlayAgain = false
    @State private var remoteWantsPlayAgain = false

    @State private var showQuitConfirmation = false
    @State private var showOpponentLeftAlert = false

    private var remotePlayerName: String {
        if startPayload.playerOneName == localPlayerName {
            return startPayload.playerTwoName
        } else {
            return startPayload.playerOneName
        }
    }

    private var canChoose: Bool {
        rpsGame.localChoice == nil && !rpsGame.isRoundComplete
    }

    private var shouldRevealChoices: Bool {
        rpsGame.localChoice != nil && rpsGame.remoteChoice != nil
    }

    var body: some View {
        VStack(spacing: 28) {
            headerSection

            choicesStatusSection

            choiceButtonsSection

            resultSection

            playAgainSection

            Spacer()
        }
        .padding()
        .navigationTitle("Rock Paper Scissors")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showQuitConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                }
                .accessibilityLabel("Quit game")
            }
        }
        .confirmationDialog(
            "Quit game?",
            isPresented: $showQuitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Quit Game", role: .destructive) {
                quitGame()
            }

            Button("Cancel", role: .cancel) {}
        }
        .alert("Opponent left the game", isPresented: $showOpponentLeftAlert) {
            Button("OK") {
                nearbyService.stop()
                dismiss()
                onExitToHome()
            }
        } message: {
            Text("The match has ended.")
        }
        .onReceive(nearbyService.$lastReceivedMessage) { message in
            guard let message else { return }
            handleReceivedMessage(message)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("\(localPlayerName) vs \(remotePlayerName)")
                .font(.headline)

            Text("Choose your move")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var choicesStatusSection: some View {
        HStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("You")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(rpsGame.localChoice?.emoji ?? "❔")
                    .font(.system(size: 52))

                Text(rpsGame.localChoice?.title ?? "Not chosen")
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                Text("Opponent")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if shouldRevealChoices {
                    Text(rpsGame.remoteChoice?.emoji ?? "❔")
                        .font(.system(size: 52))

                    Text(rpsGame.remoteChoice?.title ?? "Not chosen")
                        .font(.subheadline)
                } else {
                    Text("❔")
                        .font(.system(size: 52))

                    Text(rpsGame.remoteChoice == nil ? "Waiting" : "Chosen")
                        .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var choiceButtonsSection: some View {
        VStack(spacing: 12) {
            ForEach(RPSChoice.allCases) { choice in
                Button {
                    choose(choice)
                } label: {
                    HStack {
                        Text(choice.emoji)
                            .font(.largeTitle)

                        Text(choice.title)
                            .font(.headline)

                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(canChoose ? Color.blue.opacity(0.12) : Color.gray.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(!canChoose)
            }
        }
    }

    private var resultSection: some View {
        VStack(spacing: 8) {
            Text(resultText)
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            if rpsGame.localChoice != nil && rpsGame.remoteChoice == nil {
                Text("Waiting for opponent...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var playAgainSection: some View {
        if rpsGame.isRoundComplete {
            VStack(spacing: 8) {
                Button {
                    requestPlayAgain()
                } label: {
                    Text(localWantsPlayAgain ? "Waiting for opponent..." : "Play Again")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(localWantsPlayAgain)

                if remoteWantsPlayAgain && !localWantsPlayAgain {
                    Text("Opponent wants to play again")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if localWantsPlayAgain && !remoteWantsPlayAgain {
                    Text("Waiting for opponent to press Play Again")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var resultText: String {
        switch rpsGame.result {
        case .waiting:
            if rpsGame.localChoice == nil {
                return "Make your choice"
            } else {
                return "Choice locked"
            }

        case .draw:
            return "Draw"

        case .localWin:
            return "You win"

        case .remoteWin:
            return "You lose"
        }
    }

    private func choose(_ choice: RPSChoice) {
        guard canChoose else { return }

        rpsGame.setLocalChoice(choice)

        let payload = RPSChoicePayload(
            playerName: localPlayerName,
            choice: choice
        )

        do {
            let data = try JSONEncoder().encode(payload)

            let message = NearbyMessage(
                gameID: game.id,
                senderName: localPlayerName,
                type: .gameAction,
                payload: data
            )

            nearbyService.send(message)
        } catch {
            print("Failed to encode RPS choice: \(error)")
        }
    }

    private func handleReceivedMessage(_ message: NearbyMessage) {
        guard message.gameID == game.id else { return }

        switch message.type {
        case .gameAction:
            handleChoiceMessage(message)

        case .gameState:
            handleGameStateMessage(message)

        case .gameQuit:
            handleOpponentQuit(message)

        default:
            break
        }
    }

    private func handleChoiceMessage(_ message: NearbyMessage) {
        guard message.senderName != localPlayerName else { return }
        guard let data = message.payload else { return }

        do {
            let payload = try JSONDecoder().decode(RPSChoicePayload.self, from: data)
            rpsGame.setRemoteChoice(payload.choice)
        } catch {
            print("Failed to decode RPS choice: \(error)")
        }
    }

    private func handleGameStateMessage(_ message: NearbyMessage) {
        guard message.senderName != localPlayerName else { return }
        guard let data = message.payload else { return }

        do {
            _ = try JSONDecoder().decode(RPSPlayAgainPayload.self, from: data)
            remoteWantsPlayAgain = true
            tryStartNextRoundIfReady()
        } catch {
            print("Failed to decode RPS play again payload: \(error)")
        }
    }

    private func requestPlayAgain() {
        guard rpsGame.isRoundComplete else { return }

        localWantsPlayAgain = true

        let payload = RPSPlayAgainPayload(
            requestedBy: localPlayerName
        )

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
            print("Failed to encode RPS play again payload: \(error)")
        }

        tryStartNextRoundIfReady()
    }

    private func tryStartNextRoundIfReady() {
        guard localWantsPlayAgain && remoteWantsPlayAgain else { return }

        rpsGame.reset()

        localWantsPlayAgain = false
        remoteWantsPlayAgain = false
    }

    private func quitGame() {
        let payload = GameQuitPayload(
            playerName: localPlayerName,
            reason: "quit"
        )

        do {
            let data = try JSONEncoder().encode(payload)

            let message = NearbyMessage(
                gameID: game.id,
                senderName: localPlayerName,
                type: .gameQuit,
                payload: data
            )

            nearbyService.send(message)
        } catch {
            print("Failed to encode quit payload: \(error)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            nearbyService.stop()
            dismiss()
            onExitToHome()
        }
    }

    private func handleOpponentQuit(_ message: NearbyMessage) {
        guard message.senderName != localPlayerName else { return }
        showOpponentLeftAlert = true
    }
}

