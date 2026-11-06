import UIKit

@MainActor
final class OrientationManager {

    static let shared = OrientationManager()

    private(set) var allowedOrientations: UIInterfaceOrientationMask = .portrait

    private var transitionWindow: UIWindow?
    private var isTransitioning = false
    private var pendingTransitionMask: UIInterfaceOrientationMask?
    private var pendingTransitionShowsHomeBranding = false
    private var pendingTransitionOpponentName: String?
    private var pendingTransitionHoldDuration: TimeInterval = 0
    private var pendingTransitionChanges: (() -> Void)?

    private init() {}

    /// Covers navigation and rotation with an opaque, scene-local surface.
    /// The cover never becomes key, preserving keyboard and navigation ownership.
    func transition(to mask: UIInterfaceOrientationMask, changes: @escaping () -> Void) {
        performTransition(
            to: mask,
            showsHomeBranding: false,
            opponentName: nil,
            holdBeforeChanges: 0,
            changes: changes
        )
    }

    /// Performs one covered transition from any game directly to the home
    /// collection. Navigation and an optional rotation happen behind the same
    /// surface, so intermediate lobby screens never become visible.
    func transitionToHome(
        opponentName: String? = nil,
        changes: @escaping () -> Void
    ) {
        performTransition(
            to: .portrait,
            showsHomeBranding: true,
            opponentName: opponentName,
            holdBeforeChanges: opponentName == nil ? 0 : 1.75,
            changes: changes
        )
    }

    private func performTransition(
        to mask: UIInterfaceOrientationMask,
        showsHomeBranding: Bool,
        opponentName: String?,
        holdBeforeChanges: TimeInterval,
        changes: @escaping () -> Void
    ) {
        guard !isTransitioning else {
            // Keep only the newest requested destination. This matters when a
            // peer leaves while the local device is still completing the
            // transition into a landscape game.
            pendingTransitionMask = mask
            pendingTransitionShowsHomeBranding = showsHomeBranding
            pendingTransitionOpponentName = opponentName
            pendingTransitionHoldDuration = holdBeforeChanges
            pendingTransitionChanges = changes
            return
        }
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
        let controller = OrientationCoverController(
            showsHomeBranding: showsHomeBranding,
            opponentName: opponentName
        )
        cover.rootViewController = controller
        cover.backgroundColor = controller.view.backgroundColor
        cover.alpha = 0
        cover.isHidden = false
        transitionWindow = cover

        Task { @MainActor in
            await fade(cover, to: 1, duration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.14)
            if holdBeforeChanges > 0 {
                try? await Task.sleep(
                    nanoseconds: UInt64(holdBeforeChanges * 1_000_000_000)
                )
            }
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
            await fade(cover, to: 0, duration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.24)
            cover.isHidden = true
            cover.rootViewController = nil
            transitionWindow = nil
            isTransitioning = false

            if let pendingMask = pendingTransitionMask,
               let pendingChanges = pendingTransitionChanges {
                let pendingBranding = pendingTransitionShowsHomeBranding
                let pendingOpponentName = pendingTransitionOpponentName
                let pendingHoldDuration = pendingTransitionHoldDuration
                pendingTransitionMask = nil
                pendingTransitionChanges = nil
                pendingTransitionShowsHomeBranding = false
                pendingTransitionOpponentName = nil
                pendingTransitionHoldDuration = 0
                performTransition(
                    to: pendingMask,
                    showsHomeBranding: pendingBranding,
                    opponentName: pendingOpponentName,
                    holdBeforeChanges: pendingHoldDuration,
                    changes: pendingChanges
                )
            }
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
    private let showsHomeBranding: Bool
    private let opponentName: String?
    private let gradientLayer = CAGradientLayer()

    init(showsHomeBranding: Bool, opponentName: String?) {
        self.showsHomeBranding = showsHomeBranding
        self.opponentName = opponentName
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        OrientationManager.shared.allowedOrientations
    }

    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor(red: 7 / 255, green: 16 / 255, blue: 24 / 255, alpha: 1)
        view.isUserInteractionEnabled = true

        guard showsHomeBranding else { return }

        gradientLayer.colors = [
            UIColor(red: 5 / 255, green: 18 / 255, blue: 32 / 255, alpha: 1).cgColor,
            UIColor(red: 22 / 255, green: 12 / 255, blue: 48 / 255, alpha: 1).cgColor,
            UIColor(red: 7 / 255, green: 16 / 255, blue: 24 / 255, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)

        let icon = UIImageView(
            image: UIImage(
                systemName: opponentName == nil
                    ? "gamecontroller.fill"
                    : "person.crop.circle.badge.xmark"
            )
        )
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 34,
            weight: .bold
        )
        icon.tintColor = opponentName == nil
            ? UIColor(red: 0.12, green: 0.86, blue: 1, alpha: 1)
            : UIColor(red: 1, green: 0.38, blue: 0.34, alpha: 1)
        icon.contentMode = .scaleAspectFit
        icon.layer.shadowColor = icon.tintColor.cgColor
        icon.layer.shadowOpacity = 0.55
        icon.layer.shadowRadius = 16

        let title = UILabel()
        title.attributedText = NSAttributedString(
            string: opponentName == nil ? "NEARPLAY" : "OPPONENT LEFT",
            attributes: [
                .font: UIFont.systemFont(ofSize: 19, weight: .black),
                .foregroundColor: UIColor.white,
                .kern: 2.4
            ]
        )
        title.textAlignment = .center

        let subtitle = UILabel()
        subtitle.attributedText = NSAttributedString(
            string: opponentName.map {
                "\($0) left the game.\nReturning to the home screen…"
            } ?? "BACK TO GAMES",
            attributes: [
                .font: UIFont.systemFont(
                    ofSize: opponentName == nil ? 9 : 13,
                    weight: opponentName == nil ? .bold : .semibold
                ),
                .foregroundColor: UIColor.white.withAlphaComponent(
                    opponentName == nil ? 0.42 : 0.62
                ),
                .kern: opponentName == nil ? 1.6 : 0.2
            ]
        )
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, title, subtitle])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 58),
            icon.heightAnchor.constraint(equalToConstant: 46),
            subtitle.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }
}
