import SwiftUI

enum RicochetTheme {
    static let cyan = Color(red: 0.12, green: 0.91, blue: 0.95)
    static let magenta = Color(red: 1.0, green: 0.27, blue: 0.65)
    static let background = LinearGradient(
        colors: [Color(red: 0.015, green: 0.035, blue: 0.075), Color(red: 0.075, green: 0.025, blue: 0.12)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
