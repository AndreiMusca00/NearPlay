import SwiftUI

enum TiltRaceTheme {
    static let lime = Color(red: 0.62, green: 1.0, blue: 0.18)
    static let violet = Color(red: 0.61, green: 0.28, blue: 1.0)
    static let cyan = Color(red: 0.08, green: 0.88, blue: 0.92)
    static let background = LinearGradient(
        colors: [
            Color(red: 0.015, green: 0.045, blue: 0.075),
            Color(red: 0.075, green: 0.025, blue: 0.105)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
