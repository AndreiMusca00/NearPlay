//
//  GameIconView.swift
//  NearPlay
//

import SwiftUI
import UIKit

struct GameIconView: View {
    let game: Game

    var size: CGFloat = 64
    var cornerRadius: CGFloat = 17
    var symbolSize: CGFloat = 25

    private var accentColor: Color {
        game.accentColor
    }

    private var assetImage: UIImage? {
        guard !game.imageName.isEmpty else {
            return nil
        }

        return UIImage(named: game.imageName)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
            .fill(
                accentColor.opacity(0.09)
            )

            if let assetImage {
                Image(uiImage: assetImage)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.09)
            } else {
                Image(
                    systemName:
                        game.fallbackSystemImage
                )
                .font(
                    .system(
                        size: symbolSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(accentColor)
            }
        }
        .frame(
            width: size,
            height: size
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
            .stroke(
                accentColor.opacity(0.25),
                lineWidth: 1
            )
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Game presentation

extension Game {
    var accentColor: Color {
        Color(
            hex: accentHex
        ) ?? Color.blue
    }
}

// MARK: - Hex color

private extension Color {
    init?(hex: String) {
        let trimmed =
            hex.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let cleaned =
            trimmed.hasPrefix("#")
            ? String(trimmed.dropFirst())
            : trimmed

        guard cleaned.count == 6 ||
              cleaned.count == 8,
              let value = UInt64(
                cleaned,
                radix: 16
              ) else {
            return nil
        }

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        if cleaned.count == 8 {
            red = Double(
                (value & 0xFF000000) >> 24
            ) / 255.0

            green = Double(
                (value & 0x00FF0000) >> 16
            ) / 255.0

            blue = Double(
                (value & 0x0000FF00) >> 8
            ) / 255.0

            alpha = Double(
                value & 0x000000FF
            ) / 255.0
        } else {
            red = Double(
                (value & 0xFF0000) >> 16
            ) / 255.0

            green = Double(
                (value & 0x00FF00) >> 8
            ) / 255.0

            blue = Double(
                value & 0x0000FF
            ) / 255.0

            alpha = 1
        }

        self.init(
            red: red,
            green: green,
            blue: blue,
            opacity: alpha
        )
    }
}
