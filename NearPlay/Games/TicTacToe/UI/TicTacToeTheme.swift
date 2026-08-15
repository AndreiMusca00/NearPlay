import SwiftUI

enum TicTacToeTheme {
    static let xBlue = Color(
        red: 0.05,
        green: 0.70,
        blue: 1.00
    )

    static let oPurple = Color(
        red: 0.66,
        green: 0.25,
        blue: 1.00
    )

    static let background = LinearGradient(
        colors: [
            Color(
                red: 11.0 / 255.0,
                green: 15.0 / 255.0,
                blue: 21.0 / 255.0
            ),
            Color(
                red: 7.0 / 255.0,
                green: 16.0 / 255.0,
                blue: 24.0 / 255.0
            )
        ],
        startPoint: .top,
        endPoint: .bottom
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

    static let primaryGradient = LinearGradient(
        colors: [
            xBlue,
            Color(red: 0.27, green: 0.36, blue: 1.00),
            oPurple
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static func color(
        for mark: TicTacToeMark
    ) -> Color {
        mark == .x ? xBlue : oPurple
    }
}
