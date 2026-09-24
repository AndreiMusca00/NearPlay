import SwiftUI

enum BackgammonTheme {
    static let background = LinearGradient(
        colors: [
            Color(red: 7.0 / 255.0, green: 16.0 / 255.0, blue: 24.0 / 255.0),
            Color(red: 11.0 / 255.0, green: 15.0 / 255.0, blue: 21.0 / 255.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let board = LinearGradient(
        colors: [
            Color(red: 0.13, green: 0.12, blue: 0.16),
            Color(red: 0.08, green: 0.09, blue: 0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cyan = Color(red: 0.15, green: 0.78, blue: 1.0)
    static let purple = Color(red: 0.66, green: 0.33, blue: 1.0)
    static let gold = Color(red: 1.0, green: 0.72, blue: 0.28)

    static let primaryGradient = LinearGradient(
        colors: [cyan, purple],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cardBackground = LinearGradient(
        colors: [
            Color.white.opacity(0.08),
            Color.white.opacity(0.035)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func checkerColor(
        for player: BackgammonPlayer
    ) -> Color {
        player == .playerOne ? cyan : purple
    }
}
