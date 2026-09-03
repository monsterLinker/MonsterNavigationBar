import UIKit
import ObjectiveC.runtime

private var monsterBarStyleKey: UInt8 = 0
private var monsterBarTintColorKey: UInt8 = 0
private var monsterBarImageKey: UInt8 = 0
private var monsterTintColorKey: UInt8 = 0
private var monsterTitleTextAttributesKey: UInt8 = 0
private var monsterBarAlphaKey: UInt8 = 0
private var monsterBarHiddenKey: UInt8 = 0
private var monsterBarShadowHiddenKey: UInt8 = 0
private var monsterBackInteractiveKey: UInt8 = 0
private var monsterSwipeBackEnabledKey: UInt8 = 0
private var monsterClickBackEnabledKey: UInt8 = 0
private var monsterSplitTransitionKey: UInt8 = 0
private var monsterLiquidGlassBarButtonEnabledKey: UInt8 = 0
private var monsterExtendedLayoutDidSetKey: UInt8 = 0
private var monsterBackBarButtonItemKey: UInt8 = 0

/// Declarative navigation-bar configuration attached to each view controller.
public extension UIViewController {
    @IBInspectable var monsterBlackBarStyle: Bool {
        get { monsterBarStyle == .black }
        set { monsterBarStyle = newValue ? .black : .default }
    }

    var monsterBarStyle: UIBarStyle {
        get {
            (objc_getAssociatedObject(self, &monsterBarStyleKey) as? NSNumber).map { UIBarStyle(rawValue: $0.intValue) ?? .default }
                ?? UINavigationBar.appearance().barStyle
        }
        set { objc_setAssociatedObject(self, &monsterBarStyleKey, NSNumber(value: newValue.rawValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @IBInspectable var monsterBarTintColor: UIColor? {
        get { objc_getAssociatedObject(self, &monsterBarTintColorKey) as? UIColor }
        set { objc_setAssociatedObject(self, &monsterBarTintColorKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @IBInspectable var monsterBarImage: UIImage? {
        get { objc_getAssociatedObject(self, &monsterBarImageKey) as? UIImage }
        set { objc_setAssociatedObject(self, &monsterBarImageKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @IBInspectable var monsterTintColor: UIColor? {
        get {
            (objc_getAssociatedObject(self, &monsterTintColorKey) as? UIColor)
                ?? UINavigationBar.appearance().tintColor
                ?? .black
        }
        set { objc_setAssociatedObject(self, &monsterTintColorKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var monsterTitleTextAttributes: [NSAttributedString.Key: Any] {
        get { monsterEffectiveTitleTextAttributes }
        set { objc_setAssociatedObject(self, &monsterTitleTextAttributesKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }

    private var monsterStoredTitleTextAttributes: [NSAttributedString.Key: Any]? {
        objc_getAssociatedObject(self, &monsterTitleTextAttributesKey) as? [NSAttributedString.Key: Any]
    }

    @IBInspectable var monsterBarAlpha: CGFloat {
        get {
            if monsterBarHidden { return 0 }
            return (objc_getAssociatedObject(self, &monsterBarAlphaKey) as? NSNumber)?.doubleValue ?? 1
        }
        set { objc_setAssociatedObject(self, &monsterBarAlphaKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @IBInspectable var monsterBarHidden: Bool {
        get { (objc_getAssociatedObject(self, &monsterBarHiddenKey) as? NSNumber)?.boolValue ?? false }
        set {
            navigationItem.titleView = newValue ? UIView(frame: .zero) : nil
            if #available(iOS 16, *) {
                navigationItem.hidesBackButton = newValue
            } else if newValue {
                navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView(frame: .zero))
            } else {
                navigationItem.leftBarButtonItem = nil
            }
            objc_setAssociatedObject(self, &monsterBarHiddenKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    @IBInspectable var monsterBarShadowHidden: Bool {
        get { monsterBarHidden || ((objc_getAssociatedObject(self, &monsterBarShadowHiddenKey) as? NSNumber)?.boolValue ?? false) }
        set { objc_setAssociatedObject(self, &monsterBarShadowHiddenKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @IBInspectable var monsterBackInteractive: Bool {
        get { (objc_getAssociatedObject(self, &monsterBackInteractiveKey) as? NSNumber)?.boolValue ?? true }
        set { objc_setAssociatedObject(self, &monsterBackInteractiveKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @IBInspectable var monsterSwipeBackEnabled: Bool {
        get { (objc_getAssociatedObject(self, &monsterSwipeBackEnabledKey) as? NSNumber)?.boolValue ?? true }
        set { objc_setAssociatedObject(self, &monsterSwipeBackEnabledKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @IBInspectable var monsterClickBackEnabled: Bool {
        get { (objc_getAssociatedObject(self, &monsterClickBackEnabledKey) as? NSNumber)?.boolValue ?? true }
        set { objc_setAssociatedObject(self, &monsterClickBackEnabledKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @IBInspectable var monsterSplitNavigationBarTransition: Bool {
        get { (objc_getAssociatedObject(self, &monsterSplitTransitionKey) as? NSNumber)?.boolValue ?? false }
        set { objc_setAssociatedObject(self, &monsterSplitTransitionKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Controls whether custom navigation bar items use the system Liquid Glass
    /// background on iOS 26 and later. The default is `false` for legacy styling.
    @IBInspectable var monsterLiquidGlassBarButtonEnabled: Bool {
        get { (objc_getAssociatedObject(self, &monsterLiquidGlassBarButtonEnabledKey) as? NSNumber)?.boolValue ?? false }
        set {
            objc_setAssociatedObject(
                self,
                &monsterLiquidGlassBarButtonEnabledKey,
                NSNumber(value: newValue),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            monsterApplyLiquidGlassBarButtonStyle()
        }
    }

    /// Set internally when a caller deliberately opts into an opaque bar extending over content.
    var monsterExtendedLayoutDidSet: Bool {
        get { (objc_getAssociatedObject(self, &monsterExtendedLayoutDidSetKey) as? NSNumber)?.boolValue ?? false }
        set { objc_setAssociatedObject(self, &monsterExtendedLayoutDidSetKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var monsterBackBarButtonItem: UIBarButtonItem? {
        get { objc_getAssociatedObject(self, &monsterBackBarButtonItemKey) as? UIBarButtonItem }
        set { objc_setAssociatedObject(self, &monsterBackBarButtonItemKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var monsterComputedBarShadowAlpha: CGFloat {
        monsterBarShadowHidden ? 0 : monsterBarAlpha
    }

    var monsterComputedBarImage: UIImage? {
        if let image = monsterBarImage { return image }
        if monsterBarTintColor != nil { return nil }
        return UINavigationBar.appearance().backgroundImage(for: .default)
    }

    var monsterComputedBarTintColor: UIColor? {
        if monsterBarHidden { return .clear }
        if monsterBarImage != nil { return nil }
        if let tint = monsterBarTintColor { return tint }
        if UINavigationBar.appearance().backgroundImage(for: .default) != nil { return nil }
        if let appearanceTint = UINavigationBar.appearance().barTintColor { return appearanceTint }
        return monsterBarStyle == .default
            ? UIColor(red: 247 / 255, green: 247 / 255, blue: 247 / 255, alpha: 0.8)
            : UIColor(red: 28 / 255, green: 28 / 255, blue: 28 / 255, alpha: 0.729)
    }

    var monsterEffectiveTintColor: UIColor {
        monsterTintColor ?? .black
    }

    var monsterEffectiveTitleTextAttributes: [NSAttributedString.Key: Any] {
        var attributes = monsterStoredTitleTextAttributes
            ?? UINavigationBar.appearance().titleTextAttributes
            ?? [:]
        if attributes[.foregroundColor] == nil {
            attributes[.foregroundColor] = monsterBarStyle == .black ? UIColor.white : UIColor.black
        }
        return attributes
    }

    /// Applies the page-level button style to all caller-supplied navigation items.
    internal func monsterApplyLiquidGlassBarButtonStyle() {
        guard #available(iOS 26.0, *) else { return }

        var items = navigationItem.leftBarButtonItems ?? []
        items.append(contentsOf: navigationItem.rightBarButtonItems ?? [])
        if let backItem = navigationItem.backBarButtonItem {
            items.append(backItem)
        }

        if #available(iOS 16.0, *) {
            var groups = navigationItem.leadingItemGroups
                + navigationItem.centerItemGroups
                + navigationItem.trailingItemGroups
            if let pinnedGroup = navigationItem.pinnedTrailingGroup {
                groups.append(pinnedGroup)
            }
            for group in groups {
                items.append(contentsOf: group.barButtonItems)
                if let representativeItem = group.representativeItem {
                    items.append(representativeItem)
                }
            }
        }

        let hidesSharedBackground = !monsterLiquidGlassBarButtonEnabled
        items.forEach { $0.hidesSharedBackground = hidesSharedBackground }
    }

    var monster_computedBarShadowAlpha: CGFloat { monsterComputedBarShadowAlpha }
    var monster_computedBarTintColor: UIColor? { monsterComputedBarTintColor }
    var monster_computedBarImage: UIImage? { monsterComputedBarImage }

    /// Re-applies this controller's current values when a scroll view changes bar alpha.
    func monsterSetNeedsUpdateNavigationBar() {
        guard let navigationController = navigationController as? MonsterNavigationController,
              navigationController.topViewController === self else { return }
        navigationController.updateNavigationBar(for: self)
        navigationController.setNeedsStatusBarAppearanceUpdate()
    }

    func monster_setNeedsUpdateNavigationBar() {
        monsterSetNeedsUpdateNavigationBar()
    }

    // Source-compatible aliases for the Objective-C library's property spelling.
    var monster_barStyle: UIBarStyle { get { monsterBarStyle } set { monsterBarStyle = newValue } }
    var monster_blackBarStyle: Bool { get { monsterBlackBarStyle } set { monsterBlackBarStyle = newValue } }
    var monster_barTintColor: UIColor? { get { monsterBarTintColor } set { monsterBarTintColor = newValue } }
    var monster_barImage: UIImage? { get { monsterBarImage } set { monsterBarImage = newValue } }
    var monster_tintColor: UIColor? { get { monsterTintColor } set { monsterTintColor = newValue } }
    var monster_titleTextAttributes: [NSAttributedString.Key: Any]? {
        get { monsterTitleTextAttributes }
        set { objc_setAssociatedObject(self, &monsterTitleTextAttributesKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }
    var monster_barAlpha: CGFloat { get { monsterBarAlpha } set { monsterBarAlpha = newValue } }
    var monster_barHidden: Bool { get { monsterBarHidden } set { monsterBarHidden = newValue } }
    var monster_barShadowHidden: Bool { get { monsterBarShadowHidden } set { monsterBarShadowHidden = newValue } }
    var monster_backInteractive: Bool { get { monsterBackInteractive } set { monsterBackInteractive = newValue } }
    var monster_swipeBackEnabled: Bool { get { monsterSwipeBackEnabled } set { monsterSwipeBackEnabled = newValue } }
    var monster_clickBackEnabled: Bool { get { monsterClickBackEnabled } set { monsterClickBackEnabled = newValue } }
    var monster_splitNavigationBarTransition: Bool { get { monsterSplitNavigationBarTransition } set { monsterSplitNavigationBarTransition = newValue } }
    var monster_liquidGlassBarButtonEnabled: Bool { get { monsterLiquidGlassBarButtonEnabled } set { monsterLiquidGlassBarButtonEnabled = newValue } }
    var monster_extendedLayoutDidSet: Bool { get { monsterExtendedLayoutDidSet } set { monsterExtendedLayoutDidSet = newValue } }
    var monster_backBarButtonItem: UIBarButtonItem? { get { monsterBackBarButtonItem } set { monsterBackBarButtonItem = newValue } }
}
