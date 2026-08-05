//
//  GameLobbyView.swift
//  NearPlay
//

import SwiftUI
import UIKit

struct GameLobbyView: View {
    let game: Game

    @StateObject private var nearbyService = NearbyService()

    @AppStorage(PlayerProfile.nameKey)
    private var playerName: String = ""

    @Environment(\._favoriteGameIDsBinding)
    private var favoriteGameIDs: Binding<Set<String>>

    @Environment(\.dismiss)
    private var dismiss

    @State private var progress: Double = 0
    @State private var isSearching = false
    @State private var shouldStartGame = false
    @State private var isStartingGame = false

    @State private var countdownValue: Int?
    @State private var countdownTimer: Timer?
    @State private var hasStartedCountdown = false

    @State private var showComputerModeInfo = false

    // Keeps the lobby visually frozen behind the dialog while invitation
    // state, connection state and countdown state are changing.
    @State private var frozenDiscoveredPeers: [NearbyPeer]?

    // Tic-Tac-Toe
    @State private var localMark: TicTacToeMark?
    @State private var ticTacToeStartPayload: TicTacToeStartPayload?

    // Rock Paper Scissors
    @State private var rpsStartPayload: RPSStartPayload?

    // Number Rush
    @State private var numberRushStartPayload: NumberRushStartPayload?

    // Battleship
    @State private var battleshipStartPayload: BattleshipStartPayload?

    // MARK: - Computed properties

    private var safePlayerName: String {
        let trimmedName = playerName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmedName.isEmpty ? "Player" : trimmedName
    }

    private var isSupportedGame: Bool {
        game.id == Game.ticTacToe.id ||
        game.id == Game.rockPaperScissors.id ||
        game.id == Game.numberRush.id ||
        game.id == Game.battleship.id
    }

    private var hasConnectedOpponent: Bool {
        !nearbyService.connectedPeers.isEmpty
    }

    private var connectedOpponent: NearbyPeer? {
        nearbyService.connectedPeers.first
    }

    private var validLobbySession: LobbySessionContext? {
        guard let session = nearbyService.lobbySession,
              let connectedOpponent,
              session.matches(
                gameID: game.id,
                firstPlayerID: nearbyService.localPlayerID,
                secondPlayerID: connectedOpponent.id
              ) else {
            return nil
        }

        return session
    }

    private var isLocalHost: Bool {
        validLobbySession?.hostPlayerID ==
        nearbyService.localPlayerID
    }

    private var playerCountText: String {
        if game.minPlayers == game.maxPlayers {
            return game.minPlayers == 1
                ? "1 player"
                : "\(game.minPlayers) players"
        }

        return "\(game.minPlayers)–\(game.maxPlayers) players"
    }

    private var isFavorite: Bool {
        favoriteGameIDs.wrappedValue.contains(game.id)
    }

    private var visibleDiscoveredPeers: [NearbyPeer] {
        frozenDiscoveredPeers ?? nearbyService.discoveredPeers
    }

    private var lobbyDialogState: LobbyDialogState? {
        if let feedback = nearbyService.invitationFeedback {
            return .declined(feedback)
        }

        if let countdownValue {
            return .countdown(
                value: countdownValue,
                peerName:
                    connectedOpponent?.displayName ??
                    nearbyService.connectingPeer?.displayName ??
                    "Opponent"
            )
        }

        if let invitation = nearbyService.pendingInvitation {
            return .incoming(invitation)
        }

        if let outgoing = nearbyService.outgoingInvitation {
            if nearbyService.connectionState == .connecting ||
                nearbyService.connectionState == .connected {
                return .accepted(
                    peerName: outgoing.toPeer.displayName
                )
            }

            return .outgoing(outgoing)
        }

        if nearbyService.connectionState == .connecting,
           let peer = nearbyService.connectingPeer {
            return .accepted(peerName: peer.displayName)
        }

        if hasConnectedOpponent,
           let peer = connectedOpponent {
            return .accepted(peerName: peer.displayName)
        }

        return nil
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LobbyTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                lobbyHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 14)

                ScrollView {
                    VStack(spacing: 24) {
                        // The lobby remains visually unchanged behind the dialog.
                        // Only the content inside the same dialog card changes.
                        searchingContent

                        if let error = nearbyService.errorMessage,
                           !error.isEmpty {
                            errorView(error)
                        }
                    }
                    .padding(.top, 22)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 35)
                }
                .scrollIndicators(.hidden)
                .allowsHitTesting(lobbyDialogState == nil)
            }

            if let lobbyDialogState {
                UnifiedLobbyDialogOverlay(
                    state: lobbyDialogState,
                    gameTitle: game.title,
                    invitationDuration:
                        nearbyService.invitationDuration,
                    onAccept: {
                        UIImpactFeedbackGenerator(
                            style: .medium
                        )
                        .impactOccurred()

                        nearbyService.acceptInvitation()
                    },
                    onDecline: {
                        nearbyService.rejectInvitation()
                    }
                )
                .zIndex(20)
                .transition(
                    .opacity.combined(
                        with: .scale(scale: 0.96)
                    )
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onDisappear {
            countdownTimer?.invalidate()
            countdownTimer = nil

            if !isStartingGame {
                nearbyService.stop()
            }
        }
        .alert(
            "Play vs OP",
            isPresented: $showComputerModeInfo
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "The computer opponent will be implemented separately for this game."
            )
        }
        .onReceive(
            nearbyService.$lastReceivedMessage
        ) { message in
            guard let message else {
                return
            }

            handleReceivedMessage(message)
        }
        .onChange(
            of: nearbyService.connectedPeers.count
        ) { connectedCount in
            if connectedCount == 0 {
                resetAutomaticStartState()
                return
            }

            withAnimation(
                .spring(
                    response: 0.42,
                    dampingFraction: 0.86
                )
            ) {
                progress = 1
                isSearching = false
            }

            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)

            scheduleHostCountdownIfPossible()
        }
        .onChange(
            of: nearbyService.lobbySession?.sessionID
        ) { _ in
            scheduleHostCountdownIfPossible()
        }
        .onChange(
            of: nearbyService.pendingInvitation?.id
        ) { invitationID in
            if invitationID != nil,
               frozenDiscoveredPeers == nil {
                frozenDiscoveredPeers =
                    nearbyService.discoveredPeers
            }
        }
        .onChange(
            of: lobbyDialogState != nil
        ) { isDialogPresented in
            if !isDialogPresented,
               !hasConnectedOpponent {
                frozenDiscoveredPeers = nil
            }
        }
        .navigationDestination(
            isPresented: $shouldStartGame
        ) {
            gameDestination
        }
    }

    // MARK: - Lobby dialog

    // The dialog is intentionally represented by one view type.
    // SwiftUI updates its content in place instead of replacing the entire overlay.

    // MARK: - Searching content

    private var searchingContent: some View {
        VStack(spacing: 24) {
            HoldToSearchButton(
                progress: $progress,
                isSearching: isSearching
            ) {
                startSearching()
            }
            .accessibilityLabel(
                isSearching
                    ? "Searching for nearby players"
                    : "Start searching for nearby players"
            )

            playVersusOpponentButton

            nearbyPlayersSection
        }
    }

    // MARK: - Header

    private var lobbyHeader: some View {
        HStack(spacing: 14) {
            Button {
                cancelAndDismiss()
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
            .accessibilityLabel("Back")

            Spacer(minLength: 8)

            VStack(spacing: 4) {
                Text("\(game.title) Lobby")
                    .font(
                        .system(
                            size: 21,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(
                    "Nearby multiplayer • \(playerCountText)"
                )
                .font(
                    .system(
                        size: 14,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.5)
                )
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                toggleFavorite()
            } label: {
                Image(
                    systemName: isFavorite
                        ? "heart.fill"
                        : "heart"
                )
                .font(
                    .system(
                        size: 21,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    isFavorite
                        ? LobbyTheme.brightBlue
                        : Color.white
                )
                .frame(width: 48, height: 48)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.055))
                }
                .overlay {
                    Circle()
                        .stroke(
                            isFavorite
                                ? LobbyTheme.brightBlue.opacity(0.5)
                                : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isFavorite
                    ? "Remove from liked games"
                    : "Add to liked games"
            )
        }
    }

    // MARK: - Play versus opponent

    private var playVersusOpponentButton: some View {
        Button {
            showComputerModeInfo = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "cpu")
                    .font(
                        .system(
                            size: 23,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        LobbyTheme.primaryGradient
                    )
                    .frame(width: 42, height: 42)
                    .background {
                        Circle()
                            .fill(
                                LobbyTheme
                                    .brightPurple
                                    .opacity(0.12)
                            )
                    }

                Text("Play vs OP")
                    .font(
                        .system(
                            size: 19,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(
                        .system(
                            size: 15,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.65)
                    )
            }
            .padding(.horizontal, 20)
            .frame(height: 76)
            .background {
                RoundedRectangle(
                    cornerRadius: 27,
                    style: .continuous
                )
                .fill(Color.white.opacity(0.028))
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 27,
                    style: .continuous
                )
                .stroke(
                    LobbyTheme.primaryGradient,
                    lineWidth: 1.3
                )
            }
            .shadow(
                color: LobbyTheme.brightBlue.opacity(0.18),
                radius: 12,
                x: -3
            )
            .shadow(
                color: LobbyTheme.brightPurple.opacity(0.18),
                radius: 12,
                x: 3
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Nearby players

    private var nearbyPlayersSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "person.2.fill")
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        LobbyTheme.primaryGradient
                    )

                Text("Nearby Players")
                    .font(
                        .system(
                            size: 20,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.white)

                Spacer()

                Text(
                    "\(visibleDiscoveredPeers.count) found"
                )
                .font(
                    .system(
                        size: 14,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.45)
                )
            }

            if visibleDiscoveredPeers.isEmpty {
                emptyPlayersView
            } else {
                VStack(spacing: 12) {
                    ForEach(
                        visibleDiscoveredPeers,
                        id: \.id
                    ) { peer in
                        NearbyPlayerRow(
                            peerName: peer.displayName,
                            state: .available,
                            accentColor: accentColor(
                                for: peer.displayName
                            )
                        ) {
                            frozenDiscoveredPeers =
                                nearbyService.discoveredPeers
                            nearbyService.invite(peer)
                        }
                    }
                }
            }
        }
    }

    private var emptyPlayersView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LobbyTheme
                            .brightPurple
                            .opacity(0.07)
                    )
                    .frame(width: 108, height: 108)

                Circle()
                    .stroke(
                        LobbyTheme.primaryGradient,
                        lineWidth: 1.4
                    )
                    .frame(width: 88, height: 88)

                Image(
                    systemName:
                        isSearching
                        ? "dot.radiowaves.left.and.right"
                        : "person.2.slash"
                )
                .font(
                    .system(
                        size: 33,
                        weight: .light
                    )
                )
                .foregroundStyle(
                    LobbyTheme.primaryGradient
                )
            }

            VStack(spacing: 7) {
                Text(
                    isSearching
                        ? "Searching for nearby players"
                        : "Search for nearby players"
                )
                .font(
                    .system(
                        size: 20,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.white)

                Text(
                    isSearching
                        ? "Nearby players will appear here automatically."
                        : "Hold the button above or play versus OP."
                )
                .font(.system(size: 14))
                .foregroundStyle(
                    Color.white.opacity(0.5)
                )
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 20)
        .background {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .fill(Color.white.opacity(0.024))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.10),
                lineWidth: 1
            )
        }
    }


    // MARK: - Connected opponent

    private var connectedOpponentContent: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(
                        .system(
                            size: 38,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.green)
                    .shadow(
                        color: Color.green.opacity(0.28),
                        radius: 10
                    )

                Text("Invitation Accepted")
                    .font(
                        .system(
                            size: 23,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)

                Text("The game will start automatically.")
                    .font(.system(size: 15))
                    .foregroundStyle(
                        Color.white.opacity(0.5)
                    )
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 18)

            if let connectedPeer = connectedOpponent {
                NearbyPlayerRow(
                    peerName: connectedPeer.displayName,
                    state: .connected,
                    accentColor: accentColor(
                        for: connectedPeer.displayName
                    ),
                    isReady: true,
                    action: {}
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Search

    private func startSearching() {
        frozenDiscoveredPeers = nil

        nearbyService.start(
            gameID: game.id,
            playerName: safePlayerName,
            maxPlayers: game.maxPlayers
        )

        withAnimation(
            .spring(
                response: 0.38,
                dampingFraction: 0.84
            )
        ) {
            progress = 1
            isSearching = true
        }

        UIImpactFeedbackGenerator(
            style: .medium
        )
        .impactOccurred()
    }

    // MARK: - Automatic countdown

    private func scheduleHostCountdownIfPossible() {
        guard isSupportedGame,
              hasConnectedOpponent,
              validLobbySession != nil,
              isLocalHost,
              !hasStartedCountdown,
              !isStartingGame else {
            return
        }

        hasStartedCountdown = true

        // Small visual pause after the connection is established.
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.45
        ) {
            guard hasConnectedOpponent,
                  let session = validLobbySession,
                  isLocalHost,
                  !isStartingGame else {
                hasStartedCountdown = false
                return
            }

            let payload = LobbyCountdownPayload(
                sessionID: session.sessionID,
                seconds: 3
            )

            do {
                let data = try JSONEncoder()
                    .encode(payload)

                let message = NearbyMessage(
                    gameID: game.id,
                    senderName: safePlayerName,
                    type: .lobbyCountdown,
                    payload: data
                )

                nearbyService.send(message)

                beginLocalCountdown(
                    seconds: payload.seconds,
                    startsGameWhenFinished: true
                )
            } catch {
                hasStartedCountdown = false
                nearbyService.errorMessage =
                    "Failed to start the countdown."

                print(
                    "Failed to encode LobbyCountdownPayload: \(error)"
                )
            }
        }
    }

    private func handleLobbyCountdown(
        _ data: Data
    ) {
        do {
            let payload = try JSONDecoder().decode(
                LobbyCountdownPayload.self,
                from: data
            )

            guard let session = validLobbySession,
                  payload.sessionID == session.sessionID,
                  !isLocalHost,
                  !hasStartedCountdown else {
                return
            }

            hasStartedCountdown = true

            beginLocalCountdown(
                seconds: max(payload.seconds, 1),
                startsGameWhenFinished: false
            )
        } catch {
            nearbyService.errorMessage =
                "Failed to receive the countdown."

            print(
                "Failed to decode LobbyCountdownPayload: \(error)"
            )
        }
    }

    private func beginLocalCountdown(
        seconds: Int,
        startsGameWhenFinished: Bool
    ) {
        countdownTimer?.invalidate()
        countdownTimer = nil

        var remaining = max(seconds, 1)

        withAnimation(
            .spring(
                response: 0.34,
                dampingFraction: 0.78
            )
        ) {
            countdownValue = remaining
        }

        countdownTimer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: true
        ) { timer in
            remaining -= 1

            if remaining <= 0 {
                timer.invalidate()
                countdownTimer = nil

                withAnimation(.easeOut(duration: 0.18)) {
                    countdownValue = 0
                }

                if startsGameWhenFinished {
                    startSelectedGame()
                }
            } else {
                UIImpactFeedbackGenerator(
                    style: .soft
                )
                .impactOccurred()

                withAnimation(
                    .spring(
                        response: 0.28,
                        dampingFraction: 0.72
                    )
                ) {
                    countdownValue = remaining
                }
            }
        }
    }

    private func resetAutomaticStartState() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownValue = nil
        hasStartedCountdown = false
        isStartingGame = false
    }

    // MARK: - Starting games

    private func startSelectedGame() {
        guard isSupportedGame,
              hasConnectedOpponent,
              validLobbySession != nil,
              isLocalHost,
              !isStartingGame else {
            return
        }

        isStartingGame = true

        switch game.id {
        case Game.ticTacToe.id:
            startTicTacToe()

        case Game.rockPaperScissors.id:
            startRockPaperScissors()

        case Game.numberRush.id:
            startNumberRush()

        case Game.battleship.id:
            startBattleship()

        default:
            isStartingGame = false
        }
    }

    private func startTicTacToe() {
        guard let firstPeer = connectedOpponent else {
            isStartingGame = false
            return
        }

        let payload = TicTacToeStartPayload(
            xPlayerName: safePlayerName,
            oPlayerName: firstPeer.displayName
        )

        do {
            let data = try JSONEncoder().encode(payload)

            let message = NearbyMessage(
                gameID: game.id,
                senderName: safePlayerName,
                type: .gameStart,
                payload: data
            )

            nearbyService.send(message)

            localMark = .x
            ticTacToeStartPayload = payload
            shouldStartGame = true
        } catch {
            isStartingGame = false
            hasStartedCountdown = false
            nearbyService.errorMessage =
                "Failed to start Tic Tac Toe."

            print(
                "Failed to encode TicTacToeStartPayload: \(error)"
            )
        }
    }

    private func startRockPaperScissors() {
        guard let firstPeer = connectedOpponent else {
            isStartingGame = false
            return
        }

        let payload = RPSStartPayload(
            playerOneName: safePlayerName,
            playerTwoName: firstPeer.displayName
        )

        do {
            let data = try JSONEncoder().encode(payload)

            let message = NearbyMessage(
                gameID: game.id,
                senderName: safePlayerName,
                type: .gameStart,
                payload: data
            )

            nearbyService.send(message)

            rpsStartPayload = payload
            shouldStartGame = true
        } catch {
            isStartingGame = false
            hasStartedCountdown = false
            nearbyService.errorMessage =
                "Failed to start Rock Paper Scissors."

            print(
                "Failed to encode RPSStartPayload: \(error)"
            )
        }
    }


    private func startNumberRush() {
        guard let firstPeer = connectedOpponent,
              let session = validLobbySession else {
            isStartingGame = false
            return
        }

        let payload = NumberRushStartPayload(
            sessionID: session.sessionID,
            playerOneID: nearbyService.localPlayerID,
            playerOneName: safePlayerName,
            playerTwoID: firstPeer.id,
            playerTwoName: firstPeer.displayName,
            shuffledNumbers: Array(1...100).shuffled(),
            startingPlayerID: nearbyService.localPlayerID,
            turnDuration: 5
        )

        do {
            let data = try JSONEncoder().encode(payload)

            let message = NearbyMessage(
                gameID: game.id,
                senderName: safePlayerName,
                type: .gameStart,
                payload: data
            )

            nearbyService.send(message)

            numberRushStartPayload = payload
            shouldStartGame = true
        } catch {
            isStartingGame = false
            hasStartedCountdown = false
            nearbyService.errorMessage =
                "Failed to start Number Rush."

            print(
                "Failed to encode NumberRushStartPayload: \(error)"
            )
        }
    }


    private func startBattleship() {
        guard let firstPeer = connectedOpponent,
              let session = validLobbySession else {
            isStartingGame = false
            return
        }

        let payload = BattleshipStartPayload(
            sessionID: session.sessionID,
            playerOneID: nearbyService.localPlayerID,
            playerOneName: safePlayerName,
            playerTwoID: firstPeer.id,
            playerTwoName: firstPeer.displayName,
            initialStartingPlayerID:
                nearbyService.localPlayerID
        )

        do {
            let data = try JSONEncoder().encode(payload)

            nearbyService.send(
                NearbyMessage(
                    gameID: game.id,
                    senderName: safePlayerName,
                    type: .gameStart,
                    payload: data
                )
            )

            battleshipStartPayload = payload
            shouldStartGame = true
        } catch {
            isStartingGame = false
            hasStartedCountdown = false
            nearbyService.errorMessage =
                "Failed to start Battleship."

            print(
                "Failed to encode BattleshipStartPayload: \(error)"
            )
        }
    }

    // MARK: - Received messages

    private func handleReceivedMessage(
        _ message: NearbyMessage
    ) {
        guard message.gameID == game.id else {
            return
        }

        switch message.type {
        case .lobbyCountdown:
            guard let data = message.payload else {
                return
            }

            handleLobbyCountdown(data)

        case .gameStart:
            guard !isLocalHost,
                  validLobbySession != nil,
                  let data = message.payload else {
                return
            }

            countdownTimer?.invalidate()
            countdownTimer = nil
            countdownValue = nil

            switch game.id {
            case Game.ticTacToe.id:
                handleTicTacToeStart(data)

            case Game.rockPaperScissors.id:
                handleRockPaperScissorsStart(data)

            case Game.numberRush.id:
                handleNumberRushStart(data)

            case Game.battleship.id:
                handleBattleshipStart(data)

            default:
                break
            }

        default:
            break
        }
    }

    private func handleTicTacToeStart(
        _ data: Data
    ) {
        do {
            let payload = try JSONDecoder().decode(
                TicTacToeStartPayload.self,
                from: data
            )

            localMark = .o
            ticTacToeStartPayload = payload
            isStartingGame = true
            shouldStartGame = true
        } catch {
            nearbyService.errorMessage =
                "Failed to start Tic Tac Toe."

            print(
                "Failed to decode TicTacToeStartPayload: \(error)"
            )
        }
    }

    private func handleRockPaperScissorsStart(
        _ data: Data
    ) {
        do {
            let payload = try JSONDecoder().decode(
                RPSStartPayload.self,
                from: data
            )

            rpsStartPayload = payload
            isStartingGame = true
            shouldStartGame = true
        } catch {
            nearbyService.errorMessage =
                "Failed to start Rock Paper Scissors."

            print(
                "Failed to decode RPSStartPayload: \(error)"
            )
        }
    }


    private func handleNumberRushStart(
        _ data: Data
    ) {
        do {
            let payload = try JSONDecoder().decode(
                NumberRushStartPayload.self,
                from: data
            )

            numberRushStartPayload = payload
            isStartingGame = true
            shouldStartGame = true
        } catch {
            nearbyService.errorMessage =
                "Failed to start Number Rush."

            print(
                "Failed to decode NumberRushStartPayload: \(error)"
            )
        }
    }


    private func handleBattleshipStart(
        _ data: Data
    ) {
        do {
            let payload = try JSONDecoder().decode(
                BattleshipStartPayload.self,
                from: data
            )

            battleshipStartPayload = payload
            isStartingGame = true
            shouldStartGame = true
        } catch {
            nearbyService.errorMessage =
                "Failed to start Battleship."

            print(
                "Failed to decode BattleshipStartPayload: \(error)"
            )
        }
    }

    // MARK: - Game destination

    @ViewBuilder
    private var gameDestination: some View {
        switch game.id {
        case Game.ticTacToe.id:
            TicTacToeView(
                game: game,
                nearbyService: nearbyService,
                localPlayerName: safePlayerName,
                localMark: localMark ?? .o,
                startPayload:
                    ticTacToeStartPayload ??
                    TicTacToeStartPayload(
                        xPlayerName: safePlayerName,
                        oPlayerName:
                            nearbyService
                            .connectedPeers
                            .first?
                            .displayName ?? "Peer"
                    ),
                onExitToHome: exitToHome
            )

        case Game.rockPaperScissors.id:
            RPSView(
                game: game,
                nearbyService: nearbyService,
                localPlayerName: safePlayerName,
                startPayload:
                    rpsStartPayload ??
                    RPSStartPayload(
                        playerOneName: safePlayerName,
                        playerTwoName:
                            nearbyService
                            .connectedPeers
                            .first?
                            .displayName ?? "Peer"
                    ),
                onExitToHome: exitToHome
            )


        case Game.numberRush.id:
            NumberRushView(
                game: game,
                nearbyService: nearbyService,
                localPlayerName: safePlayerName,
                startPayload:
                    numberRushStartPayload ??
                    NumberRushStartPayload(
                        sessionID:
                            nearbyService
                            .lobbySession?
                            .sessionID ?? UUID().uuidString,
                        playerOneID:
                            nearbyService.localPlayerID,
                        playerOneName: safePlayerName,
                        playerTwoID:
                            nearbyService
                            .connectedPeers
                            .first?
                            .id ?? "peer",
                        playerTwoName:
                            nearbyService
                            .connectedPeers
                            .first?
                            .displayName ?? "Peer",
                        shuffledNumbers:
                            Array(1...100).shuffled(),
                        startingPlayerID:
                            nearbyService.localPlayerID,
                        turnDuration: 5
                    ),
                onExitToHome: exitToHome
            )


        case Game.battleship.id:
            BattleshipView(
                game: game,
                nearbyService: nearbyService,
                localPlayerName: safePlayerName,
                startPayload:
                    battleshipStartPayload ??
                    BattleshipStartPayload(
                        sessionID:
                            nearbyService
                            .lobbySession?
                            .sessionID ??
                            UUID().uuidString,
                        playerOneID:
                            nearbyService.localPlayerID,
                        playerOneName:
                            safePlayerName,
                        playerTwoID:
                            nearbyService
                            .connectedPeers
                            .first?
                            .id ?? "peer",
                        playerTwoName:
                            nearbyService
                            .connectedPeers
                            .first?
                            .displayName ?? "Peer",
                        initialStartingPlayerID:
                            nearbyService.localPlayerID
                    ),
                onExitToHome: exitToHome
            )

        default:
            Text("Game not implemented yet")
        }
    }

    // MARK: - Favorites

    private func toggleFavorite() {
        var updatedFavorites =
            favoriteGameIDs.wrappedValue

        if updatedFavorites.contains(game.id) {
            updatedFavorites.remove(game.id)
        } else {
            updatedFavorites.insert(game.id)
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            favoriteGameIDs.wrappedValue =
                updatedFavorites
        }

        UIImpactFeedbackGenerator(
            style: .light
        )
        .impactOccurred()
    }

    // MARK: - Helpers

    private func accentColor(
        for name: String
    ) -> Color {
        let value = name.unicodeScalars.reduce(0) {
            $0 + Int($1.value)
        }

        switch value % 3 {
        case 0:
            return LobbyTheme.brightBlue

        case 1:
            return LobbyTheme.brightPurple

        default:
            return .cyan
        }
    }

    private func cancelAndDismiss() {
        nearbyService.stop()
        isStartingGame = false
        shouldStartGame = false
        dismiss()
    }

    private func exitToHome() {
        nearbyService.stop()
        isStartingGame = false
        shouldStartGame = false
        dismiss()
    }

    // MARK: - Error

    private func errorView(
        _ message: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(
                systemName:
                    "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.red)

            Text(message)
                .font(.footnote)
                .foregroundStyle(
                    Color.white.opacity(0.75)
                )

            Spacer()
        }
        .padding(14)
        .background {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(Color.red.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                Color.red.opacity(0.25),
                lineWidth: 1
            )
        }
    }
}


// MARK: - Unified invitation dialog

private enum LobbyDialogState: Equatable {
    case incoming(NearbyInvitation)
    case outgoing(NearbyOutgoingInvitation)
    case accepted(peerName: String)
    case countdown(value: Int, peerName: String)
    case declined(NearbyInvitationFeedback)
}

private struct UnifiedLobbyDialogOverlay: View {
    let state: LobbyDialogState
    let gameTitle: String
    let invitationDuration: TimeInterval
    let onAccept: () -> Void
    let onDecline: () -> Void

    private var title: String {
        switch state {
        case .incoming:
            return "Game Invitation"
        case .outgoing:
            return "Invitation Sent"
        case .accepted:
            return "Invitation Accepted"
        case .countdown(let value, _):
            return value > 0
                ? "Game is starting"
                : "Starting Game"
        case .declined:
            return "Invitation Declined"
        }
    }

    private var subtitle: String {
        switch state {
        case .incoming(let invitation):
            return "\(invitation.fromPeer.displayName) wants to play \(gameTitle)."

        case .outgoing(let invitation):
            return "Waiting for \(invitation.toPeer.displayName) to respond."

        case .accepted(let peerName):
            return "Connected with \(peerName). Preparing the game…"

        case .countdown(let value, let peerName):
            return value > 0
                ? "You and \(peerName) are ready."
                : "Opening \(gameTitle)…"

        case .declined(let feedback):
            return "\(feedback.peer.displayName) declined your invitation."
        }
    }

    private var iconName: String {
        switch state {
        case .incoming:
            return "gamecontroller.fill"
        case .outgoing:
            return "paperplane.fill"
        case .accepted:
            return "checkmark"
        case .countdown:
            return "bolt.fill"
        case .declined:
            return "xmark"
        }
    }

    private var iconTone: LobbyDialogIcon.Tone {
        switch state {
        case .declined:
            return .danger
        case .accepted:
            return .success
        default:
            return .primary
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                dialogVisual
                    .frame(height: 108)

                VStack(spacing: 7) {
                    Text(title)
                        .font(
                            .system(
                                size: 27,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)
                        .contentTransition(.interpolate)

                    Text(subtitle)
                        .font(
                            .system(
                                size: 15,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(
                            Color.white.opacity(0.58)
                        )
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 40)
                        .contentTransition(.interpolate)
                }

                dialogActions
                    .frame(minHeight: 56)

                dialogProgress
                    .frame(height: 5)
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)
            .padding(.bottom, 20)
            .frame(maxWidth: 420)
            .background {
                RoundedRectangle(
                    cornerRadius: 30,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
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
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 30,
                    style: .continuous
                )
                .stroke(
                    dialogBorder,
                    lineWidth: 1.4
                )
            }
            .shadow(
                color: dialogLeftGlow,
                radius: 22,
                x: -5
            )
            .shadow(
                color: dialogRightGlow,
                radius: 22,
                x: 5
            )
            .padding(.horizontal, 22)
        }
        .animation(
            .spring(
                response: 0.36,
                dampingFraction: 0.84
            ),
            value: state
        )
    }

    @ViewBuilder
    private var dialogVisual: some View {
        switch state {
        case .countdown(let value, _):
            CountdownDialogVisual(value: value)

        default:
            LobbyDialogIcon(
                systemName: iconName,
                tone: iconTone
            )
        }
    }

    @ViewBuilder
    private var dialogActions: some View {
        switch state {
        case .incoming:
            HStack(spacing: 12) {
                Button {
                    onDecline()
                } label: {
                    InvitationActionLabel(
                        title: "Decline",
                        systemName: "xmark",
                        isPrimary: false
                    )
                }
                .buttonStyle(.plain)

                Button {
                    onAccept()
                } label: {
                    InvitationActionLabel(
                        title: "Accept",
                        systemName: "checkmark",
                        isPrimary: true
                    )
                }
                .buttonStyle(.plain)
            }

        case .outgoing:
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.white)

                Text("Waiting for response…")
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.72)
                    )
            }
            .frame(maxWidth: .infinity)

        case .accepted:
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.white)

                Text("Preparing connection…")
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.72)
                    )
            }
            .frame(maxWidth: .infinity)

        case .countdown(let value, _):
            Text(
                value > 0
                    ? "Starting in \(value)…"
                    : "Starting…"
            )
            .font(
                .system(
                    size: 17,
                    weight: .bold,
                    design: .rounded
                )
            )
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .contentTransition(.numericText())

        case .declined:
            HStack(spacing: 9) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)

                Text("Returning to nearby players…")
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.72)
                    )
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var dialogProgress: some View {
        switch state {
        case .incoming(let invitation):
            ExpiringProgressBar(
                expiresAt: invitation.expiresAt,
                duration: invitationDuration
            )

        case .outgoing(let invitation):
            ExpiringProgressBar(
                expiresAt: invitation.expiresAt,
                duration: invitationDuration
            )

        case .accepted:
            IndeterminateDialogProgressBar()

        case .countdown(let value, _):
            CountdownDialogProgressBar(value: value)

        case .declined(let feedback):
            ExpiringProgressBar(
                expiresAt: feedback.expiresAt,
                duration: 1,
                danger: true
            )
        }
    }

    private var dialogBorder: LinearGradient {
        switch state {
        case .declined:
            return LinearGradient(
                colors: [
                    Color.red,
                    Color.red.opacity(0.35)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        default:
            return LobbyTheme.primaryGradient
        }
    }

    private var dialogLeftGlow: Color {
        switch state {
        case .declined:
            return Color.red.opacity(0.24)
        default:
            return LobbyTheme.brightBlue.opacity(0.28)
        }
    }

    private var dialogRightGlow: Color {
        switch state {
        case .declined:
            return Color.red.opacity(0.16)
        default:
            return LobbyTheme.brightPurple.opacity(0.28)
        }
    }
}

private struct LobbyDialogIcon: View {
    enum Tone {
        case primary
        case success
        case danger
    }

    let systemName: String
    let tone: Tone

    private var fillColor: Color {
        switch tone {
        case .primary:
            return LobbyTheme.brightPurple.opacity(0.11)
        case .success:
            return Color.green.opacity(0.11)
        case .danger:
            return Color.red.opacity(0.11)
        }
    }

    private var iconStyle: AnyShapeStyle {
        switch tone {
        case .primary:
            return AnyShapeStyle(
                LobbyTheme.primaryGradient
            )
        case .success:
            return AnyShapeStyle(Color.green)
        case .danger:
            return AnyShapeStyle(Color.red)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .frame(width: 88, height: 88)

            Circle()
                .stroke(
                    iconStyle,
                    lineWidth: 1.5
                )
                .frame(width: 88, height: 88)
                .shadow(
                    color: glowColor.opacity(0.42),
                    radius: 13
                )

            Image(systemName: systemName)
                .font(
                    .system(
                        size: 34,
                        weight: .semibold
                    )
                )
                .foregroundStyle(iconStyle)
                .contentTransition(.interpolate)
        }
    }

    private var glowColor: Color {
        switch tone {
        case .primary:
            return LobbyTheme.brightPurple
        case .success:
            return .green
        case .danger:
            return .red
        }
    }
}

private struct CountdownDialogVisual: View {
    let value: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LobbyTheme
                        .brightPurple
                        .opacity(0.11)
                )
                .frame(width: 104, height: 104)

            Circle()
                .stroke(
                    LobbyTheme.primaryGradient,
                    lineWidth: 2
                )
                .frame(width: 104, height: 104)
                .shadow(
                    color:
                        LobbyTheme
                        .brightBlue
                        .opacity(0.44),
                    radius: 15,
                    x: -4
                )
                .shadow(
                    color:
                        LobbyTheme
                        .brightPurple
                        .opacity(0.44),
                    radius: 15,
                    x: 4
                )

            if value > 0 {
                Text("\(value)")
                    .font(
                        .system(
                            size: 54,
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(
                        LobbyTheme.primaryGradient
                    )
                    .contentTransition(.numericText())
            } else {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
    }
}

private struct InvitationActionLabel: View {
    let title: String
    let systemName: String
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .font(
                    .system(
                        size: 14,
                        weight: .bold
                    )
                )

            Text(title)
        }
        .font(
            .system(
                size: 17,
                weight: .bold,
                design: .rounded
            )
        )
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(
                isPrimary
                ? LobbyTheme.primaryGradient
                : LinearGradient(
                    colors: [
                        Color.white.opacity(0.075),
                        Color.white.opacity(0.035)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                isPrimary
                ? Color.white.opacity(0.34)
                : Color.white.opacity(0.14),
                lineWidth: 1
            )
        }
    }
}

private struct ExpiringProgressBar: View {
    let expiresAt: Date
    let duration: TimeInterval
    var danger: Bool = false

    var body: some View {
        TimelineView(
            .animation(minimumInterval: 0.03)
        ) { timeline in
            let remaining = max(
                expiresAt.timeIntervalSince(
                    timeline.date
                ),
                0
            )

            let progress = min(
                max(remaining / max(duration, 0.01), 0),
                1
            )

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(
                            Color.white.opacity(0.08)
                        )

                    Group {
                        if danger {
                            Color.red
                        } else {
                            LobbyTheme.primaryGradient
                        }
                    }
                    .frame(
                        width:
                            geometry.size.width * progress
                    )
                    .clipShape(Capsule())
                }
            }
        }
    }
}

private struct IndeterminateDialogProgressBar: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date
                .timeIntervalSinceReferenceDate
            let progress = (time * 0.7)
                .truncatingRemainder(dividingBy: 1)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    LobbyTheme.primaryGradient
                        .frame(width: geometry.size.width * 0.34)
                        .offset(
                            x:
                                (geometry.size.width * 1.34) * progress -
                                geometry.size.width * 0.34
                        )
                        .clipShape(Capsule())
                }
                .clipShape(Capsule())
            }
        }
    }
}

private struct CountdownDialogProgressBar: View {
    let value: Int

    private var progress: CGFloat {
        switch value {
        case 3:
            return 0.25
        case 2:
            return 0.50
        case 1:
            return 0.75
        default:
            return 1
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                LobbyTheme.primaryGradient
                    .frame(
                        width: geometry.size.width * progress
                    )
                    .clipShape(Capsule())
            }
        }
        .animation(
            .easeInOut(duration: 0.25),
            value: value
        )
    }
}

// MARK: - Hold to search button

private struct HoldToSearchButton: View {
    @Binding var progress: Double

    let isSearching: Bool
    let onComplete: () -> Void

    @State private var isHolding = false
    @State private var holdStartDate: Date?
    @State private var timer: Timer?

    private let holdDuration: TimeInterval = 1.6

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var visibleFillProgress: Double {
        isSearching ? 1 : clampedProgress
    }

    var body: some View {
        VStack(spacing: 11) {
            GeometryReader { geometry in
                ZStack {
                    // Fundal fix
                    RoundedRectangle(
                        cornerRadius: 36,
                        style: .continuous
                    )
                    .fill(Color.white.opacity(0.045))

                    // Gradientul are dimensiunea completă.
                    // Doar masca este umplută progresiv.
                    LobbyTheme.primaryGradient
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(
                                    width:
                                        geometry.size.width *
                                        visibleFillProgress
                                )
                        }
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 36,
                                style: .continuous
                            )
                        )

                    // Reflexie discretă
                    RoundedRectangle(
                        cornerRadius: 36,
                        style: .continuous
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.11),
                                Color.clear,
                                Color.black.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)

                    HStack(spacing: 18) {
                        if isSearching {
                            SearchingWavesIcon()
                        } else {
                            holdProgressIcon
                        }

                        if isSearching {
                            Text("Searching")
                                .font(
                                    .system(
                                        size: 24,
                                        weight: .bold,
                                        design: .rounded
                                    )
                                )
                                .foregroundStyle(.white)
                        } else {
                            VStack(
                                alignment: .leading,
                                spacing: 4
                            ) {
                                Text("Hold to Search")
                                    .font(
                                        .system(
                                            size: 22,
                                            weight: .bold,
                                            design: .rounded
                                        )
                                    )
                                    .foregroundStyle(.white)

                                Text(
                                    isHolding
                                        ? "\(Int(clampedProgress * 100))%"
                                        : "Press and hold"
                                )
                                .font(
                                    .system(
                                        size: 13,
                                        weight: .medium
                                    )
                                )
                                .foregroundStyle(
                                    Color.white.opacity(0.68)
                                )
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 23)

                    RoundedRectangle(
                        cornerRadius: 36,
                        style: .continuous
                    )
                    .stroke(
                        LobbyTheme.primaryGradient,
                        lineWidth: 1.5
                    )
                }
                // Glow-ul rămâne constant atât înainte,
                // cât și în timpul apăsării.
                .shadow(
                    color:
                        LobbyTheme
                        .brightBlue
                        .opacity(0.27),
                    radius: 15,
                    x: -4
                )
                .shadow(
                    color:
                        LobbyTheme
                        .brightPurple
                        .opacity(0.27),
                    radius: 15,
                    x: 4
                )
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: 36,
                        style: .continuous
                    )
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            startHoldIfNeeded()
                        }
                        .onEnded { _ in
                            endHold()
                        }
                )
                .allowsHitTesting(!isSearching)
            }
            .frame(height: 116)

            if !isSearching {
                Text(
                    "Press and hold to start a nearby session"
                )
                .font(
                    .system(
                        size: 14,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.48)
                )
                .transition(.opacity)
            }
        }
        .animation(
            .easeInOut(duration: 0.22),
            value: isSearching
        )
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private var holdProgressIcon: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.white.opacity(0.22),
                    lineWidth: 2
                )
                .frame(width: 58, height: 58)

            if clampedProgress > 0 {
                Circle()
                    .trim(
                        from: 0,
                        to: clampedProgress
                    )
                    .stroke(
                        Color.white,
                        style: StrokeStyle(
                            lineWidth: 3,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 58, height: 58)
            }

            Image(
                systemName:
                    "dot.radiowaves.left.and.right"
            )
            .font(
                .system(
                    size: 23,
                    weight: .semibold
                )
            )
            .foregroundStyle(.white)
        }
    }

    private func startHoldIfNeeded() {
        guard !isSearching else {
            return
        }

        guard !isHolding else {
            return
        }

        isHolding = true
        holdStartDate = Date()
        progress = 0

        UIImpactFeedbackGenerator(
            style: .soft
        )
        .impactOccurred()

        timer?.invalidate()

        timer = Timer.scheduledTimer(
            withTimeInterval: 0.016,
            repeats: true
        ) { timer in
            guard let holdStartDate else {
                return
            }

            let elapsed = Date().timeIntervalSince(
                holdStartDate
            )

            progress = min(
                elapsed / holdDuration,
                1
            )

            if progress >= 1 {
                timer.invalidate()
                self.timer = nil

                isHolding = false
                self.holdStartDate = nil

                // Gradientul rămâne complet umplut.
                progress = 1

                UINotificationFeedbackGenerator()
                    .notificationOccurred(.success)

                onComplete()
            }
        }
    }

    private func endHold() {
        timer?.invalidate()
        timer = nil

        if progress < 1 {
            withAnimation(
                .easeOut(duration: 0.20)
            ) {
                progress = 0
            }
        }

        isHolding = false
        holdStartDate = nil
    }
}

// MARK: - Animated searching icon

private struct SearchingWavesIcon: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let time =
                timeline.date
                    .timeIntervalSinceReferenceDate

            let variableValue =
                (
                    time * 0.75
                )
                .truncatingRemainder(
                    dividingBy: 1
                )

            Image(
                systemName:
                    "dot.radiowaves.left.and.right",
                variableValue: variableValue
            )
            .font(
                .system(
                    size: 30,
                    weight: .semibold
                )
            )
            .foregroundStyle(.white)
            .symbolRenderingMode(.hierarchical)
            .shadow(color: Color.white.opacity(0.25),radius: 5)
            .frame(width: 58, height: 58)
        }
    }
}

// MARK: - Nearby player row

private struct NearbyPlayerRow: View {
    enum PlayerState {
        case available
        case connected
    }

    let peerName: String
    let state: PlayerState
    let accentColor: Color
    var isReady: Bool = false
    let action: () -> Void

    private var initial: String {
        String(
            peerName
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .prefix(1)
        )
        .uppercased()
    }

    var body: some View {
        HStack(spacing: 15) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 58, height: 58)
                    .overlay {
                        Circle()
                            .stroke(
                                accentColor,
                                lineWidth: 1.5
                            )
                    }
                    .shadow(
                        color: accentColor.opacity(0.38),
                        radius: 9
                    )

                Text(initial.isEmpty ? "?" : initial)
                    .font(
                        .system(
                            size: 22,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)

                Circle()
                    .fill(Color.green)
                    .frame(width: 13, height: 13)
                    .overlay {
                        Circle()
                            .stroke(
                                LobbyTheme.backgroundBottom,
                                lineWidth: 2
                            )
                    }
            }

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(peerName)
                    .font(
                        .system(
                            size: 18,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(
                    state == .connected
                        ? (isReady ? "Ready to play" : "Connected")
                        : "Nearby"
                )
                .font(.system(size: 14))
                .foregroundStyle(
                    Color.white.opacity(0.48)
                )
            }

            Spacer()

            if state == .connected {
                HStack(spacing: 6) {
                    Image(
                        systemName: isReady
                            ? "checkmark"
                            : "clock"
                    )
                    .font(
                        .system(
                            size: 12,
                            weight: .bold
                        )
                    )

                    Text(isReady ? "Ready" : "Waiting")
                }
                .font(
                    .system(
                        size: 14,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    isReady
                        ? Color.green
                        : Color.white.opacity(0.58)
                )
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background {
                    Capsule()
                        .fill(
                            isReady
                                ? Color.green.opacity(0.09)
                                : Color.white.opacity(0.05)
                        )
                }
                .overlay {
                    Capsule()
                        .stroke(
                            isReady
                                ? Color.green.opacity(0.25)
                                : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                }
            } else {
                Button {
                    action()
                } label: {
                    Text("Invite")
                        .font(
                            .system(
                                size: 14,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            LobbyTheme.brightPurple
                        )
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background {
                            Capsule()
                                .fill(
                                    LobbyTheme
                                        .brightPurple
                                        .opacity(0.08)
                                )
                        }
                        .overlay {
                            Capsule()
                                .stroke(
                                    LobbyTheme
                                        .brightPurple
                                        .opacity(0.65),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 17)
        .frame(height: 92)
        .background {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .fill(Color.white.opacity(0.026))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                state == .connected
                    ? Color.green.opacity(0.20)
                    : Color.white.opacity(0.10),
                lineWidth: 1
            )
        }
    }
}

// MARK: - Theme

private enum LobbyTheme {
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

    static let primaryGradient = LinearGradient(
        colors: [
            brightBlue,
            Color(
                red: 0.24,
                green: 0.36,
                blue: 1.00
            ),
            brightPurple
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
    NavigationStack {
        GameLobbyView(game: .ticTacToe)
            .withPlayerNameStorage()
    }
}
