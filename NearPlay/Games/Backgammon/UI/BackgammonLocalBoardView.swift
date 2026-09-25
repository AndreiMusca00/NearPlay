import SwiftUI

/// Large landscape board shared by every Backgammon mode. Point arrays come
/// from a presentation-only perspective while all callbacks use canonical indices.
struct BackgammonLocalBoardView: View {
    let state: BackgammonGameState

    let playerOneID: String
    let playerOneName: String
    let playerTwoID: String
    let playerTwoName: String
    let boardPerspective: BackgammonBoardPerspective

    let selectedSource: BackgammonSelectedSource?
    let legalMoves: [BackgammonMove]
    let moveOptions: [BackgammonMoveOption]
    let interactionPlayer: BackgammonPlayer?
    let isInteractionEnabled: Bool
    let automaticMove: BackgammonMove?
    let onAutomaticMoveFinished: (BackgammonMove) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var automaticMoveProgress: CGFloat = 0

    private var liftedSource: BackgammonSelectedSource? {
        if let automaticMove {
            return automaticMove.source.map { .point($0) } ?? .bar
        }
        return draggedSource
    }

    let onPointTap: (Int) -> Void
    let onBarTap: () -> Void
    let onMove: (_ source: Int?, _ destination: Int?) -> Void

    @State private var draggedSource: BackgammonSelectedSource?
    @State private var dragLocation: CGPoint?
    @State private var hoveredDestination: Int?

    private var topLeft: [Int] { boardPerspective.topLeft }
    private var topRight: [Int] { boardPerspective.topRight }
    private var bottomRight: [Int] { boardPerspective.bottomRight }
    private var bottomLeft: [Int] { boardPerspective.bottomLeft }

    private let coordinateSpaceName = "BackgammonLocalBoard"
    private let legalGreen = Color(
        red: 0.24,
        green: 0.95,
        blue: 0.50
    )

    private let frameBrown = Color(
        red: 0.34,
        green: 0.20,
        blue: 0.11
    )

    private let frameHighlight = Color(
        red: 0.54,
        green: 0.34,
        blue: 0.17
    )

    private let fieldColor = Color(
        red: 0.19,
        green: 0.15,
        blue: 0.14
    )

    private let lightPoint = Color(
        red: 0.79,
        green: 0.67,
        blue: 0.51
    )

    private let darkPoint = Color(
        red: 0.57,
        green: 0.20,
        blue: 0.21
    )

    var body: some View {
        GeometryReader { geometry in
            let frameInset = max(
                8,
                geometry.size.height * 0.018
            )
            let trayWidth = min(
                54,
                max(
                    40,
                    geometry.size.width * 0.050
                )
            )
            let barWidth: CGFloat = 72

            let playOriginX =
                frameInset + trayWidth

            let playOriginY = frameInset

            let playSize = CGSize(
                width: max(
                    100,
                    geometry.size.width -
                    frameInset * 2 -
                    trayWidth * 2
                ),
                height: max(
                    100,
                    geometry.size.height -
                    frameInset * 2
                )
            )

            ZStack {
                outerFrame

                playingSurface(
                    originX: playOriginX,
                    originY: playOriginY,
                    size: playSize
                )

                playerSideRail(
                    x: frameInset,
                    width: trayWidth,
                    height: playSize.height,
                    player: leftRailPlayer,
                    playerID: playerID(for: leftRailPlayer),
                    playerName: playerName(for: leftRailPlayer),
                    borneOffCount: state.borneOffCount(for: leftRailPlayer)
                )

                playerSideRail(
                    x:
                        geometry.size.width -
                        frameInset -
                        trayWidth,
                    width: trayWidth,
                    height: playSize.height,
                    player: rightRailPlayer,
                    playerID: playerID(for: rightRailPlayer),
                    playerName: playerName(for: rightRailPlayer),
                    borneOffCount: state.borneOffCount(for: rightRailPlayer)
                )

                homeTint(
                    player: topBoardPlayer,
                    isTop: true,
                    originX: playOriginX,
                    originY: playOriginY,
                    playSize: playSize,
                    barWidth: barWidth
                )

                homeTint(
                    player: bottomBoardPlayer,
                    isTop: false,
                    originX: playOriginX,
                    originY: playOriginY,
                    playSize: playSize,
                    barWidth: barWidth
                )

                VStack(spacing: 0) {
                    pointRow(
                        left: topLeft,
                        right: topRight,
                        isTop: true,
                        boardSize: geometry.size,
                        playOriginX: playOriginX,
                        playOriginY: playOriginY,
                        playSize: playSize,
                        barWidth: barWidth
                    )

                    Rectangle()
                        .fill(Color.black.opacity(0.18))
                        .frame(height: 1)

                    pointRow(
                        left: bottomLeft,
                        right: bottomRight,
                        isTop: false,
                        boardSize: geometry.size,
                        playOriginX: playOriginX,
                        playOriginY: playOriginY,
                        playSize: playSize,
                        barWidth: barWidth
                    )
                }
                .frame(
                    width: playSize.width,
                    height: playSize.height
                )
                .position(
                    x: playOriginX + playSize.width / 2,
                    y: playOriginY + playSize.height / 2
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 7,
                        style: .continuous
                    )
                )

                bar(
                    width: barWidth,
                    height: playSize.height,
                    centerX:
                        playOriginX + playSize.width / 2,
                    centerY:
                        playOriginY + playSize.height / 2,
                    boardSize: geometry.size,
                    playOriginX: playOriginX,
                    playOriginY: playOriginY,
                    playSize: playSize
                )

                if let move = automaticMove, let player = interactionPlayer {
                    automaticChecker(
                        move: move, player: player,
                        originX: playOriginX, originY: playOriginY,
                        playSize: playSize, barWidth: barWidth,
                        trayWidth: trayWidth
                    )
                    .allowsHitTesting(false)
                    .zIndex(50)
                }

                if let dragLocation,
                   let player = draggedPlayer {
                    checker(
                        player: player,
                        diameter: draggedSource == .bar ? 25 : checkerDiameter(
                            availableHeight: (playSize.height - 1) / 2,
                            pointWidth: (playSize.width - barWidth) / 12
                        ),
                        showsCount: false,
                        count: 1
                    )
                        .position(dragLocation)
                        .allowsHitTesting(false)
                        .zIndex(50)
                }
            }
            .coordinateSpace(name: coordinateSpaceName)
            .overlay {
                RoundedRectangle(
                    cornerRadius: 15,
                    style: .continuous
                )
                .stroke(
                    frameHighlight.opacity(0.58),
                    lineWidth: 1
                )
            }
            .shadow(
                color: Color.black.opacity(0.44),
                radius: 18,
                y: 9
            )
        }
        .task(id: automaticMove) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { automaticMoveProgress = 0 }
            guard let move = automaticMove else { return }
            // Commit the source position before starting the slide.
            do { try await Task.sleep(nanoseconds: 30_000_000) }
            catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 0.52), completionCriteria: .removed) {
                automaticMoveProgress = 1
            } completion: {
                onAutomaticMoveFinished(move)
            }
        }
    }

    private func automaticChecker(
        move: BackgammonMove, player: BackgammonPlayer,
        originX: CGFloat, originY: CGFloat, playSize: CGSize,
        barWidth: CGFloat, trayWidth: CGFloat
    ) -> some View {
        let diameter = checkerDiameter(
            availableHeight: (playSize.height - 1) / 2,
            pointWidth: (playSize.width - barWidth) / 12
        )
        let source: CGPoint
        if let index = move.source {
            source = checkerCenter(
                at: index, count: state.points[index].count,
                diameter: diameter, originX: originX, originY: originY,
                playSize: playSize, barWidth: barWidth
            )
        } else {
            source = CGPoint(
                x: originX + playSize.width / 2,
                y: player == topBoardPlayer
                    ? originY + 20.5
                    : originY + playSize.height - 20.5
            )
        }
        let destination: CGPoint
        if let index = move.destination {
            let count = state.points[index].owner == player ? state.points[index].count : 0
            destination = checkerCenter(
                at: index, count: count + 1,
                diameter: diameter, originX: originX, originY: originY,
                playSize: playSize, barWidth: barWidth
            )
        } else {
            // The lower section of each player's side rail holds borne-off pieces.
            destination = CGPoint(
                x: player == leftRailPlayer
                    ? originX - trayWidth / 2
                    : originX + playSize.width + trayWidth / 2,
                y: originY + playSize.height * 0.75
            )
        }
        let progress = reduceMotion ? CGFloat(0) : automaticMoveProgress
        return checker(player: player, diameter: diameter, showsCount: false, count: 1)
            .position(
                x: source.x + (destination.x - source.x) * progress,
                y: source.y + (destination.y - source.y) * progress
            )
            .opacity(reduceMotion ? 1 - automaticMoveProgress : 1)
    }

    private func checkerCenter(
        at index: Int, count: Int, diameter: CGFloat,
        originX: CGFloat, originY: CGFloat, playSize: CGSize, barWidth: CGFloat
    ) -> CGPoint {
        let frame = pointFrame(
            for: index, originX: originX, originY: originY,
            playSize: playSize, barWidth: barWidth
        )
        let stackDepth = CGFloat(max(0, min(count, 5) - 1)) * (diameter - checkerOverlap(diameter: diameter))
        let inset = 5 + diameter / 2 + stackDepth
        return CGPoint(x: frame.midX, y: visualLocation(for: index).isTop ? frame.minY + inset : frame.maxY - inset)
    }

    // MARK: - Board Surface

    private var outerFrame: some View {
        RoundedRectangle(
            cornerRadius: 15,
            style: .continuous
        )
        .fill(
            LinearGradient(
                colors: [
                    frameHighlight,
                    frameBrown,
                    Color(
                        red: 0.23,
                        green: 0.13,
                        blue: 0.08
                    )
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 13,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.10),
                lineWidth: 1
            )
            .padding(3)
        }
    }

    private func playingSurface(
        originX: CGFloat,
        originY: CGFloat,
        size: CGSize
    ) -> some View {
        RoundedRectangle(
            cornerRadius: 7,
            style: .continuous
        )
        .fill(fieldColor)
        .overlay {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.035),
                    Color.clear,
                    Color.black.opacity(0.11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 7,
                    style: .continuous
                )
            )
        }
        .frame(
            width: size.width,
            height: size.height
        )
        .position(
            x: originX + size.width / 2,
            y: originY + size.height / 2
        )
    }

    private func playerSideRail(
        x: CGFloat,
        width: CGFloat,
        height: CGFloat,
        player: BackgammonPlayer,
        playerID: String,
        playerName: String,
        borneOffCount: Int
    ) -> some View {
        let color = BackgammonTheme.checkerColor(for: player)
        let isActive =
            state.activePlayerID == playerID &&
            !state.isFinished

        return VStack(spacing: 7) {
            playerRailIdentity(
                name: playerName,
                color: color,
                isActive: isActive
            )
            .frame(maxHeight: .infinity)

            playerRailBorneOff(
                count: borneOffCount,
                color: color
            )
            .frame(maxHeight: .infinity)
        }
        .padding(.vertical, 4)
        .frame(
            width: width,
            height: height
        )
        .position(
            x: x + width / 2,
            y: height / 2 + max(8, height * 0.018)
        )
    }

    private func playerRailIdentity(
        name: String,
        color: Color,
        isActive: Bool
    ) -> some View {
        VStack(spacing: 5) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(color.opacity(0.22))
                        .frame(width: 33, height: 33)
                        .blur(radius: 8)
                }

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                color,
                                color.opacity(0.68)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 25, height: 25)
                    .overlay {
                        Circle()
                            .stroke(
                                Color.white.opacity(0.50),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: color.opacity(isActive ? 0.78 : 0.20),
                        radius: isActive ? 9 : 3
                    )
            }
            .frame(height: 33)

            Text(name)
                .font(
                    .system(
                        size: 10,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.horizontal, 2)

            Text(isActive ? "TURN" : "WAIT")
                .font(
                    .system(
                        size: 6.5,
                        weight: .black,
                        design: .rounded
                    )
                )
                .tracking(0.5)
                .foregroundStyle(
                    isActive
                        ? color
                        : Color.white.opacity(0.24)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(
                cornerRadius: 6,
                style: .continuous
            )
            .fill(
                isActive
                    ? color.opacity(0.10)
                    : Color.black.opacity(0.18)
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 6,
                style: .continuous
            )
            .stroke(
                isActive
                    ? color.opacity(0.82)
                    : Color.white.opacity(0.07),
                lineWidth: isActive ? 1.5 : 1
            )
        }
        .shadow(
            color: isActive ? color.opacity(0.34) : .clear,
            radius: isActive ? 10 : 0
        )
        .animation(
            .easeInOut(duration: 0.22),
            value: isActive
        )
    }

    private func playerRailBorneOff(
        count: Int,
        color: Color
    ) -> some View {
        VStack(spacing: 4) {
            Text("OUT")
                .font(
                    .system(
                        size: 7,
                        weight: .black,
                        design: .rounded
                    )
                )
                .tracking(0.7)
                .foregroundStyle(
                    Color.white.opacity(0.42)
                )

            Text("\(count)")
                .font(
                    .system(
                        size: 18,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    count > 0
                        ? color
                        : Color.white.opacity(0.30)
                )

            Text("/15")
                .font(
                    .system(
                        size: 8,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.32)
                )

            Capsule()
                .fill(
                    count > 0
                        ? color.opacity(0.72)
                        : Color.white.opacity(0.08)
                )
                .frame(width: 18, height: 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(
                cornerRadius: 6,
                style: .continuous
            )
            .fill(Color.black.opacity(0.18))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 6,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.07),
                lineWidth: 1
            )
        }
    }

    private func homeTint(
        player: BackgammonPlayer,
        isTop: Bool,
        originX: CGFloat,
        originY: CGFloat,
        playSize: CGSize,
        barWidth: CGFloat
    ) -> some View {
        let quadrantWidth =
            (playSize.width - barWidth) / 2
        let quadrantHeight = playSize.height / 2
        let color = BackgammonTheme.checkerColor(for: player)

        let isRight = boardPerspective != .samePhone

        return Rectangle()
            .fill(color.opacity(0.026))
            .frame(
                width: quadrantWidth,
                height: quadrantHeight
            )
            .position(
                x:
                    originX +
                    (isRight
                        ? quadrantWidth * 1.5 + barWidth
                        : quadrantWidth / 2),
                y:
                    originY +
                    (isTop
                        ? quadrantHeight / 2
                        : quadrantHeight * 1.5)
            )
            .allowsHitTesting(false)
    }

    // MARK: - Points

    private func pointRow(
        left: [Int],
        right: [Int],
        isTop: Bool,
        boardSize: CGSize,
        playOriginX: CGFloat,
        playOriginY: CGFloat,
        playSize: CGSize,
        barWidth: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(left, id: \.self) { index in
                point(
                    index,
                    isTop: isTop,
                    boardSize: boardSize,
                    playOriginX: playOriginX,
                    playOriginY: playOriginY,
                    playSize: playSize,
                    barWidth: barWidth
                )
            }

            Color.clear
                .frame(width: barWidth)

            ForEach(right, id: \.self) { index in
                point(
                    index,
                    isTop: isTop,
                    boardSize: boardSize,
                    playOriginX: playOriginX,
                    playOriginY: playOriginY,
                    playSize: playSize,
                    barWidth: barWidth
                )
            }
        }
    }

    private func point(
        _ index: Int,
        isTop: Bool,
        boardSize: CGSize,
        playOriginX: CGFloat,
        playOriginY: CGFloat,
        playSize: CGSize,
        barWidth: CGFloat
    ) -> some View {
        let boardPoint = state.points[index]
        let canSelect = canSelectPoint(index)
        let activeSource = draggedSource ?? selectedSource

        let immediateMoves = legalMoves(
            for: activeSource
        )

        let previewOptions = moveOptions(
            for: activeSource
        )

        let isImmediateDestination = immediateMoves.contains {
            $0.destination == index
        }

        let isPreviewDestination = previewOptions.contains {
            $0.destination == index &&
            $0.moveCount > 1
        }

        let isHovered =
            hoveredDestination == index

        let isSelected =
            selectedSource == .point(index)

        return GeometryReader { geometry in
            ZStack(alignment: isTop ? .top : .bottom) {
                BackgammonLocalTriangle(
                    isTop: isTop
                )
                .fill(
                    triangleColor(
                        index: index,
                        isSelected: isSelected
                    )
                )
                .padding(.horizontal, 0.8)

                if isImmediateDestination || isPreviewDestination {
                    legalDestinationMarker(
                        isTop: isTop,
                        isHovered: isHovered,
                        isImmediate: isImmediateDestination,
                        availableHeight: geometry.size.height,
                        pointWidth: geometry.size.width
                    )
                }

                checkerStack(
                    point: boardPoint,
                    sourceIndex: index,
                    isTop: isTop,
                    availableHeight: geometry.size.height,
                    pointWidth: geometry.size.width
                )
                .padding(isTop ? .top : .bottom, 5)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard canSelect else {
                    return
                }

                onPointTap(index)
            }
            .gesture(
                dragGesture(
                    from: .point(index),
                    boardSize: boardSize,
                    barWidth: barWidth,
                    playOriginX: playOriginX,
                    playOriginY: playOriginY,
                    playSize: playSize
                ),
                including: canSelect ? .all : .none
            )
        }
    }

    private func triangleColor(
        index: Int,
        isSelected: Bool
    ) -> Color {
        // Selection is intentionally not tinted. Legal destinations are shown
        // only by the green destination markers.
        _ = isSelected

        return index.isMultiple(of: 2)
            ? lightPoint.opacity(0.95)
            : darkPoint.opacity(0.92)
    }

    /// Keeps the legal target glued to the outer edge of the playing field.
    /// It no longer floats above the checker stack.
    private func legalDestinationMarker(
        isTop: Bool,
        isHovered: Bool,
        isImmediate: Bool,
        availableHeight: CGFloat,
        pointWidth: CGFloat
    ) -> some View {
        // Immediate destinations and farther same-checker route previews use
        // exactly the same green treatment. `isImmediate` is intentionally
        // kept in the signature to distinguish direct moves from combined routes.
        _ = isImmediate

        return Capsule()
            .fill(
                legalGreen.opacity(0.90)
            )
            .frame(
                width: pointWidth * (isHovered ? 0.88 : 0.76),
                height: isHovered ? 5 : 3
            )
            .shadow(
                color: legalGreen.opacity(
                    isHovered ? 0.95 : 0.50
                ),
                radius: isHovered ? 9 : 5
            )
            .position(
                x: pointWidth / 2,
                y: isTop ? 2.5 : availableHeight - 2.5
            )
            .allowsHitTesting(false)
            .animation(
                .easeOut(duration: 0.10),
                value: isHovered
            )
    }

    // MARK: - Checkers

    private func checkerStack(
        point: BackgammonPoint,
        sourceIndex: Int,
        isTop: Bool,
        availableHeight: CGFloat,
        pointWidth: CGFloat
    ) -> some View {
        let visibleCount = min(point.count, 5)
        let isDraggingFromHere = liftedSource == .point(sourceIndex)
        let displayedCount = max(0, point.count - (isDraggingFromHere ? 1 : 0))
        // Keep the source slots stable so lifting a checker does not move
        // the remaining stack or remove the view that owns the gesture.
        let liftedSlot = isTop ? visibleCount - 1 : 0

        let diameter = checkerDiameter(
            availableHeight: availableHeight,
            pointWidth: pointWidth
        )

        let overlap = checkerOverlap(
            diameter: diameter
        )

        return VStack(spacing: -overlap) {
            ForEach(
                0..<visibleCount,
                id: \.self
            ) { position in
                checker(
                    player: point.owner,
                    diameter: diameter,
                    showsCount:
                        position == visibleCount - 1 &&
                        displayedCount > 5,
                    count: displayedCount
                )
                .opacity(isDraggingFromHere && point.count <= 5 && position == liftedSlot ? 0 : 1)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: isTop ? .top : .bottom
        )

    }

    private func checkerDiameter(
        availableHeight: CGFloat,
        pointWidth: CGFloat
    ) -> CGFloat {
        min(
            pointWidth * 0.88,
            max(
                20,
                availableHeight * 0.175
            )
        )
    }

    private func checkerOverlap(
        diameter: CGFloat
    ) -> CGFloat {
        max(3.5, diameter * 0.13)
    }

    private func checker(
        player: BackgammonPlayer?,
        diameter: CGFloat,
        showsCount: Bool,
        count: Int
    ) -> some View {
        ZStack {
            if let player {
                let color =
                    BackgammonTheme.checkerColor(
                        for: player
                    )

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                color,
                                color.opacity(0.70)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: diameter,
                        height: diameter
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                Color.white.opacity(0.52),
                                lineWidth: 1
                            )
                    }
                    .overlay {
                        Circle()
                            .stroke(
                                Color.black.opacity(0.20),
                                lineWidth: 3
                            )
                            .padding(3)
                    }
                    .shadow(
                        color: color.opacity(0.35),
                        radius: 4,
                        y: 2
                    )
            }

            if showsCount {
                Text("\(count)")
                    .font(
                        .system(
                            size: 9,
                            weight: .black
                        )
                    )
                    .foregroundStyle(
                        Color.black.opacity(0.78)
                    )
            }
        }
    }

    // MARK: - Bar

    private func bar(
        width: CGFloat,
        height: CGFloat,
        centerX: CGFloat,
        centerY: CGFloat,
        boardSize: CGSize,
        playOriginX: CGFloat,
        playOriginY: CGFloat,
        playSize: CGSize
    ) -> some View {
        let canSelectBar = interactionPlayer.map {
            state.barCount(for: $0) > 0 &&
            legalMoves.contains { $0.source == nil }
        } ?? false

        return VStack(spacing: 6) {
            barCounter(
                player: topBoardPlayer,
                count: state.barCount(for: topBoardPlayer)
            )

            Spacer(minLength: 4)

            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: 13, height: 2)

            Spacer(minLength: 4)

            barCounter(
                player: bottomBoardPlayer,
                count: state.barCount(for: bottomBoardPlayer)
            )
        }
        .padding(.vertical, 8)
        .frame(
            width: width,
            height: height
        )
        .background {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.38),
                    frameBrown.opacity(0.80),
                    Color.black.opacity(0.35)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .overlay {
            Rectangle()
                .stroke(
                    canSelectBar
                        ? legalGreen.opacity(0.35)
                        : Color.white.opacity(0.07),
                    lineWidth: 1
                )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard canSelectBar else {
                return
            }

            onBarTap()
        }
        .gesture(
            dragGesture(
                from: .bar,
                boardSize: boardSize,
                barWidth: width,
                playOriginX: playOriginX,
                playOriginY: playOriginY,
                playSize: playSize
            ),
            including: canSelectBar ? .all : .none
        )
        .position(
            x: centerX,
            y: centerY
        )
    }

    private func barCounter(
        player: BackgammonPlayer,
        count: Int
    ) -> some View {
        let displayedCount = max(0, count - (
            liftedSource == .bar && interactionPlayer == player ? 1 : 0
        ))
        let color =
            BackgammonTheme.checkerColor(
                for: player
            )

        return ZStack {
            Circle()
                .fill(
                    displayedCount > 0
                        ? color
                        : Color.white.opacity(0.055)
                )
                .frame(width: 25, height: 25)
                .overlay {
                    Circle()
                        .stroke(
                            Color.white.opacity(
                                displayedCount > 0 ? 0.34 : 0.06
                            ),
                            lineWidth: 1
                        )
                }

            Text("\(displayedCount)")
                .font(
                    .system(
                        size: 9,
                        weight: .black
                    )
                )
                .foregroundStyle(
                    displayedCount > 0
                        ? Color.black.opacity(0.74)
                        : Color.white.opacity(0.24)
                )
        }
    }

    // MARK: - Drag

    private func dragGesture(
        from source: BackgammonSelectedSource,
        boardSize: CGSize,
        barWidth: CGFloat,
        playOriginX: CGFloat? = nil,
        playOriginY: CGFloat? = nil,
        playSize: CGSize? = nil
    ) -> some Gesture {
        DragGesture(
            minimumDistance: 3,
            coordinateSpace:
                .named(coordinateSpaceName)
        )
        .onChanged { value in
            guard canDrag(source) else {
                return
            }

            if draggedSource == nil {
                draggedSource = source
            }

            dragLocation = value.location

            hoveredDestination = destination(
                at: value.location,
                from: source,
                boardSize: boardSize,
                barWidth: barWidth,
                playOriginX: playOriginX,
                playOriginY: playOriginY,
                playSize: playSize
            )
        }
        .onEnded { value in
            guard draggedSource == source else {
                resetDragState()
                return
            }

            let destination = destination(
                at: value.location,
                from: source,
                boardSize: boardSize,
                barWidth: barWidth,
                playOriginX: playOriginX,
                playOriginY: playOriginY,
                playSize: playSize
            )

            if let destination {
                onMove(
                    sourceIndex(for: source),
                    destination
                )
            }

            resetDragState()
        }
    }

    private func destination(
        at location: CGPoint,
        from source: BackgammonSelectedSource,
        boardSize: CGSize,
        barWidth: CGFloat,
        playOriginX: CGFloat? = nil,
        playOriginY: CGFloat? = nil,
        playSize: CGSize? = nil
    ) -> Int? {
        let frameInset = max(
            8,
            boardSize.height * 0.028
        )
        let trayWidth = max(
            24,
            boardSize.width * 0.047
        )

        let originX =
            playOriginX ??
            (frameInset + trayWidth)

        let originY =
            playOriginY ??
            frameInset

        let resolvedPlaySize =
            playSize ??
            CGSize(
                width:
                    boardSize.width -
                    frameInset * 2 -
                    trayWidth * 2,
                height:
                    boardSize.height -
                    frameInset * 2
            )

        let destinations =
            moveOptions(for: source)
                .compactMap(\.destination)

        return destinations.first { index in
            pointFrame(
                for: index,
                originX: originX,
                originY: originY,
                playSize: resolvedPlaySize,
                barWidth: barWidth
            )
            .insetBy(dx: -4, dy: -4)
            .contains(location)
        }
    }

    private func pointFrame(
        for index: Int,
        originX: CGFloat,
        originY: CGFloat,
        playSize: CGSize,
        barWidth: CGFloat
    ) -> CGRect {
        let pointWidth =
            (playSize.width - barWidth) / 12
        let rowHeight =
            playSize.height / 2

        let location =
            visualLocation(for: index)

        let x: CGFloat
        if location.column < 6 {
            x =
                originX +
                CGFloat(location.column) *
                pointWidth
        } else {
            x =
                originX +
                CGFloat(location.column) *
                pointWidth +
                barWidth
        }

        return CGRect(
            x: x,
            y:
                originY +
                (location.isTop ? 0 : rowHeight),
            width: pointWidth,
            height: rowHeight
        )
    }

    private func visualLocation(
        for index: Int
    ) -> (column: Int, isTop: Bool) {
        boardPerspective.visualLocation(
            forCanonicalPoint: index
        ) ?? (0, true)
    }

    private var topBoardPlayer: BackgammonPlayer {
        boardPerspective == .samePhone
            ? .playerOne
            : boardPerspective.opponentPlayer
    }

    private var bottomBoardPlayer: BackgammonPlayer {
        boardPerspective == .samePhone
            ? .playerTwo
            : boardPerspective.viewerPlayer
    }

    private var leftRailPlayer: BackgammonPlayer {
        boardPerspective == .samePhone
            ? .playerOne
            : boardPerspective.opponentPlayer
    }

    private var rightRailPlayer: BackgammonPlayer {
        boardPerspective == .samePhone
            ? .playerTwo
            : boardPerspective.viewerPlayer
    }

    private func playerID(
        for player: BackgammonPlayer
    ) -> String {
        player == .playerOne ? playerOneID : playerTwoID
    }

    private func playerName(
        for player: BackgammonPlayer
    ) -> String {
        player == .playerOne ? playerOneName : playerTwoName
    }

    private func legalMoves(
        for source: BackgammonSelectedSource?
    ) -> [BackgammonMove] {
        guard let source else {
            return []
        }

        switch source {
        case .bar:
            return legalMoves.filter {
                $0.source == nil
            }

        case .point(let index):
            return legalMoves.filter {
                $0.source == index
            }
        }
    }

    private func moveOptions(
        for source: BackgammonSelectedSource?
    ) -> [BackgammonMoveOption] {
        guard let source else {
            return []
        }

        switch source {
        case .bar:
            return moveOptions.filter {
                $0.source == nil
            }

        case .point(let index):
            return moveOptions.filter {
                $0.source == index
            }
        }
    }

    private func sourceIndex(
        for source: BackgammonSelectedSource
    ) -> Int? {
        switch source {
        case .bar:
            return nil

        case .point(let index):
            return index
        }
    }

    private func canDrag(
        _ source: BackgammonSelectedSource
    ) -> Bool {
        guard isInteractionEnabled else {
            return false
        }

        switch source {
        case .bar:
            return legalMoves.contains {
                $0.source == nil
            }

        case .point(let index):
            return canSelectPoint(index)
        }
    }

    private func canSelectPoint(
        _ index: Int
    ) -> Bool {
        guard isInteractionEnabled,
              let interactionPlayer else {
            return false
        }

        return
            state.points[index].owner ==
                interactionPlayer &&
            legalMoves.contains {
                $0.source == index
            }
    }

    private var draggedPlayer: BackgammonPlayer? {
        guard let draggedSource else {
            return nil
        }

        switch draggedSource {
        case .bar:
            return interactionPlayer

        case .point(let index):
            return state.points[index].owner
        }
    }

    private func resetDragState() {
        draggedSource = nil
        dragLocation = nil
        hoveredDestination = nil
    }
}

private struct BackgammonLocalTriangle: Shape {
    let isTop: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()

        if isTop {
            path.move(
                to: CGPoint(
                    x: rect.minX,
                    y: rect.minY
                )
            )
            path.addLine(
                to: CGPoint(
                    x: rect.maxX,
                    y: rect.minY
                )
            )
            path.addLine(
                to: CGPoint(
                    x: rect.midX,
                    y:
                        rect.minY +
                        rect.height * 0.78
                )
            )
        } else {
            path.move(
                to: CGPoint(
                    x: rect.minX,
                    y: rect.maxY
                )
            )
            path.addLine(
                to: CGPoint(
                    x: rect.maxX,
                    y: rect.maxY
                )
            )
            path.addLine(
                to: CGPoint(
                    x: rect.midX,
                    y:
                        rect.maxY -
                        rect.height * 0.78
                )
            )
        }

        path.closeSubpath()
        return path
    }
}
