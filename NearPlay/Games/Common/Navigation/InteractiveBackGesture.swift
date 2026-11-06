import SwiftUI
import UIKit

extension View {
    /// Restores UINavigationController's native edge-swipe transition on
    /// screens that hide the system navigation bar and draw their own Back
    /// button.
    func interactiveBackGestureEnabled(
        _ isEnabled: Bool = true
    ) -> some View {
        background {
            InteractiveBackGestureEnabler(
                isEnabled: isEnabled
            )
            .frame(width: 0, height: 0)
        }
    }
}

private struct InteractiveBackGestureEnabler:
    UIViewControllerRepresentable {

    let isEnabled: Bool

    func makeUIViewController(
        context: Context
    ) -> GestureHostingController {
        let controller = GestureHostingController()
        controller.isGestureEnabled = isEnabled
        return controller
    }

    func updateUIViewController(
        _ uiViewController: GestureHostingController,
        context: Context
    ) {
        uiViewController.isGestureEnabled = isEnabled
        uiViewController.installIfPossible()
    }

    static func dismantleUIViewController(
        _ uiViewController: GestureHostingController,
        coordinator: ()
    ) {
        uiViewController.restoreOriginalDelegate()
    }

    final class GestureHostingController:
        UIViewController,
        UIGestureRecognizerDelegate {

        var isGestureEnabled = true {
            didSet {
                navigationController?
                    .interactivePopGestureRecognizer?
                    .isEnabled = isGestureEnabled
            }
        }

        private weak var installedNavigationController:
            UINavigationController?
        private weak var originalDelegate:
            UIGestureRecognizerDelegate?

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            installIfPossible()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            installIfPossible()
        }

        func installIfPossible() {
            guard let navigationController,
                  let gesture = navigationController
                    .interactivePopGestureRecognizer else {
                return
            }

            if installedNavigationController !== navigationController {
                restoreOriginalDelegate()
                installedNavigationController = navigationController
                originalDelegate = gesture.delegate
            }

            if gesture.delegate !== self {
                originalDelegate = gesture.delegate
                gesture.delegate = self
            }
            gesture.isEnabled = isGestureEnabled
        }

        func restoreOriginalDelegate() {
            guard let gesture = installedNavigationController?
                .interactivePopGestureRecognizer else {
                return
            }

            if gesture.delegate === self {
                gesture.delegate = originalDelegate
            }
        }

        func gestureRecognizerShouldBegin(
            _ gestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard isGestureEnabled,
                  let navigationController = installedNavigationController,
                  navigationController.viewControllers.count > 1,
                  navigationController.transitionCoordinator == nil else {
                return false
            }

            if let pan = gestureRecognizer as? UIPanGestureRecognizer {
                let velocity = pan.velocity(in: pan.view)
                guard velocity.x > abs(velocity.y) else {
                    return false
                }
            }

            return true
        }
    }
}
