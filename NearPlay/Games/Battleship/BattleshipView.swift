//
//  BattleshipView.swift
//  NearPlay
//

import SwiftUI
import UIKit

struct BattleshipView: View {
    let game: Game

    @ObservedObject
    var nearbyService: NearbyService

    let localPlayerName: String
    let startPayload: BattleshipStartPayload
    let onExitToHome: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var rematchController: RematchController

    @State private var battleship = BattleshipGame()


    @State private var pendingAttack = false
    @State private var showQuitConfirmation = false
    @State private var isQuitting = false
    @State private var showResultOverlay = false

    @State private var feedbackText: String?
    @State private var feedbackTone:
        BattleshipFeedbackTone = .neutral

    init(
        game: Game,
        nearbyService: NearbyService,
        localPlayerName: String,
        startPayload: BattleshipStartPayload,
        onExitToHome: @escaping () -> Void = {}
    ) {
        self.game = game
        self.nearbyService = nearbyService
        self.localPlayerName = localPlayerName
        self.startPayload = startPayload
        self.onExitToHome = onExitToHome

        _rematchController = StateObject(
            wrappedValue: RematchController(
                gameID: game.id,
                sessionID: startPayload.sessionID,
                localPlayerID:
                    nearbyService.localPlayerID,
                localPlayerName: localPlayerName,
                hostPlayerID:
                    nearbyService
                    .lobbySession?
                    .hostPlayerID ??
                    startPayload.playerOneID,
                nearbyService: nearbyService
            )
        )
    }

    var body: some View {
        ZStack {
            BattleshipTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                GeometryReader { geometry in
                    Group {
                        switch battleship.phase {
                        case .placement, .waiting:
                            BattleshipPlacementView(
                                ownBoard: battleship.ownBoard,
                                localReady: battleship.localReady,
                                opponentReady:
                                    battleship.opponentReady,
                                onShipDropped:
                                    placeOrMoveShip,
                                onPlacedShipTap:
                                    rotatePlacedShip,
                                onRandomize:
                                    randomizeFleet,
                                onReady: markReady
                            )

                        case .battle:
                            BattleshipBattleView(
                                ownBoard: battleship.ownBoard,
                                opponentBoard:
                                    battleship.opponentBoard,
                                isLocalTurn: isLocalTurn,
                                localPlayerName:
                                    localPlayerName,
                                opponentName: opponentName,
                                pendingAttack: pendingAttack,
                                onAttack: sendAttack
                            )

                        case .finished:
                            BattleshipBattleView(
                                ownBoard: battleship.ownBoard,
                                opponentBoard:
                                    battleship.opponentBoard,
                                isLocalTurn: false,
                                localPlayerName:
                                    localPlayerName,
                                opponentName: opponentName,
                                pendingAttack: false,
                                onAttack: { _ in }
                            )
                        }
                    }
                    .frame(
                        width:
                            max(
                                geometry.size.width - 28,
                                0
                            ),
                        height:
                            max(
                                geometry.size.height - 10,
                                0
                            ),
                        alignment: .top
                    )
                    .offset(x: 14)
                }
            }

            if let feedbackText {
                feedbackBanner(
                    feedbackText,
                    tone: feedbackTone
                )
                .transition(
                    .move(edge: .top)
                    .combined(with: .opacity)
                )
                .zIndex(8)
            }

            if battleship.phase == .finished &&
                showResultOverlay {
                GameResultOverlay(
                    result: roundResult,
                    title: resultTitle,
                    subtitle: resultSubtitle,
                    symbolName: resultSymbol,
                    accentColor: resultColor,
                    rematchState:
                        rematchController.state,
                    onPrimaryAction: {
                        rematchController
                            .performPrimaryAction()
                    },
                    onQuit: quitGame
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
            Button(
                "Quit Game",
                role: .destructive,
                action: quitGame
            )

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "You and your opponent will return to the main screen."
            )
        }
        .onReceive(
            nearbyService.$lastReceivedMessage
        ) { message in
            handleIncoming(message)
        }
        .onChange(
            of: rematchController.confirmedRoundNumber
        ) { confirmedRound in
            guard let confirmedRound else {
                return
            }

            withAnimation(.easeOut(duration: 0.20)) {
                showResultOverlay = false
            }

            battleship.resetForRematch()
            pendingAttack = false
            feedbackText = nil

            // Alternarea jucătorului care începe este calculată
            // când ambii dau Ready pentru noua rundă.
            _ = confirmedRound

            rematchController.finishStartingRound()
        }
        .task(id: battleship.phase) {
            showResultOverlay = false

            guard battleship.phase == .finished else {
                return
            }

            try? await Task.sleep(
                nanoseconds: 850_000_000
            )

            guard !Task.isCancelled,
                  battleship.phase == .finished else {
                return
            }

            withAnimation(
                .spring(
                    response: 0.38,
                    dampingFraction: 0.84
                )
            ) {
                showResultOverlay = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                showQuitConfirmation = true
            } label: {
                Image(systemName: "chevron.left")
                    .font(
                        .system(
                            size: 20,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background {
                        Circle()
                            .fill(
                                Color.white.opacity(0.055)
                            )
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
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(headerColor)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(
                        Color.white.opacity(0.055)
                    )
                    .frame(width: 46, height: 46)

                Circle()
                    .stroke(
                        Color.white.opacity(0.12),
                        lineWidth: 1
                    )
                    .frame(width: 46, height: 46)

                Image(systemName: "ferry.fill")
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        BattleshipTheme.primaryGradient
                    )
            }
        }
    }

    private var headerSubtitle: String {
        switch battleship.phase {
        case .placement:
            return "Deploy your fleet"

        case .waiting:
            return "Waiting for both fleets"

        case .battle:
            return isLocalTurn
                ? "Your turn"
                : "\(opponentName)'s turn"

        case .finished:
            return "Battle complete"
        }
    }

    private var headerColor: Color {
        isLocalTurn
            ? BattleshipTheme.cyan
            : BattleshipTheme.purple
    }

    // MARK: - Placement

    private func placeOrMoveShip(
        _ definition: BattleshipShipDefinition,
        at coordinate: BattleshipCoordinate
    ) {
        guard !battleship.localReady else { return }

        let currentOrientation =
            battleship.placedShip(id: definition.id)?.orientation ?? .horizontal

        let placed = battleship.placeOrMoveShip(
            definition: definition,
            preferredOrigin: coordinate,
            orientation: currentOrientation
        )

        if placed {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func rotatePlacedShip(_ shipID: String) {
        guard !battleship.localReady else { return }

        let rotated = battleship.rotateShipAutomatically(id: shipID)

        if rotated {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    private func randomizeFleet() {
        guard !battleship.localReady else {
            return
        }

        var attempts = 0

        repeat {
            battleship.resetForRematch()
            attempts += 1

            for ship in
                BattleshipShipDefinition.standardFleet {
                var placed = false
                var localAttempts = 0

                while !placed && localAttempts < 200 {
                    localAttempts += 1

                    let randomOrientation:
                        BattleshipOrientation =
                        Bool.random()
                        ? .horizontal
                        : .vertical

                    let coordinate =
                        BattleshipCoordinate(
                            row:
                                Int.random(
                                    in:
                                        0..<BattleshipGame
                                        .boardSize
                                ),
                            column:
                                Int.random(
                                    in:
                                        0..<BattleshipGame
                                        .boardSize
                                )
                        )

                    do {
                        placed = battleship.placeOrMoveShip(
                            definition: ship,
                            preferredOrigin: coordinate,
                            orientation: randomOrientation
                        )
                    } catch {
                        continue
                    }
                }
            }
        } while
            !battleship.ownBoard.allShipsPlaced &&
            attempts < 20

        UIImpactFeedbackGenerator(
            style: .medium
        )
        .impactOccurred()
    }

    private func markReady() {
        guard battleship
                .ownBoard
                .allShipsPlaced,
              !battleship.localReady else {
            return
        }

        battleship.markLocalReady()

        sendPayload(
            BattleshipReadyPayload(
                sessionID: startPayload.sessionID,
                playerID: localPlayerID
            ),
            type: .gameAction
        )

        UINotificationFeedbackGenerator()
            .notificationOccurred(.success)

        beginBattleIfHostCanStart()
    }

    private func beginBattleIfHostCanStart() {
        guard isLocalHost,
              battleship.localReady,
              battleship.opponentReady,
              battleship.phase != .battle else {
            return
        }

        let startingPlayerID =
            startPayload.initialStartingPlayerID

        let payload =
            BattleshipBattleStartedPayload(
                sessionID:
                    startPayload.sessionID,
                startingPlayerID:
                    startingPlayerID,
                turnID: UUID()
            )

        battleship.beginBattle(
            startingPlayerID:
                payload.startingPlayerID,
            turnID: payload.turnID
        )

        sendPayload(
            payload,
            type: .gameState
        )

        showFeedback(
            "Battle started",
            tone: .success
        )
    }

    // MARK: - Attack

    private func sendAttack(
        _ coordinate: BattleshipCoordinate
    ) {
        guard isLocalTurn,
              !pendingAttack,
              battleship
                .opponentBoard
                .marks[coordinate] == nil,
              let turnID =
                battleship.turnID else {
            return
        }

        pendingAttack = true

        let payload =
            BattleshipAttackPayload(
                sessionID:
                    startPayload.sessionID,
                attackerPlayerID:
                    localPlayerID,
                coordinate: coordinate,
                turnID: turnID
            )

        sendPayload(
            payload,
            type: .gameAction
        )
    }

    private func resolveIncomingAttack(
        _ payload: BattleshipAttackPayload
    ) {
        guard payload.sessionID ==
                startPayload.sessionID,
              payload.attackerPlayerID ==
                opponentID,
              battleship.phase == .battle,
              battleship.activePlayerID ==
                payload.attackerPlayerID,
              battleship.turnID ==
                payload.turnID,
              let result =
                battleship.receiveAttack(
                    at: payload.coordinate
                ) else {
            return
        }

        let sunkCoordinates:
            [BattleshipCoordinate]

        if let sunkShipID =
            result.sunkShipID,
           let sunkShip =
            battleship
                .ownBoard
                .ships
                .first(
                    where: {
                        $0.id == sunkShipID
                    }
                ) {
            sunkCoordinates =
                sunkShip.occupiedCoordinates
        } else {
            sunkCoordinates = []
        }

        let winnerPlayerID =
            result.outcome == .gameOver
            ? payload.attackerPlayerID
            : nil

        let nextTurnID = UUID()

        let response =
            BattleshipAttackResultPayload(
                sessionID:
                    startPayload.sessionID,
                attackerPlayerID:
                    payload.attackerPlayerID,
                defenderPlayerID:
                    localPlayerID,
                coordinate:
                    payload.coordinate,
                outcome:
                    result.outcome,
                sunkCoordinates:
                    sunkCoordinates,
                defenderRemainingShips:
                    battleship
                    .ownBoard
                    .remainingShips,
                nextPlayerID:
                    localPlayerID,
                nextTurnID:
                    nextTurnID,
                winnerPlayerID:
                    winnerPlayerID
            )

        battleship.applyDefendedAttack(
            nextPlayerID: localPlayerID,
            nextTurnID: nextTurnID,
            winnerPlayerID: winnerPlayerID
        )

        sendPayload(
            response,
            type: .gameState
        )

        showAttackFeedback(
            result.outcome,
            isLocalAttack: false
        )
    }

    private func applyAttackResult(
        _ payload:
            BattleshipAttackResultPayload
    ) {
        guard payload.sessionID ==
                startPayload.sessionID,
              payload.attackerPlayerID ==
                localPlayerID else {
            return
        }

        battleship.applyAttackResult(
            coordinate: payload.coordinate,
            outcome: payload.outcome,
            sunkCoordinates:
                payload.sunkCoordinates,
            defenderRemainingShips:
                payload.defenderRemainingShips,
            nextPlayerID:
                payload.nextPlayerID,
            nextTurnID:
                payload.nextTurnID,
            winnerPlayerID:
                payload.winnerPlayerID
        )

        pendingAttack = false

        showAttackFeedback(
            payload.outcome,
            isLocalAttack: true
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

        guard let data = message.payload else {
            if message.type == .gameQuit {
                handleOpponentQuit()
            }
            return
        }

        switch message.type {
        case .gameAction:
            if let ready =
                try? JSONDecoder().decode(
                    BattleshipReadyPayload.self,
                    from: data
                ),
               ready.sessionID ==
                startPayload.sessionID,
               ready.playerID == opponentID {
                battleship.markOpponentReady()
                beginBattleIfHostCanStart()
                return
            }

            if let attack =
                try? JSONDecoder().decode(
                    BattleshipAttackPayload.self,
                    from: data
                ) {
                resolveIncomingAttack(attack)
            }

        case .gameState:
            if let started =
                try? JSONDecoder().decode(
                    BattleshipBattleStartedPayload.self,
                    from: data
                ),
               started.sessionID ==
                startPayload.sessionID {
                battleship.beginBattle(
                    startingPlayerID:
                        started.startingPlayerID,
                    turnID: started.turnID
                )

                showFeedback(
                    "Battle started",
                    tone: .success
                )
                return
            }

            if let result =
                try? JSONDecoder().decode(
                    BattleshipAttackResultPayload.self,
                    from: data
                ) {
                applyAttackResult(result)
            }

        case .gameQuit:
            handleOpponentQuit()

        default:
            break
        }
    }

    // MARK: - Networking helper

    private func sendPayload<T: Encodable>(
        _ payload: T,
        type: NearbyMessageType
    ) {
        do {
            let data = try JSONEncoder()
                .encode(payload)

            nearbyService.send(
                NearbyMessage(
                    gameID: game.id,
                    senderName: localPlayerName,
                    type: type,
                    payload: data
                )
            )
        } catch {
            nearbyService.errorMessage =
                "Failed to synchronize Battleship."

            print(
                "Battleship payload encoding failed: \(error)"
            )
        }
    }

    // MARK: - Feedback

    private func showAttackFeedback(
        _ outcome: BattleshipAttackOutcome,
        isLocalAttack: Bool
    ) {
        let prefix =
            isLocalAttack ? "" : "Enemy: "

        switch outcome {
        case .miss:
            showFeedback(
                "\(prefix)Miss",
                tone: .neutral
            )

        case .hit:
            showFeedback(
                "\(prefix)Hit!",
                tone: .warning
            )

        case .sunk:
            showFeedback(
                "\(prefix)Ship sunk!",
                tone: .danger
            )

        case .gameOver:
            showFeedback(
                isLocalAttack
                ? "Enemy fleet destroyed!"
                : "Your fleet was destroyed",
                tone:
                    isLocalAttack
                    ? .success
                    : .danger
            )
        }
    }

    private func showFeedback(
        _ text: String,
        tone: BattleshipFeedbackTone
    ) {
        feedbackText = text
        feedbackTone = tone

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1.15
        ) {
            withAnimation(.easeOut(duration: 0.18)) {
                if feedbackText == text {
                    feedbackText = nil
                }
            }
        }
    }

    private func feedbackBanner(
        _ text: String,
        tone: BattleshipFeedbackTone
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: tone.iconName)
                .font(.system(size: 17, weight: .bold))

            Text(text)
                .font(
                    .system(
                        size: 15,
                        weight: .bold,
                        design: .rounded
                    )
                )
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(height: 48)
        .background {
            Capsule()
                .fill(tone.color.opacity(0.88))
        }
        .overlay {
            Capsule()
                .stroke(
                    Color.white.opacity(0.26),
                    lineWidth: 1
                )
        }
        .shadow(
            color: tone.color.opacity(0.42),
            radius: 12
        )
        .frame(
            maxHeight: .infinity,
            alignment: .top
        )
        .padding(.top, 74)
    }

    // MARK: - Quit

    private func quitGame() {
        guard !isQuitting else {
            return
        }

        isQuitting = true

        let payload = GameQuitPayload(
            playerName: localPlayerName,
            reason: "quit"
        )

        let data = try? JSONEncoder()
            .encode(payload)

        nearbyService.send(
            NearbyMessage(
                gameID: game.id,
                senderName: localPlayerName,
                type: .gameQuit,
                payload: data
            )
        )

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.35
        ) {
            nearbyService.stop()
            dismiss()
            onExitToHome()
            isQuitting = false
        }
    }

    private func handleOpponentQuit() {
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

                Text("Leaving battle…")
                    .font(
                        .system(
                            size: 16,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .background {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .fill(
                    BattleshipTheme.cardBackground
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(
                    BattleshipTheme.primaryGradient,
                    lineWidth: 1.2
                )
            }
        }
    }

    // MARK: - Result

    private var roundResult: GameRoundResult {
        battleship.winnerPlayerID ==
        localPlayerID
        ? .win
        : .loss
    }

    private var resultTitle: String {
        roundResult == .win
            ? "You Win!"
            : "Fleet Destroyed"
    }

    private var resultSubtitle: String {
        roundResult == .win
            ? "You sank every ship in \(opponentName)'s fleet."
            : "\(opponentName) sank your entire fleet."
    }

    private var resultSymbol: String {
        roundResult == .win
            ? "crown.fill"
            : "ferry.fill"
    }

    private var resultColor: Color {
        roundResult == .win
            ? BattleshipTheme.cyan
            : BattleshipTheme.purple
    }

    // MARK: - Identity

    private var localPlayerID: String {
        nearbyService.localPlayerID
    }

    private var opponentID: String {
        startPayload.playerOneID ==
        localPlayerID
        ? startPayload.playerTwoID
        : startPayload.playerOneID
    }

    private var opponentName: String {
        startPayload.playerOneID ==
        localPlayerID
        ? startPayload.playerTwoName
        : startPayload.playerOneName
    }

    private var isLocalHost: Bool {
        nearbyService
            .lobbySession?
            .hostPlayerID ==
        localPlayerID
    }

    private var isLocalTurn: Bool {
        battleship.phase == .battle &&
        battleship.activePlayerID ==
        localPlayerID
    }
}

// MARK: - Feedback

private enum BattleshipFeedbackTone {
    case neutral
    case success
    case warning
    case danger

    var color: Color {
        switch self {
        case .neutral:
            return BattleshipTheme.blue

        case .success:
            return .green

        case .warning:
            return .orange

        case .danger:
            return .red
        }
    }

    var iconName: String {
        switch self {
        case .neutral:
            return "circle.dotted"

        case .success:
            return "checkmark.circle.fill"

        case .warning:
            return "burst.fill"

        case .danger:
            return "xmark.octagon.fill"
        }
    }
}

// MARK: - Theme

enum BattleshipTheme {
    static let cyan = Color(
        red: 0.03,
        green: 0.78,
        blue: 1.00
    )

    static let blue = Color(
        red: 0.08,
        green: 0.40,
        blue: 1.00
    )

    static let purple = Color(
        red: 0.66,
        green: 0.23,
        blue: 1.00
    )

    static let waterCell = Color(
        red: 13.0 / 255.0,
        green: 32.0 / 255.0,
        blue: 48.0 / 255.0
    )

    static let primaryGradient =
        LinearGradient(
            colors: [
                cyan,
                blue,
                purple
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

    static let shipGradient =
        LinearGradient(
            colors: [
                cyan.opacity(0.94),
                blue.opacity(0.88),
                purple.opacity(0.84)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

    static let sunkGradient =
        LinearGradient(
            colors: [
                Color.red.opacity(0.92),
                Color.orange.opacity(0.72)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

    static let background =
        LinearGradient(
            colors: [
                Color(
                    red: 10.0 / 255.0,
                    green: 16.0 / 255.0,
                    blue: 24.0 / 255.0
                ),
                Color(
                    red: 5.0 / 255.0,
                    green: 14.0 / 255.0,
                    blue: 24.0 / 255.0
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )

    static let cardBackground =
        LinearGradient(
            colors: [
                Color(
                    red: 13.0 / 255.0,
                    green: 23.0 / 255.0,
                    blue: 37.0 / 255.0
                ),
                Color(
                    red: 8.0 / 255.0,
                    green: 15.0 / 255.0,
                    blue: 27.0 / 255.0
                )
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
}
