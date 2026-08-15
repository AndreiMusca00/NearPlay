# GameLobbyView changes for the refactored Tic Tac Toe

The new `TicTacToeStartPayload` now uses:

- `sessionID`
- `playerOneID`
- `playerOneName`
- `playerTwoID`
- `playerTwoName`
- `initialState`

So `GameLobbyView` can no longer call the old initializer:

```swift
TicTacToeStartPayload(xPlayerName: ..., oPlayerName: ...)
```

## 1. Remove old Tic Tac Toe state

Remove this if it exists:

```swift
@State private var localMark: TicTacToeMark?
```

Keep / add this:

```swift
@State private var ticTacToeStartPayload: TicTacToeStartPayload?
```

## 2. Replace `startTicTacToe()`

```swift
private func startTicTacToe() {
    guard let firstPeer = nearbyService.connectedPeers.first else {
        return
    }

    let sessionID =
        nearbyService.lobbySession?.sessionID ??
        UUID().uuidString

    let playerOneID = nearbyService.localPlayerID
    let playerTwoID = firstPeer.id

    let initialState =
        TicTacToeGame.makeInitialState(
            startingPlayerID: playerOneID
        )

    let payload = TicTacToeStartPayload(
        sessionID: sessionID,
        playerOneID: playerOneID,
        playerOneName: safePlayerName,
        playerTwoID: playerTwoID,
        playerTwoName: firstPeer.displayName,
        initialState: initialState
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

        ticTacToeStartPayload = payload
        isStartingGame = true
        shouldStartGame = true
    } catch {
        nearbyService.errorMessage = "Failed to start Tic Tac Toe."
        print("Failed to encode TicTacToeStartPayload: \(error)")
    }
}
```

## 3. Replace `handleTicTacToeStart(_:)`

```swift
private func handleTicTacToeStart(_ data: Data) {
    do {
        let payload = try JSONDecoder().decode(
            TicTacToeStartPayload.self,
            from: data
        )

        ticTacToeStartPayload = payload
        isStartingGame = true
        shouldStartGame = true
    } catch {
        nearbyService.errorMessage = "Failed to start Tic Tac Toe."
        print("Failed to decode TicTacToeStartPayload: \(error)")
    }
}
```

## 4. Replace the Tic Tac Toe case in `gameDestination`

Replace the old call that passed `localMark` with this:

```swift
case Game.ticTacToe.id:
    TicTacToeView(
        game: game,
        nearbyService: nearbyService,
        localPlayerName: safePlayerName,
        startPayload: ticTacToeStartPayload ?? TicTacToeStartPayload(
            sessionID: UUID().uuidString,
            playerOneID: nearbyService.localPlayerID,
            playerOneName: safePlayerName,
            playerTwoID: nearbyService.connectedPeers.first?.id ?? "peer",
            playerTwoName: nearbyService.connectedPeers.first?.displayName ?? "Peer",
            initialState: TicTacToeGame.makeInitialState(
                startingPlayerID: nearbyService.localPlayerID
            )
        ),
        onExitToHome: exitToHome
    )
```

## 5. Keep the RPS / Connect Four cases unchanged

Only adjust the Tic Tac Toe case unless you are also refactoring those games.
