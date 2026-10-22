import SwiftUI
import UIKit

struct DotsAndBoxesLocalView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PlayerProfile.nameKey) private var playerName = ""
    @StateObject private var controller: DotsAndBoxesMatchController
    @State private var roundNumber = 0
    @State private var showResult = false
    @State private var showQuit = false

    private static let one = "dots_local_one"
    private static let two = "dots_local_two"

    init(game: Game) {
        self.game = game
        _controller = StateObject(wrappedValue: DotsAndBoxesMatchController(
            playerOneID: Self.one, playerTwoID: Self.two,
            initialState: DotsAndBoxesGame.makeInitialState(startingPlayerID: Self.one)
        ))
    }

    var body: some View {
        ZStack {
            DotsAndBoxesGameScreen(
                controller: controller, gameTitle: game.title,
                firstPlayer: .init(id: Self.one, name: firstName, badge: "YOU"),
                secondPlayer: .init(id: Self.two, name: "Guest", badge: "GUEST"),
                statusText: statusText, isInteractionEnabled: !controller.state.isFinished,
                showsProgress: false, onEdgeSelected: play, onQuitRequested: { showQuit = true }
            )
            if showResult { resultOverlay.zIndex(10) }
        }
        .alert("Quit game?", isPresented: $showQuit) {
            Button("Quit Game", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The current round will be discarded.") }
        .task(id: controller.state.isFinished) {
            showResult = false
            guard controller.state.isFinished else { return }
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) { showResult = true }
        }
    }

    private func play(_ edge: DotsAndBoxesEdge) {
        let result = controller.play(edge: edge, by: controller.state.activePlayerID)
        haptic(result)
    }

    private func haptic(_ result: DotsAndBoxesMoveResult) {
        switch result {
        case .scored, .finished: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .placed: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        default: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func playAgain() {
        roundNumber += 1
        showResult = false
        controller.reset(startingPlayerID: roundNumber.isMultiple(of: 2) ? Self.one : Self.two)
    }

    private var firstName: String { playerName.trimmingCharacters(in: .whitespaces).isEmpty ? "You" : playerName }
    private var statusText: String {
        if controller.state.isFinished { return "Round complete" }
        return controller.state.activePlayerID == Self.one ? "\(firstName)'s turn" : "Guest's turn"
    }
    private var resultOverlay: some View {
        let one = controller.state.score(for: Self.one), two = controller.state.score(for: Self.two)
        return DotsAndBoxesResultOverlay(
            title: one == two ? "It's a Draw!" : (one > two ? "\(firstName) Wins!" : "Guest Wins!"),
            subtitle: "Every box has been claimed.", firstName: firstName, secondName: "Guest",
            firstScore: one, secondScore: two, onPlayAgain: playAgain, onQuit: { dismiss() }
        )
    }
}
