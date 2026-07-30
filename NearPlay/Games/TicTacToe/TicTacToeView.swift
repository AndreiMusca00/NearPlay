//
//  TicTacToeView.swift
//  NearPlay
//
//  Created by Andrei Musca on 01/07/2026.
//

import SwiftUI
import UIKit

struct TicTacToeView: View {
    let game: Game

    @ObservedObject var nearbyService: NearbyService

    let localPlayerName: String
    let localMark: TicTacToeMark
    let startPayload: TicTacToeStartPayload
    let onExitToHome: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var rematchController: RematchController

    @State private var ticTacToeGame = TicTacToeGame()
    @State private var showQuitConfirmation = false
    @State private var isQuitting = false

    init(
        game: Game,
        nearbyService: NearbyService,
        localPlayerName: String,
        localMark: TicTacToeMark,
        startPayload: TicTacToeStartPayload,
        onExitToHome: @escaping () -> Void = {}
    ) {
        self.game = game
        self.nearbyService = nearbyService
        self.localPlayerName = localPlayerName
        self.localMark = localMark
        self.startPayload = startPayload
        self.onExitToHome = onExitToHome

        let remotePlayerID =
            nearbyService.connectedPeers.first?.id ?? "peer"

        let sortedPlayerIDs = [
            nearbyService.localPlayerID,
            remotePlayerID
        ]
        .sorted()

        let fallbackSessionID = [
            game.id,
            sortedPlayerIDs.joined(separator: "-")
        ]
        .joined(separator: "-")

        let sessionID =
            nearbyService.lobbySession?.sessionID ??
            fallbackSessionID

        let hostPlayerID =
            nearbyService.lobbySession?.hostPlayerID ??
            sortedPlayerIDs.first ??
            nearbyService.localPlayerID

        _rematchController = StateObject(
            wrappedValue: RematchController(
                gameID: game.id,
                sessionID: sessionID,
                localPlayerID: nearbyService.localPlayerID,
                localPlayerName: localPlayerName,
                hostPlayerID: hostPlayerID,
                nearbyService: nearbyService
            )
        )
    }

    var body: some View {
        ZStack {
            TicTacToeTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                customHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        playersSection
                        turnStatusView

                        boardView
                            .padding(.horizontal, 4)

                        connectionStatusView
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }

            if isGameOver {
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
                        // Din dialogul final ieșim direct, fără a doua alertă.
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
            Button(
                "Quit Game",
                role: .destructive
            ) {
                quitGame()
            }

            Button(
                "Cancel",
                role: .cancel
            ) {}
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
        ) { _, confirmedRound in
            guard confirmedRound != nil else {
                return
            }

            withAnimation(
                .spring(
                    response: 0.40,
                    dampingFraction: 0.84
                )
            ) {
                ticTacToeGame.reset()
            }

            rematchController.finishStartingRound()
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
                    .frame(width: 48, height: 48)
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
            .accessibilityLabel("Quit game")

            Spacer(minLength: 8)

            VStack(spacing: 3) {
                Text(game.title)
                    .font(
                        .system(
                            size: 24,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(headerSubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(headerSubtitleColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.055))
                    .frame(width: 48, height: 48)

                Circle()
                    .stroke(
                        Color.white.opacity(0.12),
                        lineWidth: 1
                    )
                    .frame(width: 48, height: 48)

                Image(
                    systemName:
                        nearbyService.connectedPeers.isEmpty
                        ? "wifi.slash"
                        : "wifi"
                )
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    nearbyService.connectedPeers.isEmpty
                        ? Color.orange
                        : Color.green
                )
            }
        }
    }

    private var headerSubtitle: String {
        if let winnerName {
            return "\(winnerName) wins"
        }

        if ticTacToeGame.isDraw {
            return "Round draw"
        }

        return isLocalTurn
            ? "Your turn"
            : "\(opponentName)'s turn"
    }

    private var headerSubtitleColor: Color {
        if isGameOver {
            return Color.white.opacity(0.55)
        }

        return isLocalTurn
            ? TicTacToeTheme.xBlue
            : TicTacToeTheme.oPurple
    }

    // MARK: - Players

    private var playersSection: some View {
        HStack(spacing: 12) {
            TicTacToePlayerCard(
                name: startPayload.xPlayerName,
                mark: .x,
                isLocalPlayer: localMark == .x,
                isCurrentTurn:
                    !isGameOver &&
                    ticTacToeGame.currentTurn == .x,
                isWinner: ticTacToeGame.winner == .x
            )

            TicTacToePlayerCard(
                name: startPayload.oPlayerName,
                mark: .o,
                isLocalPlayer: localMark == .o,
                isCurrentTurn:
                    !isGameOver &&
                    ticTacToeGame.currentTurn == .o,
                isWinner: ticTacToeGame.winner == .o
            )
        }
    }

    // MARK: - Status

    private var turnStatusView: some View {
        HStack(spacing: 10) {
            if isGameOver {
                Image(
                    systemName:
                        ticTacToeGame.isDraw
                        ? "equal.circle.fill"
                        : "crown.fill"
                )
                .foregroundStyle(
                    ticTacToeGame.isDraw
                        ? Color.white.opacity(0.65)
                        : Color.yellow
                )

                Text(
                    ticTacToeGame.isDraw
                        ? "The round ended in a draw"
                        : "\(winnerName ?? "Player") won the round"
                )
            } else {
                Circle()
                    .fill(isLocalTurn ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .shadow(
                        color:
                            isLocalTurn
                            ? Color.green.opacity(0.6)
                            : Color.orange.opacity(0.6),
                        radius: 5
                    )

                Text(
                    isLocalTurn
                        ? "Your move"
                        : "Waiting for \(opponentName)"
                )
            }

            Spacer()

            if !isGameOver {
                TicTacToeMarkView(
                    mark: ticTacToeGame.currentTurn,
                    size: 22
                )
            }
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Color.white.opacity(0.72))
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(Color.white.opacity(0.028))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.09), lineWidth: 1)
        }
    }

    // MARK: - Board

    private var boardView: some View {
        GeometryReader { geometry in
            let side = min(
                geometry.size.width,
                geometry.size.height
            )
            let spacing: CGFloat = 10
            let cellSize = (side - spacing * 2) / 3

            ZStack {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(
                            .flexible(),
                            spacing: spacing
                        ),
                        count: 3
                    ),
                    spacing: spacing
                ) {
                    ForEach(0..<9, id: \.self) { index in
                        boardCell(
                            at: index,
                            size: cellSize
                        )
                    }
                }
                .frame(width: side, height: side)

                if let winningCombination,
                   let winner = ticTacToeGame.winner {
                    TicTacToeWinningLine(
                        combination: winningCombination,
                        mark: winner,
                        boardSide: side,
                        spacing: spacing
                    )
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func boardCell(
        at index: Int,
        size: CGFloat
    ) -> some View {
        let mark = ticTacToeGame.board[index]
        let isWinningCell =
            winningCombination?.contains(index) == true

        return Button {
            cellTapped(index)
        } label: {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(
                                isWinningCell ? 0.075 : 0.04
                            ),
                            Color.white.opacity(0.018)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(Color.white.opacity(0.11), lineWidth: 1)

                if isWinningCell,
                   let winner = ticTacToeGame.winner {
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .stroke(
                        markColor(winner).opacity(0.7),
                        lineWidth: 1.5
                    )
                    .shadow(
                        color: markColor(winner).opacity(0.55),
                        radius: 12
                    )
                }

                if let mark {
                    TicTacToeMarkView(
                        mark: mark,
                        size: size * 0.53
                    )
                    .transition(
                        .scale.combined(with: .opacity)
                    )
                }
            }
            .frame(height: size)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(
            !isBoardInteractive ||
            mark != nil
        )
    }

    // MARK: - Connection

    private var connectionStatusView: some View {
        HStack(spacing: 11) {
            Image(
                systemName:
                    nearbyService.connectedPeers.isEmpty
                    ? "exclamationmark.triangle.fill"
                    : "checkmark.circle.fill"
            )
            .foregroundStyle(
                nearbyService.connectedPeers.isEmpty
                    ? Color.orange
                    : Color.green
            )

            Text(
                nearbyService.connectedPeers.isEmpty
                    ? "Opponent disconnected"
                    : "Connected to \(opponentName)"
            )
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.55))

            Spacer()
        }
        .padding(.horizontal, 15)
        .frame(height: 48)
        .background {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(Color.white.opacity(0.022))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    // MARK: - Quit overlay

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
                .fill(TicTacToeTheme.cardBackground)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(
                    TicTacToeTheme.primaryGradient,
                    lineWidth: 1.2
                )
            }
        }
    }

    // MARK: - Result

    private var localRoundResult: GameRoundResult {
        if ticTacToeGame.isDraw {
            return .draw
        }

        return ticTacToeGame.winner == localMark
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
        switch localRoundResult {
        case .win:
            return "Great game, \(localPlayerName)."
        case .loss:
            return "Better luck in the next round."
        case .draw:
            return "Nobody won this round."
        }
    }

    private var resultSymbolName: String {
        if ticTacToeGame.isDraw {
            return "equal"
        }

        guard let winner = ticTacToeGame.winner else {
            return "gamecontroller.fill"
        }

        return winner == .x ? "xmark" : "circle"
    }

    private var resultAccentColor: Color {
        guard let winner = ticTacToeGame.winner else {
            return Color.white.opacity(0.78)
        }

        return markColor(winner)
    }

    // MARK: - Game state

    private var isLocalTurn: Bool {
        ticTacToeGame.currentTurn == localMark
    }

    private var isGameOver: Bool {
        ticTacToeGame.winner != nil ||
        ticTacToeGame.isDraw
    }

    private var isBoardInteractive: Bool {
        isLocalTurn && !isGameOver
    }

    private var opponentName: String {
        localMark == .x
            ? startPayload.oPlayerName
            : startPayload.xPlayerName
    }

    private var winnerName: String? {
        guard let winner = ticTacToeGame.winner else {
            return nil
        }

        return winner == .x
            ? startPayload.xPlayerName
            : startPayload.oPlayerName
    }

    private var winningCombination: [Int]? {
        let combinations: [[Int]] = [
            [0, 1, 2],
            [3, 4, 5],
            [6, 7, 8],
            [0, 3, 6],
            [1, 4, 7],
            [2, 5, 8],
            [0, 4, 8],
            [2, 4, 6]
        ]

        for combination in combinations {
            guard let firstMark =
                    ticTacToeGame.board[combination[0]] else {
                continue
            }

            if combination.allSatisfy({ index in
                ticTacToeGame.board[index] == firstMark
            }) {
                return combination
            }
        }

        return nil
    }

    // MARK: - Actions

    private func cellTapped(_ index: Int) {
        guard isBoardInteractive else {
            return
        }

        let moved = ticTacToeGame.makeMove(
            at: index,
            by: localMark
        )

        guard moved else {
            return
        }

        UIImpactFeedbackGenerator(style: .light)
            .impactOccurred()

        let payload = TicTacToeMovePayload(
            index: index,
            mark: localMark
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
            gameResultHapticIfNeeded()
        } catch {
            print("Failed to encode move: \(error)")
        }
    }

    private func quitGame() {
        guard !isQuitting else {
            return
        }

        isQuitting = true

        let payload = GameQuitPayload(
            playerName: localPlayerName,
            reason: "quit"
        )

        let data = try? JSONEncoder().encode(payload)

        let message = NearbyMessage(
            gameID: game.id,
            senderName: localPlayerName,
            type: .gameQuit,
            payload: data
        )

        nearbyService.send(message)

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.4
        ) {
            nearbyService.stop()

            // Păstrat exact pentru flow-ul corect de navigare.
            dismiss()
            onExitToHome()

            isQuitting = false
        }
    }

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
            handleIncomingMove(message)

        case .gameQuit:
            handleOpponentQuit()

        default:
            break
        }
    }

    private func handleIncomingMove(
        _ message: NearbyMessage
    ) {
        guard let payload = message.payload else {
            return
        }

        do {
            let move = try JSONDecoder().decode(
                TicTacToeMovePayload.self,
                from: payload
            )

            let moved = ticTacToeGame.makeMove(
                at: move.index,
                by: move.mark
            )

            if moved {
                UIImpactFeedbackGenerator(style: .soft)
                    .impactOccurred()

                gameResultHapticIfNeeded()
            }
        } catch {
            print("Failed to decode move: \(error)")
        }
    }

    private func handleOpponentQuit() {
        nearbyService.stop()

        // Păstrat exact pentru navigarea corectă.
        dismiss()
        onExitToHome()
    }

    private func gameResultHapticIfNeeded() {
        guard isGameOver else {
            return
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.15
        ) {
            switch localRoundResult {
            case .win:
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.success)
            case .loss:
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.warning)
            case .draw:
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.warning)
            }
        }
    }

    private func markColor(
        _ mark: TicTacToeMark
    ) -> Color {
        mark == .x
            ? TicTacToeTheme.xBlue
            : TicTacToeTheme.oPurple
    }
}

// MARK: - Player card

private struct TicTacToePlayerCard: View {
    let name: String
    let mark: TicTacToeMark
    let isLocalPlayer: Bool
    let isCurrentTurn: Bool
    let isWinner: Bool

    private var accentColor: Color {
        mark == .x
            ? TicTacToeTheme.xBlue
            : TicTacToeTheme.oPurple
    }

    private var statusText: String {
        if isWinner {
            return "Winner"
        }

        if isCurrentTurn {
            return isLocalPlayer ? "Your turn" : "Playing"
        }

        return isLocalPlayer ? "You" : "Opponent"
    }

    var body: some View {
        HStack(spacing: 13) {
            TicTacToeMarkView(mark: mark, size: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        isWinner || isCurrentTurn
                            ? accentColor
                            : Color.white.opacity(0.42)
                    )
            }

            Spacer(minLength: 4)

            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(
                Color.white.opacity(
                    isCurrentTurn || isWinner ? 0.05 : 0.025
                )
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.10), lineWidth: 1)

            if isCurrentTurn || isWinner {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(
                    LinearGradient(
                        colors: [
                            accentColor,
                            accentColor.opacity(0.38)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.5
                )
            }
        }
        .shadow(
            color:
                isCurrentTurn || isWinner
                ? accentColor.opacity(0.24)
                : .clear,
            radius: 12
        )
    }
}

// MARK: - Mark

private struct TicTacToeMarkView: View {
    let mark: TicTacToeMark
    let size: CGFloat

    private var color: Color {
        mark == .x
            ? TicTacToeTheme.xBlue
            : TicTacToeTheme.oPurple
    }

    var body: some View {
        Image(
            systemName: mark == .x ? "xmark" : "circle"
        )
        .font(
            .system(
                size: size,
                weight: mark == .x ? .medium : .regular
            )
        )
        .foregroundStyle(color)
        .shadow(
            color: color.opacity(0.95),
            radius: max(5, size * 0.13)
        )
        .shadow(
            color: color.opacity(0.45),
            radius: max(10, size * 0.22)
        )
    }
}

// MARK: - Winning line

private struct TicTacToeWinningLine: View {
    let combination: [Int]
    let mark: TicTacToeMark
    let boardSide: CGFloat
    let spacing: CGFloat

    private var color: Color {
        mark == .x
            ? TicTacToeTheme.xBlue
            : TicTacToeTheme.oPurple
    }

    var body: some View {
        let cellSize = (boardSide - spacing * 2) / 3
        let startPoint = point(
            for: combination.first ?? 0,
            cellSize: cellSize
        )
        let endPoint = point(
            for: combination.last ?? 0,
            cellSize: cellSize
        )

        Path { path in
            path.move(to: startPoint)
            path.addLine(to: endPoint)
        }
        .stroke(
            color,
            style: StrokeStyle(
                lineWidth: 5,
                lineCap: .round
            )
        )
        .shadow(color: color.opacity(0.95), radius: 7)
        .shadow(color: color.opacity(0.55), radius: 14)
        .frame(width: boardSide, height: boardSide)
    }

    private func point(
        for index: Int,
        cellSize: CGFloat
    ) -> CGPoint {
        let row = index / 3
        let column = index % 3

        let x =
            CGFloat(column) * (cellSize + spacing) +
            cellSize / 2

        let y =
            CGFloat(row) * (cellSize + spacing) +
            cellSize / 2

        return CGPoint(x: x, y: y)
    }
}

// MARK: - Theme

private enum TicTacToeTheme {
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

    static let xBlue = Color(
        red: 0.05,
        green: 0.70,
        blue: 1.00
    )

    static let oPurple = Color(
        red: 0.66,
        green: 0.25,
        blue: 1.00
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

    static let primaryGradient = LinearGradient(
        colors: [
            xBlue,
            Color(red: 0.27, green: 0.36, blue: 1.00),
            oPurple
        ],
        startPoint: .leading,
        endPoint: .trailing
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

#Preview {
    Text("TicTacToeView requires an active NearbyService session.")
        .preferredColorScheme(.dark)
}
