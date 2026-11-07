import SwiftUI

enum TapFrenzyTheme {
    static let coral = Color(red: 1.00, green: 0.27, blue: 0.52)
    static let orange = Color(red: 1.00, green: 0.63, blue: 0.16)
    static let cyan = Color(red: 0.12, green: 0.88, blue: 0.95)
    static let violet = Color(red: 0.55, green: 0.31, blue: 1.00)

    static let background = LinearGradient(
        colors: [
            Color(red: 0.055, green: 0.025, blue: 0.095),
            Color(red: 0.025, green: 0.055, blue: 0.09)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let buttonGradient = LinearGradient(
        colors: [coral, orange],
        startPoint: .leading,
        endPoint: .trailing
    )
}
