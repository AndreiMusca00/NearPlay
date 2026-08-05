//
//  ConnectFourTheme.swift
//  NearPlay
//

import SwiftUI

enum ConnectFourTheme {
    static let cyan = Color(
        red: 0.03,
        green: 0.78,
        blue: 1.00
    )

    static let blue = Color(
        red: 0.08,
        green: 0.40,
        blue: 1.00
    )

    static let purple = Color(
        red: 0.66,
        green: 0.23,
        blue: 1.00
    )

    static let playerOneGradient = LinearGradient(
        colors: [
            cyan,
            blue
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let playerTwoGradient = LinearGradient(
        colors: [
            purple,
            Color(
                red: 0.42,
                green: 0.18,
                blue: 1.00
            )
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryGradient = LinearGradient(
        colors: [
            cyan,
            blue,
            purple
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let boardGradient = LinearGradient(
        colors: [
            Color(
                red: 0.06,
                green: 0.28,
                blue: 0.48
            ),
            Color(
                red: 0.10,
                green: 0.12,
                blue: 0.38
            ),
            Color(
                red: 0.28,
                green: 0.09,
                blue: 0.44
            )
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let background = LinearGradient(
        colors: [
            Color(
                red: 10.0 / 255.0,
                green: 16.0 / 255.0,
                blue: 24.0 / 255.0
            ),
            Color(
                red: 5.0 / 255.0,
                green: 12.0 / 255.0,
                blue: 23.0 / 255.0
            )
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardBackground = LinearGradient(
        colors: [
            Color(
                red: 13.0 / 255.0,
                green: 23.0 / 255.0,
                blue: 37.0 / 255.0
            ),
            Color(
                red: 8.0 / 255.0,
                green: 15.0 / 255.0,
                blue: 27.0 / 255.0
            )
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let emptySlot = Color(
        red: 6.0 / 255.0,
        green: 13.0 / 255.0,
        blue: 23.0 / 255.0
    )

    static func color(
        for disc: ConnectFourDisc
    ) -> Color {
        switch disc {
        case .playerOne:
            return cyan
        case .playerTwo:
            return purple
        }
    }

    static func gradient(
        for disc: ConnectFourDisc
    ) -> LinearGradient {
        switch disc {
        case .playerOne:
            return playerOneGradient
        case .playerTwo:
            return playerTwoGradient
        }
    }
}
