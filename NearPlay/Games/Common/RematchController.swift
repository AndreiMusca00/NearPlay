import Foundation
import Combine

/// Controlează flow-ul comun de revanșă pentru jocurile NearPlay.
///
/// NearbyService rămâne stratul de transport. Controllerul decide când se
/// trimite request/accept/confirmed și garantează că doar host-ul confirmă
/// începerea rundei următoare.
@MainActor
final class RematchController: ObservableObject {
    @Published private(set) var state: RematchState = .available

    /// Se schimbă de fiecare dată când o rundă nouă a fost confirmată.
    /// View-ul jocului ascultă această proprietate și își resetează starea.
    @Published private(set) var confirmedRoundNumber: Int?

    private weak var nearbyService: NearbyService?

    private let gameID: String
    private let sessionID: String
    private let localPlayerID: String
    private let localPlayerName: String
    private let hostPlayerID: String

    private var currentRoundNumber: Int = 1
    private var localAccepted = false
    private var remoteAccepted = false
    private var hasConfirmedCurrentRound = false

    init(
        gameID: String,
        sessionID: String,
        localPlayerID: String,
        localPlayerName: String,
        hostPlayerID: String,
        nearbyService: NearbyService
    ) {
        self.gameID = gameID
        self.sessionID = sessionID
        self.localPlayerID = localPlayerID
        self.localPlayerName = localPlayerName
        self.hostPlayerID = hostPlayerID
        self.nearbyService = nearbyService
    }

    var isLocalHost: Bool {
        localPlayerID == hostPlayerID
    }

    /// Folosit direct de butonul principal al GameResultOverlay.
    func performPrimaryAction() {
        switch state {
        case .available:
            requestRematch()

        case .opponentRequested:
            acceptRematch()

        case .waitingForOpponent, .starting:
            break
        }
    }

    func requestRematch() {
        guard state == .available,
              !localAccepted else {
            return
        }

        localAccepted = true
        state = remoteAccepted
            ? .starting
            : .waitingForOpponent

        send(action: .request)
        confirmIfBothPlayersAccepted()
    }

    func acceptRematch() {
        guard remoteAccepted,
              !localAccepted else {
            return
        }

        localAccepted = true
        state = .starting

        send(action: .accept)
        confirmIfBothPlayersAccepted()
    }

    /// Returnează `true` dacă mesajul a fost un mesaj de rematch și a fost
    /// consumat de controller. Jocul nu mai trebuie să îl proceseze.
    @discardableResult
    func handleIncoming(_ message: NearbyMessage) -> Bool {
        guard message.gameID == gameID,
              message.type == .rematch,
              let data = message.payload else {
            return false
        }

        let payload: RematchPayload

        do {
            payload = try JSONDecoder().decode(
                RematchPayload.self,
                from: data
            )
        } catch {
            print("Failed to decode RematchPayload: \(error)")
            return true
        }

        guard payload.sessionID == sessionID,
              payload.roundNumber == currentRoundNumber,
              payload.playerID != localPlayerID else {
            return true
        }

        switch payload.action {
        case .request, .accept:
            remoteAccepted = true

            if localAccepted {
                state = .starting
                confirmIfBothPlayersAccepted()
            } else {
                state = .opponentRequested(
                    playerName: payload.playerName
                )
            }

        case .confirmed:
            // Numai host-ul stabilit în lobby poate confirma revanșa.
            guard payload.playerID == hostPlayerID else {
                return true
            }

            applyConfirmedRematch()

        case .cancel:
            remoteAccepted = false

            if localAccepted {
                state = .waitingForOpponent
            } else {
                state = .available
            }
        }

        return true
    }

    /// Se apelează după ce jocul și-a resetat tabla/starea internă.
    func finishStartingRound() {
        guard state == .starting else {
            return
        }

        state = .available
    }

    private func confirmIfBothPlayersAccepted() {
        guard localAccepted,
              remoteAccepted else {
            updateStateFromFlags()
            return
        }

        state = .starting

        // Guest-ul așteaptă confirmarea unică trimisă de host.
        guard isLocalHost,
              !hasConfirmedCurrentRound else {
            return
        }

        hasConfirmedCurrentRound = true
        send(action: .confirmed)
        applyConfirmedRematch()
    }

    private func applyConfirmedRematch() {
        let nextRoundNumber = currentRoundNumber + 1

        currentRoundNumber = nextRoundNumber
        localAccepted = false
        remoteAccepted = false
        hasConfirmedCurrentRound = false
        state = .starting
        confirmedRoundNumber = nextRoundNumber
    }

    private func updateStateFromFlags() {
        switch (localAccepted, remoteAccepted) {
        case (false, false):
            state = .available

        case (true, false):
            state = .waitingForOpponent

        case (false, true):
            state = .opponentRequested(
                playerName: "Opponent"
            )

        case (true, true):
            state = .starting
        }
    }

    private func send(action: RematchAction) {
        let payload = RematchPayload(
            sessionID: sessionID,
            roundNumber: currentRoundNumber,
            playerID: localPlayerID,
            playerName: localPlayerName,
            action: action
        )

        do {
            let data = try JSONEncoder().encode(payload)

            let message = NearbyMessage(
                gameID: gameID,
                senderName: localPlayerName,
                type: .rematch,
                payload: data
            )

            nearbyService?.send(message)
        } catch {
            nearbyService?.errorMessage =
                "Failed to send rematch request."

            print("Failed to encode RematchPayload: \(error)")
        }
    }
}
