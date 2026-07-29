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

    @State private var showComputerModeInfo = false

    // Tic-Tac-Toe
    @State private var localMark: TicTacToeMark?
    @State private var ticTacToeStartPayload: TicTacToeStartPayload?

    // Rock Paper Scissors
    @State private var rpsStartPayload: RPSStartPayload?

    // MARK: - Computed properties

    private var safePlayerName: String {
        let trimmedName = playerName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return trimmedName.isEmpty ? "Player" : trimmedName
    }

    private var isSupportedGame: Bool {
        game.id == Game.ticTacToe.id ||
        game.id == Game.rockPaperScissors.id
    }

    private var hasConnectedOpponent: Bool {
        !nearbyService.connectedPeers.isEmpty
    }

    private var canStartGame: Bool {
        isSupportedGame &&
        (nearbyService.connectedPeers.count + 1) >= game.minPlayers
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

    private var invitationBinding: Binding<Bool> {
        Binding(
            get: {
                nearbyService.pendingInvitation != nil &&
                !hasConnectedOpponent
            },
            set: { isPresented in
                if !isPresented,
                   nearbyService.pendingInvitation != nil {
                    nearbyService.rejectInvitation()
                }
            }
        )
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
                        if hasConnectedOpponent {
                            connectedOpponentContent
                                .transition(
                                    .opacity.combined(
                                        with: .scale(scale: 0.97)
                                    )
                                )
                        } else {
                            searchingContent
                                .transition(.opacity)
                        }

                        if let error = nearbyService.errorMessage,
                           !error.isEmpty {
                            errorView(error)
                        }
                    }
                    // Spațiu suplimentar pentru ca glow-ul și conturul
                    // butonului să nu fie tăiate în partea de sus.
                    .padding(.top, 22)
                    .padding(.horizontal, 20)
                    .padding(
                        .bottom,
                        hasConnectedOpponent ? 125 : 35
                    )
                }
                .scrollIndicators(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hasConnectedOpponent {
                startGameBottomBar
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onDisappear {
            if !isStartingGame {
                nearbyService.stop()
            }
        }
        .alert(
            "Invitation",
            isPresented: invitationBinding
        ) {
            Button("Accept") {
                nearbyService.acceptInvitation()
            }

            Button("Reject", role: .destructive) {
                nearbyService.rejectInvitation()
            }
        } message: {
            if let pending = nearbyService.pendingInvitation {
                Text(
                    "\(pending.from.displayName) wants to play \(game.title)."
                )
            } else {
                Text("")
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
            guard connectedCount > 0 else {
                return
            }

            // În cazul în care mai exista o invitație deschisă,
            // o respingem deoarece avem deja un adversar.
            if nearbyService.pendingInvitation != nil {
                nearbyService.rejectInvitation()
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
        }
        .onChange(
            of: nearbyService.pendingInvitation != nil
        ) { hasPendingInvitation in
            guard hasPendingInvitation,
                  hasConnectedOpponent else {
                return
            }

            // Nu acceptăm un al doilea adversar după conectare.
            nearbyService.rejectInvitation()
        }
        .navigationDestination(
            isPresented: $shouldStartGame
        ) {
            gameDestination
        }
    }

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
                    hasConnectedOpponent
                        ? "Opponent connected"
                        : "Nearby multiplayer • \(playerCountText)"
                )
                .font(
                    .system(
                        size: 14,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    hasConnectedOpponent
                        ? Color.green.opacity(0.85)
                        : Color.white.opacity(0.5)
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
                    "\(nearbyService.discoveredPeers.count) found"
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

            if nearbyService.discoveredPeers.isEmpty {
                emptyPlayersView
            } else {
                VStack(spacing: 12) {
                    ForEach(
                        nearbyService.discoveredPeers,
                        id: \.id
                    ) { peer in
                        NearbyPlayerRow(
                            peerName: peer.displayName,
                            state: .available,
                            accentColor: accentColor(
                                for: peer.displayName
                            )
                        ) {
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

                Text("Opponent Connected")
                    .font(
                        .system(
                            size: 23,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)

                Text(
                    "Everything is ready. You can start the game."
                )
                .font(.system(size: 15))
                .foregroundStyle(
                    Color.white.opacity(0.5)
                )
                .multilineTextAlignment(.center)
            }
            .padding(.top, 18)

            if let connectedPeer =
                nearbyService.connectedPeers.first {
                NearbyPlayerRow(
                    peerName: connectedPeer.displayName,
                    state: .connected,
                    accentColor: accentColor(
                        for: connectedPeer.displayName
                    ),
                    action: {}
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Start game bottom bar

    private var startGameBottomBar: some View {
        Button {
            startSelectedGame()
        } label: {
            HStack(spacing: 11) {
                Text("Start Game")

                Image(systemName: "chevron.right")
                    .font(
                        .system(
                            size: 15,
                            weight: .bold
                        )
                    )
            }
            .font(
                .system(
                    size: 19,
                    weight: .bold,
                    design: .rounded
                )
            )
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background {
                RoundedRectangle(
                    cornerRadius: 21,
                    style: .continuous
                )
                .fill(
                    canStartGame
                        ? LobbyTheme.primaryGradient
                        : LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 21,
                    style: .continuous
                )
                .stroke(
                    canStartGame
                        ? Color.white.opacity(0.35)
                        : Color.white.opacity(0.10),
                    lineWidth: 1
                )
            }
            .shadow(
                color: canStartGame
                    ? LobbyTheme.brightBlue.opacity(0.32)
                    : .clear,
                radius: 15,
                x: -4
            )
            .shadow(
                color: canStartGame
                    ? LobbyTheme.brightPurple.opacity(0.32)
                    : .clear,
                radius: 15,
                x: 4
            )
        }
        .buttonStyle(.plain)
        .disabled(!canStartGame)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background {
            LinearGradient(
                colors: [
                    LobbyTheme.backgroundBottom.opacity(0),
                    LobbyTheme.backgroundBottom.opacity(0.96),
                    LobbyTheme.backgroundBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Search

    private func startSearching() {
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

    // MARK: - Starting games

    private func startSelectedGame() {
        guard canStartGame else {
            return
        }

        switch game.id {
        case Game.ticTacToe.id:
            startTicTacToe()

        case Game.rockPaperScissors.id:
            startRockPaperScissors()

        default:
            break
        }
    }

    private func startTicTacToe() {
        guard let firstPeer =
                nearbyService.connectedPeers.first else {
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
            isStartingGame = true
            shouldStartGame = true
        } catch {
            nearbyService.errorMessage =
                "Failed to start Tic Tac Toe."

            print(
                "Failed to encode TicTacToeStartPayload: \(error)"
            )
        }
    }

    private func startRockPaperScissors() {
        guard let firstPeer =
                nearbyService.connectedPeers.first else {
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
            isStartingGame = true
            shouldStartGame = true
        } catch {
            nearbyService.errorMessage =
                "Failed to start Rock Paper Scissors."

            print(
                "Failed to encode RPSStartPayload: \(error)"
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

        guard message.type == .gameStart else {
            return
        }

        guard let data = message.payload else {
            return
        }

        switch game.id {
        case Game.ticTacToe.id:
            handleTicTacToeStart(data)

        case Game.rockPaperScissors.id:
            handleRockPaperScissorsStart(data)

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
                        ? "Connected"
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
                    Image(systemName: "checkmark")
                        .font(
                            .system(
                                size: 12,
                                weight: .bold
                            )
                        )

                    Text("Ready")
                }
                .font(
                    .system(
                        size: 14,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.green)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background {
                    Capsule()
                        .fill(Color.green.opacity(0.09))
                }
                .overlay {
                    Capsule()
                        .stroke(
                            Color.green.opacity(0.25),
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
