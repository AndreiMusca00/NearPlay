import SwiftUI

enum SwipeRushTheme {
    static let magenta = Color(red: 1.00, green: 0.24, blue: 0.62)
    static let cyan = Color(red: 0.08, green: 0.91, blue: 1.00)
    static let lime = Color(red: 0.67, green: 1.00, blue: 0.18)
    static let violet = Color(red: 0.56, green: 0.30, blue: 1.00)
    static let orange = Color(red: 1.00, green: 0.61, blue: 0.15)

    static let background = LinearGradient(
        colors: [
            Color(red: 0.025, green: 0.018, blue: 0.075),
            Color(red: 0.055, green: 0.020, blue: 0.105),
            Color(red: 0.010, green: 0.075, blue: 0.105)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func color(for direction: SwipeRushDirection) -> Color {
        switch direction {
        case .up: cyan
        case .right: magenta
        case .down: orange
        case .left: violet
        }
    }
}
