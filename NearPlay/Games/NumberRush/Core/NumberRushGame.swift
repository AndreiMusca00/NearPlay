import Foundation

struct NumberRushGame: Sendable {
    static let firstTargetNumber = 1
    static let finalTargetNumber = 100

    let playerOneID: String
    let playerTwoID: String
    let baseTurnDuration: TimeInterval

    private(set) var state: NumberRushGameState

    init(
        playerOneID: String,
        playerTwoID: String,
        shuffledNumbers: [Int],
        startingPlayerID: String,
        baseTurnDuration: TimeInterval = 5,
        now: Date = Date()
    ) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID
        self.baseTurnDuration = baseTurnDuration

        self.state = Self.makeInitialState(
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            shuffledNumbers: shuffledNumbers,
            startingPlayerID: startingPlayerID,
            turnDuration: baseTurnDuration,
            now: now
        )
    }

    init(
        playerOneID: String,
        playerTwoID: String,
        baseTurnDuration: TimeInterval,
        state: NumberRushGameState
    ) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID
        self.baseTurnDuration = baseTurnDuration
        self.state = state
    }

    static func makeInitialState(
        playerOneID: String,
        playerTwoID: String,
        shuffledNumbers: [Int],
        startingPlayerID: String,
        turnDuration: TimeInterval = 5,
        now: Date = Date()
    ) -> NumberRushGameState {
        NumberRushGameState(
            shuffledNumbers: shuffledNumbers,
            targetNumber: firstTargetNumber,
            scores: [
                playerOneID: 0,
                playerTwoID: 0
            ],
            activePlayerID: startingPlayerID,
            turnID: UUID(),
            turnStartedAt: now,
            turnDuration: turnDuration,
            isFinished: false
        )
    }

    mutating func applyRemoteState(
        _ newState: NumberRushGameState
    ) {
        state = newState
    }

    mutating func select(
        number: Int,
        by playerID: String,
        turnID: UUID,
        now: Date = Date()
    ) -> NumberRushSelectionOutcome {
        guard !state.isFinished,
              playerID == state.activePlayerID,
              turnID == state.turnID,
              now < state.deadline else {
            return .ignored
        }

        guard number == state.targetNumber else {
            switchTurn(now: now)
            return .wrong(number: number)
        }

        state.scores[playerID, default: 0] += 1

        let selectedTarget = state.targetNumber
        state.targetNumber += 1

        if selectedTarget >= Self.finalTargetNumber {
            state.isFinished = true
            return .finished(number: selectedTarget)
        }

        let remaining = max(
            state.deadline.timeIntervalSince(now),
            0
        )

        state.turnStartedAt = now
        state.turnDuration = remaining + 1

        return .correct(number: selectedTarget)
    }

    mutating func expireTurn(
        expectedTurnID: UUID,
        now: Date = Date()
    ) -> Bool {
        guard !state.isFinished,
              state.turnID == expectedTurnID,
              now >= state.deadline else {
            return false
        }

        switchTurn(now: now)
        return true
    }

    mutating func reset(
        shuffledNumbers: [Int],
        startingPlayerID: String,
        now: Date = Date()
    ) {
        state = Self.makeInitialState(
            playerOneID: playerOneID,
            playerTwoID: playerTwoID,
            shuffledNumbers: shuffledNumbers,
            startingPlayerID: startingPlayerID,
            turnDuration: baseTurnDuration,
            now: now
        )
    }

    func opponentID(
        for playerID: String
    ) -> String {
        playerID == playerOneID
            ? playerTwoID
            : playerOneID
    }

    private mutating func switchTurn(
        now: Date
    ) {
        state.activePlayerID =
            state.activePlayerID == playerOneID
            ? playerTwoID
            : playerOneID

        state.turnID = UUID()
        state.turnStartedAt = now
        state.turnDuration = baseTurnDuration
    }
}
