import SwiftUI

enum LaserDuelTheme {
    static let cyan = Color(red: 0.10, green: 0.88, blue: 1.0)
    static let crimson = Color(red: 1.0, green: 0.18, blue: 0.34)
    static let violet = Color(red: 0.65, green: 0.25, blue: 1.0)
    static let background = LinearGradient(
        colors: [
            Color(red: 0.012, green: 0.025, blue: 0.065),
            Color(red: 0.075, green: 0.018, blue: 0.075)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
