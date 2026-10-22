import SwiftUI
import UIKit

struct DotsAndBoxesView: View {
    let game: Game
    @ObservedObject var nearbyService: NearbyService
    let localPlayerName: String
    let startPayload: DotsAndBoxesStartPayload
    let onExitToHome: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller: DotsAndBoxesMatchController
    @State private var pendingMove = false
    @State private var roundNumber = 0
    @State private var showResult = false
    @State private var showQuit = false
    @State private var isQuitting = false

    init(game: Game, nearbyService: NearbyService, localPlayerName: String,
         startPayload: DotsAndBoxesStartPayload, onExitToHome: @escaping () -> Void = {}) {
        self.game = game
        self.nearbyService = nearbyService
        self.localPlayerName = localPlayerName
        self.startPayload = startPayload
        self.onExitToHome = onExitToHome
        _controller = StateObject(wrappedValue: DotsAndBoxesMatchController(
            playerOneID: startPayload.playerOneID, playerTwoID: startPayload.playerTwoID,
            initialState: startPayload.initialState
        ))
    }

    var body: some View {
        ZStack {
            DotsAndBoxesGameScreen(
                controller: controller, gameTitle: game.title,
                firstPlayer: .init(id: localPlayerID, name: localPlayerName, badge: "YOU"),
                secondPlayer: .init(id: opponentID, name: opponentName, badge: "OPPONENT"),
                statusText: statusText, isInteractionEnabled: canPlay, showsProgress: pendingMove,
                onEdgeSelected: selectEdge, onQuitRequested: { showQuit = true }
            )
            if showResult { resultOverlay.zIndex(10) }
            if isQuitting { Color.black.opacity(0.72).ignoresSafeArea().overlay(ProgressView("Leaving game…").tint(.white)).zIndex(20) }
        }
        .alert("Quit game?", isPresented: $showQuit) {
            Button("Quit Game", role: .destructive, action: quitGame)
            Button("Cancel", role: .cancel) {}
        } message: { Text("You and your opponent will return to the main screen.") }
        .onReceive(nearbyService.$lastReceivedMessage) { handleIncoming($0) }
        .task(id: controller.state.isFinished) {
            showResult = false
            guard controller.state.isFinished else { return }
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) { showResult = true }
        }
    }

    private func selectEdge(_ edge: DotsAndBoxesEdge) {
        guard canPlay else { return }
        if isHost {
            let result = controller.play(edge: edge, by: localPlayerID)
            if result.didPlaceEdge { broadcastState(); moveHaptic(result) }
        } else {
            let payload = DotsAndBoxesMovePayload(sessionID: startPayload.sessionID, playerID: localPlayerID,
                                                  edge: edge, turnID: controller.state.turnID)
            guard let data = try? JSONEncoder().encode(payload) else { return }
            pendingMove = true
            nearbyService.send(.init(gameID: game.id, senderName: localPlayerName, type: .gameAction, payload: data))
        }
    }

    private func handleIncoming(_ message: NearbyMessage?) {
        guard let message, message.gameID == game.id else { return }
        switch message.type {
        case .gameAction: handleAction(message)
        case .gameState: handleState(message)
        case .rematch: handleReset(message)
        case .gameQuit: opponentQuit()
        default: break
        }
    }

    private func handleAction(_ message: NearbyMessage) {
        guard isHost, let data = message.payload,
              let payload = try? JSONDecoder().decode(DotsAndBoxesMovePayload.self, from: data),
              payload.sessionID == startPayload.sessionID else { return }
        let result = controller.play(edge: payload.edge, by: payload.playerID, turnID: payload.turnID)
        if result.didPlaceEdge { broadcastState(); moveHaptic(result) }
    }

    private func handleState(_ message: NearbyMessage) {
        guard let data = message.payload,
              let payload = try? JSONDecoder().decode(DotsAndBoxesStatePayload.self, from: data),
              payload.sessionID == startPayload.sessionID else { return }
        roundNumber = max(roundNumber, payload.roundNumber)
        pendingMove = false
        controller.applyRemoteState(payload.state)
    }

    private func broadcastState() {
        let payload = DotsAndBoxesStatePayload(sessionID: startPayload.sessionID, roundNumber: roundNumber, state: controller.state)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        nearbyService.send(.init(gameID: game.id, senderName: localPlayerName, type: .gameState, payload: data))
    }

    private func requestPlayAgain() {
        showResult = false
        if isHost { startNextRound(roundNumber + 1) }
        else {
            let payload = DotsAndBoxesResetPayload(sessionID: startPayload.sessionID, requestedRoundNumber: roundNumber + 1)
            guard let data = try? JSONEncoder().encode(payload) else { return }
            nearbyService.send(.init(gameID: game.id, senderName: localPlayerName, type: .rematch, payload: data))
        }
    }

    private func handleReset(_ message: NearbyMessage) {
        guard isHost, let data = message.payload,
              let payload = try? JSONDecoder().decode(DotsAndBoxesResetPayload.self, from: data),
              payload.sessionID == startPayload.sessionID else { return }
        startNextRound(max(roundNumber + 1, payload.requestedRoundNumber))
    }

    private func startNextRound(_ next: Int) {
        roundNumber = next
        let starter = next.isMultiple(of: 2) ? startPayload.playerOneID : startPayload.playerTwoID
        controller.reset(startingPlayerID: starter)
        broadcastState()
    }

    private func moveHaptic(_ result: DotsAndBoxesMoveResult) {
        switch result {
        case .scored, .finished: UINotificationFeedbackGenerator().notificationOccurred(.success)
        default: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func quitGame() {
        guard !isQuitting else { return }
        isQuitting = true
        nearbyService.send(.init(gameID: game.id, senderName: localPlayerName, type: .gameQuit))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            nearbyService.stop(); dismiss(); onExitToHome(); isQuitting = false
        }
    }
    private func opponentQuit() { nearbyService.stop(); dismiss(); onExitToHome() }

    private var localPlayerID: String { nearbyService.localPlayerID }
    private var opponentID: String { localPlayerID == startPayload.playerOneID ? startPayload.playerTwoID : startPayload.playerOneID }
    private var opponentName: String { localPlayerID == startPayload.playerOneID ? startPayload.playerTwoName : startPayload.playerOneName }
    private var isHost: Bool { (nearbyService.lobbySession?.hostPlayerID ?? startPayload.playerOneID) == localPlayerID }
    private var canPlay: Bool { !controller.state.isFinished && !pendingMove && controller.state.activePlayerID == localPlayerID }
    private var statusText: String {
        if controller.state.isFinished { return "Round complete" }
        return canPlay ? "Your turn" : "\(opponentName)'s turn"
    }
    private var resultOverlay: some View {
        let local = controller.state.score(for: localPlayerID), other = controller.state.score(for: opponentID)
        return DotsAndBoxesResultOverlay(
            title: local == other ? "It's a Draw!" : (local > other ? "You Win!" : "\(opponentName) Wins"),
            subtitle: "Every box has been claimed.", firstName: localPlayerName, secondName: opponentName,
            firstScore: local, secondScore: other, onPlayAgain: requestPlayAgain, onQuit: quitGame
        )
    }
}
