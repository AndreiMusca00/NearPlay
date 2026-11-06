import Combine
import CoreMotion
import Foundation

@MainActor
final class TiltRaceMotionController: ObservableObject {
    @Published private(set) var tiltX = 0.0
    @Published private(set) var tiltY = 0.0
    @Published private(set) var isAvailable = false
    @Published private(set) var isReceivingUpdates = false
    @Published private(set) var isCalibrating = true

    var isReady: Bool {
        isAvailable && isReceivingUpdates && !isCalibrating
    }

    private let manager = CMMotionManager()

    private var neutralGravityX = 0.0
    private var neutralGravityY = 0.0
    private var calibrationSampleCount = 0
    private var smoothedX = 0.0
    private var smoothedY = 0.0

    private var startedAt: Date?
    private var lastUpdateAt: Date?
    private var lastRestartAttemptAt = Date.distantPast

    private let requiredCalibrationSamples = 12
    private let staleUpdateInterval: TimeInterval = 0.35
    private let restartInterval: TimeInterval = 0.9

    func start(recalibrating: Bool = false) {
        guard manager.isDeviceMotionAvailable else {
            isAvailable = false
            isReceivingUpdates = false
            isCalibrating = false
            return
        }

        isAvailable = true

        if recalibrating {
            calibrate()
        }

        guard !manager.isDeviceMotionActive else {
            return
        }

        startedAt = Date()
        lastUpdateAt = nil
        isReceivingUpdates = false
        manager.deviceMotionUpdateInterval = 1.0 / 60.0

        // Gravity is more stable than raw roll/pitch here: it does not wrap at
        // ±π and keeps behaving like a real ball on a flat phone.
        manager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: .main
        ) { [weak self] motion, error in
            Task { @MainActor in
                guard let self else { return }

                guard error == nil, let motion else {
                    self.isReceivingUpdates = false
                    return
                }

                self.consume(
                    gravityX: motion.gravity.x,
                    gravityY: motion.gravity.y,
                    at: Date()
                )
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        startedAt = nil
        lastUpdateAt = nil
        isReceivingUpdates = false
        smoothedX = 0
        smoothedY = 0
        tiltX = 0
        tiltY = 0
    }

    func calibrate() {
        neutralGravityX = 0
        neutralGravityY = 0
        calibrationSampleCount = 0
        smoothedX = 0
        smoothedY = 0
        tiltX = 0
        tiltY = 0
        isCalibrating = true
    }

    /// Prevents a suspended Core Motion stream from leaving the last strong
    /// tilt applied forever while the ball is touching an arena edge.
    func updateHealth(at date: Date) {
        guard isAvailable, manager.isDeviceMotionActive else {
            isReceivingUpdates = false
            return
        }

        let referenceDate = lastUpdateAt ?? startedAt ?? date
        let age = date.timeIntervalSince(referenceDate)

        if age > staleUpdateInterval {
            isReceivingUpdates = false
            smoothedX *= 0.72
            smoothedY *= 0.72
            tiltX = smoothedX
            tiltY = smoothedY
        }

        guard age > restartInterval,
              date.timeIntervalSince(lastRestartAttemptAt) > restartInterval else {
            return
        }

        lastRestartAttemptAt = date
        manager.stopDeviceMotionUpdates()
        start(recalibrating: true)
    }

    private func consume(
        gravityX: Double,
        gravityY: Double,
        at date: Date
    ) {
        lastUpdateAt = date
        isReceivingUpdates = true

        if calibrationSampleCount < requiredCalibrationSamples {
            calibrationSampleCount += 1
            let count = Double(calibrationSampleCount)
            neutralGravityX += (gravityX - neutralGravityX) / count
            neutralGravityY += (gravityY - neutralGravityY) / count
            tiltX = 0
            tiltY = 0

            if calibrationSampleCount == requiredCalibrationSamples {
                isCalibrating = false
            }
            return
        }

        let targetX = ((gravityX - neutralGravityX) / 0.36)
            .applyingDeadZone(0.035)
            .clamped(to: -1...1)

        // Gravity Y is opposite to the screen movement expected by the player.
        let targetY = (-(gravityY - neutralGravityY) / 0.34)
            .applyingDeadZone(0.035)
            .clamped(to: -1...1)

        smoothedX += (targetX - smoothedX) * 0.20
        smoothedY += (targetY - smoothedY) * 0.20
        tiltX = smoothedX
        tiltY = smoothedY
    }
}

private extension Double {
    func applyingDeadZone(_ radius: Double) -> Double {
        guard abs(self) > radius else { return 0 }
        return self > 0 ? self - radius : self + radius
    }

    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
