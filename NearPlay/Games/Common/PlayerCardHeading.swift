import SwiftUI

/// Keep the full player name legible on compact score cards. On narrower
/// screens, move the small role badge below the name instead of truncating it.
struct PlayerCardHeading: View {
    let name: String
    let badge: String
    let color: Color
    var fontSize: CGFloat = 13

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                marker
                nameText.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 4)
                badgeText.fixedSize(horizontal: true, vertical: false)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    marker
                    nameText.minimumScaleFactor(0.7)
                }
                badgeText
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var marker: some View {
        Circle().fill(color).frame(width: 8, height: 8)
            .shadow(color: color, radius: 5)
    }

    private var nameText: some View {
        Text(name)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
    }

    private var badgeText: some View {
        Text(badge)
            .font(.system(size: 8, weight: .black, design: .rounded))
            .foregroundStyle(.white.opacity(0.34))
    }
}
