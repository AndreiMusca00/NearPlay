import SwiftUI

enum BattleshipTheme {
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

    static let waterCell = Color(
        red: 13.0 / 255.0,
        green: 32.0 / 255.0,
        blue: 48.0 / 255.0
    )

    static let primaryGradient =
        LinearGradient(
            colors: [
                cyan,
                blue,
                purple
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

    static let shipGradient =
        LinearGradient(
            colors: [
                cyan.opacity(0.94),
                blue.opacity(0.88),
                purple.opacity(0.84)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

    static let sunkGradient =
        LinearGradient(
            colors: [
                Color.red.opacity(0.92),
                Color.orange.opacity(0.72)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

    static let background =
        LinearGradient(
            colors: [
                Color(
                    red: 10.0 / 255.0,
                    green: 16.0 / 255.0,
                    blue: 24.0 / 255.0
                ),
                Color(
                    red: 5.0 / 255.0,
                    green: 14.0 / 255.0,
                    blue: 24.0 / 255.0
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )

    static let cardBackground =
        LinearGradient(
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
}

enum BattleshipFeedbackTone {
    case neutral
    case success
    case warning
    case danger

    var color: Color {
        switch self {
        case .neutral:
            return BattleshipTheme.blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .danger:
            return .red
        }
    }

    var iconName: String {
        switch self {
        case .neutral:
            return "circle.dotted"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "burst.fill"
        case .danger:
            return "xmark.octagon.fill"
        }
    }
}
