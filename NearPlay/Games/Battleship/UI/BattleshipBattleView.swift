//
//  BattleshipBattleView.swift
//  NearPlay
//

import SwiftUI

struct BattleshipBattleView: View {
    let ownBoard: BattleshipLocalBoard
    let opponentBoard: BattleshipOpponentBoard

    let isLocalTurn: Bool
    let localPlayerName: String
    let opponentName: String
    let pendingAttack: Bool

    let onAttack: (BattleshipCoordinate) -> Void

    var body: some View {
        VStack(spacing: 14) {
            battleStatus

            VStack(spacing: 8) {
                boardTitle(
                    title: "Enemy Waters",
                    subtitle:
                        "\(opponentBoard.remainingShips) ships remaining",
                    color: BattleshipTheme.purple
                )

                BattleshipBoardView(
                    mode: .opponentBattle,
                    ownBoard: ownBoard,
                    opponentBoard: opponentBoard,
                    isInteractionEnabled:
                        isLocalTurn && !pendingAttack,
                    onCellTap: onAttack
                )
                .padding(8)
                .background(boardBackground)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    boardTitle(
                        title: "Your Fleet",
                        subtitle:
                            "\(ownBoard.remainingShips) ships remaining",
                        color: BattleshipTheme.cyan
                    )

                    BattleshipBoardView(
                        mode: .ownBattle,
                        ownBoard: ownBoard,
                        opponentBoard: opponentBoard,
                        isInteractionEnabled: false,
                        onCellTap: { _ in }
                    )
                    .frame(width: 126, height: 126)
                    .padding(7)
                    .background(boardBackground)
                }

                Spacer(minLength: 4)

                VStack(spacing: 10) {
                    playerCard(
                        name: localPlayerName,
                        isActive: isLocalTurn,
                        isLocal: true,
                        color: BattleshipTheme.cyan
                    )

                    playerCard(
                        name: opponentName,
                        isActive: !isLocalTurn,
                        isLocal: false,
                        color: BattleshipTheme.purple
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var battleStatus: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        activeColor.opacity(0.12)
                    )
                    .frame(width: 43, height: 43)

                Image(
                    systemName:
                        isLocalTurn
                        ? "scope"
                        : "hourglass"
                )
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(activeColor)
                .shadow(
                    color: activeColor.opacity(0.48),
                    radius: 7
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(
                    pendingAttack
                    ? "Resolving attack…"
                    : (
                        isLocalTurn
                        ? "Choose one target"
                        : "\(opponentName) is attacking"
                    )
                )
                .font(
                    .system(
                        size: 17,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)

                Text(
                    "One attack per turn, even after a hit."
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.46))
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 65)
        .background(BattleshipTheme.cardBackground)
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
                activeColor.opacity(0.28),
                lineWidth: 1
            )
        }
    }

    private func boardTitle(
        title: String,
        subtitle: String,
        color: Color
    ) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(
                    color: color.opacity(0.8),
                    radius: 5
                )

            Text(title)
                .font(
                    .system(
                        size: 15,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)

            Spacer()

            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.43))
        }
    }

    private func playerCard(
        name: String,
        isActive: Bool,
        isLocal: Bool,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(
                systemName:
                    isLocal
                    ? "person.fill"
                    : "person.2.fill"
            )
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background {
                Circle()
                    .fill(color.opacity(0.12))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(
                        .system(
                            size: 14,
                            weight: .bold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(
                    isActive
                    ? "ACTIVE"
                    : "WAITING"
                )
                .font(
                    .system(
                        size: 10,
                        weight: .black,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    isActive
                    ? color
                    : Color.white.opacity(0.34)
                )
            }

            Spacer()
        }
        .padding(.horizontal, 11)
        .frame(height: 57)
        .background {
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .fill(
                isActive
                ? color.opacity(0.09)
                : Color.white.opacity(0.025)
            )
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: 17,
                style: .continuous
            )
            .stroke(
                isActive
                ? color.opacity(0.55)
                : Color.white.opacity(0.08),
                lineWidth: 1
            )
        }
        .shadow(
            color:
                isActive
                ? color.opacity(0.18)
                : .clear,
            radius: 9
        )
    }

    private var activeColor: Color {
        isLocalTurn
            ? BattleshipTheme.cyan
            : BattleshipTheme.purple
    }

    private var boardBackground: some View {
        RoundedRectangle(
            cornerRadius: 22,
            style: .continuous
        )
        .fill(Color.white.opacity(0.022))
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.08),
                lineWidth: 1
            )
        }
    }
}
