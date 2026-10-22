import SwiftUI

enum DotsAndBoxesTheme {
    static let blue = Color(red: 0.10, green: 0.78, blue: 1)
    static let coral = Color(red: 1, green: 0.38, blue: 0.50)
    static let background = LinearGradient(
        colors: [Color(red: 0.025, green: 0.06, blue: 0.10), Color(red: 0.06, green: 0.035, blue: 0.12)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let primaryGradient = LinearGradient(colors: [blue, Color(red: 0.48, green: 0.28, blue: 1)], startPoint: .leading, endPoint: .trailing)
    static let cardBackground = LinearGradient(colors: [Color(red: 0.08, green: 0.10, blue: 0.17), Color(red: 0.04, green: 0.055, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct DotsAndBoxesPlayerPresentation: Identifiable {
    let id: String
    let name: String
    let badge: String
}

struct DotsAndBoxesGameScreen: View {
    @ObservedObject var controller: DotsAndBoxesMatchController
    let gameTitle: String
    let firstPlayer: DotsAndBoxesPlayerPresentation
    let secondPlayer: DotsAndBoxesPlayerPresentation
    let statusText: String
    let isInteractionEnabled: Bool
    let showsProgress: Bool
    let onEdgeSelected: (DotsAndBoxesEdge) -> Void
    let onQuitRequested: () -> Void

    var body: some View {
        ZStack {
            DotsAndBoxesTheme.background.ignoresSafeArea()
            VStack(spacing: 12) {
                header
                scoreRow
                GeometryReader { geometry in
                    let size = min(geometry.size.width - 28, geometry.size.height - 4, 470)
                    DotsAndBoxesBoardView(
                        state: controller.state,
                        firstPlayerID: firstPlayer.id,
                        secondPlayerID: secondPlayer.id,
                        isInteractionEnabled: isInteractionEnabled,
                        onEdgeSelected: onEdgeSelected
                    )
                    .frame(width: size, height: size)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                .frame(maxHeight: .infinity)
                Text(controller.state.isFinished ? "All boxes claimed" : "Close a box to keep your turn")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.46))
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Button(action: onQuitRequested) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 3) {
                Text(gameTitle).font(.system(size: 22, weight: .bold, design: .rounded))
                HStack(spacing: 7) {
                    if showsProgress { ProgressView().controlSize(.small).tint(.white) }
                    Text(statusText).font(.system(size: 13, weight: .semibold)).foregroundStyle(activeColor)
                }
            }
            Spacer()
            Image(systemName: "square.grid.3x3.square")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(DotsAndBoxesTheme.primaryGradient)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.06)))
        }
        .foregroundStyle(.white)
        .padding(.top, 6)
    }

    private var scoreRow: some View {
        HStack(spacing: 10) {
            scoreCard(firstPlayer, color: DotsAndBoxesTheme.blue)
            Text("–").font(.title2.bold()).foregroundStyle(.white.opacity(0.28))
            scoreCard(secondPlayer, color: DotsAndBoxesTheme.coral)
        }
    }

    private func scoreCard(_ player: DotsAndBoxesPlayerPresentation, color: Color) -> some View {
        let active = !controller.state.isFinished && controller.state.activePlayerID == player.id
        return HStack(spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10).shadow(color: color.opacity(active ? 0.9 : 0), radius: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name).font(.system(size: 14, weight: .bold, design: .rounded)).lineLimit(1)
                Text(active ? "PLAYING" : player.badge).font(.system(size: 10, weight: .bold)).foregroundStyle(active ? color : .white.opacity(0.38))
            }
            Spacer(minLength: 2)
            Text("\(controller.state.score(for: player.id))")
                .font(.system(size: 25, weight: .black, design: .rounded)).foregroundStyle(color)
        }
        .padding(.horizontal, 13).frame(maxWidth: .infinity).frame(height: 62)
        .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(active ? 0.075 : 0.035)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(active ? 0.46 : 0.12), lineWidth: active ? 1.4 : 1))
    }

    private var activeColor: Color {
        controller.state.activePlayerID == firstPlayer.id ? DotsAndBoxesTheme.blue : DotsAndBoxesTheme.coral
    }
}

private struct DotsAndBoxesBoardView: View {
    let state: DotsAndBoxesGameState
    let firstPlayerID: String
    let secondPlayerID: String
    let isInteractionEnabled: Bool
    let onEdgeSelected: (DotsAndBoxesEdge) -> Void

    var body: some View {
        GeometryReader { geometry in
            let inset = geometry.size.width * 0.075
            let span = (geometry.size.width - inset * 2) / CGFloat(DotsAndBoxesGame.dotCount - 1)
            ZStack {
                RoundedRectangle(cornerRadius: 28).fill(.white.opacity(0.035))
                RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.10), lineWidth: 1)

                ForEach(0..<DotsAndBoxesGame.boxCount, id: \.self) { index in
                    if let owner = state.boxOwners[index] {
                        let row = index / 4, column = index % 4
                        RoundedRectangle(cornerRadius: 11)
                            .fill(color(for: owner).opacity(0.25))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(color(for: owner).opacity(0.46), lineWidth: 1))
                            .frame(width: span - 10, height: span - 10)
                            .position(x: inset + (CGFloat(column) + 0.5) * span, y: inset + (CGFloat(row) + 0.5) * span)
                            .transition(.scale(scale: 0.75).combined(with: .opacity))
                    }
                }

                ForEach(DotsAndBoxesGame.allEdges, id: \.self) { edge in
                    let owner = state.owner(of: edge)
                    let horizontal = edge.orientation == .horizontal
                    Capsule()
                        .fill(owner.map(color(for:)) ?? .white.opacity(0.075))
                        .frame(width: horizontal ? span - 14 : 12, height: horizontal ? 12 : span - 14)
                        .contentShape(Rectangle().inset(by: -8))
                        .position(
                            x: inset + (CGFloat(edge.column) + (horizontal ? 0.5 : 0)) * span,
                            y: inset + (CGFloat(edge.row) + (horizontal ? 0 : 0.5)) * span
                        )
                        .shadow(color: owner.map { color(for: $0).opacity(0.75) } ?? .clear, radius: 5)
                        .onTapGesture {
                            guard isInteractionEnabled, owner == nil else { return }
                            onEdgeSelected(edge)
                        }
                }

                ForEach(0..<DotsAndBoxesGame.dotCount, id: \.self) { row in
                    ForEach(0..<DotsAndBoxesGame.dotCount, id: \.self) { column in
                        Circle().fill(Color.white).frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color(red: 0.35, green: 0.25, blue: 0.66), lineWidth: 3))
                            .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
                            .position(x: inset + CGFloat(column) * span, y: inset + CGFloat(row) * span)
                    }
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.edges.count)
        }
    }

    private func color(for playerID: String) -> Color {
        playerID == firstPlayerID ? DotsAndBoxesTheme.blue : DotsAndBoxesTheme.coral
    }
}

struct DotsAndBoxesResultOverlay: View {
    let title: String
    let subtitle: String
    let firstName: String
    let secondName: String
    let firstScore: Int
    let secondScore: Int
    let onPlayAgain: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.76).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "square.grid.3x3.fill").font(.system(size: 38, weight: .bold)).foregroundStyle(DotsAndBoxesTheme.primaryGradient)
                VStack(spacing: 6) {
                    Text(title).font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(subtitle).font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                }
                HStack(spacing: 18) {
                    resultScore(firstName, score: firstScore, color: DotsAndBoxesTheme.blue)
                    resultScore(secondName, score: secondScore, color: DotsAndBoxesTheme.coral)
                }
                Button(action: onPlayAgain) {
                    Label("Play Again", systemImage: "arrow.clockwise")
                        .font(.system(size: 16, weight: .bold, design: .rounded)).frame(maxWidth: .infinity).frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 17).fill(DotsAndBoxesTheme.primaryGradient))
                }.buttonStyle(.plain)
                Button("Quit", action: onQuit).buttonStyle(.plain).foregroundStyle(.white.opacity(0.6)).frame(height: 38)
            }
            .padding(26).frame(maxWidth: 350)
            .background(RoundedRectangle(cornerRadius: 28).fill(DotsAndBoxesTheme.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.12)))
            .padding(24)
        }
    }

    private func resultScore(_ name: String, score: Int, color: Color) -> some View {
        VStack(spacing: 5) {
            Text("\(score)").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(color)
            Text(name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
        }.frame(maxWidth: .infinity)
    }
}
