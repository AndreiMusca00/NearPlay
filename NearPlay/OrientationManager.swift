import UIKit

@MainActor
final class OrientationManager {

    static let shared = OrientationManager()

    private(set) var allowedOrientations: UIInterfaceOrientationMask = .portrait

    private init() {}

    func lockToLandscape() {
        setOrientation(
            mask: [.landscapeLeft, .landscapeRight]
        )
    }

    func lockToPortrait() {
        setOrientation(
            mask: .portrait
        )
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
