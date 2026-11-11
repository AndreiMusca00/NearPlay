import SwiftUI

private struct TutorialScreenshot<Annotations: View>: View {
    let imageName: String
    let imageDescription: String
    @ViewBuilder let annotations: (CGSize) -> Annotations

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { geometry in
                    annotations(geometry.size)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .accessibilityLabel(imageDescription)
    }
}

private struct TutorialCallout: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 0.035, green: 0.055, blue: 0.10), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.90), lineWidth: 1.5))
    }
}

struct TutorialArrow: Shape {
    let start: CGPoint
    let control: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        let startPoint = CGPoint(x: start.x * rect.width, y: start.y * rect.height)
        let controlPoint = CGPoint(x: control.x * rect.width, y: control.y * rect.height)
        let endPoint = CGPoint(x: end.x * rect.width, y: end.y * rect.height)
        let angle = atan2(endPoint.y - controlPoint.y, endPoint.x - controlPoint.x)
        let headLength = max(9, rect.width * 0.035)

        return Path { path in
            path.move(to: startPoint)
            path.addQuadCurve(to: endPoint, control: controlPoint)
            path.move(to: CGPoint(
                x: endPoint.x - headLength * cos(angle - .pi / 6),
                y: endPoint.y - headLength * sin(angle - .pi / 6)
            ))
            path.addLine(to: endPoint)
            path.addLine(to: CGPoint(
                x: endPoint.x - headLength * cos(angle + .pi / 6),
                y: endPoint.y - headLength * sin(angle + .pi / 6)
            ))
        }
    }
}

struct NumberRushTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color

    private var imageName: String {
        switch phase {
        case 0: "tutorial_number_rush_find"
        case 1: "tutorial_number_rush_timer"
        default: "tutorial_number_rush_score"
        }
    }

    private var imageDescription: String {
        switch phase {
        case 0:
            "The target is 1. An arrow points to number 1 in the bottom row, seventh column. Player 1 is active."
        case 1:
            "Numbers 1, 2 and 3 are purple. Player 2 has three points and 1.5 seconds left. The arrow points to the timer below the grid."
        default:
            "Forty-nine numbers have been found. Player 1 has 26 cyan numbers and Player 2 has 23 purple numbers. Their score cards are below the grid."
        }
    }

    var body: some View {
        TutorialScreenshot(imageName: imageName, imageDescription: imageDescription) { size in
            let stroke = StrokeStyle(lineWidth: max(2, size.width * 0.008), lineCap: .round, lineJoin: .round)

            switch phase {
            case 0:
                Circle()
                    .stroke(accent, lineWidth: 2.5)
                    .frame(width: size.width * 0.16, height: size.width * 0.16)
                    .position(x: size.width * 0.146, y: size.height * 0.073)

                Circle()
                    .stroke(.white, lineWidth: 2.5)
                    .shadow(color: accent, radius: 6)
                    .frame(width: size.width * 0.087, height: size.width * 0.087)
                    .position(x: size.width * 0.646, y: size.height * 0.807)

                TutorialArrow(
                    start: CGPoint(x: 0.72, y: 0.16),
                    control: CGPoint(x: 0.91, y: 0.47),
                    end: CGPoint(x: 0.66, y: 0.765)
                )
                .stroke(accent, style: stroke)

                TutorialCallout(text: "FIND AND TAP 1", color: accent)
                    .frame(maxWidth: size.width * 0.65)
                    .position(x: size.width * 0.59, y: size.height * 0.105)

            case 1:
                RoundedRectangle(cornerRadius: 8)
                    .stroke(secondary, lineWidth: 2.5)
                    .shadow(color: secondary.opacity(0.65), radius: 7)
                    .frame(width: size.width * 0.21, height: size.height * 0.068)
                    .position(x: size.width * 0.89, y: size.height * 0.947)

                TutorialArrow(
                    start: CGPoint(x: 0.62, y: 0.82),
                    control: CGPoint(x: 0.87, y: 0.83),
                    end: CGPoint(x: 0.89, y: 0.91)
                )
                .stroke(secondary, style: stroke)

                TutorialCallout(text: "WATCH YOUR TIME", color: secondary)
                    .frame(maxWidth: size.width * 0.70)
                    .position(x: size.width * 0.38, y: size.height * 0.79)

            default:
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accent, lineWidth: 2)
                    .frame(width: size.width * 0.97, height: size.height * 0.137)
                    .position(x: size.width * 0.50, y: size.height * 0.925)

                TutorialArrow(
                    start: CGPoint(x: 0.37, y: 0.30),
                    control: CGPoint(x: 0.16, y: 0.29),
                    end: CGPoint(x: 0.15, y: 0.23)
                )
                .stroke(accent, style: stroke)

                TutorialArrow(
                    start: CGPoint(x: 0.30, y: 0.33),
                    control: CGPoint(x: 0.06, y: 0.34),
                    end: CGPoint(x: 0.052, y: 0.23)
                )
                .stroke(secondary, style: stroke)

                TutorialCallout(text: "COLOR = POINTS", color: accent)
                    .frame(maxWidth: size.width * 0.69)
                    .position(x: size.width * 0.61, y: size.height * 0.32)
            }
        }
    }
}

struct BattleshipTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color

    private var imageName: String {
        switch phase {
        case 0: "tutorial_battleship_deploy"
        case 1: "tutorial_battleship_ready"
        default: "tutorial_battleship_attack"
        }
    }

    private var imageDescription: String {
        switch phase {
        case 0:
            "An empty eight by eight grid and five ships in the dock. An arrow shows a ship being dragged from the dock to the grid."
        case 1:
            "All five ships are placed on the board. Tap a ship to rotate it, then use the highlighted Ready for Battle button."
        default:
            "Enemy Waters. An orange star in row 3, column 3 is a hit. A gray dot in row 3, column 4 is a miss."
        }
    }

    var body: some View {
        TutorialScreenshot(imageName: imageName, imageDescription: imageDescription) { size in
            let stroke = StrokeStyle(lineWidth: max(2, size.width * 0.008), lineCap: .round, lineJoin: .round)

            switch phase {
            case 0:
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accent, lineWidth: 2)
                    .frame(width: size.width * 0.29, height: size.height * 0.065)
                    .position(x: size.width * 0.38, y: size.height * 0.875)

                TutorialArrow(
                    start: CGPoint(x: 0.37, y: 0.83),
                    control: CGPoint(x: 0.18, y: 0.60),
                    end: CGPoint(x: 0.32, y: 0.40)
                )
                .stroke(accent, style: stroke)

                TutorialCallout(text: "DRAG A SHIP", color: accent)
                    .frame(maxWidth: size.width * 0.62)
                    .position(x: size.width * 0.61, y: size.height * 0.28)

            case 1:
                RoundedRectangle(cornerRadius: 13)
                    .stroke(.white.opacity(0.90), lineWidth: 2)
                    .frame(width: size.width * 0.98, height: size.height * 0.13)
                    .position(x: size.width * 0.50, y: size.height * 0.93)

                TutorialArrow(
                    start: CGPoint(x: 0.65, y: 0.19),
                    control: CGPoint(x: 0.53, y: 0.08),
                    end: CGPoint(x: 0.45, y: 0.12)
                )
                .stroke(accent, style: stroke)

                TutorialCallout(text: "TAP TO ROTATE", color: accent)
                    .frame(maxWidth: size.width * 0.59)
                    .position(x: size.width * 0.65, y: size.height * 0.25)

            default:
                Circle()
                    .stroke(Color.orange, lineWidth: 2.5)
                    .frame(width: size.width * 0.09, height: size.width * 0.09)
                    .position(x: size.width * 0.322, y: size.height * 0.360)

                TutorialArrow(
                    start: CGPoint(x: 0.24, y: 0.23),
                    control: CGPoint(x: 0.30, y: 0.27),
                    end: CGPoint(x: 0.322, y: 0.31)
                )
                .stroke(Color.orange, style: stroke)

                TutorialCallout(text: "HIT", color: .orange)
                    .position(x: size.width * 0.23, y: size.height * 0.18)

                TutorialArrow(
                    start: CGPoint(x: 0.64, y: 0.24),
                    control: CGPoint(x: 0.50, y: 0.25),
                    end: CGPoint(x: 0.44, y: 0.32)
                )
                .stroke(.white.opacity(0.85), style: stroke)

                TutorialCallout(text: "MISS", color: .gray)
                    .position(x: size.width * 0.67, y: size.height * 0.18)
            }
        }
    }
}

struct BackgammonTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color

    private var imageName: String {
        phase == 0 ? "tutorial_backgammon_roll" : "tutorial_backgammon_move"
    }

    private var imageDescription: String {
        switch phase {
        case 0:
            "The Backgammon board with Player 1 in purple and Player 2 in cyan. An arrow points to the dice button in the center."
        case 1:
            "The dice show 4 and 5. An arrow points to one of Player 1's purple checkers to show where a drag starts."
        default:
            "An arrow points to the checkmark used to confirm moves. Another points to the OUT counter, where the goal is 15 checkers."
        }
    }

    var body: some View {
        TutorialScreenshot(imageName: imageName, imageDescription: imageDescription) { size in
            let stroke = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)

            switch phase {
            case 0:
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: size.width * 0.085, height: size.width * 0.085)
                    .position(x: size.width * 0.498, y: size.height * 0.520)

                TutorialArrow(
                    start: CGPoint(x: 0.32, y: 0.45),
                    control: CGPoint(x: 0.40, y: 0.36),
                    end: CGPoint(x: 0.46, y: 0.48)
                )
                .stroke(accent, style: stroke)

                TutorialCallout(text: "ROLL", color: accent)
                    .position(x: size.width * 0.25, y: size.height * 0.44)

            case 1:
                RoundedRectangle(cornerRadius: 7)
                    .stroke(accent, lineWidth: 2)
                    .frame(width: size.width * 0.06, height: size.height * 0.23)
                    .position(x: size.width * 0.498, y: size.height * 0.335)

                TutorialArrow(
                    start: CGPoint(x: 0.22, y: 0.66),
                    control: CGPoint(x: 0.27, y: 0.74),
                    end: CGPoint(x: 0.33, y: 0.76)
                )
                .stroke(accent, style: stroke)

                TutorialCallout(text: "DRAG A CHECKER", color: accent)
                    .frame(maxWidth: size.width * 0.51)
                    .position(x: size.width * 0.22, y: size.height * 0.51)

            default:
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: size.width * 0.08, height: size.width * 0.08)
                    .position(x: size.width * 0.498, y: size.height * 0.55)

                TutorialArrow(
                    start: CGPoint(x: 0.70, y: 0.48),
                    control: CGPoint(x: 0.61, y: 0.48),
                    end: CGPoint(x: 0.54, y: 0.53)
                )
                .stroke(accent, style: stroke)

                TutorialCallout(text: "CONFIRM", color: accent)
                    .position(x: size.width * 0.77, y: size.height * 0.44)

                TutorialArrow(
                    start: CGPoint(x: 0.78, y: 0.69),
                    control: CGPoint(x: 0.87, y: 0.68),
                    end: CGPoint(x: 0.93, y: 0.73)
                )
                .stroke(accent, style: stroke)

                TutorialCallout(text: "15 OUT = WIN", color: accent)
                    .frame(maxWidth: size.width * 0.44)
                    .position(x: size.width * 0.72, y: size.height * 0.88)
            }
        }
    }
}

struct TiltRaceTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color

    var body: some View {
        VStack(spacing: 12) {
            if phase == 2 {
                HStack {
                    Text("PLAYER 1")
                        .foregroundStyle(accent)
                    Spacer()
                    Text("PLAYER 2")
                        .foregroundStyle(secondary)
                }
                .font(.system(size: 12, weight: .black, design: .rounded))
                .padding(.horizontal, 14)

                Image("tutorial_tilt_race_times")
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Player 1's current run is 19.35 seconds. Player 2 is waiting for their turn on the same track.")
            }

            TutorialScreenshot(
                imageName: phase == 0 ? "tutorial_tilt_race_start" : "tutorial_tilt_race_progress",
                imageDescription: phase == 0
                    ? "Gate 1 of 10. The glowing ball is just below the first green gate. Tilt the phone to roll into the ring."
                    : "Gate 7 of 10. The ball is on the left and the next green gate is on the right. Only the current gate is visible."
            ) { size in
                let stroke = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                switch phase {
                case 0:
                    TutorialCallout(text: "LEAN TO ROLL", color: accent)
                        .position(x: size.width * 0.67, y: size.height * 0.79)
                    TutorialArrow(
                        start: CGPoint(x: 0.53, y: 0.77),
                        control: CGPoint(x: 0.38, y: 0.77),
                        end: CGPoint(x: 0.32, y: 0.68)
                    )
                    .stroke(.white, style: stroke)
                    TutorialArrow(
                        start: CGPoint(x: 0.29, y: 0.60),
                        control: CGPoint(x: 0.28, y: 0.54),
                        end: CGPoint(x: 0.30, y: 0.51)
                    )
                    .stroke(accent, style: stroke)
                case 1:
                    TutorialCallout(text: "NEXT GATE", color: accent)
                        .position(x: size.width * 0.43, y: size.height * 0.83)
                    TutorialArrow(
                        start: CGPoint(x: 0.56, y: 0.82),
                        control: CGPoint(x: 0.70, y: 0.82),
                        end: CGPoint(x: 0.74, y: 0.74)
                    )
                    .stroke(.white, style: stroke)
                    Circle()
                        .stroke(.white.opacity(0.9), lineWidth: 2)
                        .frame(width: size.width * 0.17, height: size.width * 0.17)
                        .position(x: size.width * 0.746, y: size.height * 0.653)
                default:
                    TutorialCallout(text: "REACH ALL 10", color: accent)
                        .position(x: size.width * 0.50, y: size.height * 0.24)
                    TutorialArrow(
                        start: CGPoint(x: 0.50, y: 0.19),
                        control: CGPoint(x: 0.66, y: 0.13),
                        end: CGPoint(x: 0.61, y: 0.065)
                    )
                    .stroke(.white, style: stroke)
                }
            }
        }
    }
}

struct TapFrenzyTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color

    private var imageName: String {
        switch phase {
        case 0: "tutorial_tap_frenzy_order"
        case 1: "tutorial_tap_frenzy_relocate"
        case 2: "tutorial_tap_frenzy_sequence"
        default: "tutorial_tap_frenzy_score"
        }
    }

    private var imageDescription: String {
        switch phase {
        case 0: "Five targets numbered 1 to 5. An arrow points to the pink number 1, which must be tapped first."
        case 1: "The same five targets have relocated. The glowing pink number 1 is now near the top of the arena."
        case 2: "Numbers 1, 2 and 3 have disappeared. Only purple 4 and green 5 remain. Tap 4, then 5."
        default: "Only number 5 remains. Player 1 has 47 points, four completed sequences, two mistakes and 27.7 seconds remaining."
        }
    }

    var body: some View {
        TutorialScreenshot(imageName: imageName, imageDescription: imageDescription) { size in
            let stroke = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            switch phase {
            case 0:
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: size.width * 0.19, height: size.width * 0.19)
                    .position(x: size.width * 0.585, y: size.height * 0.539)
                TutorialCallout(text: "TAP 1 FIRST", color: accent)
                    .position(x: size.width * 0.25, y: size.height * 0.56)
                TutorialArrow(
                    start: CGPoint(x: 0.40, y: 0.56),
                    control: CGPoint(x: 0.45, y: 0.56),
                    end: CGPoint(x: 0.48, y: 0.54)
                )
                .stroke(.white, style: stroke)
            case 1:
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: size.width * 0.19, height: size.width * 0.19)
                    .position(x: size.width * 0.428, y: size.height * 0.402)
                TutorialCallout(text: "FIND 1 AGAIN", color: accent)
                    .position(x: size.width * 0.34, y: size.height * 0.64)
                TutorialArrow(
                    start: CGPoint(x: 0.45, y: 0.61),
                    control: CGPoint(x: 0.57, y: 0.53),
                    end: CGPoint(x: 0.47, y: 0.46)
                )
                .stroke(.white, style: stroke)
                RoundedRectangle(cornerRadius: 7)
                    .stroke(secondary, lineWidth: 2)
                    .frame(width: size.width * 0.69, height: size.height * 0.044)
                    .position(x: size.width * 0.35, y: size.height * 0.967)
            case 2:
                TutorialCallout(text: "4 THEN 5", color: .purple)
                    .position(x: size.width * 0.28, y: size.height * 0.76)
                TutorialArrow(
                    start: CGPoint(x: 0.67, y: 0.79),
                    control: CGPoint(x: 0.52, y: 0.75),
                    end: CGPoint(x: 0.56, y: 0.66)
                )
                .stroke(.white, style: stroke)
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .frame(width: size.width * 0.19, height: size.width * 0.19)
                    .position(x: size.width * 0.789, y: size.height * 0.823)
            default:
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white, lineWidth: 2)
                    .frame(width: size.width * 0.25, height: size.height * 0.075)
                    .position(x: size.width * 0.865, y: size.height * 0.048)
                TutorialCallout(text: "60 SECOND RUN", color: accent)
                    .position(x: size.width * 0.38, y: size.height * 0.12)
                TutorialArrow(
                    start: CGPoint(x: 0.60, y: 0.12),
                    control: CGPoint(x: 0.69, y: 0.12),
                    end: CGPoint(x: 0.74, y: 0.075)
                )
                .stroke(.white, style: stroke)
                RoundedRectangle(cornerRadius: 9)
                    .stroke(accent, lineWidth: 2)
                    .frame(width: size.width * 0.31, height: size.height * 0.12)
                    .position(x: size.width * 0.165, y: size.height * 0.328)
                TutorialCallout(text: "+10 + SPEED BONUS", color: secondary)
                    .frame(maxWidth: size.width * 0.86)
                    .position(x: size.width * 0.50, y: size.height * 0.84)
                TutorialArrow(
                    start: CGPoint(x: 0.62, y: 0.79),
                    control: CGPoint(x: 0.74, y: 0.71),
                    end: CGPoint(x: 0.67, y: 0.65)
                )
                .stroke(.white, style: stroke)
            }
        }
    }
}

struct DotsAndBoxesTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color

    private let pink = Color(red: 1.0, green: 0.31, blue: 0.51)

    var body: some View {
        VStack(spacing: 12) {
            if phase == 2 {
                HStack(spacing: 10) {
                    playerScore(name: "PLAYER 1", score: 0, color: accent)
                    playerScore(name: "PLAYER 2", score: 1, color: pink)
                }
            }

            TutorialScreenshot(
                imageName: phase == 0 ? "tutorial_dots_boxes_empty" : "tutorial_dots_boxes_claim",
                imageDescription: phase == 0
                    ? "An empty four by four Dots and Boxes board. An arrow points to an unused horizontal edge between two neighboring dots."
                    : "The second square in the top row has all four sides completed and is filled pink. Player 2 has one point."
            ) { size in
                let stroke = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                switch phase {
                case 0:
                    Capsule()
                        .stroke(accent, lineWidth: 2)
                        .frame(width: size.width * 0.17, height: size.height * 0.055)
                        .position(x: size.width * 0.185, y: size.height * 0.08)
                    TutorialCallout(text: "TAP AN UNUSED EDGE", color: accent)
                        .frame(maxWidth: size.width * 0.80)
                        .position(x: size.width * 0.54, y: size.height * 0.45)
                    TutorialArrow(
                        start: CGPoint(x: 0.43, y: 0.39),
                        control: CGPoint(x: 0.16, y: 0.32),
                        end: CGPoint(x: 0.185, y: 0.13)
                    )
                    .stroke(.white, style: stroke)
                case 1:
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white, lineWidth: 2)
                        .frame(width: size.width * 0.18, height: size.height * 0.18)
                        .position(x: size.width * 0.395, y: size.height * 0.185)
                    TutorialCallout(text: "FOUR SIDES = 1 POINT", color: pink)
                        .frame(maxWidth: size.width * 0.85)
                        .position(x: size.width * 0.54, y: size.height * 0.65)
                    TutorialArrow(
                        start: CGPoint(x: 0.54, y: 0.59),
                        control: CGPoint(x: 0.59, y: 0.43),
                        end: CGPoint(x: 0.42, y: 0.32)
                    )
                    .stroke(.white, style: stroke)
                default:
                    TutorialCallout(text: "CLAIM A BOX, PLAY AGAIN", color: pink)
                        .frame(maxWidth: size.width * 0.94)
                        .position(x: size.width * 0.51, y: size.height * 0.69)
                    TutorialArrow(
                        start: CGPoint(x: 0.58, y: 0.62),
                        control: CGPoint(x: 0.94, y: 0.49),
                        end: CGPoint(x: 0.815, y: 0.335)
                    )
                    .stroke(.white, style: stroke)
                    Capsule()
                        .stroke(pink, lineWidth: 2)
                        .frame(width: size.width * 0.17, height: size.height * 0.055)
                        .position(x: size.width * 0.815, y: size.height * 0.29)
                }
            }
        }
    }

    private func playerScore(name: String, score: Int, color: Color) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 10, weight: .black, design: .rounded))
            Spacer(minLength: 4)
            Text("\(score)")
                .font(.system(size: 23, weight: .black, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.65), lineWidth: 1))
    }
}

struct SwipeRushTutorialArtwork: View {
    let phase: Int
    let accent: Color
    let secondary: Color

    private var imageName: String {
        switch phase {
        case 0: "tutorial_swipe_rush_start"
        case 1: "tutorial_swipe_rush_direction"
        case 2: "tutorial_swipe_rush_mistake"
        default: "tutorial_swipe_rush_combo"
        }
    }

    private var imageDescription: String {
        switch phase {
        case 0: "A pink target points right. Start your touch inside the circle and swipe right."
        case 1: "The next target is orange and points down. Its outer ring is the remaining time for this swipe."
        case 2: "A wrong-direction swipe has cost three points and reset the combo to zero."
        default: "Player 1 has a score of 153 and a combo of 15. A perfect swipe has just earned 11 points."
        }
    }

    var body: some View {
        TutorialScreenshot(imageName: imageName, imageDescription: imageDescription) { size in
            let stroke = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            switch phase {
            case 0:
                TutorialCallout(text: "START HERE", color: accent)
                    .position(x: size.width * 0.31, y: size.height * 0.49)
                TutorialArrow(
                    start: CGPoint(x: 0.43, y: 0.52),
                    control: CGPoint(x: 0.52, y: 0.55),
                    end: CGPoint(x: 0.50, y: 0.60)
                )
                .stroke(.white, style: stroke)
                TutorialArrow(
                    start: CGPoint(x: 0.53, y: 0.715),
                    control: CGPoint(x: 0.73, y: 0.715),
                    end: CGPoint(x: 0.92, y: 0.715)
                )
                .stroke(.white, style: stroke)
            case 1:
                TutorialCallout(text: "SWIPE DOWN", color: .orange)
                    .position(x: size.width * 0.29, y: size.height * 0.60)
                TutorialArrow(
                    start: CGPoint(x: 0.73, y: 0.66),
                    control: CGPoint(x: 0.73, y: 0.74),
                    end: CGPoint(x: 0.73, y: 0.81)
                )
                .stroke(.white, style: stroke)
            case 2:
                TutorialCallout(text: "FOLLOW THE ARROW", color: accent)
                    .frame(maxWidth: size.width * 0.75)
                    .position(x: size.width * 0.63, y: size.height * 0.42)
                TutorialArrow(
                    start: CGPoint(x: 0.57, y: 0.46),
                    control: CGPoint(x: 0.51, y: 0.49),
                    end: CGPoint(x: 0.46, y: 0.54)
                )
                .stroke(.white, style: stroke)
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.orange, lineWidth: 2)
                    .frame(width: size.width * 0.80, height: size.height * 0.10)
                    .position(x: size.width * 0.50, y: size.height * 0.88)
            default:
                RoundedRectangle(cornerRadius: 10)
                    .stroke(secondary, lineWidth: 2)
                    .frame(width: size.width * 0.32, height: size.height * 0.09)
                    .position(x: size.width * 0.50, y: size.height * 0.24)
                TutorialCallout(text: "KEEP YOUR COMBO", color: secondary)
                    .frame(maxWidth: size.width * 0.80)
                    .position(x: size.width * 0.62, y: size.height * 0.62)
                TutorialArrow(
                    start: CGPoint(x: 0.72, y: 0.59),
                    control: CGPoint(x: 0.96, y: 0.38),
                    end: CGPoint(x: 0.64, y: 0.28)
                )
                .stroke(.white, style: stroke)
            }
        }
    }
}
