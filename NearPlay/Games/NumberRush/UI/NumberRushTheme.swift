import SwiftUI

enum NumberRushTheme {
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

    static let blue = Color(
        red: 0.05,
        green: 0.70,
        blue: 1.00
    )

    static let purple = Color(
        red: 0.66,
        green: 0.25,
        blue: 1.00
    )

    static let primaryGradient = LinearGradient(
        colors: [
            blue,
            Color(red: 0.27, green: 0.36, blue: 1.00),
            purple
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

    static func feedbackColor(
        for tone: NumberRushFeedbackTone
    ) -> Color {
        switch tone {
        case .neutral:
            return purple
        case .success:
            return .green
        case .danger:
            return .red
        }
    }
}
