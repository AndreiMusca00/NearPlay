import SwiftUI

enum RPSTheme {
    static let backgroundTop = Color(
        red: 11.0 / 255.0,
        green: 15.0 / 255.0,
        blue: 21.0 / 255.0
    )

    static let backgroundBottom = Color(
        red: 7.0 / 255.0,
        green: 16.0 / 255.0,
        blue: 24.0 / 255.0
    )

    static let brightBlue = Color(
        red: 0.05,
        green: 0.70,
        blue: 1.00
    )

    static let brightPurple = Color(
        red: 0.66,
        green: 0.25,
        blue: 1.00
    )

    static let rockBlue = Color(
        red: 0.12,
        green: 0.72,
        blue: 1.00
    )

    static let paperPurple = Color(
        red: 0.64,
        green: 0.34,
        blue: 1.00
    )

    static let scissorsPink = Color(
        red: 1.00,
        green: 0.30,
        blue: 0.68
    )

    static let primaryGradient = LinearGradient(
        colors: [
            brightBlue,
            Color(
                red: 0.27,
                green: 0.36,
                blue: 1.00
            ),
            brightPurple
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cardBackground = LinearGradient(
        colors: [
            Color(
                red: 12.0 / 255.0,
                green: 20.0 / 255.0,
                blue: 35.0 / 255.0
            ),
            Color(
                red: 7.0 / 255.0,
                green: 13.0 / 255.0,
                blue: 25.0 / 255.0
            )
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let background = LinearGradient(
        colors: [
            backgroundTop,
            backgroundBottom
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static func color(
        for choice: RPSChoice?
    ) -> Color {
        guard let choice else {
            return Color.white.opacity(0.50)
        }

        switch choice {
        case .rock:
            return rockBlue
        case .paper:
            return paperPurple
        case .scissors:
            return scissorsPink
        }
    }
}
