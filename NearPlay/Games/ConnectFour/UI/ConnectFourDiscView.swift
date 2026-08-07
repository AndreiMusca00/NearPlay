//
//  ConnectFourDiscView.swift
//  NearPlay
//

import SwiftUI

struct ConnectFourDiscView: View {
    let disc: ConnectFourDisc
    let size: CGFloat

    var isWinning = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    ConnectFourTheme.gradient(
                        for: disc
                    )
                )

            Circle()
                .stroke(
                    Color.white.opacity(0.34),
                    lineWidth: max(1, size * 0.035)
                )

            Circle()
                .fill(Color.white.opacity(0.20))
                .frame(
                    width: size * 0.33,
                    height: size * 0.18
                )
                .blur(radius: size * 0.03)
                .offset(
                    x: -size * 0.15,
                    y: -size * 0.19
                )

            if isWinning {
                Circle()
                    .stroke(
                        Color.white.opacity(0.92),
                        lineWidth: max(2, size * 0.075)
                    )
                    .padding(size * 0.04)
            }
        }
        .frame(width: size, height: size)
        .shadow(
            color:
                ConnectFourTheme
                .color(for: disc)
                .opacity(isWinning ? 0.82 : 0.42),
            radius: isWinning ? 11 : 5
        )
    }
}
