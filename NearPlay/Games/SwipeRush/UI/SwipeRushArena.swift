import SwiftUI

struct SwipeRushArena: View {
    let target: SwipeRushTarget
    let targetSize: CGFloat
    let timeProgress: Double
    let accentColor: Color
    let isActive: Bool
    let onSwipe: (SwipeRushDirection) -> Void
    let onInvalidSwipe: () -> Void

    @State private var dragStart: CGPoint?
    @State private var dragPoint: CGPoint?
    @State private var pulse = false
    @State private var shakeToken = 0

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(
                x: proxy.size.width * target.x,
                y: proxy.size.height * target.y
            )

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.07, green: 0.025, blue: 0.14),
                                Color(red: 0.015, green: 0.105, blue: 0.13)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                ambientGlow(size: proxy.size)

                ForEach(0..<4, id: \.self) { index in
                    Image(systemName: target.direction.symbolName)
                        .font(.system(size: 25 + CGFloat(index * 6), weight: .black))
                        .foregroundStyle(accentColor.opacity(0.035 + Double(index) * 0.018))
                        .offset(
                            x: CGFloat(index - 2) * proxy.size.width * 0.19,
                            y: CGFloat(2 - index) * proxy.size.height * 0.16
                        )
                }
                .allowsHitTesting(false)

                if let dragStart, let dragPoint {
                    swipeTrail(from: dragStart, to: dragPoint)
                }

                targetView
                    .position(center)
                    .modifier(SwipeRushShakeEffect(animatableData: CGFloat(shakeToken)))
                    .id(target.id)
                    .transition(.scale(scale: 0.55).combined(with: .opacity))
            }
            .contentShape(RoundedRectangle(cornerRadius: 28))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(accentColor.opacity(0.24), lineWidth: 1.2)
            )
            .gesture(dragGesture(targetCenter: center))
            .animation(.spring(response: 0.32, dampingFraction: 0.72), value: target.id)
        }
        .onAppear { pulse = true }
    }

    private var targetView: some View {
        let color = SwipeRushTheme.color(for: target.direction)

        return ZStack {
            Circle()
                .stroke(color.opacity(0.24), lineWidth: 3)
                .frame(width: targetSize + 30, height: targetSize + 30)
                .scaleEffect(pulse ? 1.08 : 0.92)
                .opacity(pulse ? 0.28 : 0.85)
                .animation(
                    .easeInOut(duration: 0.62).repeatForever(autoreverses: true),
                    value: pulse
                )

            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 7)
                .frame(width: targetSize + 14, height: targetSize + 14)

            Circle()
                .trim(from: 0, to: max(0.001, min(1, timeProgress)))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: targetSize + 14, height: targetSize + 14)
                .shadow(color: color.opacity(0.65), radius: 8)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.96), color],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: targetSize * 0.72
                    )
                )
                .frame(width: targetSize, height: targetSize)
                .overlay(Circle().stroke(.white.opacity(0.58), lineWidth: 1.4))
                .shadow(color: color.opacity(0.58), radius: 18)

            Image(systemName: target.direction.symbolName)
                .font(.system(size: targetSize * 0.43, weight: .black, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.72))
        }
        .accessibilityLabel("Swipe \(target.direction.rawValue)")
    }

    private func ambientGlow(size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(SwipeRushTheme.magenta.opacity(0.10))
                .frame(width: size.width * 0.70)
                .blur(radius: 38)
                .offset(x: -size.width * 0.30, y: -size.height * 0.28)
            Circle()
                .fill(SwipeRushTheme.cyan.opacity(0.09))
                .frame(width: size.width * 0.74)
                .blur(radius: 42)
                .offset(x: size.width * 0.28, y: size.height * 0.30)
        }
        .allowsHitTesting(false)
    }

    private func swipeTrail(from start: CGPoint, to end: CGPoint) -> some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(
            LinearGradient(
                colors: [accentColor.opacity(0.25), accentColor],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 8, lineCap: .round)
        )
        .shadow(color: accentColor, radius: 12)
        .allowsHitTesting(false)
    }

    private func dragGesture(targetCenter: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard isActive else { return }
                if dragStart == nil { dragStart = value.startLocation }
                dragPoint = value.location
            }
            .onEnded { value in
                defer {
                    withAnimation(.easeOut(duration: 0.16)) {
                        dragStart = nil
                        dragPoint = nil
                    }
                }

                guard isActive else { return }
                let startDistance = hypot(
                    value.startLocation.x - targetCenter.x,
                    value.startLocation.y - targetCenter.y
                )
                guard startDistance <= targetSize * 0.72,
                      let direction = SwipeRushDirection.from(
                        translation: value.translation
                      ) else {
                    withAnimation(.linear(duration: 0.32)) {
                        shakeToken += 1
                    }
                    onInvalidSwipe()
                    return
                }
                onSwipe(direction)
            }
    }
}

private struct SwipeRushShakeEffect: GeometryEffect {
    var amount: CGFloat = 9
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}
