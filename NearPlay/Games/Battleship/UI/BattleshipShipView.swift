import SwiftUI

/// The full footprint includes only the gaps between occupied cells.
enum BattleshipGridLayout {
    static let spacing: CGFloat = 3

    static func cellSize(for boardWidth: CGFloat) -> CGFloat {
        let count = CGFloat(BattleshipGame.boardSize)
        return (boardWidth - spacing * (count - 1)) / count
    }

    static func span(length: Int, cellSize: CGFloat, spacing: CGFloat) -> CGFloat {
        CGFloat(length) * cellSize + CGFloat(length - 1) * spacing
    }

    static func shipBounds(
        length: Int,
        orientation: BattleshipOrientation,
        cellSize: CGFloat,
        spacing: CGFloat,
        origin: BattleshipCoordinate = .init(row: 0, column: 0)
    ) -> CGRect {
        let step = cellSize + spacing
        let lengthOnBoard = span(length: length, cellSize: cellSize, spacing: spacing)
        return CGRect(
            x: CGFloat(origin.column) * step,
            y: CGFloat(origin.row) * step,
            width: orientation == .horizontal ? lengthOnBoard : cellSize,
            height: orientation == .vertical ? lengthOnBoard : cellSize
        )
    }
}

struct BattleshipShipView: View {
    let length: Int
    let orientation: BattleshipOrientation
    let cellSize: CGFloat
    var cellSpacing = BattleshipGridLayout.spacing
    var isSelected = false
    var isSunk = false

    private var span: CGFloat {
        BattleshipGridLayout.span(length: length, cellSize: cellSize, spacing: cellSpacing)
    }

    var body: some View {
        Canvas { context, size in
            drawShip(in: context, size: size)
        }
        .frame(width: span, height: cellSize)
        .rotationEffect(.degrees(orientation == .vertical ? 90 : 0))
        .frame(
            width: orientation == .horizontal ? span : cellSize,
            height: orientation == .vertical ? span : cellSize
        )
        .clipped()
        .opacity(isSunk ? 0.60 : 1)
        .accessibilityHidden(true)
    }

    private func drawShip(in context: GraphicsContext, size: CGSize) {
        let accent = isSunk ? Color.red : BattleshipTheme.cyan
        let secondary = isSunk ? Color.orange : BattleshipTheme.blue
        let bowShoulder: CGFloat = length == 4 ? 0.85 : 0.77
        let hull = shape([
            (0.06, 0.26), (0.16, 0.13), (bowShoulder, 0.13),
            (0.96, 0.43), (0.96, 0.57), (bowShoulder, 0.87),
            (0.16, 0.87), (0.06, 0.74)
        ], in: size)

        context.fill(hull, with: .linearGradient(
            Gradient(colors: [accent.opacity(0.76), Color(red: 0.09, green: 0.17, blue: 0.26), secondary.opacity(0.82)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
        ))
        context.stroke(hull, with: .color(accent.opacity(isSelected ? 0.95 : 0.72)), lineWidth: isSelected ? 1.4 : 1)

        let deck = shape([
            (0.11, 0.34), (0.19, 0.24), (bowShoulder, 0.24),
            (0.91, 0.50), (bowShoulder, 0.76), (0.19, 0.76), (0.11, 0.66)
        ], in: size)
        context.fill(deck, with: .linearGradient(
            Gradient(colors: [Color(red: 0.20, green: 0.35, blue: 0.48), Color(red: 0.05, green: 0.10, blue: 0.18)]),
            startPoint: CGPoint(x: 0, y: size.height * 0.24),
            endPoint: CGPoint(x: 0, y: size.height * 0.76)
        ))

        if length == 4 {
            let runway = CGRect(x: size.width * 0.20, y: size.height * 0.39,
                                width: size.width * 0.59, height: size.height * 0.23)
            context.fill(Path(roundedRect: runway, cornerRadius: 2), with: .color(.black.opacity(0.30)))
            let stripe = Path { path in
                path.move(to: CGPoint(x: size.width * 0.25, y: runway.midY))
                path.addLine(to: CGPoint(x: size.width * 0.73, y: runway.midY))
            }
            context.stroke(stripe, with: .color(accent.opacity(0.85)), style: StrokeStyle(lineWidth: 1.1, dash: [4, 3]))
            drawModule(at: 0.80, width: 0.085, accent: accent, in: context, size: size)
        } else {
            drawModule(at: 0.42, width: 0.21, accent: accent, in: context, size: size)
            if length == 3 {
                drawModule(at: 0.71, width: 0.11, accent: accent, in: context, size: size)
            }
        }

        let engine = shape([(0.10, 0.37), (0.15, 0.37), (0.15, 0.63), (0.10, 0.63)], in: size)
        context.fill(engine, with: .color(accent.opacity(0.85)))
    }

    private func drawModule(
        at position: CGFloat,
        width: CGFloat,
        accent: Color,
        in context: GraphicsContext,
        size: CGSize
    ) {
        let left = position - width / 2
        let right = position + width / 2
        let module = shape([(left, 0.34), (right - 0.035, 0.34), (right, 0.50),
                            (right - 0.035, 0.66), (left, 0.66)], in: size)
        context.fill(module, with: .color(accent.opacity(0.45)))
        context.stroke(module, with: .color(accent.opacity(0.90)), lineWidth: 0.8)
    }

    private func shape(_ points: [(CGFloat, CGFloat)], in size: CGSize) -> Path {
        Path { path in
            path.addLines(points.map { CGPoint(x: $0.0 * size.width, y: $0.1 * size.height) })
            path.closeSubpath()
        }
    }
}
