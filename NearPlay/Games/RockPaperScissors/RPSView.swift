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
    @ObservedObject var nearbyService: NearbyService

    let localPlayerName: String
    let startPayload: RPSStartPayload
    let onExitToHome: () -> Void

    @Environment(\.dismiss) private var dismiss

    @Namespace private var choiceNamespace

    @StateObject private var rematchController: RematchController

    @State private var rpsGame = RPSGame()

    @State private var showQuitConfirmation = false
    @State private var isQuitting = false

    @State private var presentationPhase: RPSPresentationPhase = .choosing
    @State private var duelCardsVisible = false
    @State private var highlightWinner = false
    @State private var showResultOverlay = false
    @State private var revealSequenceID = UUID()

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

        let remotePlayerID = nearbyService.connectedPeers.first?.id ?? "peer"

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
            RPSTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                customHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 22) {
                        roundStatusView

                        stageSection

                        connectionStatusView
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
            }

            if rpsGame.isRoundComplete && showResultOverlay {
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

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You and your opponent will return to the main screen.")
        }
        .onReceive(nearbyService.$lastReceivedMessage) { message in
            handleIncoming(message)
        }
        .onChange(of: rematchController.confirmedRoundNumber) { _, confirmedRound in
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
                resetPresentationState()
            }

            rematchController.finishStartingRound()
        }
        .onAppear {
            resetPresentationState()
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
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quit game")

            Spacer(minLength: 8)

            VStack(spacing: 3) {
                Text(game.title)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

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
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
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
        if rpsGame.isRoundComplete {
            switch rpsGame.result {
            case .draw:
                return "Round draw"
            case .localWin:
                return "You won the round"
            case .remoteWin:
                return "\(remotePlayerName) won the round"
            case .waiting:
                return "Round finished"
            }
        }

        switch presentationPhase {
        case .choosing:
            if rpsGame.remoteChoice != nil {
                return "\(remotePlayerName) is ready — choose your move"
            }
            return "Choose your move"

        case .lockedSelection:
            return "Waiting for \(remotePlayerName)"

        case .duel, .finished:
            return "Revealing both choices"
        }
    }

    private var headerSubtitleColor: Color {
        if rpsGame.isRoundComplete {
            switch rpsGame.result {
            case .draw:
                return Color.white.opacity(0.58)
            case .localWin:
                return Color.green.opacity(0.90)
            case .remoteWin:
                return Color.red.opacity(0.86)
            case .waiting:
                return Color.white.opacity(0.58)
            }
        }

        switch presentationPhase {
        case .choosing:
            return RPSTheme.brightBlue
        case .lockedSelection:
            return RPSTheme.brightPurple
        case .duel, .finished:
            return Color.white.opacity(0.60)
        }
    }

    // MARK: - Status

    private var roundStatusView: some View {
        HStack(spacing: 10) {
            Image(systemName: roundStatusIcon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(roundStatusColor)

            Text(roundStatusText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.72))

            Spacer()

            statusPill
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.028))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
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

        switch presentationPhase {
        case .choosing:
            if rpsGame.remoteChoice != nil {
                return "\(remotePlayerName) is ready — choose your move"
            }
            return "Choose rock, paper or scissors"

        case .lockedSelection:
            return "Choice locked — waiting for \(remotePlayerName)"

        case .duel, .finished:
            if highlightWinner {
                return duelSummaryText
            }
            return "Revealing both choices"
        }
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

        switch presentationPhase {
        case .choosing:
            return "hand.tap.fill"
        case .lockedSelection:
            return "lock.fill"
        case .duel, .finished:
            return "sparkles"
        }
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

        switch presentationPhase {
        case .choosing:
            return RPSTheme.brightBlue
        case .lockedSelection:
            return RPSTheme.brightPurple
        case .duel, .finished:
            return Color.white.opacity(0.72)
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        if let localChoice = rpsGame.localChoice, !rpsGame.isRoundComplete {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .bold))

                Text(localChoice.title)
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(choiceAccentColor(localChoice))
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.045))
            }
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            }
        } else if !rpsGame.isRoundComplete {
            Text("1 vs 1")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(RPSTheme.primaryGradient)
                .padding(.horizontal, 11)
                .frame(height: 28)
                .background {
                    Capsule()
                        .fill(Color.white.opacity(0.045))
                }
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                }
        }
    }

    // MARK: - Main stage

    private var stageSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(stageTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                if let localChoice = rpsGame.localChoice {
                    Text(localChoice.emoji)
                        .font(.system(size: 26))
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.035),
                                Color.white.opacity(0.015)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)

                stageContent
                    .padding(18)
            }
            .frame(minHeight: 340)
        }
    }

    private var stageTitle: String {
        switch presentationPhase {
        case .choosing:
            return "Choose Your Move"
        case .lockedSelection:
            return "Choice Locked"
        case .duel, .finished:
            return "Battle Reveal"
        }
    }

    @ViewBuilder
    private var stageContent: some View {
        switch presentationPhase {
        case .choosing:
            choosingStage

        case .lockedSelection:
            lockedChoiceStage

        case .duel, .finished:
            duelStage
        }
    }

    private var choosingStage: some View {
        VStack(spacing: 16) {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 12),
                    count: 3
                ),
                spacing: 12
            ) {
                ForEach(RPSChoice.allCases) { choice in
                    Button {
                        choose(choice)
                    } label: {
                        RPSSelectableChoiceCard(
                            choice: choice,
                            accentColor: choiceAccentColor(choice),
                            subtitle: "Choose",
                            isEmphasized: false
                        )
                        .matchedGeometryEffect(
                            id: localChoiceAnimationID(for: choice),
                            in: choiceNamespace
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canChoose)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.94)),
                            removal: .opacity.combined(with: .scale(scale: 0.88))
                        )
                    )
                }
            }

            Text(
                rpsGame.remoteChoice == nil
                    ? "Pick one move to lock your choice."
                    : "\(remotePlayerName) is already ready. Pick your move to reveal the round."
            )
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.48))
            .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var lockedChoiceStage: some View {
        if let localChoice = rpsGame.localChoice {
            VStack(spacing: 18) {
                Spacer(minLength: 0)

                RPSSelectableChoiceCard(
                    choice: localChoice,
                    accentColor: choiceAccentColor(localChoice),
                    subtitle: "Locked",
                    isEmphasized: true
                )
                .matchedGeometryEffect(
                    id: localChoiceAnimationID(for: localChoice),
                    in: choiceNamespace
                )
                .frame(maxWidth: 240)
                .shadow(
                    color: choiceAccentColor(localChoice).opacity(0.28),
                    radius: 18
                )

                VStack(spacing: 8) {
                    Text("Waiting for \(remotePlayerName)...")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Your move is locked in.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.46))
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private var duelStage: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            HStack(spacing: 14) {
                if let localChoice = rpsGame.localChoice {
                    RPSDuelChoiceCard(
                        title: localPlayerName,
                        choice: localChoice,
                        accentColor: choiceAccentColor(localChoice),
                        isWinner: didLocalPlayerWin,
                        isDimmed: didRemotePlayerWin && highlightWinner
                    )
                    .matchedGeometryEffect(
                        id: localChoiceAnimationID(for: localChoice),
                        in: choiceNamespace
                    )
                    .scaleEffect(localDuelScale)
                    .opacity(duelCardsVisible ? 1 : 0)
                    .offset(
                        x: duelCardsVisible ? 0 : -120,
                        y: duelCardsVisible ? 0 : 12
                    )
                }

                ZStack {
                    Circle()
                        .fill(RPSTheme.backgroundBottom)
                        .frame(width: 58, height: 58)

                    Circle()
                        .stroke(RPSTheme.primaryGradient, lineWidth: 1.6)
                        .frame(width: 58, height: 58)
                        .shadow(
                            color: RPSTheme.brightPurple.opacity(0.34),
                            radius: 10
                        )

                    Text("VS")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .scaleEffect(duelCardsVisible ? 1 : 0.72)
                .opacity(duelCardsVisible ? 1 : 0)

                if let remoteChoice = rpsGame.remoteChoice {
                    RPSDuelChoiceCard(
                        title: remotePlayerName,
                        choice: remoteChoice,
                        accentColor: choiceAccentColor(remoteChoice),
                        isWinner: didRemotePlayerWin,
                        isDimmed: didLocalPlayerWin && highlightWinner
                    )
                    .scaleEffect(remoteDuelScale)
                    .opacity(duelCardsVisible ? 1 : 0)
                    .offset(
                        x: duelCardsVisible ? 0 : 120,
                        y: duelCardsVisible ? 0 : 12
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(
                .spring(response: 0.42, dampingFraction: 0.84),
                value: duelCardsVisible
            )
            .animation(
                .spring(response: 0.32, dampingFraction: 0.82),
                value: highlightWinner
            )

            VStack(spacing: 8) {
                Text(duelHeadlineText)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(duelSubheadlineText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .multilineTextAlignment(.center)
            }
            .opacity(duelCardsVisible ? 1 : 0)
            .offset(y: duelCardsVisible ? 0 : 12)
            .animation(
                .easeOut(duration: 0.28),
                value: duelCardsVisible
            )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }

    private var localDuelScale: CGFloat {
        guard highlightWinner else { return 1.0 }
        if didLocalPlayerWin { return 1.08 }
        if didRemotePlayerWin { return 0.94 }
        return 1.0
    }

    private var remoteDuelScale: CGFloat {
        guard highlightWinner else { return 1.0 }
        if didRemotePlayerWin { return 1.08 }
        if didLocalPlayerWin { return 0.94 }
        return 1.0
    }

    private var duelHeadlineText: String {
        if !highlightWinner {
            return "Moves Revealed"
        }

        switch localRoundResult {
        case .win:
            return "You Win!"
        case .loss:
            return "You Lose"
        case .draw:
            return "It's a Draw!"
        }
    }

    private var duelSubheadlineText: String {
        if !highlightWinner {
            return "Let’s see who takes the round."
        }

        return duelSummaryText
    }

    private var duelSummaryText: String {
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
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.55))

            Spacer()
        }
        .padding(.horizontal, 15)
        .frame(height: 48)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.022))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(RPSTheme.cardBackground)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(RPSTheme.primaryGradient, lineWidth: 1.2)
            }
        }
    }

    // MARK: - Game state helpers

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

    private func localChoiceAnimationID(for choice: RPSChoice) -> String {
        "local-choice-\(choice.title)"
    }

    // MARK: - Result overlay data

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
            return choiceSymbolName(rpsGame.localChoice)
        case .loss:
            return choiceSymbolName(rpsGame.remoteChoice)
        case .draw:
            return "equal"
        }
    }

    private var resultAccentColor: Color {
        switch localRoundResult {
        case .win:
            return choiceAccentColor(rpsGame.localChoice)
        case .loss:
            return choiceAccentColor(rpsGame.remoteChoice)
        case .draw:
            return RPSTheme.brightPurple
        }
    }

    // MARK: - Actions

    private func choose(_ choice: RPSChoice) {
        guard canChoose else {
            return
        }

        withAnimation(
            .spring(response: 0.38, dampingFraction: 0.82)
        ) {
            rpsGame.setLocalChoice(choice)
            presentationPhase = .lockedSelection
        }

        UIImpactFeedbackGenerator(style: .medium)
            .impactOccurred()

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

        if rpsGame.remoteChoice != nil {
            startRevealSequence(after: 0.20)
        }
    }

    private func startRevealSequence(after delay: TimeInterval) {
        guard rpsGame.localChoice != nil,
              rpsGame.remoteChoice != nil,
              !showResultOverlay else {
            return
        }

        if presentationPhase == .duel || presentationPhase == .finished {
            return
        }

        let sequenceID = UUID()
        revealSequenceID = sequenceID

        duelCardsVisible = false
        highlightWinner = false
        showResultOverlay = false

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard revealSequenceID == sequenceID,
                  rpsGame.localChoice != nil,
                  rpsGame.remoteChoice != nil else {
                return
            }

            withAnimation(
                .spring(response: 0.42, dampingFraction: 0.84)
            ) {
                presentationPhase = .duel
                duelCardsVisible = true
            }

            UIImpactFeedbackGenerator(style: .soft)
                .impactOccurred()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                guard revealSequenceID == sequenceID,
                      rpsGame.isRoundComplete else {
                    return
                }

                withAnimation(
                    .spring(response: 0.34, dampingFraction: 0.84)
                ) {
                    highlightWinner = true
                }

                gameResultHapticIfNeeded()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                    guard revealSequenceID == sequenceID,
                          rpsGame.isRoundComplete else {
                        return
                    }

                    withAnimation(
                        .spring(response: 0.40, dampingFraction: 0.84)
                    ) {
                        showResultOverlay = true
                        presentationPhase = .finished
                    }
                }
            }
        }
    }

    private func resetPresentationState() {
        revealSequenceID = UUID()
        presentationPhase = .choosing
        duelCardsVisible = false
        highlightWinner = false
        showResultOverlay = false
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            nearbyService.stop()
            dismiss()
            onExitToHome()
            isQuitting = false
        }
    }

    // MARK: - Incoming messages

    private func handleIncoming(_ message: NearbyMessage?) {
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

    private func handleChoiceMessage(_ message: NearbyMessage) {
        guard message.senderName != localPlayerName,
              let data = message.payload else {
            return
        }

        do {
            let payload = try JSONDecoder().decode(
                RPSChoicePayload.self,
                from: data
            )

            let hadLocalChoice = rpsGame.localChoice != nil

            withAnimation(
                .spring(response: 0.34, dampingFraction: 0.80)
            ) {
                rpsGame.setRemoteChoice(payload.choice)
            }

            UIImpactFeedbackGenerator(style: .soft)
                .impactOccurred()

            if hadLocalChoice {
                startRevealSequence(after: 0.18)
            }
        } catch {
            print("Failed to decode RPS choice: \(error)")
        }
    }

    private func handleOpponentQuit() {
        nearbyService.stop()
        dismiss()
        onExitToHome()
    }

    private func gameResultHapticIfNeeded() {
        guard rpsGame.isRoundComplete else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
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

    private func choiceSymbolName(_ choice: RPSChoice?) -> String {
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

    private func choiceAccentColor(_ choice: RPSChoice?) -> Color {
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

// MARK: - Presentation phase

private enum RPSPresentationPhase {
    case choosing
    case lockedSelection
    case duel
    case finished
}

// MARK: - Choice card used for grid + selected state

private struct RPSSelectableChoiceCard: View {
    let choice: RPSChoice
    let accentColor: Color
    let subtitle: String
    let isEmphasized: Bool

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(isEmphasized ? 0.18 : 0.10))
                    .frame(
                        width: isEmphasized ? 92 : 76,
                        height: isEmphasized ? 92 : 76
                    )

                Text(choice.emoji)
                    .font(.system(size: isEmphasized ? 52 : 40))
            }

            Text(choice.title)
                .font(.system(size: isEmphasized ? 22 : 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isEmphasized ? accentColor : Color.white.opacity(0.40))
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: isEmphasized ? 220 : 166)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(isEmphasized ? 0.14 : 0.055),
                            Color.white.opacity(0.018)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isEmphasized
                        ? accentColor.opacity(0.88)
                        : Color.white.opacity(0.10),
                    lineWidth: isEmphasized ? 1.5 : 1
                )
        }
        .shadow(
            color: isEmphasized ? accentColor.opacity(0.28) : .clear,
            radius: 14
        )
    }
}

// MARK: - Duel card

private struct RPSDuelChoiceCard: View {
    let title: String
    let choice: RPSChoice
    let accentColor: Color
    let isWinner: Bool
    let isDimmed: Bool

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.42))

                Spacer()

                if isWinner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.yellow)
                }
            }

            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 86, height: 86)

                Circle()
                    .stroke(accentColor.opacity(0.72), lineWidth: 1.5)
                    .frame(width: 86, height: 86)
                    .shadow(color: accentColor.opacity(0.36), radius: 12)

                Text(choice.emoji)
                    .font(.system(size: 50))
            }

            VStack(spacing: 4) {
                Text(choice.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(isWinner ? "Winner" : "Revealed")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isWinner ? accentColor : Color.white.opacity(0.40))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 214)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(isWinner ? 0.12 : 0.06),
                            Color.white.opacity(0.016)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    isWinner
                        ? accentColor.opacity(0.84)
                        : Color.white.opacity(0.10),
                    lineWidth: isWinner ? 1.5 : 1
                )
        }
        .opacity(isDimmed ? 0.72 : 1)
        .shadow(
            color: isWinner ? accentColor.opacity(0.24) : .clear,
            radius: 14
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
    Text("RPSView requires an active NearbyService session.")
        .preferredColorScheme(.dark)
}
