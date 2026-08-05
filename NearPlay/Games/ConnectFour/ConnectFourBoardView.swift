//
//  ConnectFourBoardView.swift
//  NearPlay
//

import SwiftUI

struct ConnectFourBoardView: View {
    let state: ConnectFourGameState
    let isInteractionEnabled: Bool
    let animationID: UUID
    let onColumnTap: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let metrics = BoardMetrics(
                size: geometry.size
            )

            ZStack(alignment: .topLeading) {
                RoundedRectangle(
                    cornerRadius: metrics.cornerRadius,
                    style: .continuous
                )
                .fill(ConnectFourTheme.boardGradient)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: metrics.cornerRadius,
                        style: .continuous
                    )
                    .stroke(
                        Color.white.opacity(0.20),
                        lineWidth: 1
                    )
                }
                .shadow(
                    color:
                        ConnectFourTheme.blue.opacity(0.24),
                    radius: 16,
                    x: -4
                )
                .shadow(
                    color:
                        ConnectFourTheme.purple.opacity(0.22),
                    radius: 16,
                    x: 4
                )

                VStack(spacing: metrics.spacing) {
                    ForEach(
                        0..<ConnectFourGame.rows,
                        id: \.self
                    ) { row in
                        HStack(spacing: metrics.spacing) {
                            ForEach(
                                0..<ConnectFourGame.columns,
                                id: \.self
                            ) { column in
                                slot(
                                    row: row,
                                    column: column,
                                    metrics: metrics
                                )
                            }
                        }
                    }
                }
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2
                )

                HStack(spacing: metrics.spacing) {
                    ForEach(
                        0..<ConnectFourGame.columns,
                        id: \.self
                    ) { column in
                        Button {
                            onColumnTap(column)
                        } label: {
                            Color.clear
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(
                            width: metrics.cellSize,
                            height: metrics.gridHeight
                        )
                        .disabled(
                            !isInteractionEnabled ||
                            state.isColumnFull(column)
                        )
                        .accessibilityLabel(
                            "Drop disc in column \(column + 1)"
                        )
                    }
                }
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2
                )
            }
        }
    }

    private func slot(
        row: Int,
        column: Int,
        metrics: BoardMetrics
    ) -> some View {
        let coordinate = ConnectFourCoordinate(
            row: row,
            column: column
        )

        let disc = state.disc(
            row: row,
            column: column
        )

        let isWinning =
            state.winningCoordinates.contains(
                coordinate
            )

        return ZStack {
            Circle()
                .fill(ConnectFourTheme.emptySlot)
                .overlay {
                    Circle()
                        .stroke(
                            Color.black.opacity(0.32),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: Color.black.opacity(0.60),
                    radius: 3,
                    x: 0,
                    y: 2
                )

            if let disc {
                FallingConnectFourDisc(
                    disc: disc,
                    coordinate: coordinate,
                    cellSize: metrics.cellSize,
                    rowStep:
                        metrics.cellSize +
                        metrics.spacing,
                    shouldAnimate:
                        coordinate == state.lastMove,
                    animationID: animationID,
                    isWinning: isWinning
                )
            }
        }
        .frame(
            width: metrics.cellSize,
            height: metrics.cellSize
        )
    }
}

private struct FallingConnectFourDisc: View {
    let disc: ConnectFourDisc
    let coordinate: ConnectFourCoordinate
    let cellSize: CGFloat
    let rowStep: CGFloat
    let shouldAnimate: Bool
    let animationID: UUID
    let isWinning: Bool

    @State private var hasLanded = true

    var body: some View {
        ConnectFourDiscView(
            disc: disc,
            size: cellSize * 0.82,
            isWinning: isWinning
        )
        .offset(
            y:
                shouldAnimate && !hasLanded
                ? -CGFloat(coordinate.row + 1) * rowStep
                : 0
        )
        .task(id: animationID) {
            guard shouldAnimate else {
                hasLanded = true
                return
            }

            hasLanded = false
            await Task.yield()

            withAnimation(
                .interpolatingSpring(
                    mass: 0.78,
                    stiffness: 205,
                    damping: 17,
                    initialVelocity: 0
                )
            ) {
                hasLanded = true
            }
        }
    }
}

private struct BoardMetrics {
    let cellSize: CGFloat
    let spacing: CGFloat
    let gridHeight: CGFloat
    let cornerRadius: CGFloat

    init(size: CGSize) {
        spacing = max(
            3,
            min(size.width, size.height) * 0.014
        )

        let horizontalPadding = max(
            10,
            size.width * 0.035
        )

        let verticalPadding = max(
            10,
            size.height * 0.035
        )

        let widthCell =
            (
                size.width -
                horizontalPadding * 2 -
                spacing *
                CGFloat(ConnectFourGame.columns - 1)
            ) /
            CGFloat(ConnectFourGame.columns)

        let heightCell =
            (
                size.height -
                verticalPadding * 2 -
                spacing *
                CGFloat(ConnectFourGame.rows - 1)
            ) /
            CGFloat(ConnectFourGame.rows)

        cellSize = max(
            1,
            min(widthCell, heightCell)
        )

        gridHeight =
            cellSize *
            CGFloat(ConnectFourGame.rows) +
            spacing *
            CGFloat(ConnectFourGame.rows - 1)

        cornerRadius = max(
            18,
            min(size.width, size.height) * 0.075
        )
    }
}
