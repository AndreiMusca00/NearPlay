import Combine
import CoreMotion
import Foundation

@MainActor
final class LaserDuelMotionController: ObservableObject {
    @Published private(set) var position = 0.5
    @Published private(set) var isAvailable = false

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
            Task { @MainActor in
                self.consume(roll: motion.attitude.roll)
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    func calibrate() {
        neutralRoll = nil
        smoothedPosition = 0.5
        position = 0.5
    }

    private func consume(roll: Double) {
        if neutralRoll == nil { neutralRoll = roll }
        let delta = roll - (neutralRoll ?? roll)
        let target = (0.5 + delta / 0.975).clamped(to: 0.08...0.92)
        smoothedPosition += (target - smoothedPosition) * 0.20
        position = smoothedPosition
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
