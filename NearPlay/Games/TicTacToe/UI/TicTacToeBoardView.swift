import SwiftUI

struct TicTacToeBoardView: View {
    let state: TicTacToeGameState
    let isInteractionEnabled: Bool
    let animationID: UUID
    let onCellTap: (Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            let side = min(
                geometry.size.width,
                geometry.size.height
            )

            let spacing = max(8, side * 0.035)
            let cellSize = (side - spacing * 2) / 3

            ZStack {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(
                            .flexible(),
                            spacing: spacing
                        ),
                        count: 3
                    ),
                    spacing: spacing
                ) {
                    ForEach(0..<9, id: \.self) { index in
                        cell(
                            index: index,
                            size: cellSize
                        )
                    }
                }
                .frame(width: side, height: side)

                if !state.winningIndexes.isEmpty,
                   let winningMark = markForWinningPlayer() {
                    TicTacToeWinningLine(
                        indexes: state.winningIndexes,
                        mark: winningMark,
                        boardSide: side,
                        spacing: spacing
                    )
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func cell(
        index: Int,
        size: CGFloat
    ) -> some View {
        let mark = state.board[index]
        let isWinningCell =
            state.winningIndexes.contains(index)

        return Button {
            onCellTap(index)
        } label: {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(
                                isWinningCell ? 0.075 : 0.04
                            ),
                            Color.white.opacity(0.018)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
                .stroke(
                    Color.white.opacity(0.11),
                    lineWidth: 1
                )

                if isWinningCell,
                   let mark {
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .stroke(
                        TicTacToeTheme
                            .color(for: mark)
                            .opacity(0.7),
                        lineWidth: 1.5
                    )
                    .shadow(
                        color:
                            TicTacToeTheme
                            .color(for: mark)
                            .opacity(0.55),
                        radius: 12
                    )
                }

                if let mark {
                    TicTacToeMarkIcon(
                        mark: mark,
                        size: size * 0.53
                    )
                    .id("\(animationID)-\(index)")
                    .transition(
                        .scale.combined(with: .opacity)
                    )
                }
            }
            .frame(height: max(size, 72))
            .contentShape(
                RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(
            !isInteractionEnabled ||
            mark != nil
        )
        .accessibilityLabel(
            "Cell \(index + 1)"
        )
    }

    private func markForWinningPlayer() -> TicTacToeMark? {
        guard let firstIndex = state.winningIndexes.first else {
            return nil
        }

        return state.board[firstIndex]
    }
}

struct TicTacToeMarkIcon: View {
    let mark: TicTacToeMark
    let size: CGFloat

    var body: some View {
        Image(systemName: mark.systemName)
            .font(
                .system(
                    size: size,
                    weight: mark == .x ? .medium : .regular
                )
            )
            .foregroundStyle(
                TicTacToeTheme.color(for: mark)
            )
            .shadow(
                color:
                    TicTacToeTheme
                    .color(for: mark)
                    .opacity(0.95),
                radius: max(5, size * 0.13)
            )
            .shadow(
                color:
                    TicTacToeTheme
                    .color(for: mark)
                    .opacity(0.45),
                radius: max(10, size * 0.22)
            )
    }
}

private struct TicTacToeWinningLine: View {
    let indexes: [Int]
    let mark: TicTacToeMark
    let boardSide: CGFloat
    let spacing: CGFloat

    var body: some View {
        let cellSize = (boardSide - spacing * 2) / 3
        let startPoint = point(
            for: indexes.first ?? 0,
            cellSize: cellSize
        )
        let endPoint = point(
            for: indexes.last ?? 0,
            cellSize: cellSize
        )

        Path { path in
            path.move(to: startPoint)
            path.addLine(to: endPoint)
        }
        .stroke(
            TicTacToeTheme.color(for: mark),
            style: StrokeStyle(
                lineWidth: 5,
                lineCap: .round
            )
        )
        .shadow(
            color:
                TicTacToeTheme
                .color(for: mark)
                .opacity(0.95),
            radius: 7
        )
        .shadow(
            color:
                TicTacToeTheme
                .color(for: mark)
                .opacity(0.55),
            radius: 14
        )
        .frame(width: boardSide, height: boardSide)
    }

    private func point(
        for index: Int,
        cellSize: CGFloat
    ) -> CGPoint {
        let row = index / 3
        let column = index % 3

        let x =
            CGFloat(column) *
            (cellSize + spacing) +
            cellSize / 2

        let y =
            CGFloat(row) *
            (cellSize + spacing) +
            cellSize / 2

        return CGPoint(x: x, y: y)
    }
}
