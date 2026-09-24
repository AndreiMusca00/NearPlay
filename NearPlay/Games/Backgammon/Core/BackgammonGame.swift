import Foundation

struct BackgammonGame: Sendable {
    static let pointCount = 24
    static let checkerCount = 15

    let playerOneID: String
    let playerTwoID: String

    /// Same Phone can keep a turn open until the player explicitly taps Ready.
    /// Nearby / Computer keep the original automatic turn-ending behavior.
    let manualTurnCommit: Bool

    private(set) var state: BackgammonGameState

    init(
        playerOneID: String,
        playerTwoID: String,
        state: BackgammonGameState,
        manualTurnCommit: Bool = false
    ) {
        self.playerOneID = playerOneID
        self.playerTwoID = playerTwoID
        self.manualTurnCommit = manualTurnCommit
        self.state = state
    }

    static func makeInitialState(
        startingPlayerID: String
    ) -> BackgammonGameState {
        var points = Array(
            repeating: BackgammonPoint.empty,
            count: pointCount
        )

        // Standard Backgammon starting position.
        // Internal indices 0...23 correspond to points 1...24.
        // Player One travels from 24 -> 1.
        setPoint(&points, index: 23, owner: .playerOne, count: 2)
        setPoint(&points, index: 12, owner: .playerOne, count: 5)
        setPoint(&points, index: 7, owner: .playerOne, count: 3)
        setPoint(&points, index: 5, owner: .playerOne, count: 5)

        // Player Two travels from 1 -> 24.
        setPoint(&points, index: 0, owner: .playerTwo, count: 2)
        setPoint(&points, index: 11, owner: .playerTwo, count: 5)
        setPoint(&points, index: 16, owner: .playerTwo, count: 3)
        setPoint(&points, index: 18, owner: .playerTwo, count: 5)

        return BackgammonGameState(
            points: points,
            playerOneBar: 0,
            playerTwoBar: 0,
            playerOneBorneOff: 0,
            playerTwoBorneOff: 0,
            activePlayerID: startingPlayerID,
            turnID: UUID(),
            dice: [],
            remainingDice: [],
            lastMove: nil,
            winnerPlayerID: nil
        )
    }

    mutating func applyRemoteState(
        _ newState: BackgammonGameState
    ) {
        state = newState
    }

    mutating func reset(
        startingPlayerID: String
    ) {
        state = Self.makeInitialState(
            startingPlayerID: startingPlayerID
        )
    }

    func player(for playerID: String) -> BackgammonPlayer? {
        if playerID == playerOneID {
            return .playerOne
        }

        if playerID == playerTwoID {
            return .playerTwo
        }

        return nil
    }

    func playerID(for player: BackgammonPlayer) -> String {
        player == .playerOne ? playerOneID : playerTwoID
    }

    func legalMoves(
        for playerID: String
    ) -> [BackgammonMove] {
        guard let player = player(for: playerID),
              playerID == state.activePlayerID,
              !state.isFinished,
              !state.remainingDice.isEmpty else {
            return []
        }

        return Self.bestLegalSequences(
            state: state,
            player: player,
            dice: state.remainingDice
        )
        .compactMap(\.first)
        .uniqued()
    }


    /// Returns every legal destination the same checker can reach by using
    /// one or more of the remaining dice consecutively.
    ///
    /// Every step obeys the global dice-usage rules, so each preview can also
    /// be executed as a combined drag without crossing a blocked point.
    ///
    /// Example: with 5 + 1, a checker may expose +1, +5 and +6 destinations.
    /// With 5 + 5, the same checker may expose +5, +10, +15 and +20.
    func moveOptions(
        for playerID: String
    ) -> [BackgammonMoveOption] {
        guard let player = player(for: playerID),
              playerID == state.activePlayerID,
              !state.isFinished,
              !state.remainingDice.isEmpty else {
            return []
        }

        // The first step must obey the normal global Backgammon rules,
        // including maximum dice usage and the higher-die rule.
        let firstMoves = legalMoves(for: playerID)

        var options: [BackgammonMoveOption] = []

        for firstMove in firstMoves {
            var stateAfterFirst = state
            _ = Self.apply(
                firstMove,
                for: player,
                to: &stateAfterFirst
            )

            var remainingDice = state.remainingDice
            if let dieIndex = remainingDice.firstIndex(of: firstMove.die) {
                remainingDice.remove(at: dieIndex)
            }

            let firstOption = BackgammonMoveOption(
                source: firstMove.source,
                destination: firstMove.destination,
                moves: [firstMove]
            )
            options.append(firstOption)

            guard let firstDestination = firstMove.destination else {
                continue
            }

            Self.collectSameCheckerOptions(
                originalSource: firstMove.source,
                currentSource: firstDestination,
                state: stateAfterFirst,
                player: player,
                dice: remainingDice,
                path: [firstMove],
                into: &options
            )
        }

        // Keep one representative option for each source/destination pair.
        // Prefer the shortest path because the UI only needs to know that the
        // destination is reachable; immediate moves are styled separately.
        let sorted = options.sorted { lhs, rhs in
            if lhs.moveCount != rhs.moveCount {
                return lhs.moveCount < rhs.moveCount
            }

            if lhs.totalPips != rhs.totalPips {
                return lhs.totalPips < rhs.totalPips
            }

            return lhs.diceUsed.lexicographicallyPrecedes(
                rhs.diceUsed
            )
        }

        var result: [BackgammonMoveOption] = []

        for option in sorted {
            let alreadyExists = result.contains { existing in
                existing.source == option.source &&
                existing.destination == option.destination
            }

            if !alreadyExists {
                result.append(option)
            }
        }

        return result
    }

    private static func collectSameCheckerOptions(
        originalSource: Int?,
        currentSource: Int,
        state: BackgammonGameState,
        player: BackgammonPlayer,
        dice: [Int],
        path: [BackgammonMove],
        into options: inout [BackgammonMoveOption]
    ) {
        guard !dice.isEmpty else {
            return
        }

        for die in Array(Set(dice)).sorted() {
            let moves = bestLegalSequences(state: state, player: player, dice: dice)
                .compactMap(\.first)
                .uniqued()
                .filter { $0.source == currentSource && $0.die == die }

            for move in moves {
                let nextPath = path + [move]

                options.append(
                    BackgammonMoveOption(
                        source: originalSource,
                        destination: move.destination,
                        moves: nextPath
                    )
                )

                guard let nextSource = move.destination else {
                    continue
                }

                var nextState = state
                _ = apply(
                    move,
                    for: player,
                    to: &nextState
                )

                var nextDice = dice
                if let dieIndex = nextDice.firstIndex(of: die) {
                    nextDice.remove(at: dieIndex)
                }

                collectSameCheckerOptions(
                    originalSource: originalSource,
                    currentSource: nextSource,
                    state: nextState,
                    player: player,
                    dice: nextDice,
                    path: nextPath,
                    into: &options
                )
            }
        }
    }

    /// Returns a move that is genuinely forced by the current globally legal
    /// turn sequences. The comparison intentionally ignores which die is used
    /// for the same source/destination action, which matters during bearing off
    /// with oversized dice.
    func forcedMove(
        for playerID: String
    ) -> BackgammonMove? {
        guard let player = player(for: playerID),
              playerID == state.activePlayerID,
              !state.isFinished,
              !state.remainingDice.isEmpty else {
            return nil
        }

        let sequences = Self.bestLegalSequences(
            state: state,
            player: player,
            dice: state.remainingDice
        )
        .filter { !$0.isEmpty }

        guard !sequences.isEmpty else {
            return nil
        }

        let firstMoves = sequences
            .compactMap(\.first)
            .uniqued()

        guard !firstMoves.isEmpty else {
            return nil
        }

        let unavoidableFirstMoves = firstMoves.filter { candidate in
            sequences.allSatisfy { sequence in
                sequence.contains { move in
                    move.source == candidate.source &&
                    move.destination == candidate.destination
                }
            }
        }

        guard !unavoidableFirstMoves.isEmpty else {
            return nil
        }

        return unavoidableFirstMoves.sorted { lhs, rhs in
            if lhs.die != rhs.die {
                return lhs.die > rhs.die
            }

            let lhsSource = lhs.source ?? -1
            let rhsSource = rhs.source ?? -1
            return lhsSource < rhsSource
        }
        .first
    }

    @discardableResult
    mutating func roll(
        dieOne: Int,
        dieTwo: Int,
        by playerID: String,
        turnID: UUID
    ) -> BackgammonRollResult {
        guard !state.isFinished,
              playerID == state.activePlayerID,
              state.turnID == turnID,
              state.dice.isEmpty,
              (1...6).contains(dieOne),
              (1...6).contains(dieTwo),
              let player = player(for: playerID) else {
            return .ignored
        }

        let rolledDice = [dieOne, dieTwo]
        state.dice = rolledDice
        state.remainingDice = dieOne == dieTwo
            ? Array(repeating: dieOne, count: 4)
            : rolledDice

        let sequences = Self.bestLegalSequences(
            state: state,
            player: player,
            dice: state.remainingDice
        )

        if sequences.first?.isEmpty ?? true {
            let dice = rolledDice

            if !manualTurnCommit {
                endTurn()
            }

            return .noLegalMoves(dice)
        }

        return .rolled(rolledDice)
    }

    @discardableResult
    mutating func play(
        source: Int?,
        destination: Int?,
        by playerID: String,
        turnID: UUID,
        preferredDie: Int? = nil
    ) -> BackgammonMoveResult {
        guard !state.isFinished,
              playerID == state.activePlayerID,
              state.turnID == turnID,
              let player = player(for: playerID) else {
            return .ignored
        }

        var candidates = legalMoves(for: playerID)
            .filter {
                $0.source == source &&
                $0.destination == destination
            }

        if let preferredDie {
            candidates = candidates.filter {
                $0.die == preferredDie
            }
        }

        candidates.sort { lhs, rhs in
            lhs.die < rhs.die
        }

        guard let move = candidates.first else {
            return .ignored
        }

        let didHit = Self.apply(
            move,
            for: player,
            to: &state
        )

        removeOneDie(move.die)
        state.lastMove = move

        if state.borneOffCount(for: player) >= Self.checkerCount {
            state.winnerPlayerID = playerID
            state.remainingDice = []
            return .won(move)
        }

        let remainingSequences = Self.bestLegalSequences(
            state: state,
            player: player,
            dice: state.remainingDice
        )

        let mustEndTurn = state.remainingDice.isEmpty ||
            (remainingSequences.first?.isEmpty ?? true)

        if mustEndTurn {
            if manualTurnCommit {
                return .moved(move, didHit: didHit)
            }

            endTurn()
            return .turnEnded(move, didHit: didHit)
        }

        return .moved(move, didHit: didHit)
    }

    /// In manual-turn mode, Ready becomes valid only after the player rolled
    /// and there are no more legal moves that the rules require them to play.
    func canCommitTurn(
        by playerID: String,
        turnID: UUID
    ) -> Bool {
        guard manualTurnCommit,
              !state.isFinished,
              playerID == state.activePlayerID,
              state.turnID == turnID,
              state.hasRolled,
              let player = player(for: playerID) else {
            return false
        }

        if state.borneOffCount(for: player) >= Self.checkerCount {
            return true
        }

        if state.remainingDice.isEmpty {
            return true
        }

        let sequences = Self.bestLegalSequences(
            state: state,
            player: player,
            dice: state.remainingDice
        )

        return sequences.first?.isEmpty ?? true
    }

    /// Commits the draft turn. Until this is called, Same Phone keeps the
    /// active player and turnID unchanged so every move can still be undone.
    @discardableResult
    mutating func commitTurn(
        by playerID: String,
        turnID: UUID
    ) -> Bool {
        guard canCommitTurn(
            by: playerID,
            turnID: turnID
        ), let player = player(for: playerID) else {
            return false
        }

        if state.borneOffCount(for: player) >= Self.checkerCount {
            state.winnerPlayerID = playerID
            state.remainingDice = []
            return true
        }

        endTurn()
        return true
    }

    // MARK: - Legal move search

    private static func bestLegalSequences(
        state: BackgammonGameState,
        player: BackgammonPlayer,
        dice: [Int]
    ) -> [[BackgammonMove]] {
        guard !dice.isEmpty else {
            return [[]]
        }

        let allSequences = legalSequences(
            state: state,
            player: player,
            dice: dice
        )

        guard let maximumLength = allSequences
            .map(\.count)
            .max() else {
            return [[]]
        }

        var best = allSequences.filter {
            $0.count == maximumLength
        }

        // Official rule: if only one of two different dice can be played,
        // the higher die must be used.
        if maximumLength == 1,
           Set(dice).count > 1,
           let highestPlayableDie = best
            .compactMap({ $0.first?.die })
            .max() {
            best = best.filter {
                $0.first?.die == highestPlayableDie
            }
        }

        return best.isEmpty ? [[]] : best
    }

    private static func legalSequences(
        state: BackgammonGameState,
        player: BackgammonPlayer,
        dice: [Int]
    ) -> [[BackgammonMove]] {
        guard !dice.isEmpty else {
            return [[]]
        }

        var sequences: [[BackgammonMove]] = []
        let uniqueDice = Array(Set(dice)).sorted()

        for die in uniqueDice {
            let moves = singleLegalMoves(
                state: state,
                player: player,
                die: die
            )

            for move in moves {
                var nextState = state
                _ = apply(
                    move,
                    for: player,
                    to: &nextState
                )

                var nextDice = dice
                if let index = nextDice.firstIndex(of: die) {
                    nextDice.remove(at: index)
                }

                let tails = legalSequences(
                    state: nextState,
                    player: player,
                    dice: nextDice
                )

                for tail in tails {
                    sequences.append([move] + tail)
                }
            }
        }

        if sequences.isEmpty {
            return [[]]
        }

        return sequences
    }

    private static func singleLegalMoves(
        state: BackgammonGameState,
        player: BackgammonPlayer,
        die: Int
    ) -> [BackgammonMove] {
        guard (1...6).contains(die) else {
            return []
        }

        if state.barCount(for: player) > 0 {
            let destination = entryPoint(
                for: player,
                die: die
            )

            guard isOpen(
                point: destination,
                for: player,
                in: state
            ) else {
                return []
            }

            return [
                BackgammonMove(
                    source: nil,
                    destination: destination,
                    die: die
                )
            ]
        }

        var moves: [BackgammonMove] = []

        for source in 0..<pointCount {
            let point = state.points[source]

            guard point.owner == player,
                  point.count > 0 else {
                continue
            }

            let destination = source + direction(for: player) * die

            if (0..<pointCount).contains(destination) {
                if isOpen(
                    point: destination,
                    for: player,
                    in: state
                ) {
                    moves.append(
                        BackgammonMove(
                            source: source,
                            destination: destination,
                            die: die
                        )
                    )
                }

                continue
            }

            if canBearOff(
                from: source,
                die: die,
                player: player,
                state: state
            ) {
                moves.append(
                    BackgammonMove(
                        source: source,
                        destination: nil,
                        die: die
                    )
                )
            }
        }

        return moves
    }

    private static func canBearOff(
        from source: Int,
        die: Int,
        player: BackgammonPlayer,
        state: BackgammonGameState
    ) -> Bool {
        guard allCheckersInHome(
            player: player,
            state: state
        ) else {
            return false
        }

        switch player {
        case .playerOne:
            guard (0...5).contains(source) else {
                return false
            }

            let exactDistance = source + 1

            if die == exactDistance {
                return true
            }

            guard die > exactDistance else {
                return false
            }

            // An oversized die can bear off only if there is no checker
            // farther from the edge.
            return ((source + 1)...5).allSatisfy { index in
                state.points[index].owner != player ||
                state.points[index].count == 0
            }

        case .playerTwo:
            guard (18...23).contains(source) else {
                return false
            }

            let exactDistance = 24 - source

            if die == exactDistance {
                return true
            }

            guard die > exactDistance else {
                return false
            }

            return (18..<source).allSatisfy { index in
                state.points[index].owner != player ||
                state.points[index].count == 0
            }
        }
    }

    private static func allCheckersInHome(
        player: BackgammonPlayer,
        state: BackgammonGameState
    ) -> Bool {
        guard state.barCount(for: player) == 0 else {
            return false
        }

        let homeRange: ClosedRange<Int> =
            player == .playerOne ? 0...5 : 18...23

        for index in 0..<pointCount {
            let point = state.points[index]

            if point.owner == player,
               point.count > 0,
               !homeRange.contains(index) {
                return false
            }
        }

        return true
    }

    private static func isOpen(
        point index: Int,
        for player: BackgammonPlayer,
        in state: BackgammonGameState
    ) -> Bool {
        guard (0..<pointCount).contains(index) else {
            return false
        }

        let point = state.points[index]

        return point.owner == nil ||
            point.owner == player ||
            point.count <= 1
    }

    private static func entryPoint(
        for player: BackgammonPlayer,
        die: Int
    ) -> Int {
        player == .playerOne
            ? 24 - die
            : die - 1
    }

    private static func direction(
        for player: BackgammonPlayer
    ) -> Int {
        player == .playerOne ? -1 : 1
    }

    @discardableResult
    private static func apply(
        _ move: BackgammonMove,
        for player: BackgammonPlayer,
        to state: inout BackgammonGameState
    ) -> Bool {
        if let source = move.source {
            removeChecker(
                from: source,
                player: player,
                state: &state
            )
        } else {
            decrementBar(
                for: player,
                state: &state
            )
        }

        guard let destination = move.destination else {
            incrementBorneOff(
                for: player,
                state: &state
            )
            return false
        }

        var didHit = false
        let destinationPoint = state.points[destination]

        if destinationPoint.owner == player.opponent,
           destinationPoint.count == 1 {
            state.points[destination] = .empty
            incrementBar(
                for: player.opponent,
                state: &state
            )
            didHit = true
        }

        addChecker(
            to: destination,
            player: player,
            state: &state
        )

        return didHit
    }

    private static func setPoint(
        _ points: inout [BackgammonPoint],
        index: Int,
        owner: BackgammonPlayer,
        count: Int
    ) {
        points[index] = BackgammonPoint(
            owner: owner,
            count: count
        )
    }

    private static func removeChecker(
        from index: Int,
        player: BackgammonPlayer,
        state: inout BackgammonGameState
    ) {
        guard (0..<pointCount).contains(index),
              state.points[index].owner == player,
              state.points[index].count > 0 else {
            return
        }

        state.points[index].count -= 1

        if state.points[index].count == 0 {
            state.points[index].owner = nil
        }
    }

    private static func addChecker(
        to index: Int,
        player: BackgammonPlayer,
        state: inout BackgammonGameState
    ) {
        guard (0..<pointCount).contains(index) else {
            return
        }

        if state.points[index].owner == player {
            state.points[index].count += 1
        } else {
            state.points[index] = BackgammonPoint(
                owner: player,
                count: 1
            )
        }
    }

    private static func incrementBar(
        for player: BackgammonPlayer,
        state: inout BackgammonGameState
    ) {
        if player == .playerOne {
            state.playerOneBar += 1
        } else {
            state.playerTwoBar += 1
        }
    }

    private static func decrementBar(
        for player: BackgammonPlayer,
        state: inout BackgammonGameState
    ) {
        if player == .playerOne {
            state.playerOneBar = max(0, state.playerOneBar - 1)
        } else {
            state.playerTwoBar = max(0, state.playerTwoBar - 1)
        }
    }

    private static func incrementBorneOff(
        for player: BackgammonPlayer,
        state: inout BackgammonGameState
    ) {
        if player == .playerOne {
            state.playerOneBorneOff += 1
        } else {
            state.playerTwoBorneOff += 1
        }
    }

    private mutating func removeOneDie(
        _ die: Int
    ) {
        if let index = state.remainingDice.firstIndex(of: die) {
            state.remainingDice.remove(at: index)
        }
    }

    private mutating func endTurn() {
        guard !state.isFinished else {
            return
        }

        state.dice = []
        state.remainingDice = []
        state.lastMove = nil
        state.activePlayerID =
            state.activePlayerID == playerOneID
            ? playerTwoID
            : playerOneID
        state.turnID = UUID()
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
