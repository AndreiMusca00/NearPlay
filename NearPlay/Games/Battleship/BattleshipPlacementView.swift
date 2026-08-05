//
//  BattleshipPlacementView.swift
//  NearPlay
//

import SwiftUI
import UIKit

struct BattleshipPlacementView: View {
    let ownBoard: BattleshipLocalBoard
    let localReady: Bool
    let opponentReady: Bool

    let onShipDropped:
        (
            BattleshipShipDefinition,
            BattleshipCoordinate
        ) -> Void

    let onPlacedShipTap: (String) -> Void
    let onRandomize: () -> Void
    let onReady: () -> Void

    @State private var draggedShipID: String?
    @State private var draggedShipDefinition:
        BattleshipShipDefinition?
    @State private var draggedOrientation:
        BattleshipOrientation = .horizontal
    @State private var dragLocation: CGPoint = .zero

    private let boardPadding: CGFloat = 8
    private let boardSpacing: CGFloat = 3

    private var unplacedShipIDs: Set<String> {
        let placedIDs = Set(
            ownBoard.ships.map(\.id)
        )

        return Set(
            BattleshipShipDefinition
                .standardFleet
                .filter {
                    !placedIDs.contains($0.id)
                }
                .map(\.id)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = PlacementMetrics(
                size: geometry.size
            )

            ZStack(alignment: .topLeading) {
                VStack(spacing: metrics.spacing) {
                    statusCard(
                        height: metrics.statusHeight
                    )

                    BattleshipBoardView(
                        mode: .placement,
                        ownBoard: ownBoard,
                        opponentBoard:
                            BattleshipOpponentBoard(),
                        isInteractionEnabled: !localReady,
                        hiddenShipID: draggedShipID,
                        onCellTap: { _ in },
                        onPlacedShipTap:
                            onPlacedShipTap,
                        onPlacedShipDragChanged: {
                            shipID,
                            location in

                            beginPlacedShipDrag(
                                shipID: shipID,
                                location: location
                            )
                        },
                        onPlacedShipDragEnded: {
                            shipID,
                            location in

                            finishDrag(
                                shipID: shipID,
                                location: location,
                                metrics: metrics
                            )
                        }
                    )
                    .frame(
                        width: metrics.boardSize,
                        height: metrics.boardSize
                    )
                    .padding(boardPadding)
                    .frame(
                        width:
                            metrics.boardSize +
                            boardPadding * 2,
                        height:
                            metrics.boardSize +
                            boardPadding * 2
                    )
                    .background(boardBackground)
                    .frame(maxWidth: .infinity)

                    fleetDock(
                        metrics: metrics
                    )
                    .frame(height: metrics.dockHeight)

                    controlsRow(
                        compact: metrics.isCompact
                    )
                    .frame(height: metrics.controlsHeight)

                    readyButton(
                        height: metrics.readyHeight
                    )
                }

                if let draggedShipDefinition {
                    BattleshipShipView(
                        length:
                            draggedShipDefinition.length,
                        orientation:
                            draggedOrientation,
                        cellSize: metrics.cellSize,
                        isSelected: true,
                        isSunk: false,
                        showsDragHint: false,
                        showsGlow: false
                    )
                    .position(dragLocation)
                    .allowsHitTesting(false)
                    .zIndex(100)
                }
            }
            .coordinateSpace(
                name: "BattleshipPlacementSpace"
            )
        }
    }

    // MARK: - Drag

    private func beginPlacedShipDrag(
        shipID: String,
        location: CGPoint
    ) {
        guard !localReady,
              let ship = ownBoard.ships.first(
                where: { $0.id == shipID }
              ) else {
            return
        }

        draggedShipID = shipID
        draggedShipDefinition =
            BattleshipShipDefinition(
                id: ship.id,
                name: ship.name,
                length: ship.length
            )
        draggedOrientation = ship.orientation
        dragLocation = location
    }

    private func beginDockShipDrag(
        definition: BattleshipShipDefinition,
        location: CGPoint
    ) {
        guard !localReady else {
            return
        }

        draggedShipID = definition.id
        draggedShipDefinition = definition
        draggedOrientation = .horizontal
        dragLocation = location
    }

    private func finishDrag(
        shipID: String,
        location: CGPoint,
        metrics: PlacementMetrics
    ) {
        guard let definition =
                draggedShipDefinition ??
                BattleshipShipDefinition
                .standardFleet
                .first(
                    where: { $0.id == shipID }
                ) else {
            clearDrag()
            return
        }

        let coordinate =
            nearestBoardCoordinate(
                for: location,
                metrics: metrics
            )

        onShipDropped(
            definition,
            coordinate
        )

        clearDrag()
    }

    private func nearestBoardCoordinate(
        for location: CGPoint,
        metrics: PlacementMetrics
    ) -> BattleshipCoordinate {
        let step =
            metrics.cellSize + boardSpacing

        let gridLeft =
            metrics.boardContainerLeft +
            boardPadding

        let gridTop =
            metrics.boardTop +
            boardPadding

        let rawColumn = Int(
            round(
                (
                    location.x -
                    gridLeft -
                    metrics.cellSize / 2
                ) / step
            )
        )

        let rawRow = Int(
            round(
                (
                    location.y -
                    gridTop -
                    metrics.cellSize / 2
                ) / step
            )
        )

        return BattleshipCoordinate(
            row:
                min(
                    max(rawRow, 0),
                    BattleshipGame.boardSize - 1
                ),
            column:
                min(
                    max(rawColumn, 0),
                    BattleshipGame.boardSize - 1
                )
        )
    }

    private func clearDrag() {
        withAnimation(
            .easeOut(duration: 0.10)
        ) {
            draggedShipID = nil
            draggedShipDefinition = nil
        }
    }

    // MARK: - Status

    private func statusCard(
        height: CGFloat
    ) -> some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(
                        BattleshipTheme
                            .cyan
                            .opacity(0.12)
                    )
                    .frame(
                        width: height * 0.64,
                        height: height * 0.64
                    )

                Image(systemName: "scope")
                    .font(
                        .system(
                            size: height * 0.28,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        BattleshipTheme.primaryGradient
                    )
            }

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(
                    localReady
                    ? "Fleet locked"
                    : "Deploy your fleet"
                )
                .font(
                    .system(
                        size: 16,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)

                Text(statusSubtitle)
                    .font(
                        .system(
                            size: 12,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Color.white.opacity(0.48)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 6)

            Text("\(ownBoard.ships.count)/5")
                .font(
                    .system(
                        size: 17,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    BattleshipTheme.cyan
                )
        }
        .padding(.horizontal, 14)
        .frame(height: height)
        .background(
            BattleshipTheme.cardBackground
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 19,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 19,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.09),
                lineWidth: 1
            )
        }
    }

    private var statusSubtitle: String {
        if localReady {
            return opponentReady
                ? "Both fleets are ready."
                : "Waiting for your opponent…"
        }

        return unplacedShipIDs.isEmpty
            ? "Tap a ship to rotate it."
            : "Drag every ship onto the grid."
    }

    // MARK: - Fleet dock

    private func fleetDock(
        metrics: PlacementMetrics
    ) -> some View {
        VStack(spacing: metrics.dockRowSpacing) {
            fleetRow(
                ships: Array(
                    BattleshipShipDefinition
                        .standardFleet[0...1]
                ),
                metrics: metrics
            )

            fleetRow(
                ships: Array(
                    BattleshipShipDefinition
                        .standardFleet[2...4]
                ),
                metrics: metrics
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, metrics.dockPadding)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(Color.white.opacity(0.025))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.08),
                lineWidth: 1
            )
        }
    }

    private func fleetRow(
        ships: [BattleshipShipDefinition],
        metrics: PlacementMetrics
    ) -> some View {
        HStack(
            spacing: metrics.shipSpacing
        ) {
            ForEach(ships) { ship in
                let isUnplaced =
                    unplacedShipIDs.contains(ship.id)

                BattleshipShipView(
                    length: ship.length,
                    orientation: .horizontal,
                    cellSize: metrics.dockCellSize,
                    isSelected: false,
                    isSunk: false,
                    showsDragHint:
                        isUnplaced &&
                        draggedShipID == nil,
                    showsGlow: false
                )
                .opacity(
                    isUnplaced &&
                    draggedShipID != ship.id
                    ? 1
                    : 0
                )
                .frame(
                    width:
                        metrics.dockCellSize *
                        CGFloat(ship.length),
                    height:
                        metrics.dockCellSize * 0.82
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(
                        minimumDistance: 3,
                        coordinateSpace:
                            .named(
                                "BattleshipPlacementSpace"
                            )
                    )
                    .onChanged { value in
                        guard isUnplaced else {
                            return
                        }

                        beginDockShipDrag(
                            definition: ship,
                            location: value.location
                        )
                    }
                    .onEnded { value in
                        guard isUnplaced else {
                            return
                        }

                        finishDrag(
                            shipID: ship.id,
                            location: value.location,
                            metrics: metrics
                        )
                    }
                )
                .allowsHitTesting(
                    isUnplaced && !localReady
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Controls

    private func controlsRow(
        compact: Bool
    ) -> some View {
        HStack(spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "hand.draw.fill")
                    .foregroundStyle(
                        BattleshipTheme.cyan
                    )

                Text(
                    compact
                    ? "Drag • Tap to rotate"
                    : "Drag ships • Tap to rotate"
                )
                .font(
                    .system(
                        size: compact ? 11 : 12,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Color.white.opacity(0.56)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .background {
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .fill(Color.white.opacity(0.025))
            }

            Button(action: onRandomize) {
                HStack(spacing: 7) {
                    Image(systemName: "shuffle")

                    Text("Random")
                }
                .font(
                    .system(
                        size: 13,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(maxHeight: .infinity)
                .background {
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                    .fill(Color.white.opacity(0.045))
                }
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 14,
                        style: .continuous
                    )
                    .stroke(
                        Color.white.opacity(0.10),
                        lineWidth: 1
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(localReady)
        }
    }

    private func readyButton(
        height: CGFloat
    ) -> some View {
        Button(action: onReady) {
            HStack(spacing: 10) {
                if localReady {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(
                        systemName:
                            "checkmark.shield.fill"
                    )
                }

                Text(
                    localReady
                    ? "Waiting for opponent…"
                    : "Ready for Battle"
                )
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
            .frame(height: height)
            .background {
                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
                .fill(
                    ownBoard.allShipsPlaced
                    ? BattleshipTheme.primaryGradient
                    : LinearGradient(
                        colors: [
                            Color.white.opacity(0.07),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
                .stroke(
                    ownBoard.allShipsPlaced
                    ? Color.white.opacity(0.28)
                    : Color.white.opacity(0.10),
                    lineWidth: 1
                )
            }
        }
        .buttonStyle(.plain)
        .disabled(
            !ownBoard.allShipsPlaced ||
            localReady
        )
    }

    private var boardBackground: some View {
        RoundedRectangle(
            cornerRadius: 23,
            style: .continuous
        )
        .fill(Color.white.opacity(0.022))
        .overlay {
            RoundedRectangle(
                cornerRadius: 23,
                style: .continuous
            )
            .stroke(
                BattleshipTheme
                    .cyan
                    .opacity(0.14),
                lineWidth: 1
            )
        }
    }
}

// MARK: - Responsive metrics

private struct PlacementMetrics {
    let size: CGSize

    let horizontalPadding: CGFloat
    let spacing: CGFloat
    let statusHeight: CGFloat
    let dockHeight: CGFloat
    let controlsHeight: CGFloat
    let readyHeight: CGFloat
    let dockPadding: CGFloat
    let dockRowSpacing: CGFloat
    let shipSpacing: CGFloat

    let boardSize: CGFloat
    let cellSize: CGFloat
    let dockCellSize: CGFloat

    let boardTop: CGFloat
    let boardContainerLeft: CGFloat

    let isCompact: Bool

    init(size: CGSize) {
        self.size = size
        isCompact = size.height < 640
        horizontalPadding = 0

        spacing = isCompact ? 7 : 9
        statusHeight = isCompact ? 54 : 62
        controlsHeight = isCompact ? 40 : 44
        readyHeight = isCompact ? 49 : 54
        dockPadding = isCompact ? 6 : 8
        dockRowSpacing = isCompact ? 4 : 6
        shipSpacing = isCompact ? 7 : 10

        let reservedWithoutBoard =
            statusHeight +
            controlsHeight +
            readyHeight +
            spacing * 4

        let preferredDockHeight =
            isCompact ? 82.0 : 96.0

        let maximumBoardFromHeight =
            size.height -
            reservedWithoutBoard -
            preferredDockHeight -
            16

        let maximumBoardFromWidth =
            size.width - 16

        let proposedBoardSize = min(
            maximumBoardFromWidth,
            maximumBoardFromHeight
        )

        // The board must never exceed the available width.
        // On short displays it may shrink, but it cannot be clipped.
        boardSize = min(
            maximumBoardFromWidth,
            max(
                170,
                proposedBoardSize
            )
        )

        cellSize =
            (
                boardSize -
                3 *
                CGFloat(
                    BattleshipGame.boardSize - 1
                )
            ) /
            CGFloat(BattleshipGame.boardSize)

        dockCellSize = min(
            cellSize,
            isCompact ? 24 : 28
        )

        dockHeight = preferredDockHeight

        boardTop =
            statusHeight + spacing

        boardContainerLeft =
            (
                size.width -
                (
                    boardSize + 16
                )
            ) / 2
    }
}
