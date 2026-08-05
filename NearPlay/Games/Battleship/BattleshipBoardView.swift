import SwiftUI

enum BattleshipBoardMode {
    case placement
    case ownBattle
    case opponentBattle
}

struct BattleshipBoardView: View {
    let mode: BattleshipBoardMode
    let ownBoard: BattleshipLocalBoard
    let opponentBoard: BattleshipOpponentBoard

    var isInteractionEnabled = true
    var hiddenShipID: String?

    let onCellTap: (BattleshipCoordinate) -> Void
    var onPlacedShipTap: ((String) -> Void)?
    var onPlacedShipDragChanged:
        ((String, CGPoint) -> Void)?
    var onPlacedShipDragEnded:
        ((String, CGPoint) -> Void)?

    @State
    private var activePlacementShipID: String?

    private let spacing: CGFloat = 3
    private let dragThreshold: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            let cellSize =
                (
                    geometry.size.width -
                    spacing *
                    CGFloat(BattleshipGame.boardSize - 1)
                ) /
                CGFloat(BattleshipGame.boardSize)

            let boardFrame = geometry.frame(
                in: .named(
                    "BattleshipPlacementSpace"
                )
            )

            ZStack(alignment: .topLeading) {
                grid(cellSize: cellSize)

                if mode != .opponentBattle {
                    shipsLayer(cellSize: cellSize)
                }
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.width
            )
            .contentShape(Rectangle())
            .gesture(
                placementDragGesture(
                    cellSize: cellSize,
                    boardFrame: boardFrame
                ),
                including:
                    mode == .placement &&
                    isInteractionEnabled
                    ? .all
                    : .none
            )
            .simultaneousGesture(
                placementTapGesture(
                    cellSize: cellSize,
                    boardFrame: boardFrame
                ),
                including:
                    mode == .placement &&
                    isInteractionEnabled
                    ? .all
                    : .none
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Grid

    private func grid(
        cellSize: CGFloat
    ) -> some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(
                    .fixed(cellSize),
                    spacing: spacing
                ),
                count: BattleshipGame.boardSize
            ),
            spacing: spacing
        ) {
            ForEach(
                0..<(BattleshipGame.boardSize *
                     BattleshipGame.boardSize),
                id: \.self
            ) { index in
                let coordinate =
                    BattleshipCoordinate(
                        row:
                            index /
                            BattleshipGame.boardSize,
                        column:
                            index %
                            BattleshipGame.boardSize
                    )

                BattleshipCellView(
                    coordinate: coordinate,
                    mode: mode,
                    ownBoard: ownBoard,
                    opponentBoard: opponentBoard
                )
                .frame(
                    width: cellSize,
                    height: cellSize
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    guard mode != .placement,
                          isInteractionEnabled else {
                        return
                    }

                    onCellTap(coordinate)
                }
            }
        }
    }

    // MARK: - Ships

    @ViewBuilder
    private func shipsLayer(
        cellSize: CGFloat
    ) -> some View {
        ForEach(ownBoard.ships) { ship in
            let center = shipCenter(
                for: ship,
                cellSize: cellSize
            )

            BattleshipShipView(
                length: ship.length,
                orientation: ship.orientation,
                cellSize: cellSize,
                isSelected: mode == .placement,
                isSunk: ship.isSunk,
                showsGlow: mode != .placement
            )
            .opacity(
                hiddenShipID == ship.id
                ? 0
                : 1
            )
            .position(
                x: center.x,
                y: center.y
            )
            .zIndex(10)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Placement interaction

    private func placementTapGesture(
        cellSize: CGFloat,
        boardFrame: CGRect
    ) -> some Gesture {
        SpatialTapGesture(
            coordinateSpace:
                .named(
                    "BattleshipPlacementSpace"
                )
        )
        .onEnded { value in
            guard mode == .placement,
                  isInteractionEnabled,
                  hiddenShipID == nil,
                  let shipID = shipID(
                    at: value.location,
                    cellSize: cellSize,
                    boardFrame: boardFrame
                  ) else {
                return
            }

            onPlacedShipTap?(shipID)
        }
    }

    private func placementDragGesture(
        cellSize: CGFloat,
        boardFrame: CGRect
    ) -> some Gesture {
        DragGesture(
            minimumDistance: dragThreshold,
            coordinateSpace:
                .named(
                    "BattleshipPlacementSpace"
                )
        )
        .onChanged { value in
            guard mode == .placement,
                  isInteractionEnabled else {
                return
            }

            if activePlacementShipID == nil {
                activePlacementShipID =
                    shipID(
                        at: value.startLocation,
                        cellSize: cellSize,
                        boardFrame: boardFrame
                    )
            }

            guard let shipID =
                    activePlacementShipID else {
                return
            }

            onPlacedShipDragChanged?(
                shipID,
                value.location
            )
        }
        .onEnded { value in
            guard mode == .placement,
                  isInteractionEnabled else {
                activePlacementShipID = nil
                return
            }

            let shipID =
                activePlacementShipID ??
                self.shipID(
                    at: value.startLocation,
                    cellSize: cellSize,
                    boardFrame: boardFrame
                )

            activePlacementShipID = nil

            guard let shipID else {
                return
            }

            onPlacedShipDragEnded?(
                shipID,
                value.location
            )
        }
    }

    private func shipID(
        at point: CGPoint,
        cellSize: CGFloat,
        boardFrame: CGRect
    ) -> String? {
        let localPoint = CGPoint(
            x: point.x - boardFrame.minX,
            y: point.y - boardFrame.minY
        )

        guard localPoint.x >= 0,
              localPoint.y >= 0,
              localPoint.x <= boardFrame.width,
              localPoint.y <= boardFrame.height else {
            return nil
        }

        // Reversed makes the visually uppermost ship win
        // in the unlikely event that two hit rectangles touch.
        let matchingShip =
            ownBoard.ships.reversed().first {
                ship in

                shipRect(
                    for: ship,
                    cellSize: cellSize
                )
                .insetBy(dx: -3, dy: -3)
                .contains(localPoint)
            }

        return matchingShip?.id
    }

    private func shipRect(
        for ship: BattleshipPlacedShip,
        cellSize: CGFloat
    ) -> CGRect {
        let step = cellSize + spacing

        let leadingX =
            CGFloat(ship.origin.column) * step

        let topY =
            CGFloat(ship.origin.row) * step

        switch ship.orientation {
        case .horizontal:
            let height = cellSize * 0.80

            return CGRect(
                x: leadingX,
                y:
                    topY +
                    (cellSize - height) / 2,
                width:
                    cellSize *
                    CGFloat(ship.length),
                height: height
            )

        case .vertical:
            let width = cellSize * 0.80

            return CGRect(
                x:
                    leadingX +
                    (cellSize - width) / 2,
                y: topY,
                width: width,
                height:
                    cellSize *
                    CGFloat(ship.length)
            )
        }
    }

    private func shipCenter(
        for ship: BattleshipPlacedShip,
        cellSize: CGFloat
    ) -> CGPoint {
        let rect = shipRect(
            for: ship,
            cellSize: cellSize
        )

        return CGPoint(
            x: rect.midX,
            y: rect.midY
        )
    }

}

private struct BattleshipCellView: View {
    let coordinate: BattleshipCoordinate
    let mode: BattleshipBoardMode
    let ownBoard: BattleshipLocalBoard
    let opponentBoard: BattleshipOpponentBoard

    private var mark: BattleshipCellMark? {
        switch mode {
        case .placement, .ownBattle:
            return ownBoard.mark(at: coordinate)

        case .opponentBattle:
            return opponentBoard.marks[coordinate]
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: 7,
                style: .continuous
            )
            .fill(cellBackground)

            RoundedRectangle(
                cornerRadius: 7,
                style: .continuous
            )
            .stroke(
                cellBorder,
                lineWidth: 0.8
            )

            if let mark {
                markView(mark)
            }
        }
    }

    private var cellBackground: Color {
        switch mark {
        case .miss:
            return Color.white.opacity(0.04)
        case .hit:
            return Color.orange.opacity(0.17)
        case .sunk:
            return Color.red.opacity(0.20)
        case nil:
            return BattleshipTheme.waterCell
        }
    }

    private var cellBorder: Color {
        switch mark {
        case .miss:
            return Color.white.opacity(0.18)
        case .hit:
            return Color.orange.opacity(0.72)
        case .sunk:
            return Color.red.opacity(0.86)
        case nil:
            return BattleshipTheme.cyan.opacity(0.16)
        }
    }

    @ViewBuilder
    private func markView(
        _ mark: BattleshipCellMark
    ) -> some View {
        switch mark {
        case .miss:
            Circle()
                .fill(Color.white.opacity(0.66))
                .frame(width: 7, height: 7)

        case .hit:
            Image(systemName: "burst.fill")
                .font(
                    .system(
                        size: 13,
                        weight: .bold
                    )
                )
                .foregroundStyle(.orange)
                .shadow(
                    color: Color.orange.opacity(0.75),
                    radius: 5
                )

        case .sunk:
            Image(systemName: "xmark")
                .font(
                    .system(
                        size: 18,
                        weight: .black
                    )
                )
                .foregroundStyle(.red)
                .shadow(
                    color: Color.red.opacity(0.75),
                    radius: 6
                )
        }
    }
}
