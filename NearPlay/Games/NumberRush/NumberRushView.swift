//
//  NumberRushView.swift
//  NearPlay
//

import SwiftUI
import UIKit

struct NumberRushView: View {
    let game: Game
    @ObservedObject var nearbyService: NearbyService

    let localPlayerName: String
    let startPayload: NumberRushStartPayload
    let onExitToHome: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var rematchController: RematchController

    @State private var numberRushGame: NumberRushGame

    @State private var wrongNumber: Int?
    @State private var correctNumber: Int?
    @State private var pendingSelection = false

    @State private var showQuitConfirmation = false
    @State private var isQuitting = false
    @State private var showResultOverlay = false

    @State private var timeoutWorkItem: DispatchWorkItem?

    private let columnsCount = 10
    private let gridSpacing: CGFloat = 4

    init(
        game: Game,
        nearbyService: NearbyService,
        localPlayerName: String,
        startPayload: NumberRushStartPayload,
        onExitToHome: @escaping () -> Void = {}
    ) {
        self.game = game
        self.nearbyService = nearbyService
        self.localPlayerName = localPlayerName
        self.startPayload = startPayload
        self.onExitToHome = onExitToHome

        _numberRushGame = State(
            initialValue: NumberRushGame(
                playerOneID: startPayload.playerOneID,
                playerTwoID: startPayload.playerTwoID,
                shuffledNumbers: startPayload.shuffledNumbers,
                startingPlayerID: startPayload.startingPlayerID,
                baseTurnDuration: startPayload.turnDuration
            )
        )

        _rematchController = StateObject(
            wrappedValue: RematchController(
                gameID: game.id,
                sessionID: startPayload.sessionID,
                localPlayerID: nearbyService.localPlayerID,
                localPlayerName: localPlayerName,
                hostPlayerID:
                    nearbyService.lobbySession?.hostPlayerID ??
                    startPayload.playerOneID,
                nearbyService: nearbyService
            )
        )
    }

    var body: some View {
        ZStack {
            NumberRushTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                customHeader
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                targetSection
                    .padding(.horizontal, 18)
                    .padding(.top, 15)

                numberGrid
                    .padding(.horizontal, 10)
                    .padding(.top, 13)
                    .padding(.bottom, 10)

                playersTimerSection
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }

            if numberRushGame.state.isFinished &&
                showResultOverlay {
                GameResultOverlay(
                    result: localRoundResult,
                    title: resultTitle,
                    subtitle: resultSubtitle,
                    symbolName: resultSymbolName,
                    accentColor: resultAccentColor,
                    rematchState: rematchController.state,
                    onPrimaryAction: {
                        rematchController.performPrimaryAction()
                    },
                    onQuit: {
                        quitGame()
                    }
                )
                .zIndex(10)
            }

            if isQuitting {
                quittingOverlay
                    .zIndex(20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .alert(
            "Quit game?",
            isPresented: $showQuitConfirmation
        ) {
            Button("Quit Game", role: .destructive) {
                quitGame()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "You and your opponent will return to the main screen."
            )
        }
        .onAppear {
            scheduleHostTimeout()
        }
        .onDisappear {
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
        }
        .onReceive(
            nearbyService.$lastReceivedMessage
        ) { message in
            handleIncoming(message)
        }
        .onChange(
            of: rematchController.confirmedRoundNumber
        ) { _, confirmedRound in
            guard let confirmedRound else {
                return
            }

            showResultOverlay = false
            wrongNumber = nil
            correctNumber = nil
            pendingSelection = false

            if isLocalHost {
                let startingPlayerID =
                    confirmedRound.isMultiple(of: 2)
                    ? startPayload.playerTwoID
                    : startPayload.playerOneID

                numberRushGame.reset(
                    shuffledNumbers:
                        Array(1...100).shuffled(),
                    startingPlayerID: startingPlayerID
                )

                broadcastAuthoritativeState()
                scheduleHostTimeout()
            }

            rematchController.finishStartingRound()
        }
        .task(id: numberRushGame.state.isFinished) {
            showResultOverlay = false

            guard numberRushGame.state.isFinished else {
                return
            }

            try? await Task.sleep(
                nanoseconds: 900_000_000
            )

            guard !Task.isCancelled,
                  numberRushGame.state.isFinished else {
                return
            }

            withAnimation(
                .spring(
                    response: 0.40,
                    dampingFraction: 0.84
                )
            ) {
                showResultOverlay = true
            }
        }
    }

    // MARK: - Header

    private var customHeader: some View {
        HStack(spacing: 14) {
            Button {
                showQuitConfirmation = true
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.055))
                    }
                    .overlay {
                        Circle()
                            .stroke(
                                Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 3) {
                Text(game.title)
                    .font(
                        .system(
                            size: 23,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)

                Text(headerSubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(headerSubtitleColor)
                    .lineLimit(1)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.055))
                    .frame(width: 46, height: 46)

                Circle()
                    .stroke(
                        Color.white.opacity(0.12),
                        lineWidth: 1
                    )
                    .frame(width: 46, height: 46)

                Image(
                    systemName:
                        nearbyService.connectedPeers.isEmpty
                        ? "wifi.slash"
                        : "wifi"
                )
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(
                    nearbyService.connectedPeers.isEmpty
                    ? Color.orange
                    : Color.green
                )
            }
        }
    }

    private var headerSubtitle: String {
        if numberRushGame.state.isFinished {
            return "Round complete"
        }

        return isLocalTurn
            ? "Your turn"
            : "\(opponentName)'s turn"
    }

    private var headerSubtitleColor: Color {
        isLocalTurn
            ? NumberRushTheme.blue
            : NumberRushTheme.purple
    }

    // MARK: - Target

    private var targetSection: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        NumberRushTheme.blue.opacity(0.12)
                    )
                    .frame(width: 58, height: 58)

                Circle()
                    .stroke(
                        NumberRushTheme.primaryGradient,
                        lineWidth: 1.5
                    )
                    .frame(width: 58, height: 58)
                    .shadow(
                        color:
                            NumberRushTheme.blue.opacity(0.42),
                        radius: 10
                    )

                Text(
                    numberRushGame.state.isFinished
                    ? "✓"
                    : "\(numberRushGame.state.targetNumber)"
                )
                .font(
                    .system(
                        size: 24,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(
                    numberRushGame.state.isFinished
                    ? "Grid complete"
                    : "Find number"
                )
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.44))

                Text(
                    numberRushGame.state.isFinished
                    ? "Excellent!"
                    : "\(numberRushGame.state.targetNumber)"
                )
                .font(
                    .system(
                        size: 22,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("FOUND")
                    .font(
                        .system(
                            size: 11,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(Color.white.opacity(0.38))

                Text(
                    "\(numberRushGame.state.completedNumbers.count)/100"
                )
                .font(
                    .system(
                        size: 18,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(NumberRushTheme.purple)
                .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 78)
        .background {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(Color.white.opacity(0.028))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.09), lineWidth: 1)
        }
    }

    // MARK: - Grid

    private var numberGrid: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let totalSpacing =
                CGFloat(columnsCount - 1) * gridSpacing
            let cellSize =
                (availableWidth - totalSpacing) /
                CGFloat(columnsCount)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(
                        .fixed(cellSize),
                        spacing: gridSpacing
                    ),
                    count: columnsCount
                ),
                spacing: gridSpacing
            ) {
                ForEach(
                    numberRushGame.state.shuffledNumbers,
                    id: \.self
                ) { number in
                    numberCell(
                        number,
                        size: cellSize
                    )
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .top
            )
        }
    }

    private func numberCell(
        _ number: Int,
        size: CGFloat
    ) -> some View {
        let isCompleted =
            numberRushGame
                .state
                .completedNumbers
                .contains(number)

        let isWrong = wrongNumber == number
        let isCorrect = correctNumber == number

        return Button {
            selectNumber(number)
        } label: {
            ZStack {
                RoundedRectangle(
                    cornerRadius: max(6, size * 0.22),
                    style: .continuous
                )
                .fill(
                    cellBackground(
                        completed: isCompleted,
                        wrong: isWrong,
                        correct: isCorrect
                    )
                )

                RoundedRectangle(
                    cornerRadius: max(6, size * 0.22),
                    style: .continuous
                )
                .stroke(
                    cellBorder(
                        completed: isCompleted,
                        wrong: isWrong,
                        correct: isCorrect
                    ),
                    lineWidth:
                        isCompleted || isWrong || isCorrect
                        ? 1.5
                        : 0.7
                )

                if isCompleted {
                    Circle()
                        .stroke(
                            NumberRushTheme.primaryGradient,
                            lineWidth: 2
                        )
                        .padding(3)
                        .shadow(
                            color:
                                NumberRushTheme.blue.opacity(0.70),
                            radius: 5
                        )
                }

                Text("\(number)")
                    .font(
                        .system(
                            size:
                                number == 100
                                ? size * 0.31
                                : size * 0.37,
                            weight:
                                isCompleted
                                ? .bold
                                : .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        numberTextColor(
                            completed: isCompleted,
                            wrong: isWrong
                        )
                    )
                    .minimumScaleFactor(0.7)
            }
            .frame(width: size, height: size)
            .scaleEffect(isWrong ? 0.86 : 1)
            .rotationEffect(.degrees(isWrong ? -4 : 0))
            .animation(
                .spring(
                    response: 0.24,
                    dampingFraction: 0.55
                ),
                value: isWrong
            )
        }
        .buttonStyle(.plain)
        .disabled(
            isCompleted ||
            !isLocalTurn ||
            numberRushGame.state.isFinished ||
            pendingSelection
        )
    }

    // MARK: - Players and timer

    private var playersTimerSection: some View {
        GeometryReader { geometry in
            let compactWidth: CGFloat = 104
            let spacing: CGFloat = 10
            let expandedWidth =
                max(
                    geometry.size.width -
                    compactWidth -
                    spacing,
                    compactWidth
                )

            HStack(spacing: spacing) {
                NumberRushPlayerTimerCard(
                    playerName: startPayload.playerOneName,
                    score:
                        numberRushGame
                        .state
                        .scores[startPayload.playerOneID] ?? 0,
                    isLocalPlayer:
                        startPayload.playerOneID == localPlayerID,
                    isActive:
                        numberRushGame.state.activePlayerID ==
                        startPayload.playerOneID,
                    turnStartedAt:
                        numberRushGame.state.turnStartedAt,
                    turnDuration:
                        numberRushGame.state.turnDuration,
                    accentColor: NumberRushTheme.blue
                )
                .frame(
                    width:
                        numberRushGame.state.activePlayerID ==
                        startPayload.playerOneID
                        ? expandedWidth
                        : compactWidth
                )

                NumberRushPlayerTimerCard(
                    playerName: startPayload.playerTwoName,
                    score:
                        numberRushGame
                        .state
                        .scores[startPayload.playerTwoID] ?? 0,
                    isLocalPlayer:
                        startPayload.playerTwoID == localPlayerID,
                    isActive:
                        numberRushGame.state.activePlayerID ==
                        startPayload.playerTwoID,
                    turnStartedAt:
                        numberRushGame.state.turnStartedAt,
                    turnDuration:
                        numberRushGame.state.turnDuration,
                    accentColor: NumberRushTheme.purple
                )
                .frame(
                    width:
                        numberRushGame.state.activePlayerID ==
                        startPayload.playerTwoID
                        ? expandedWidth
                        : compactWidth
                )
            }
            .animation(
                .spring(
                    response: 0.48,
                    dampingFraction: 0.84
                ),
                value: numberRushGame.state.activePlayerID
            )
        }
        .frame(height: 76)
    }

    // MARK: - Networking actions

    private func selectNumber(
        _ number: Int
    ) {
        guard isLocalTurn,
              !pendingSelection,
              !numberRushGame.state.isFinished else {
            return
        }

        pendingSelection = true

        let payload = NumberRushSelectionPayload(
            sessionID: startPayload.sessionID,
            playerID: localPlayerID,
            selectedNumber: number,
            turnID: numberRushGame.state.turnID
        )

        if isLocalHost {
            resolveSelection(payload)
        } else {
            do {
                let data = try JSONEncoder().encode(payload)

                nearbyService.send(
                    NearbyMessage(
                        gameID: game.id,
                        senderName: localPlayerName,
                        type: .gameAction,
                        payload: data
                    )
                )
            } catch {
                pendingSelection = false
                nearbyService.errorMessage =
                    "Failed to send your number."
            }
        }
    }

    private func resolveSelection(
        _ selection: NumberRushSelectionPayload
    ) {
        guard isLocalHost,
              selection.sessionID == startPayload.sessionID else {
            pendingSelection = false
            return
        }

        let outcome = numberRushGame.select(
            number: selection.selectedNumber,
            by: selection.playerID,
            turnID: selection.turnID
        )

        switch outcome {
        case .ignored:
            break

        case .correct(let number),
             .finished(let number):
            showCorrectFeedback(number)

        case .wrong(let number):
            showWrongFeedback(number)
        }

        pendingSelection = false
        broadcastAuthoritativeState()
        scheduleHostTimeout()
    }

    private func broadcastAuthoritativeState() {
        guard isLocalHost else {
            return
        }

        let payload = NumberRushStatePayload(
            sessionID: startPayload.sessionID,
            state: numberRushGame.state
        )

        do {
            let data = try JSONEncoder().encode(payload)

            nearbyService.send(
                NearbyMessage(
                    gameID: game.id,
                    senderName: localPlayerName,
                    type: .gameState,
                    payload: data
                )
            )
        } catch {
            nearbyService.errorMessage =
                "Failed to synchronize Number Rush."
        }
    }

    private func scheduleHostTimeout() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil

        guard isLocalHost,
              !numberRushGame.state.isFinished else {
            return
        }

        let expectedTurnID =
            numberRushGame.state.turnID

        let delay = max(
            numberRushGame
                .state
                .deadline
                .timeIntervalSinceNow,
            0
        )

        let workItem = DispatchWorkItem {
            guard numberRushGame.state.turnID ==
                    expectedTurnID else {
                return
            }

            let changed = numberRushGame.expireTurn(
                expectedTurnID: expectedTurnID
            )

            guard changed else {
                return
            }

            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)

            pendingSelection = false
            broadcastAuthoritativeState()
            scheduleHostTimeout()
        }

        timeoutWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: workItem
        )
    }

    // MARK: - Incoming messages

    private func handleIncoming(
        _ message: NearbyMessage?
    ) {
        guard let message,
              message.gameID == game.id else {
            return
        }

        if rematchController.handleIncoming(message) {
            return
        }

        switch message.type {
        case .gameAction:
            guard isLocalHost,
                  let data = message.payload,
                  let payload =
                    try? JSONDecoder().decode(
                        NumberRushSelectionPayload.self,
                        from: data
                    ) else {
                return
            }

            resolveSelection(payload)

        case .gameState:
            guard !isLocalHost,
                  let data = message.payload,
                  let payload =
                    try? JSONDecoder().decode(
                        NumberRushStatePayload.self,
                        from: data
                    ),
                  payload.sessionID ==
                    startPayload.sessionID else {
                return
            }

            applyRemoteState(payload.state)

        case .gameQuit:
            handleOpponentQuit()

        default:
            break
        }
    }

    private func applyRemoteState(
        _ newState: NumberRushGameState
    ) {
        let oldTarget =
            numberRushGame.state.targetNumber
        let oldActivePlayer =
            numberRushGame.state.activePlayerID

        withAnimation(
            .spring(
                response: 0.32,
                dampingFraction: 0.80
            )
        ) {
            numberRushGame.applyRemoteState(newState)
        }

        pendingSelection = false

        if newState.targetNumber > oldTarget {
            showCorrectFeedback(newState.targetNumber - 1)
        } else if newState.activePlayerID != oldActivePlayer {
            UINotificationFeedbackGenerator()
                .notificationOccurred(.warning)
        }
    }

    // MARK: - Feedback

    private func showCorrectFeedback(
        _ number: Int
    ) {
        correctNumber = number

        UIImpactFeedbackGenerator(style: .light)
            .impactOccurred()

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.30
        ) {
            if correctNumber == number {
                correctNumber = nil
            }
        }
    }

    private func showWrongFeedback(
        _ number: Int
    ) {
        wrongNumber = number

        UINotificationFeedbackGenerator()
            .notificationOccurred(.error)

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.38
        ) {
            withAnimation(.easeOut(duration: 0.18)) {
                if wrongNumber == number {
                    wrongNumber = nil
                }
            }
        }
    }

    // MARK: - Quit

    private func quitGame() {
        guard !isQuitting else {
            return
        }

        isQuitting = true
        timeoutWorkItem?.cancel()

        let payload = GameQuitPayload(
            playerName: localPlayerName,
            reason: "quit"
        )

        let data = try? JSONEncoder().encode(payload)

        nearbyService.send(
            NearbyMessage(
                gameID: game.id,
                senderName: localPlayerName,
                type: .gameQuit,
                payload: data
            )
        )

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.4
        ) {
            nearbyService.stop()
            dismiss()
            onExitToHome()
            isQuitting = false
        }
    }

    private func handleOpponentQuit() {
        timeoutWorkItem?.cancel()
        nearbyService.stop()
        dismiss()
        onExitToHome()
    }

    private var quittingOverlay: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.15)

                Text("Leaving game…")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .background {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .fill(NumberRushTheme.cardBackground)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(
                    NumberRushTheme.primaryGradient,
                    lineWidth: 1.2
                )
            }
        }
    }

    // MARK: - Result

    private var localRoundResult: GameRoundResult {
        let localScore =
            numberRushGame.state.scores[localPlayerID] ?? 0
        let remoteScore =
            numberRushGame.state.scores[opponentID] ?? 0

        if localScore == remoteScore {
            return .draw
        }

        return localScore > remoteScore
            ? .win
            : .loss
    }

    private var resultTitle: String {
        switch localRoundResult {
        case .win:
            return "You Win!"
        case .loss:
            return "You Lose"
        case .draw:
            return "It's a Draw!"
        }
    }

    private var resultSubtitle: String {
        let localScore =
            numberRushGame.state.scores[localPlayerID] ?? 0
        let remoteScore =
            numberRushGame.state.scores[opponentID] ?? 0

        return "\(localScore) – \(remoteScore) against \(opponentName)."
    }

    private var resultSymbolName: String {
        switch localRoundResult {
        case .win:
            return "crown.fill"
        case .loss:
            return "flag.checkered"
        case .draw:
            return "equal"
        }
    }

    private var resultAccentColor: Color {
        switch localRoundResult {
        case .win:
            return NumberRushTheme.blue
        case .loss:
            return NumberRushTheme.purple
        case .draw:
            return Color.white.opacity(0.78)
        }
    }

    // MARK: - Helpers

    private var localPlayerID: String {
        nearbyService.localPlayerID
    }

    private var isLocalHost: Bool {
        nearbyService.lobbySession?.hostPlayerID ==
        localPlayerID
    }

    private var isLocalTurn: Bool {
        numberRushGame.state.activePlayerID ==
        localPlayerID
    }

    private var opponentID: String {
        startPayload.playerOneID == localPlayerID
            ? startPayload.playerTwoID
            : startPayload.playerOneID
    }

    private var opponentName: String {
        startPayload.playerOneID == localPlayerID
            ? startPayload.playerTwoName
            : startPayload.playerOneName
    }

    private func cellBackground(
        completed: Bool,
        wrong: Bool,
        correct: Bool
    ) -> Color {
        if wrong {
            return Color.red.opacity(0.16)
        }

        if correct {
            return Color.green.opacity(0.18)
        }

        if completed {
            return NumberRushTheme.blue.opacity(0.10)
        }

        return Color.white.opacity(0.028)
    }

    private func cellBorder(
        completed: Bool,
        wrong: Bool,
        correct: Bool
    ) -> Color {
        if wrong {
            return Color.red.opacity(0.90)
        }

        if correct {
            return Color.green.opacity(0.95)
        }

        if completed {
            return NumberRushTheme.blue.opacity(0.72)
        }

        return Color.white.opacity(0.09)
    }

    private func numberTextColor(
        completed: Bool,
        wrong: Bool
    ) -> Color {
        if wrong {
            return Color.red.opacity(0.95)
        }

        if completed {
            return Color.white.opacity(0.44)
        }

        return Color.white.opacity(0.88)
    }
}

// MARK: - Theme

enum NumberRushTheme {
    static let backgroundTop = Color(
        red: 11.0 / 255.0,
        green: 15.0 / 255.0,
        blue: 21.0 / 255.0
    )

    static let backgroundBottom = Color(
        red: 7.0 / 255.0,
        green: 16.0 / 255.0,
        blue: 24.0 / 255.0
    )

    static let blue = Color(
        red: 0.05,
        green: 0.70,
        blue: 1.00
    )

    static let purple = Color(
        red: 0.66,
        green: 0.25,
        blue: 1.00
    )

    static let primaryGradient = LinearGradient(
        colors: [
            blue,
            Color(red: 0.27, green: 0.36, blue: 1.00),
            purple
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cardBackground = LinearGradient(
        colors: [
            Color(
                red: 12.0 / 255.0,
                green: 20.0 / 255.0,
                blue: 35.0 / 255.0
            ),
            Color(
                red: 7.0 / 255.0,
                green: 13.0 / 255.0,
                blue: 25.0 / 255.0
            )
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let background = LinearGradient(
        colors: [
            backgroundTop,
            backgroundBottom
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
