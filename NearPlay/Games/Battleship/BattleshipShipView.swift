import SwiftUI

struct BattleshipShipView: View {
    let length: Int
    let orientation: BattleshipOrientation
    let cellSize: CGFloat

    var isSelected = false
    var isSunk = false
    var showsDragHint = false
    var showsGlow = true

    var body: some View {
        ZStack {
            shipBody
            shipWindows

            if showsDragHint {
                Image(systemName: "hand.draw.fill")
                    .font(
                        .system(
                            size: max(11, cellSize * 0.24),
                            weight: .bold
                        )
                    )
                    .foregroundStyle(Color.white.opacity(0.72))
            }
        }
        .frame(
            width:
                orientation == .horizontal
                ? cellSize * CGFloat(length)
                : cellSize * 0.80,
            height:
                orientation == .vertical
                ? cellSize * CGFloat(length)
                : cellSize * 0.80
        )
        .contentShape(Rectangle())
        .opacity(isSunk ? 0.48 : 1)
        .shadow(
            color: glowColor,
            radius: glowRadius
        )
    }

    private var shipBody: some View {
        RoundedRectangle(
            cornerRadius: max(6, cellSize * 0.29),
            style: .continuous
        )
        .fill(
            isSunk
            ? BattleshipTheme.sunkGradient
            : BattleshipTheme.shipGradient
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: max(6, cellSize * 0.29),
                style: .continuous
            )
            .stroke(
                isSelected
                ? Color.white.opacity(0.82)
                : Color.white.opacity(0.28),
                lineWidth: isSelected ? 1.5 : 1
            )
        }
    }

    @ViewBuilder
    private var shipWindows: some View {
        if orientation == .horizontal {
            HStack(spacing: max(3, cellSize * 0.15)) {
                windows
            }
        } else {
            VStack(spacing: max(3, cellSize * 0.15)) {
                windows
            }
        }
    }

    private var windows: some View {
        ForEach(0..<length, id: \.self) { _ in
            Circle()
                .fill(Color.white.opacity(0.46))
                .frame(
                    width: max(3, cellSize * 0.10),
                    height: max(3, cellSize * 0.10)
                )
        }
    }

    private var glowColor: Color {
        guard showsGlow else {
            return .clear
        }

        if isSunk {
            return Color.red.opacity(0.65)
        }

        return BattleshipTheme.cyan.opacity(
            isSelected ? 0.66 : 0.30
        )
    }

    private var glowRadius: CGFloat {
        guard showsGlow else {
            return 0
        }

        return isSelected ? 10 : 5
    }
}
