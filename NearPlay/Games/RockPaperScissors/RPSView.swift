//
//  RPSView.swift
//  NearPlay
//
//  Created by Andrei Musca on 29/07/2026.
//

import SwiftUI
import UIKit

struct RPSView: View {
    let game: Game

    @ObservedObject
    var nearbyService: NearbyService

    let localPlayerName: String
    let startPayload: RPSStartPayload
    let onExitToHome: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @StateObject
    private var rematchController: RematchController

    @State private var rpsGame = RPSGame()
    @State private var showQuitConfirmation = false
    @State private var isQuitting = false

    init(
        game: Game,
        nearbyService: NearbyService,
        localPlayerName: String,
        startPayload: RPSStartPayload,
        onExitToHome: @escaping () -> Void = {}
    ) {
        self.game = game
        self.nearbyService = nearbyService
        self.localPlayerName = localPlayerName
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

    // MARK: - Body

    var body: some View {
        ZStack {
            RPSTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                customHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 22) {
                        roundStatusView

                        battleArena

                        choiceButtonsSection

                        connectionStatusView
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
            }

            if rpsGame.isRoundComplete {
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
                        // Din dialogul final ieșim direct,
                        // fără încă o confirmare.
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
                rpsGame.reset()
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
                    .font(
                        .system(
                            size: 20,
                            weight: .semibold
                        )
                    )
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
                            size: 23,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(headerSubtitle)
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
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
                .font(
                    .system(
                        size: 18,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    nearbyService.connectedPeers.isEmpty
                        ? Color.orange
                        : Color.green
                )
            }
        }
    }

    private var headerSubtitle: String {
        switch rpsGame.result {
        case .waiting:
            if rpsGame.localChoice == nil {
                return "Choose your move"
            }

            return "Choice locked"

        case .draw:
            return "Round draw"

        case .localWin:
            return "You won the round"

        case .remoteWin:
            return "\(remotePlayerName) won the round"
        }
    }

    private var headerSubtitleColor: Color {
        switch rpsGame.result {
        case .waiting:
            return rpsGame.localChoice == nil
                ? RPSTheme.brightBlue
                : RPSTheme.brightPurple

        case .draw:
            return Color.white.opacity(0.56)

        case .localWin:
            return Color.green.opacity(0.90)

        case .remoteWin:
            return Color.red.opacity(0.86)
        }
    }

    // MARK: - Status

    private var roundStatusView: some View {
        HStack(spacing: 10) {
            Image(systemName: roundStatusIcon)
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )
                .foregroundStyle(roundStatusColor)

            Text(roundStatusText)
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.72)
                )

            Spacer()

            if !rpsGame.isRoundComplete {
                Text("1 vs 1")
                    .font(
                        .system(
                            size: 13,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        RPSTheme.primaryGradient
                    )
                    .padding(.horizontal, 11)
                    .frame(height: 28)
                    .background {
                        Capsule()
                            .fill(Color.white.opacity(0.045))
                    }
                    .overlay {
                        Capsule()
                            .stroke(
                                Color.white.opacity(0.09),
                                lineWidth: 1
                            )
                    }
            }
        }
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
            .stroke(
                Color.white.opacity(0.09),
                lineWidth: 1
            )
        }
    }

    private var roundStatusText: String {
        if rpsGame.isRoundComplete {
            switch rpsGame.result {
            case .draw:
                return "Both players chose the same move"
            case .localWin:
                return "Your move wins this round"
            case .remoteWin:
                return "\(remotePlayerName)'s move wins"
            case .waiting:
                return "Round complete"
            }
        }

        if rpsGame.localChoice == nil {
            if rpsGame.remoteChoice == nil {
                return "Choose rock, paper or scissors"
            }

            return "\(remotePlayerName) is ready — choose your move"
        }

        if rpsGame.remoteChoice == nil {
            return "Waiting for \(remotePlayerName)"
        }

        return "Revealing both choices"
    }

    private var roundStatusIcon: String {
        if rpsGame.isRoundComplete {
            switch rpsGame.result {
            case .localWin:
                return "crown.fill"
            case .remoteWin:
                return "flag.checkered"
            case .draw:
                return "equal.circle.fill"
            case .waiting:
                return "checkmark.circle.fill"
            }
        }

        if rpsGame.localChoice != nil {
            return "lock.fill"
        }

        return "hand.tap.fill"
    }

    private var roundStatusColor: Color {
        if rpsGame.isRoundComplete {
            switch rpsGame.result {
            case .localWin:
                return .yellow
            case .remoteWin:
                return .red
            case .draw:
                return Color.white.opacity(0.70)
            case .waiting:
                return .green
            }
        }

        return rpsGame.localChoice == nil
            ? RPSTheme.brightBlue
            : RPSTheme.brightPurple
    }

    // MARK: - Battle arena

    private var battleArena: some View {
        HStack(spacing: 10) {
            RPSPlayerChoiceCard(
                playerName: localPlayerName,
                playerLabel: "You",
                choice: rpsGame.localChoice,
                choiceIsHidden: false,
                hasLockedChoice: rpsGame.localChoice != nil,
                accentColor: choiceAccentColor(
                    rpsGame.localChoice
                ),
                isWinner: didLocalPlayerWin
            )

            versusBadge

            RPSPlayerChoiceCard(
                playerName: remotePlayerName,
                playerLabel: "Opponent",
                choice:
                    shouldRevealChoices
                    ? rpsGame.remoteChoice
                    : nil,
                choiceIsHidden:
                    !shouldRevealChoices &&
                    rpsGame.remoteChoice != nil,
                hasLockedChoice:
                    rpsGame.remoteChoice != nil,
                accentColor: choiceAccentColor(
                    shouldRevealChoices
                        ? rpsGame.remoteChoice
                        : nil
                ),
                isWinner: didRemotePlayerWin
            )
        }
    }

    private var versusBadge: some View {
        ZStack {
            Circle()
                .fill(RPSTheme.backgroundBottom)
                .frame(width: 42, height: 42)

            Circle()
                .stroke(
                    RPSTheme.primaryGradient,
                    lineWidth: 1.4
                )
                .frame(width: 42, height: 42)
                .shadow(
                    color: RPSTheme.brightPurple.opacity(0.34),
                    radius: 8
                )

            Text("VS")
                .font(
                    .system(
                        size: 12,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
        }
        .frame(width: 34)
        .zIndex(2)
    }

    // MARK: - Choices

    private var choiceButtonsSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Choose Your Move")
                    .font(
                        .system(
                            size: 20,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)

                Spacer()

                if let localChoice = rpsGame.localChoice {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(
                                .system(
                                    size: 11,
                                    weight: .bold
                                )
                            )

                        Text(localChoice.title)
                    }
                    .font(
                        .system(
                            size: 13,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        choiceAccentColor(localChoice)
                    )
                }
            }

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(
                        .flexible(),
                        spacing: 10
                    ),
                    count: 3
                ),
                spacing: 10
            ) {
                ForEach(RPSChoice.allCases) { choice in
                    RPSChoiceButton(
                        choice: choice,
                        accentColor: choiceAccentColor(choice),
                        isSelected: isSelected(choice),
                        isEnabled: canChoose
                    ) {
                        choose(choice)
                    }
                }
            }
        }
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
                    : "Connected to \(remotePlayerName)"
            )
            .font(
                .system(
                    size: 14,
                    weight: .medium
                )
            )
            .foregroundStyle(
                Color.white.opacity(0.55)
            )

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
            .stroke(
                Color.white.opacity(0.08),
                lineWidth: 1
            )
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
                .fill(RPSTheme.cardBackground)
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(
                    RPSTheme.primaryGradient,
                    lineWidth: 1.2
                )
            }
        }
    }

    // MARK: - Game state

    private var remotePlayerName: String {
        if startPayload.playerOneName == localPlayerName {
            return startPayload.playerTwoName
        }

        return startPayload.playerOneName
    }

    private var canChoose: Bool {
        rpsGame.localChoice == nil &&
        !rpsGame.isRoundComplete
    }

    private var shouldRevealChoices: Bool {
        rpsGame.localChoice != nil &&
        rpsGame.remoteChoice != nil
    }

    private var didLocalPlayerWin: Bool {
        if case .localWin = rpsGame.result {
            return true
        }

        return false
    }

    private var didRemotePlayerWin: Bool {
        if case .remoteWin = rpsGame.result {
            return true
        }

        return false
    }

    private func isSelected(
        _ choice: RPSChoice
    ) -> Bool {
        guard let selectedChoice = rpsGame.localChoice else {
            return false
        }

        return selectedChoice.id == choice.id
    }

    // MARK: - Result

    private var localRoundResult: GameRoundResult {
        switch rpsGame.result {
        case .localWin:
            return .win
        case .remoteWin:
            return .loss
        case .draw:
            return .draw
        case .waiting:
            return .draw
        }
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
        guard let localChoice = rpsGame.localChoice,
              let remoteChoice = rpsGame.remoteChoice else {
            return "The round has ended."
        }

        switch localRoundResult {
        case .win:
            return "\(localChoice.title) beats \(remoteChoice.title)."

        case .loss:
            return "\(remoteChoice.title) beats \(localChoice.title)."

        case .draw:
            return "You both chose \(localChoice.title)."
        }
    }

    private var resultSymbolName: String {
        switch localRoundResult {
        case .win:
            return choiceSymbolName(
                rpsGame.localChoice
            )

        case .loss:
            return choiceSymbolName(
                rpsGame.remoteChoice
            )

        case .draw:
            return "equal"
        }
    }

    private var resultAccentColor: Color {
        switch localRoundResult {
        case .win:
            return choiceAccentColor(
                rpsGame.localChoice
            )

        case .loss:
            return choiceAccentColor(
                rpsGame.remoteChoice
            )

        case .draw:
            return RPSTheme.brightPurple
        }
    }

    // MARK: - Actions

    private func choose(
        _ choice: RPSChoice
    ) {
        guard canChoose else {
            return
        }

        withAnimation(
            .spring(
                response: 0.34,
                dampingFraction: 0.78
            )
        ) {
            rpsGame.setLocalChoice(choice)
        }

        UIImpactFeedbackGenerator(
            style: .medium
        )
        .impactOccurred()

        let payload = RPSChoicePayload(
            playerName: localPlayerName,
            choice: choice
        )

        do {
            let data = try JSONEncoder()
                .encode(payload)

            let message = NearbyMessage(
                gameID: game.id,
                senderName: localPlayerName,
                type: .gameAction,
                payload: data
            )

            nearbyService.send(message)
            gameResultHapticIfNeeded()
        } catch {
            print(
                "Failed to encode RPS choice: \(error)"
            )
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

        let data = try? JSONEncoder()
            .encode(payload)

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

            // Păstrat pentru navigarea corectă:
            // închide jocul, apoi lobby-ul.
            dismiss()
            onExitToHome()

            isQuitting = false
        }
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
            handleChoiceMessage(message)

        case .gameQuit:
            handleOpponentQuit()

        default:
            break
        }
    }

    private func handleChoiceMessage(
        _ message: NearbyMessage
    ) {
        guard message.senderName != localPlayerName,
              let data = message.payload else {
            return
        }

        do {
            let payload = try JSONDecoder().decode(
                RPSChoicePayload.self,
                from: data
            )

            withAnimation(
                .spring(
                    response: 0.34,
                    dampingFraction: 0.78
                )
            ) {
                rpsGame.setRemoteChoice(
                    payload.choice
                )
            }

            UIImpactFeedbackGenerator(
                style: .soft
            )
            .impactOccurred()

            gameResultHapticIfNeeded()
        } catch {
            print(
                "Failed to decode RPS choice: \(error)"
            )
        }
    }

    private func handleOpponentQuit() {
        nearbyService.stop()

        // Păstrat exact pentru navigarea corectă.
        dismiss()
        onExitToHome()
    }

    private func gameResultHapticIfNeeded() {
        guard rpsGame.isRoundComplete else {
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

    // MARK: - Choice helpers

    private func choiceSymbolName(
        _ choice: RPSChoice?
    ) -> String {
        guard let choice else {
            return "questionmark"
        }

        switch choice.title.lowercased() {
        case "rock":
            return "circle.fill"

        case "paper":
            return "doc.fill"

        case "scissors":
            return "scissors"

        default:
            return "hand.raised.fill"
        }
    }

    private func choiceAccentColor(
        _ choice: RPSChoice?
    ) -> Color {
        guard let choice else {
            return Color.white.opacity(0.50)
        }

        switch choice.title.lowercased() {
        case "rock":
            return RPSTheme.rockBlue

        case "paper":
            return RPSTheme.paperPurple

        case "scissors":
            return RPSTheme.scissorsPink

        default:
            return RPSTheme.brightPurple
        }
    }
}

// MARK: - Player choice card

private struct RPSPlayerChoiceCard: View {
    let playerName: String
    let playerLabel: String
    let choice: RPSChoice?
    let choiceIsHidden: Bool
    let hasLockedChoice: Bool
    let accentColor: Color
    let isWinner: Bool

    private var choiceTitle: String {
        if choiceIsHidden {
            return "Choice locked"
        }

        if let choice {
            return choice.title
        }

        return hasLockedChoice
            ? "Ready"
            : "Waiting"
    }

    private var displayEmoji: String {
        if choiceIsHidden {
            return "?"
        }

        return choice?.emoji ?? "?"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                Text(playerLabel.uppercased())
                    .font(
                        .system(
                            size: 11,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.42)
                    )

                Spacer()

                if isWinner {
                    Image(systemName: "crown.fill")
                        .font(
                            .system(
                                size: 13,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.yellow)
                } else if hasLockedChoice {
                    Image(systemName: "lock.fill")
                        .font(
                            .system(
                                size: 11,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            accentColor.opacity(0.85)
                        )
                }
            }

            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.10))
                    .frame(width: 82, height: 82)

                Circle()
                    .stroke(
                        accentColor.opacity(
                            hasLockedChoice ? 0.72 : 0.22
                        ),
                        lineWidth: 1.4
                    )
                    .frame(width: 82, height: 82)
                    .shadow(
                        color:
                            hasLockedChoice
                            ? accentColor.opacity(0.42)
                            : .clear,
                        radius: 11
                    )

                Text(displayEmoji)
                    .font(
                        .system(
                            size: choiceIsHidden ? 43 : 48,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        choiceIsHidden
                            ? accentColor
                            : Color.white
                    )
            }

            VStack(spacing: 4) {
                Text(playerName)
                    .font(
                        .system(
                            size: 16,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(choiceTitle)
                    .font(
                        .system(
                            size: 13,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        hasLockedChoice
                            ? accentColor
                            : Color.white.opacity(0.40)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 202)
        .background {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(
                            hasLockedChoice ? 0.050 : 0.026
                        ),
                        Color.white.opacity(0.014)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                hasLockedChoice
                    ? accentColor.opacity(0.50)
                    : Color.white.opacity(0.09),
                lineWidth: hasLockedChoice ? 1.3 : 1
            )
        }
        .shadow(
            color:
                hasLockedChoice
                ? accentColor.opacity(0.18)
                : .clear,
            radius: 14
        )
    }
}

// MARK: - Choice button

private struct RPSChoiceButton: View {
    let choice: RPSChoice
    let accentColor: Color
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    private var opacity: Double {
        if isEnabled || isSelected {
            return 1
        }

        return 0.42
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            accentColor.opacity(
                                isSelected ? 0.18 : 0.09
                            )
                        )
                        .frame(width: 62, height: 62)

                    Text(choice.emoji)
                        .font(.system(size: 36))
                }

                Text(choice.title)
                    .font(
                        .system(
                            size: 15,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(
                    isSelected
                        ? "Locked"
                        : "Choose"
                )
                .font(
                    .system(
                        size: 11,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    isSelected
                        ? accentColor
                        : Color.white.opacity(0.38)
                )
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 126)
            .background {
                RoundedRectangle(
                    cornerRadius: 21,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(
                                isSelected ? 0.14 : 0.045
                            ),
                            Color.white.opacity(0.018)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 21,
                    style: .continuous
                )
                .stroke(
                    isSelected
                        ? accentColor.opacity(0.88)
                        : Color.white.opacity(0.10),
                    lineWidth: isSelected ? 1.5 : 1
                )
            }
            .shadow(
                color:
                    isSelected
                    ? accentColor.opacity(0.30)
                    : .clear,
                radius: 12
            )
            .opacity(opacity)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(
            isSelected
                ? "\(choice.title), selected"
                : "Choose \(choice.title)"
        )
    }
}

// MARK: - Theme

private enum RPSTheme {
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

    static let brightBlue = Color(
        red: 0.05,
        green: 0.70,
        blue: 1.00
    )

    static let brightPurple = Color(
        red: 0.66,
        green: 0.25,
        blue: 1.00
    )

    static let rockBlue = Color(
        red: 0.12,
        green: 0.72,
        blue: 1.00
    )

    static let paperPurple = Color(
        red: 0.64,
        green: 0.34,
        blue: 1.00
    )

    static let scissorsPink = Color(
        red: 1.00,
        green: 0.30,
        blue: 0.68
    )

    static let primaryGradient = LinearGradient(
        colors: [
            brightBlue,
            Color(
                red: 0.27,
                green: 0.36,
                blue: 1.00
            ),
            brightPurple
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

#Preview {
    Text(
        "RPSView requires an active NearbyService session."
    )
    .preferredColorScheme(.dark)
}
