//
//  NearPlayLoadingView.swift
//  NearPlay
//

import SwiftUI

struct NearPlayLoadingView: View {
    @State private var contentVisible = false
    @State private var pulse = false
    @State private var animateDots = false

    var body: some View {
        ZStack {
            Color(
                red: 11.0 / 255.0,
                green: 15.0 / 255.0,
                blue: 21.0 / 255.0
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0.42),
                                    Color.purple.opacity(0.34)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 92, height: 92)
                        .scaleEffect(pulse ? 1.14 : 0.92)
                        .opacity(pulse ? 0.08 : 0.38)

                    Circle()
                        .fill(Color.white.opacity(0.045))
                        .frame(width: 78, height: 78)
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        }

                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(
                                        red: 0.05,
                                        green: 0.72,
                                        blue: 1.00
                                    ),
                                    Color(
                                        red: 0.45,
                                        green: 0.38,
                                        blue: 1.00
                                    ),
                                    Color(
                                        red: 0.66,
                                        green: 0.25,
                                        blue: 1.00
                                    )
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(contentVisible ? 1.0 : 0.86)
                .opacity(contentVisible ? 1.0 : 0.0)

                VStack(spacing: 10) {
                    Text("NearPlay")
                        .font(
                            .system(
                                size: 42,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(
                                        red: 0.05,
                                        green: 0.72,
                                        blue: 1.00
                                    ),
                                    Color(
                                        red: 0.35,
                                        green: 0.40,
                                        blue: 1.00
                                    ),
                                    Color(
                                        red: 0.66,
                                        green: 0.25,
                                        blue: 1.00
                                    )
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Play together. Anywhere.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.46))
                }
                .offset(y: contentVisible ? 0 : 8)
                .opacity(contentVisible ? 1.0 : 0.0)

                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.white.opacity(0.52))
                            .frame(width: 6, height: 6)
                            .scaleEffect(animateDots ? 1.0 : 0.55)
                            .opacity(animateDots ? 0.85 : 0.25)
                            .animation(
                                .easeInOut(duration: 0.52)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.14),
                                value: animateDots
                            )
                    }
                }
                .padding(.top, 4)
                .opacity(contentVisible ? 1.0 : 0.0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.34)) {
                contentVisible = true
            }

            withAnimation(
                .easeInOut(duration: 1.05)
                    .repeatForever(autoreverses: true)
            ) {
                pulse = true
            }

            animateDots = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("NearPlay is starting")
    }
}

#Preview {
    NearPlayLoadingView()
        .preferredColorScheme(.dark)
}
