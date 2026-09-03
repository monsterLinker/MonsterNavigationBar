import UIKit

/// Implemented by custom full-screen pop gesture recognizers that want to invoke
/// UIKit's private interactive-pop transition action.
public protocol MonsterNavigationTransitionProtocol: AnyObject {
    func handleNavigationTransition(_ pan: UIScreenEdgePanGestureRecognizer)
}

private final class MonsterNavigationBarSnapshot: UIView {
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private let colorView = UIView()
    private let imageView = UIImageView()
    private let shadowView = UIImageView()

    init(navigationBar: MonsterNavigationBar, controller: UIViewController, navigationController: UINavigationController) {
        let barHeight = navigationBar.frame.height + navigationBar.frame.minY
        let y = controller.view.bounds.height == navigationController.view.bounds.height ? 0 : -barHeight
        super.init(frame: CGRect(x: 0, y: y, width: navigationBar.frame.width, height: barHeight))
        isUserInteractionEnabled = false
        clipsToBounds = true

        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.isUserInteractionEnabled = false
        colorView.frame = blurView.contentView.bounds
        colorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        colorView.backgroundColor = controller.monsterComputedBarTintColor
        blurView.contentView.addSubview(colorView)
        addSubview(blurView)

        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleToFill
        imageView.image = controller.monsterComputedBarImage
        addSubview(imageView)

        let hairline = MonsterNavigationBar.monsterHairlineWidth(for: navigationBar)
        shadowView.frame = CGRect(x: 0, y: bounds.height - hairline, width: bounds.width, height: hairline)
        shadowView.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        shadowView.image = navigationBar.shadowImageView.image
        shadowView.backgroundColor = navigationBar.shadowImageView.backgroundColor
        addSubview(shadowView)

        let alpha = controller.monsterBarAlpha
        blurView.alpha = controller.monsterComputedBarImage == nil ? alpha : 0
        imageView.alpha = controller.monsterComputedBarImage == nil ? 0 : alpha
        shadowView.alpha = controller.monsterComputedBarShadowAlpha
    }

    required init?(coder: NSCoder) {
        fatalError("MonsterNavigationBarSnapshot does not support NSCoder initialization")
    }
}

private var monsterSafeAreaBaselineKey: UInt8 = 0

/// UINavigationController that keeps per-controller navigation-bar state in sync
/// during normal and interactive push/pop transitions.
open class MonsterNavigationController: UINavigationController, UINavigationControllerDelegate, UIGestureRecognizerDelegate, UINavigationBarDelegate, MonsterNavigationTransitionProtocol {
    /// An optional delegate that receives the normal UINavigationController callbacks.
    /// The Monster controller remains UIKit's delegate so it can coordinate bar transitions.
    public weak var monsterDelegate: UINavigationControllerDelegate?

    /// UIKit's delegate setter is proxied so assigning a business delegate cannot disable
    /// the navigation-bar transition coordinator.
    open override weak var delegate: UINavigationControllerDelegate? {
        get { monsterDelegate }
        set {
            if let newValue, (newValue as AnyObject) !== (self as AnyObject) {
                monsterDelegate = newValue
            } else if newValue == nil {
                monsterDelegate = nil
            }
            super.delegate = self
        }
    }

    private var transitionSnapshots: [UIView: MonsterNavigationBarSnapshot] = [:]
    private var transitionFrom: UIViewController?
    private var transitionTo: UIViewController?
    private var poppingViewController: UIViewController?
    private weak var transitionBackButtonLabel: UILabel?
    private var savedAdditionalSafeAreaInsetsForFrom: UIEdgeInsets = .zero
    private var savedAdditionalSafeAreaInsetsForTo: UIEdgeInsets = .zero
    private var didCompensateSafeAreaForFrom = false
    private var didCompensateSafeAreaForTo = false
    private weak var systemPopGestureTarget: NSObject?

    public init() {
        super.init(navigationBarClass: MonsterNavigationBar.self, toolbarClass: nil)
    }

    public override init(rootViewController: UIViewController) {
        super.init(navigationBarClass: MonsterNavigationBar.self, toolbarClass: nil)
        viewControllers = [rootViewController]
    }

    public override init(navigationBarClass: AnyClass?, toolbarClass: AnyClass?) {
        precondition(
            navigationBarClass == nil || navigationBarClass is MonsterNavigationBar.Type ||
                (navigationBarClass as? UINavigationBar.Type)?.isSubclass(of: MonsterNavigationBar.self) == true,
            "navigationBarClass must be MonsterNavigationBar or a subclass"
        )
        super.init(navigationBarClass: navigationBarClass ?? MonsterNavigationBar.self, toolbarClass: toolbarClass)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        super.delegate = self
        systemPopGestureTarget = interactivePopGestureRecognizer?.delegate as? NSObject
        interactivePopGestureRecognizer?.delegate = self
        interactivePopGestureRecognizer?.addTarget(self, action: #selector(handleInteractivePopGesture(_:)))
        navigationBar.isTranslucent = true
        if let bar = navigationBar as? MonsterNavigationBar {
            bar.shadowImage = UINavigationBar.appearance().shadowImage
        }
        if #available(iOS 13, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear
            appearance.setBackIndicatorImage(
                UINavigationBar.appearance().backIndicatorImage,
                transitionMaskImage: UINavigationBar.appearance().backIndicatorTransitionMaskImage
            )
            navigationBar.scrollEdgeAppearance = appearance
            navigationBar.standardAppearance = appearance.copy()
        }
        if let top = topViewController {
            updateNavigationBar(for: top)
        }
    }

    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if transitionCoordinator == nil, let top = topViewController {
            updateNavigationBar(for: top)
        }
    }

    open override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        prepareManagedBackButton(for: viewController, previousController: topViewController)
        super.pushViewController(viewController, animated: animated)
    }

    open override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        if let rootController = viewControllers.first {
            prepareManagedBackButton(for: rootController, previousController: nil)
        }
        for (previousController, currentController) in zip(viewControllers, viewControllers.dropFirst()) {
            prepareManagedBackButton(for: currentController, previousController: previousController)
        }
        super.setViewControllers(viewControllers, animated: animated)
    }

    open override func popViewController(animated: Bool) -> UIViewController? {
        guard canPopTopViewController else { return nil }
        if viewControllers.count > 1 { poppingViewController = topViewController }
        let result = super.popViewController(animated: animated)
        if transitionCoordinator == nil, let top = topViewController { updateNavigationBar(for: top) }
        return result
    }

    open override func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        guard canPopTopViewController else { return nil }
        if viewControllers.count > 1 { poppingViewController = topViewController }
        let result = super.popToViewController(viewController, animated: animated)
        if transitionCoordinator == nil, let top = topViewController { updateNavigationBar(for: top) }
        return result
    }

    open override func popToRootViewController(animated: Bool) -> [UIViewController]? {
        guard canPopTopViewController else { return nil }
        if viewControllers.count > 1 { poppingViewController = topViewController }
        let result = super.popToRootViewController(animated: animated)
        if transitionCoordinator == nil, let top = topViewController { updateNavigationBar(for: top) }
        return result
    }

    open override var preferredStatusBarStyle: UIStatusBarStyle {
        guard topViewController?.monsterBarStyle == .black else {
            if #available(iOS 13, *) { return .darkContent }
            return .default
        }
        return .lightContent
    }

    open override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .fade
    }

    open override var childForStatusBarHidden: UIViewController? {
        topViewController
    }

    @available(iOS 11.0, *)
    open override var childForHomeIndicatorAutoHidden: UIViewController? {
        topViewController
    }

    /// Applies all effective style values to the custom navigation bar.
    public func updateNavigationBar(for viewController: UIViewController) {
        let bar = navigationBar as? MonsterNavigationBar
        navigationBar.barStyle = viewController.monsterBarStyle
        navigationBar.tintColor = viewController.monsterEffectiveTintColor
        navigationBar.titleTextAttributes = viewController.monsterEffectiveTitleTextAttributes
        prepareManagedBackButton(
            for: viewController,
            previousController: previousViewController(before: viewController)
        )
        viewController.monsterApplyLiquidGlassBarButtonStyle()

        if #available(iOS 13, *) {
            navigationBar.standardAppearance.titleTextAttributes = viewController.monsterEffectiveTitleTextAttributes
            navigationBar.scrollEdgeAppearance?.titleTextAttributes = viewController.monsterEffectiveTitleTextAttributes
        }

        if let bar {
            bar.barTintColor = viewController.monsterComputedBarTintColor
            bar.backgroundImageView.image = viewController.monsterComputedBarImage
            bar.fakeView.alpha = viewController.monsterComputedBarImage == nil ? viewController.monsterBarAlpha : 0
            bar.backgroundImageView.alpha = viewController.monsterComputedBarImage == nil ? 0 : viewController.monsterBarAlpha
            bar.shadowImageView.alpha = viewController.monsterComputedBarShadowAlpha
            bar.monsterSetContentHidden(viewController.monsterBarHidden)
            bar.monsterBackgroundView?.layer.mask = viewController.monsterBarAlpha == 0 ? CALayer() : nil
        }
        adjustLayout(for: viewController)
    }

    /// Objective-C-compatible spelling used by older integrations.
    public func updateNavigationBarForViewController(_ viewController: UIViewController) {
        updateNavigationBar(for: viewController)
    }

    open func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        let from = transitionCoordinator?.viewController(forKey: .from)
        forwardWillShow(viewController, animated: animated)
        updateNavigationBar(for: viewController)

        guard let from, from !== viewController, shouldShowFakeBar(from: from, to: viewController) else { return }
        transitionFrom = from
        transitionTo = viewController
        installSnapshots(from: from, to: viewController)

        if #available(iOS 12, *) {
            resetButtonLabels(in: navigationBar)
        }

        if poppingViewController != nil {
            let label = (navigationBar as? MonsterNavigationBar)?.backButtonLabel
            label?.monsterSpecifiedTextColor = label?.textColor
            transitionBackButtonLabel = label
            prepareBackButtonItem(from: from, to: viewController)
        }

        guard let coordinator = transitionCoordinator else {
            clearSnapshots()
            return
        }
        hideActualBarLayers()
        coordinator.animate(alongsideTransition: { [weak self] context in
            guard let self else { return }
            self.compensateSafeArea(for: viewController, expectedTopInset: self.navigationBar.frame.maxY, isTo: true)
            self.compensateSafeArea(for: from, expectedTopInset: self.navigationBar.frame.maxY, isTo: false)
            self.prepareTabBar(from: from, to: viewController)
            self.animateTabBar(from: from, to: viewController)
        }) { [weak self] context in
            guard let self else { return }
            let cancelled = context.isCancelled
            self.restoreCompensatedSafeArea(from: from, to: viewController)
            self.completeTabBar(from: from, to: viewController, cancelled: cancelled)
            self.transitionBackButtonLabel?.monsterSpecifiedTextColor = nil
            self.transitionBackButtonLabel = nil
            self.clearSnapshots()
            if cancelled {
                self.updateNavigationBar(for: from)
            } else {
                self.updateNavigationBar(for: viewController)
            }
            if #available(iOS 13, *) {
                self.navigationBar.scrollEdgeAppearance?.backgroundColor = .clear
                self.navigationBar.scrollEdgeAppearance?.backgroundImage = nil
                self.navigationBar.standardAppearance.backgroundColor = .clear
                self.navigationBar.standardAppearance.backgroundImage = nil
            }
            self.transitionFrom = nil
            self.transitionTo = nil
        }
    }

    open func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        monsterDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
        clearSnapshots()
        transitionFrom = nil
        transitionTo = nil
        updateNavigationBar(for: viewController)
        if let item = viewController.monsterBackBarButtonItem, #available(iOS 11, *) {
            viewController.navigationItem.backBarButtonItem = item
        }
        transitionBackButtonLabel?.monsterSpecifiedTextColor = nil
        transitionBackButtonLabel = nil
        poppingViewController = nil
    }

    /// Allows callers to continue using a delegate for the two callbacks Monster intercepts.
    private func forwardWillShow(_ viewController: UIViewController, animated: Bool) {
        monsterDelegate?.navigationController?(self, willShow: viewController, animated: animated)
    }

    open func navigationControllerSupportedInterfaceOrientations(_ navigationController: UINavigationController) -> UIInterfaceOrientationMask {
        monsterDelegate?.navigationControllerSupportedInterfaceOrientations?(navigationController) ?? .portrait
    }

    open func navigationControllerPreferredInterfaceOrientationForPresentation(_ navigationController: UINavigationController) -> UIInterfaceOrientation {
        monsterDelegate?.navigationControllerPreferredInterfaceOrientationForPresentation?(navigationController) ?? .portrait
    }

    open func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        monsterDelegate?.navigationController?(navigationController, interactionControllerFor: animationController)
    }

    open func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        monsterDelegate?.navigationController?(navigationController, animationControllerFor: operation, from: fromVC, to: toVC)
    }

    open func navigationBar(_ navigationBar: UINavigationBar, shouldPop item: UINavigationItem) -> Bool {
        guard viewControllers.count > 1,
              let top = topViewController,
              top.navigationItem === item else { return true }
        let allowed = shouldAllowBack(for: top) && top.monsterClickBackEnabled
        if !allowed { resetNavigationBarSubviews(in: navigationBar) }
        return allowed
    }

    /// Override this hook when a screen needs to display a confirmation before returning.
    open func shouldAllowBack(for viewController: UIViewController) -> Bool {
        viewController.monsterBackInteractive
    }

    /// Creates a configurable iOS 26 back item without replacing caller-supplied left items.
    private func prepareManagedBackButton(
        for viewController: UIViewController,
        previousController: UIViewController?
    ) {
        #if compiler(>=6.2)
        guard #available(iOS 26.0, *) else { return }

        let navigationItem = viewController.navigationItem
        let managedItem = viewController.monsterManagedBackBarButtonItem
        if previousController == nil || navigationItem.hidesBackButton {
            if navigationItem.leftBarButtonItem === managedItem {
                navigationItem.leftBarButtonItem = nil
            }
            viewController.monsterManagedBackBarButtonItem = nil
            return
        }
        guard let previousController else { return }

        if let leftItem = navigationItem.leftBarButtonItem, leftItem !== managedItem {
            viewController.monsterManagedBackBarButtonItem = nil
            return
        }

        let title = managedBackButtonTitle(from: previousController)
        let item = managedItem ?? makeManagedBackButton(title: title)
        item.title = title
        updateManagedBackButtonContent(item, title: title)
        item.hidesSharedBackground = !viewController.monsterLiquidGlassBarButtonEnabled
        navigationItem.leftBarButtonItem = item
        viewController.monsterManagedBackBarButtonItem = item
        #endif
    }

    /// Builds the back control as a custom view so compact navigation bars retain its title.
    @available(iOS 15.0, *)
    private func makeManagedBackButton(title: String?) -> UIBarButtonItem {
        let button = UIButton(configuration: managedBackButtonConfiguration(title: title))
        button.addTarget(self, action: #selector(handleManagedBackButton), for: .touchUpInside)
        return UIBarButtonItem(customView: button)
    }

    /// Keeps a reused managed item in sync when its previous controller changes.
    @available(iOS 15.0, *)
    private func updateManagedBackButtonContent(_ item: UIBarButtonItem, title: String?) {
        guard let button = item.customView as? UIButton else { return }
        button.configuration = managedBackButtonConfiguration(title: title)
        button.accessibilityLabel = title
    }

    /// Matches the standard back-button image and title spacing without adding a background.
    @available(iOS 15.0, *)
    private func managedBackButtonConfiguration(title: String?) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = UIImage(systemName: "chevron.backward")
        configuration.imagePlacement = .leading
        configuration.imagePadding = title == nil ? 0 : 4
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 4)
        return configuration
    }

    /// Resolves the title UIKit would normally source from the previous navigation item.
    private func managedBackButtonTitle(from previousController: UIViewController) -> String? {
        let navigationItem = previousController.navigationItem
        if #available(iOS 14.0, *), navigationItem.backButtonDisplayMode == .minimal {
            return nil
        }
        return navigationItem.backBarButtonItem?.title
            ?? navigationItem.backButtonTitle
            ?? navigationItem.title
            ?? previousController.title
    }

    /// Finds the controller that owns the current page's system back-button title.
    private func previousViewController(before viewController: UIViewController) -> UIViewController? {
        guard let index = viewControllers.firstIndex(where: { $0 === viewController }), index > 0 else {
            return nil
        }
        return viewControllers[index - 1]
    }

    @objc private func handleManagedBackButton() {
        _ = popViewController(animated: true)
    }

    /// Centralizes button and programmatic pop permission checks. UIKit invokes
    /// `popViewController(animated:)` for the system back button, so this path
    /// remains available on iOS versions that reject a custom navigation-bar
    /// delegate.
    private var canPopTopViewController: Bool {
        guard viewControllers.count > 1, let top = topViewController else { return false }
        return top.monsterClickBackEnabled && shouldAllowBack(for: top)
    }

    open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer,
              viewControllers.count > 1,
              let top = topViewController else { return true }
        guard transitionCoordinator == nil else { return false }
        return top.monsterSwipeBackEnabled && shouldAllowBack(for: top)
    }

    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer === interactivePopGestureRecognizer
    }

    /// Forwards the target/action used by UIKit's edge-pop transition. This keeps the
    /// upstream full-screen-pan example usable without exposing private UIKit types.
    @objc public func handleNavigationTransition(_ pan: UIScreenEdgePanGestureRecognizer) {
        let selector = NSSelectorFromString("handleNavigationTransition:")
        guard let target = systemPopGestureTarget, target.responds(to: selector) else { return }
        _ = target.perform(selector, with: pan)
    }

    @objc private func handleInteractivePopGesture(_ gesture: UIGestureRecognizer) {
        if gesture.state == .began,
           let top = topViewController,
           top.navigationItem.backBarButtonItem != nil,
           poppingViewController == nil {
            top.monsterBackBarButtonItem = top.navigationItem.backBarButtonItem
        }
        guard let coordinator = transitionCoordinator,
              let from = coordinator.viewController(forKey: .from),
              let to = coordinator.viewController(forKey: .to),
              let bar = navigationBar as? MonsterNavigationBar else { return }
        if gesture.state == .began || gesture.state == .changed {
            bar.tintColor = MonsterNavigationController.blendColor(
                from.monsterEffectiveTintColor,
                to.monsterEffectiveTintColor,
                coordinator.percentComplete
            )
        }
    }

    private func installSnapshots(from: UIViewController, to: UIViewController) {
        guard let bar = navigationBar as? MonsterNavigationBar else { return }
        let fromSnapshot = MonsterNavigationBarSnapshot(navigationBar: bar, controller: from, navigationController: self)
        let toSnapshot = MonsterNavigationBarSnapshot(navigationBar: bar, controller: to, navigationController: self)
        from.view.addSubview(fromSnapshot)
        to.view.addSubview(toSnapshot)
        transitionSnapshots[from.view] = fromSnapshot
        transitionSnapshots[to.view] = toSnapshot
    }

    private func hideActualBarLayers() {
        guard let bar = navigationBar as? MonsterNavigationBar else { return }
        bar.fakeView.alpha = 0
        bar.backgroundImageView.alpha = 0
        bar.shadowImageView.alpha = 0
    }

    private func clearSnapshots() {
        transitionSnapshots.values.forEach { $0.removeFromSuperview() }
        transitionSnapshots.removeAll()
    }

    private func prepareBackButtonItem(from: UIViewController, to: UIViewController) {
        guard #available(iOS 11, *), poppingViewController === from else { return }
        let oldItem = to.navigationItem.backBarButtonItem
        let item = UIBarButtonItem()
        item.title = oldItem?.title ?? (navigationBar as? MonsterNavigationBar)?.backButtonLabel?.text
        item.tintColor = from.monsterEffectiveTintColor
        to.navigationItem.backBarButtonItem = item
        to.monsterApplyLiquidGlassBarButtonStyle()
    }

    private func resetButtonLabels(in view: UIView) {
        let name = String(describing: type(of: view)).replacingOccurrences(of: "_", with: "")
        if name == "UIButtonLabel" { view.alpha = 1 }
        view.subviews.forEach { resetButtonLabels(in: $0) }
    }

    private func resetNavigationBarSubviews(in navigationBar: UINavigationBar) {
        if #available(iOS 11, *) { return }
        navigationBar.subviews.filter { $0.alpha < 1 }.forEach { view in
            UIView.animate(withDuration: 0.25) { view.alpha = 1 }
        }
    }

    private func shouldShowFakeBar(from: UIViewController, to: UIViewController) -> Bool {
        if from.monsterSplitNavigationBarTransition || to.monsterSplitNavigationBarTransition { return true }

        let fromImage = from.monsterComputedBarImage
        let toImage = to.monsterComputedBarImage
        if let fromImage, let toImage, MonsterNavigationController.imageData(fromImage) == MonsterNavigationController.imageData(toImage) {
            return from.monsterBarAlpha != to.monsterBarAlpha
        }
        if fromImage == nil, toImage == nil,
           MonsterNavigationController.colorsEqual(from.monsterComputedBarTintColor, to.monsterComputedBarTintColor) {
            return from.monsterBarAlpha != to.monsterBarAlpha
        }
        return true
    }

    private func adjustLayout(for viewController: UIViewController) {
        var translucent = viewController.monsterBarHidden || viewController.monsterBarAlpha < 1
        if !translucent {
            if let image = viewController.monsterComputedBarImage {
                translucent = MonsterNavigationController.imageHasAlpha(image)
            } else {
                translucent = MonsterNavigationController.colorHasAlpha(viewController.monsterComputedBarTintColor)
            }
        }

        if translucent || viewController.extendedLayoutIncludesOpaqueBars {
            viewController.edgesForExtendedLayout.insert(.top)
        } else {
            viewController.edgesForExtendedLayout.remove(.top)
        }

        if #available(iOS 11, *) {
            if viewController.monsterBarHidden {
                if objc_getAssociatedObject(viewController, &monsterSafeAreaBaselineKey) == nil {
                    objc_setAssociatedObject(viewController, &monsterSafeAreaBaselineKey, NSValue(uiEdgeInsets: viewController.additionalSafeAreaInsets), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
                let baseline = (objc_getAssociatedObject(viewController, &monsterSafeAreaBaselineKey) as? NSValue)?.uiEdgeInsetsValue ?? .zero
                var insets = viewController.additionalSafeAreaInsets
                insets.top = baseline.top - navigationBar.bounds.height
                viewController.additionalSafeAreaInsets = insets
            } else if let value = objc_getAssociatedObject(viewController, &monsterSafeAreaBaselineKey) as? NSValue {
                viewController.additionalSafeAreaInsets = value.uiEdgeInsetsValue
                objc_setAssociatedObject(viewController, &monsterSafeAreaBaselineKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
        viewController.monsterExtendedLayoutDidSet = true
    }

    private static func imageHasAlpha(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return true }
        switch cgImage.alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }

    private static func imageData(_ image: UIImage) -> Data? {
        if #available(iOS 10, *) {
            return image.pngData()
        }
        // iOS 9 has no Swift-visible PNG representation API. Returning nil
        // simply makes equal-but-distinct images use the conservative transition.
        return nil
    }

    private static func colorHasAlpha(_ color: UIColor?) -> Bool {
        guard let color else { return true }
        var alpha: CGFloat = 1
        guard color.getRed(nil, green: nil, blue: nil, alpha: &alpha) else { return true }
        return alpha < 1
    }

    private static func colorsEqual(_ lhs: UIColor?, _ rhs: UIColor?) -> Bool {
        guard let lhs, let rhs else { return lhs == nil && rhs == nil }
        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        var rr: CGFloat = 0, rg: CGFloat = 0, rb: CGFloat = 0, ra: CGFloat = 0
        guard lhs.getRed(&lr, green: &lg, blue: &lb, alpha: &la), rhs.getRed(&rr, green: &rg, blue: &rb, alpha: &ra) else {
            return lhs.cgColor == rhs.cgColor
        }
        return abs(lr - rr) < 0.0001 && abs(lg - rg) < 0.0001 && abs(lb - rb) < 0.0001 && abs(la - ra) < 0.0001
    }

    private static func blendColor(_ from: UIColor, _ to: UIColor, _ percent: CGFloat) -> UIColor {
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        guard from.getRed(&fr, green: &fg, blue: &fb, alpha: &fa), to.getRed(&tr, green: &tg, blue: &tb, alpha: &ta) else {
            return percent < 0.5 ? from : to
        }
        let progress = min(1, max(0, percent * 4))
        return UIColor(
            red: fr + (tr - fr) * progress,
            green: fg + (tg - fg) * progress,
            blue: fb + (tb - fb) * progress,
            alpha: fa + (ta - fa) * progress
        )
    }

    private func compensateSafeArea(for viewController: UIViewController, expectedTopInset: CGFloat, isTo: Bool) {
        guard #available(iOS 11, *), viewController.isViewLoaded else { return }
        viewController.view.layoutIfNeeded()
        let systemTop = viewController.view.safeAreaInsets.top
        let compensate = max(0, expectedTopInset - systemTop)
        if isTo {
            savedAdditionalSafeAreaInsetsForTo = viewController.additionalSafeAreaInsets
            didCompensateSafeAreaForTo = compensate > 0
        } else {
            savedAdditionalSafeAreaInsetsForFrom = viewController.additionalSafeAreaInsets
            didCompensateSafeAreaForFrom = compensate > 0
        }
        guard compensate > 0 else { return }
        var insets = viewController.additionalSafeAreaInsets
        insets.top += compensate
        viewController.additionalSafeAreaInsets = insets
    }

    private func restoreCompensatedSafeArea(from: UIViewController, to: UIViewController) {
        guard #available(iOS 11, *) else { return }
        if didCompensateSafeAreaForTo {
            to.additionalSafeAreaInsets = savedAdditionalSafeAreaInsetsForTo
            didCompensateSafeAreaForTo = false
        }
        if didCompensateSafeAreaForFrom {
            from.additionalSafeAreaInsets = savedAdditionalSafeAreaInsetsForFrom
            didCompensateSafeAreaForFrom = false
        }
    }

    private func prepareTabBar(from: UIViewController, to: UIViewController) {
        guard from.hidesBottomBarWhenPushed != to.hidesBottomBarWhenPushed,
              let tabBar = tabBarController?.tabBar else { return }
        tabBar.layer.removeAllAnimations()
        tabBar.isHidden = false
        tabBar.alpha = from.hidesBottomBarWhenPushed ? 0 : 1
    }

    private func animateTabBar(from: UIViewController, to: UIViewController) {
        guard from.hidesBottomBarWhenPushed != to.hidesBottomBarWhenPushed,
              let tabBar = tabBarController?.tabBar else { return }
        tabBar.alpha = to.hidesBottomBarWhenPushed ? 0 : 1
    }

    private func completeTabBar(from: UIViewController, to: UIViewController, cancelled: Bool) {
        guard from.hidesBottomBarWhenPushed != to.hidesBottomBarWhenPushed,
              let tabBar = tabBarController?.tabBar else { return }
        tabBar.layer.removeAllAnimations()
        let visible = cancelled ? from : to
        tabBar.isHidden = visible.hidesBottomBarWhenPushed
        tabBar.alpha = 1
    }
}

extension MonsterNavigationBar {
    fileprivate static func monsterHairlineWidth(for view: UIView) -> CGFloat {
        let scale = view.window?.screen.scale ?? view.traitCollection.displayScale
        return scale > 0 ? 1 / scale : 1
    }
}
