//
//  BackgammonBoardView.swift
//  NearPlay
//
//  Created by Andrei Musca on 10/09/2026.
//

import SwiftUI

enum BackgammonSelectedSource: Hashable {
    case point(Int)
    case bar
}

struct BackgammonBoardView: View {
    let state: BackgammonGameState
    let selectedSource: BackgammonSelectedSource?
    let legalMoves: [BackgammonMove]
    let interactionPlayer: BackgammonPlayer?
    let isInteractionEnabled: Bool

    let onPointTap: (Int) -> Void
    let onBarTap: () -> Void
    let onMove: (_ source: Int?, _ destination: Int?) -> Void

    @State private var draggedSource: BackgammonSelectedSource?
    @State private var dragLocation: CGPoint?
    @State private var hoveredDestination: Int?

    // Player One travels clockwise on screen:
    // top-left -> top-right -> bottom-right -> bottom-left (home).
    private let topLeft = [23, 22, 21, 20, 19, 18]
    private let topRight = [17, 16, 15, 14, 13, 12]
    private let bottomRight = [11, 10, 9, 8, 7, 6]
    private let bottomLeft = [5, 4, 3, 2, 1, 0]

    private let boardCoordinateSpace = "BackgammonBoardCoordinateSpace"
    private let legalGreen = Color(
        red: 0.23,
        green: 0.95,
        blue: 0.52
    )

    var body: some View {
        GeometryReader { geometry in
            let barWidth = max(26, geometry.size.width * 0.07)

            ZStack {
                boardSurface

                homeBoardTint(
                    player: .playerTwo,
                    isTop: true,
                    geometry: geometry,
                    barWidth: barWidth
                )

                homeBoardTint(
                    player: .playerOne,
                    isTop: false,
                    geometry: geometry,
                    barWidth: barWidth
                )

                VStack(spacing: 0) {
                    pointRow(
                        left: topLeft,
                        right: topRight,
                        isTop: true,
                        boardSize: geometry.size,
                        barWidth: barWidth
                    )

                    Rectangle()
                        .fill(Color.white.opacity(0.055))
                        .frame(height: 1)

                    pointRow(
                        left: bottomLeft,
                        right: bottomRight,
                        isTop: false,
                        boardSize: geometry.size,
                        barWidth: barWidth
                    )
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 24,
                        style: .continuous
                    )
                )

                bar(
                    width: barWidth,
                    boardSize: geometry.size
                )

                if let dragLocation,
                   let player = draggedPlayer {
                    floatingChecker(player: player)
                        .position(dragLocation)
                        .allowsHitTesting(false)
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(20)
                }
            }
            .coordinateSpace(name: boardCoordinateSpace)
            .overlay {
                RoundedRectangle(
                    cornerRadius: 24,
                    style: .continuous
                )
                .stroke(
                    Color.white.opacity(0.15),
                    lineWidth: 1
                )
            }
            .shadow(
                color: Color.black.opacity(0.32),
                radius: 18,
                y: 10
            )
        }
        .aspectRatio(1.42, contentMode: .fit)
    }

    private var boardSurface: some View {
        RoundedRectangle(
            cornerRadius: 24,
            style: .continuous
        )
        .fill(BackgammonTheme.board)
        .overlay {
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.035),
                        Color.clear,
                        Color.black.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private func homeBoardTint(
        player: BackgammonPlayer,
        isTop: Bool,
        geometry: GeometryProxy,
        barWidth: CGFloat
    ) -> some View {
        let availableWidth = geometry.size.width - barWidth
        let quadrantWidth = availableWidth / 2
        let quadrantHeight = geometry.size.height / 2
        let color = BackgammonTheme.checkerColor(for: player)

        return ZStack(alignment: isTop ? .topLeading : .bottomLeading) {
            Rectangle()
                .fill(color.opacity(0.026))

            Text("HOME")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(color.opacity(0.25))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .frame(
            width: quadrantWidth,
            height: quadrantHeight
        )
        .position(
            x: quadrantWidth / 2,
            y: isTop
                ? quadrantHeight / 2
                : quadrantHeight + quadrantHeight / 2
        )
        .allowsHitTesting(false)
    }

    private func pointRow(
        left: [Int],
        right: [Int],
        isTop: Bool,
        boardSize: CGSize,
        barWidth: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(left, id: \.self) { index in
                point(
                    index,
                    isTop: isTop,
                    boardSize: boardSize,
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
                    barWidth: barWidth
                )
            }
        }
    }

    private func point(
        _ index: Int,
        isTop: Bool,
        boardSize: CGSize,
        barWidth: CGFloat
    ) -> some View {
        let point = state.points[index]
        let canSelect = canSelectPoint(index)
        let source = draggedSource ?? selectedSource
        let sourceMoves = legalMoves(for: source)
        let isLegalDestination = sourceMoves.contains {
            $0.destination == index
        }
        let isHovered = hoveredDestination == index
        let isSelected = selectedSource == .point(index)

        return Button {
            onPointTap(index)
        } label: {
            GeometryReader { geometry in
                ZStack(alignment: isTop ? .top : .bottom) {
                    BackgammonTriangle(isTop: isTop)
                        .fill(
                            triangleColor(
                                index: index,
                                isSelected: isSelected
                            )
                        )
                        .padding(.horizontal, 1.4)

                    if isLegalDestination {
                        legalDestinationLine(
                            isTop: isTop,
                            isHovered: isHovered
                        )
                    }

                    checkerStack(
                        point: point,
                        sourceIndex: index,
                        isTop: isTop,
                        availableHeight: geometry.size.height,
                        canDrag: canSelect,
                        boardSize: boardSize,
                        barWidth: barWidth
                    )
                    .padding(isTop ? .top : .bottom, 9)
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .disabled(!isInteractionEnabled && !isLegalDestination)
        .opacity(
            canSelect ||
            isLegalDestination ||
            point.count > 0
                ? 1
                : 0.94
        )
    }

    private func legalDestinationLine(
        isTop: Bool,
        isHovered: Bool
    ) -> some View {
        VStack(spacing: 0) {
            if !isTop {
                Spacer(minLength: 0)
            }

            Capsule()
                .fill(
                    legalGreen.opacity(
                        isHovered ? 1.0 : 0.72
                    )
                )
                .frame(
                    width: isHovered ? 24 : 18,
                    height: isHovered ? 4 : 3
                )
                .shadow(
                    color: legalGreen.opacity(
                        isHovered ? 0.85 : 0.42
                    ),
                    radius: isHovered ? 8 : 4
                )
                .padding(isTop ? .top : .bottom, 6)

            if isTop {
                Spacer(minLength: 0)
            }
        }
        .frame(maxHeight: .infinity)
        .animation(
            .easeOut(duration: 0.12),
            value: isHovered
        )
    }

    private func checkerStack(
        point: BackgammonPoint,
        sourceIndex: Int,
        isTop: Bool,
        availableHeight: CGFloat,
        canDrag: Bool,
        boardSize: CGSize,
        barWidth: CGFloat
    ) -> some View {
        let visibleCount = min(point.count, 5)
        let diameter = min(
            29,
            max(18, availableHeight * 0.145)
        )

        return VStack(spacing: -4.5) {
            ForEach(0..<visibleCount, id: \.self) { position in
                checker(
                    player: point.owner,
                    diameter: diameter,
                    showsCount:
                        position == visibleCount - 1 &&
                        point.count > 5,
                    count: point.count
                )
            }
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            dragGesture(
                from: .point(sourceIndex),
                boardSize: boardSize,
                barWidth: barWidth
            ),
            including: canDrag ? .all : .none
        )
        .scaleEffect(
            draggedSource == .point(sourceIndex)
                ? 0.96
                : 1
        )
        .opacity(
            draggedSource == .point(sourceIndex)
                ? 0.56
                : 1
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: isTop ? .top : .bottom
        )
    }

    private func checker(
        player: BackgammonPlayer?,
        diameter: CGFloat,
        showsCount: Bool,
        count: Int
    ) -> some View {
        ZStack {
            if let player {
                let color = BackgammonTheme.checkerColor(for: player)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(1.0),
                                color.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: diameter, height: diameter)
                    .overlay {
                        Circle()
                            .stroke(
                                Color.white.opacity(0.42),
                                lineWidth: 1
                            )
                    }
                    .overlay {
                        Circle()
                            .stroke(
                                Color.black.opacity(0.15),
                                lineWidth: 3
                            )
                            .padding(3)
                    }
                    .shadow(
                        color: color.opacity(0.38),
                        radius: 5,
                        y: 2
                    )
            }

            if showsCount {
                Text("\(count)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.black.opacity(0.76))
            }
        }
    }

    private func floatingChecker(
        player: BackgammonPlayer
    ) -> some View {
        let color = BackgammonTheme.checkerColor(for: player)

        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            color,
                            color.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 34, height: 34)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.66), lineWidth: 1.5)
                }
                .shadow(color: color.opacity(0.7), radius: 12)

            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 3)
                .frame(width: 27, height: 27)
        }
    }

    private func bar(
        width: CGFloat,
        boardSize: CGSize
    ) -> some View {
        let canSelectBar = interactionPlayer.map {
            state.barCount(for: $0) > 0 &&
            legalMoves.contains { $0.source == nil }
        } ?? false

        return Button(action: onBarTap) {
            VStack(spacing: 8) {
                barCounter(
                    player: .playerTwo,
                    count: state.playerTwoBar,
                    isDraggable:
                        canSelectBar &&
                        interactionPlayer == .playerTwo,
                    boardSize: boardSize,
                    barWidth: width
                )

                Spacer(minLength: 8)

                VStack(spacing: 3) {
                    Capsule()
                        .fill(Color.white.opacity(0.09))
                        .frame(width: 14, height: 2)

                    Capsule()
                        .fill(Color.white.opacity(0.055))
                        .frame(width: 10, height: 2)
                }

                Spacer(minLength: 8)

                barCounter(
                    player: .playerOne,
                    count: state.playerOneBar,
                    isDraggable:
                        canSelectBar &&
                        interactionPlayer == .playerOne,
                    boardSize: boardSize,
                    barWidth: width
                )
            }
            .padding(.vertical, 12)
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .background {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.28),
                        Color.black.opacity(0.16),
                        Color.black.opacity(0.30)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .overlay {
                Rectangle()
                    .stroke(
                        canSelectBar
                            ? legalGreen.opacity(0.34)
                            : Color.white.opacity(0.055),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!isInteractionEnabled || !canSelectBar)
    }

    private func barCounter(
        player: BackgammonPlayer,
        count: Int,
        isDraggable: Bool,
        boardSize: CGSize,
        barWidth: CGFloat
    ) -> some View {
        let color = BackgammonTheme.checkerColor(for: player)

        return ZStack {
            Circle()
                .fill(
                    count > 0
                        ? color
                        : Color.white.opacity(0.05)
                )
                .frame(width: 26, height: 26)
                .overlay {
                    Circle()
                        .stroke(
                            count > 0
                                ? Color.white.opacity(0.35)
                                : Color.white.opacity(0.05),
                            lineWidth: 1
                        )
                }

            Text("\(count)")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(
                    count > 0
                        ? Color.black.opacity(0.74)
                        : Color.white.opacity(0.25)
                )
        }
        .contentShape(Circle())
        .highPriorityGesture(
            dragGesture(
                from: .bar,
                boardSize: boardSize,
                barWidth: barWidth
            ),
            including: isDraggable ? .all : .none
        )
        .opacity(draggedSource == .bar ? 0.55 : 1)
    }

    private func dragGesture(
        from source: BackgammonSelectedSource,
        boardSize: CGSize,
        barWidth: CGFloat
    ) -> some Gesture {
        DragGesture(
            minimumDistance: 3,
            coordinateSpace: .named(boardCoordinateSpace)
        )
        .onChanged { value in
            guard canDrag(source) else {
                return
            }

            if draggedSource == nil {
                withAnimation(.easeOut(duration: 0.12)) {
                    draggedSource = source
                }
            }

            dragLocation = value.location
            hoveredDestination = destination(
                at: value.location,
                from: source,
                boardSize: boardSize,
                barWidth: barWidth
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
                barWidth: barWidth
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

    private func resetDragState() {
        withAnimation(.easeOut(duration: 0.12)) {
            draggedSource = nil
            dragLocation = nil
            hoveredDestination = nil
        }
    }

    private func destination(
        at location: CGPoint,
        from source: BackgammonSelectedSource,
        boardSize: CGSize,
        barWidth: CGFloat
    ) -> Int? {
        let destinations = legalMoves(for: source)
            .compactMap(\.destination)

        return destinations.first { index in
            pointFrame(
                for: index,
                boardSize: boardSize,
                barWidth: barWidth
            )
            .insetBy(dx: -2, dy: -3)
            .contains(location)
        }
    }

    private func pointFrame(
        for index: Int,
        boardSize: CGSize,
        barWidth: CGFloat
    ) -> CGRect {
        let pointWidth = (boardSize.width - barWidth) / 12
        let rowHeight = boardSize.height / 2

        let location = visualLocation(for: index)
        let column = location.column

        let x: CGFloat
        if column < 6 {
            x = CGFloat(column) * pointWidth
        } else {
            x =
                CGFloat(column) * pointWidth +
                barWidth
        }

        return CGRect(
            x: x,
            y: location.isTop ? 0 : rowHeight,
            width: pointWidth,
            height: rowHeight
        )
    }

    private func visualLocation(
        for index: Int
    ) -> (column: Int, isTop: Bool) {
        if let position = topLeft.firstIndex(of: index) {
            return (position, true)
        }

        if let position = topRight.firstIndex(of: index) {
            return (position + 6, true)
        }

        if let position = bottomLeft.firstIndex(of: index) {
            return (position, false)
        }

        if let position = bottomRight.firstIndex(of: index) {
            return (position + 6, false)
        }

        return (0, true)
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

    private func canSelectPoint(_ index: Int) -> Bool {
        guard isInteractionEnabled,
              let interactionPlayer else {
            return false
        }

        return state.points[index].owner == interactionPlayer &&
            legalMoves.contains { $0.source == index }
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

    private func triangleColor(
        index: Int,
        isSelected: Bool
    ) -> Color {
        if isSelected {
            return BackgammonTheme.gold.opacity(0.48)
        }

        return index.isMultiple(of: 2)
            ? BackgammonTheme.cyan.opacity(0.23)
            : BackgammonTheme.purple.opacity(0.25)
    }
}

private struct BackgammonTriangle: Shape {
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
                    y: rect.maxY * 0.88
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
                    y: rect.minY + rect.height * 0.12
                )
            )
        }

        path.closeSubpath()
        return path
    }
}
