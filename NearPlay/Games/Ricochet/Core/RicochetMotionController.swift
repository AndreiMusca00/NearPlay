import CoreMotion
import Combine
import Foundation

@MainActor
final class RicochetMotionController: ObservableObject {
    @Published private(set) var position = 0.5
    @Published private(set) var isAvailable = false
    @Published private(set) var isRunning = false

    private let manager = CMMotionManager()
    private var neutralRoll: Double?
    private var smoothedPosition = 0.5

    func start() {
        guard manager.isDeviceMotionAvailable else {
            isAvailable = false
            return
        }
        isAvailable = true
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            Task { @MainActor in self.consume(roll: motion.attitude.roll) }
        }
        isRunning = true
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isRunning = false
    }

    func calibrate() {
        neutralRoll = nil
        smoothedPosition = 0.5
        position = 0.5
    }

    private func consume(roll: Double) {
        if neutralRoll == nil { neutralRoll = roll }
        let delta = roll - (neutralRoll ?? roll)
        let target = (0.5 + delta / 0.85).clamped(to: 0.08...0.92)
        smoothedPosition += (target - smoothedPosition) * 0.18
        position = smoothedPosition
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
