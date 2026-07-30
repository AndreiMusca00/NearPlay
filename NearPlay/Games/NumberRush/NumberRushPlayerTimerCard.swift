//
//  NumberRushPlayerTimerCard.swift
//  NearPlay
//

import SwiftUI

struct NumberRushPlayerTimerCard: View {
    let playerName: String
    let score: Int
    let isLocalPlayer: Bool
    let isActive: Bool

    let turnStartedAt: Date
    let turnDuration: TimeInterval

    let accentColor: Color

    var body: some View {
        TimelineView(
            .animation(minimumInterval: 0.03)
        ) { timeline in
            let progress = timerProgress(at: timeline.date)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .fill(Color.white.opacity(isActive ? 0.045 : 0.025))

                    if isActive {
                        NumberRushTheme.primaryGradient
                            .frame(
                                width:
                                    geometry.size.width *
                                    progress
                            )
                            .opacity(0.26)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: 22,
                                    style: .continuous
                                )
                            )
                    }

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(accentColor.opacity(0.14))
                                .frame(width: 42, height: 42)

                            Image(
                                systemName:
                                    isLocalPlayer
                                    ? "person.fill"
                                    : "person.2.fill"
                            )
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(accentColor)
                        }

                        if isActive {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(playerName)
                                    .font(
                                        .system(
                                            size: 16,
                                            weight: .bold,
                                            design: .rounded
                                        )
                                    )
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                Text(isLocalPlayer ? "Your turn" : "Playing")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(accentColor)
                            }

                            Spacer(minLength: 4)

                            VStack(alignment: .trailing, spacing: 3) {
                                Text("\(score) pts")
                                    .font(
                                        .system(
                                            size: 15,
                                            weight: .bold,
                                            design: .rounded
                                        )
                                    )
                                    .foregroundStyle(.white)

                                Text(
                                    remainingTimeText(
                                        at: timeline.date
                                    )
                                )
                                .font(
                                    .system(
                                        size: 13,
                                        weight: .black,
                                        design: .monospaced
                                    )
                                )
                                .foregroundStyle(
                                    progress < 0.25
                                    ? Color.red
                                    : Color.white.opacity(0.72)
                                )
                                .contentTransition(.numericText())
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(playerName)
                                    .font(
                                        .system(
                                            size: 13,
                                            weight: .bold,
                                            design: .rounded
                                        )
                                    )
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                Text("\(score) pts")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.43))
                            }
                        }
                    }
                    .padding(.horizontal, 13)
                }
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 22,
                        style: .continuous
                    )
                    .stroke(
                        isActive
                        ? accentColor.opacity(0.72)
                        : Color.white.opacity(0.09),
                        lineWidth: isActive ? 1.4 : 1
                    )
                }
                .shadow(
                    color:
                        isActive
                        ? accentColor.opacity(0.24)
                        : .clear,
                    radius: 14
                )
            }
        }
        .frame(height: 76)
        .animation(
            .spring(
                response: 0.42,
                dampingFraction: 0.84
            ),
            value: isActive
        )
    }

    private func timerProgress(
        at date: Date
    ) -> CGFloat {
        guard isActive,
              turnDuration > 0 else {
            return 0
        }

        let deadline =
            turnStartedAt.addingTimeInterval(turnDuration)

        let remaining = max(
            deadline.timeIntervalSince(date),
            0
        )

        return CGFloat(
            min(max(remaining / turnDuration, 0), 1)
        )
    }

    private func remainingTimeText(
        at date: Date
    ) -> String {
        let deadline =
            turnStartedAt.addingTimeInterval(turnDuration)

        let remaining = max(
            deadline.timeIntervalSince(date),
            0
        )

        return String(format: "%.1f s", remaining)
    }
}
