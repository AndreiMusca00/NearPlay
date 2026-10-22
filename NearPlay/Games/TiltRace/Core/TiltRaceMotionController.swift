import Combine
import CoreMotion
import Foundation

@MainActor
final class TiltRaceMotionController: ObservableObject {
    @Published private(set) var tiltX = 0.0
    @Published private(set) var tiltY = 0.0
    @Published private(set) var isAvailable = false

    private let manager = CMMotionManager()
    private var neutralRoll: Double?
    private var neutralPitch: Double?
    private var smoothedX = 0.0
    private var smoothedY = 0.0

    func start() {
        guard manager.isDeviceMotionAvailable else {
            isAvailable = false
            return
        }

        isAvailable = true
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            Task { @MainActor in
                self.consume(
                    roll: motion.attitude.roll,
                    pitch: motion.attitude.pitch
                )
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    func calibrate() {
        neutralRoll = nil
        neutralPitch = nil
        smoothedX = 0
        smoothedY = 0
        tiltX = 0
        tiltY = 0
    }

    private func consume(roll: Double, pitch: Double) {
        if neutralRoll == nil { neutralRoll = roll }
        if neutralPitch == nil { neutralPitch = pitch }

        let targetX = ((roll - (neutralRoll ?? roll)) / 0.42)
            .clamped(to: -1...1)
        let targetY = ((pitch - (neutralPitch ?? pitch)) / 0.38)
            .clamped(to: -1...1)

        smoothedX += (targetX - smoothedX) * 0.18
        smoothedY += (targetY - smoothedY) * 0.18
        tiltX = smoothedX
        tiltY = smoothedY
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
