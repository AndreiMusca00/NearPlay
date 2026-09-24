import UIKit

@MainActor
final class OrientationManager {

    static let shared = OrientationManager()

    private(set) var allowedOrientations: UIInterfaceOrientationMask = .portrait

    private var transitionWindow: UIWindow?
    private var isTransitioning = false

    private init() {}

    /// Covers navigation and rotation with an opaque, scene-local surface.
    /// The cover never becomes key, preserving keyboard and navigation ownership.
    func transition(to mask: UIInterfaceOrientationMask, changes: @escaping () -> Void) {
        guard !isTransitioning else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            setOrientation(mask: mask)
            changes()
            return
        }
        isTransitioning = true
        let cover = UIWindow(windowScene: scene)
        cover.windowLevel = .alert + 1
        let controller = OrientationCoverController()
        cover.rootViewController = controller
        cover.backgroundColor = controller.view.backgroundColor
        cover.alpha = 0
        cover.isHidden = false
        transitionWindow = cover

        Task { @MainActor in
            await fade(cover, to: 1, duration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.12)
            setOrientation(mask: mask)
            changes()

            // Require a stable target orientation and completed UIKit transitions.
            // A bounded wait also releases the cover if the system rejects rotation.
            var stableSamples = 0
            for _ in 0..<100 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                let matches = mask.contains(.portrait)
                    ? scene.interfaceOrientation == .portrait
                    : scene.interfaceOrientation.isLandscape
                let rotating = scene.keyWindow?.rootViewController?.transitionCoordinator?.isAnimated == true
                stableSamples = matches && !rotating ? stableSamples + 1 : 0
                if stableSamples >= 8 { break }
            }
            await fade(cover, to: 0, duration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.2)
            cover.isHidden = true
            cover.rootViewController = nil
            transitionWindow = nil
            isTransitioning = false
        }
    }

    private func fade(_ window: UIWindow, to alpha: CGFloat, duration: TimeInterval) async {
        await withCheckedContinuation { continuation in
            UIView.animate(withDuration: duration, animations: {
                window.alpha = alpha
            }, completion: { _ in continuation.resume() })
        }
    }

    func lockToLandscape() {
        guard allowedOrientations != [.landscapeLeft, .landscapeRight], !isTransitioning else { return }
        transition(to: [.landscapeLeft, .landscapeRight], changes: {})
    }

    func lockToPortrait() {
        guard allowedOrientations != .portrait, !isTransitioning else { return }
        transition(to: .portrait, changes: {})
    }

    private func setOrientation(
        mask: UIInterfaceOrientationMask
    ) {
        allowedOrientations = mask

        guard let windowScene = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: {
                $0.activationState == .foregroundActive
            })
        else {
            return
        }

        if #available(iOS 16.0, *) {
            windowScene.keyWindow?
                .rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()

            transitionWindow?.rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()

            let preferences =
                UIWindowScene.GeometryPreferences.iOS(
                    interfaceOrientations: mask
                )

            windowScene.requestGeometryUpdate(
                preferences
            ) { error in
                #if DEBUG
                print(
                    "Orientation update failed:",
                    error.localizedDescription
                )
                #endif
            }
        } else {
            let targetOrientation: UIInterfaceOrientation =
                mask.contains(.landscapeRight)
                ? .landscapeRight
                : .portrait

            UIDevice.current.setValue(
                targetOrientation.rawValue,
                forKey: "orientation"
            )

            UIViewController
                .attemptRotationToDeviceOrientation()
        }
    }
}

@MainActor
final class NearPlayOrientationAppDelegate:
    NSObject,
    UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationManager.shared.allowedOrientations
    }
}

@MainActor
private final class OrientationCoverController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        OrientationManager.shared.allowedOrientations
    }

    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor(red: 7 / 255, green: 16 / 255, blue: 24 / 255, alpha: 1)
        view.isUserInteractionEnabled = true
    }
}
