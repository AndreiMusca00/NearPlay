import SwiftUI
import UIKit

struct DotsAndBoxesComputerView: View {
    let game: Game
    let difficulty: GameAIDifficulty
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PlayerProfile.nameKey) private var playerName = ""
    @StateObject private var controller: DotsAndBoxesMatchController
    @State private var roundNumber = 0
    @State private var computerThinking = false
    @State private var showResult = false
    @State private var showQuit = false
    @State private var computerTask: Task<Void, Never>?

    private static let human = "dots_human"
    private static let computer = "dots_computer"

    init(game: Game, difficulty: GameAIDifficulty) {
        self.game = game
        self.difficulty = difficulty
        _controller = StateObject(wrappedValue: DotsAndBoxesMatchController(
            playerOneID: Self.human, playerTwoID: Self.computer,
            initialState: DotsAndBoxesGame.makeInitialState(startingPlayerID: Self.human)
        ))
    }

    var body: some View {
        ZStack {
            DotsAndBoxesGameScreen(
                controller: controller, gameTitle: game.title,
                firstPlayer: .init(id: Self.human, name: humanName, badge: "YOU"),
                secondPlayer: .init(id: Self.computer, name: "Computer", badge: difficulty.title.uppercased()),
                statusText: statusText, isInteractionEnabled: canPlay,
                showsProgress: computerThinking, onEdgeSelected: humanPlay, onQuitRequested: { showQuit = true }
            )
            if showResult { resultOverlay.zIndex(10) }
        }
        .alert("Quit game?", isPresented: $showQuit) {
            Button("Quit Game", role: .destructive) { computerTask?.cancel(); dismiss() }
            Button("Cancel", role: .cancel) {}
        }
        .onDisappear { computerTask?.cancel() }
        .task(id: controller.state.isFinished) {
            showResult = false
            guard controller.state.isFinished else { return }
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) { showResult = true }
        }
    }

    private func humanPlay(_ edge: DotsAndBoxesEdge) {
        guard canPlay else { return }
        let result = controller.play(edge: edge, by: Self.human)
        if case .scored = result { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        else { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        scheduleComputerIfNeeded()
    }

    private func scheduleComputerIfNeeded() {
        computerTask?.cancel()
        guard !controller.state.isFinished, controller.state.activePlayerID == Self.computer else { return }
        computerThinking = true
        computerTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 520_000_000)
            guard !Task.isCancelled,
                  let edge = DotsAndBoxesAI.chooseEdge(state: controller.state, difficulty: difficulty) else {
                computerThinking = false; return
            }
            let result = controller.play(edge: edge, by: Self.computer)
            computerThinking = false
            if case .scored = result { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
            if !controller.state.isFinished && controller.state.activePlayerID == Self.computer { scheduleComputerIfNeeded() }
        }
    }

    private func playAgain() {
        computerTask?.cancel(); roundNumber += 1; showResult = false; computerThinking = false
        controller.reset(startingPlayerID: roundNumber.isMultiple(of: 2) ? Self.human : Self.computer)
        scheduleComputerIfNeeded()
    }

    private var canPlay: Bool { !controller.state.isFinished && !computerThinking && controller.state.activePlayerID == Self.human }
    private var humanName: String { playerName.trimmingCharacters(in: .whitespaces).isEmpty ? "You" : playerName }
    private var statusText: String {
        if controller.state.isFinished { return "Round complete" }
        return canPlay ? "Your turn" : "Computer thinking"
    }
    private var resultOverlay: some View {
        let human = controller.state.score(for: Self.human), computer = controller.state.score(for: Self.computer)
        return DotsAndBoxesResultOverlay(
            title: human == computer ? "It's a Draw!" : (human > computer ? "You Win!" : "Computer Wins"),
            subtitle: human > computer ? "You controlled the board." : "Every line changes the endgame.",
            firstName: humanName, secondName: "Computer", firstScore: human, secondScore: computer,
            onPlayAgain: playAgain, onQuit: { dismiss() }
        )
    }
}
