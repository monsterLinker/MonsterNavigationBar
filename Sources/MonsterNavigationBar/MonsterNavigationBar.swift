import UIKit
import ObjectiveC.runtime

/// A UINavigationBar whose background, shadow and translucency can be changed
/// independently while a navigation controller is transitioning.
open class MonsterNavigationBar: UINavigationBar {
    private weak var overlayContainerReference: UIView?
    private var storedBarTintColor: UIColor?
    /// The layer used for the one-pixel shadow below the bar.
    public private(set) lazy var shadowImageView: UIImageView = {
        let view = UIImageView()
        view.isUserInteractionEnabled = false
        view.contentScaleFactor = 1
        view.layer.allowsEdgeAntialiasing = true
        return view
    }()

    /// The blur layer used when a controller supplies a color background.
    public private(set) lazy var fakeView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        view.isUserInteractionEnabled = false
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }()

    /// The image layer used when a controller supplies a background image.
    public private(set) lazy var backgroundImageView: UIImageView = {
        let view = UIImageView()
        view.isUserInteractionEnabled = false
        view.contentScaleFactor = 1
        view.contentMode = .scaleToFill
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }()

    /// The title label in the system back button, when UIKit exposes one.
    public var backButtonLabel: UILabel? {
        let candidates = allSubviews(in: self).reversed()
        for candidate in candidates {
            let className = String(describing: type(of: candidate))
            if className.contains("UIButtonBarButton"),
               let label = allSubviews(in: candidate).compactMap({ $0 as? UILabel }).first {
                return label
            }
        }
        return allSubviews(in: self).compactMap { $0 as? UILabel }.last
    }

    /// UIKit's private background container, if it is available on this OS.
    public var monsterBackgroundView: UIView? {
        allSubviews(in: self).first { view in
            let name = String(describing: type(of: view))
            return name.contains("BarBackground") || name.contains("NavigationBarBackground")
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureOverlayViews()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureOverlayViews()
    }

    /// MonsterNavigationBar is always translucent; changing this value is ignored.
    open override var isTranslucent: Bool {
        get { true }
        set { /* The bar must stay translucent for transitions. */ }
    }

    /// Keeps UIKit's barTintColor API usable while routing the color into the blur layer.
    open override var barTintColor: UIColor? {
        get { storedBarTintColor ?? super.barTintColor }
        set {
            storedBarTintColor = newValue
            ensureOverlayViews()
            fakeView.contentView.backgroundColor = newValue
            fakeView.subviews.last?.backgroundColor = newValue
        }
    }

    /// Keeps the public UINavigationBar shadowImage API in sync with the transition layer.
    open override var shadowImage: UIImage? {
        get { shadowImageView.image }
        set {
            ensureOverlayViews()
            shadowImageView.image = newValue
            shadowImageView.backgroundColor = newValue == nil
                ? UIColor(white: 0, alpha: 77.0 / 255.0)
                : nil
        }
    }

    open override func setBackgroundImage(_ backgroundImage: UIImage?, for barMetrics: UIBarMetrics) {
        ensureOverlayViews()
        backgroundImageView.image = backgroundImage
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        ensureOverlayViews()
        let container = overlayContainer
        fakeView.frame = container.bounds
        backgroundImageView.frame = container.bounds
        let hairline = MonsterNavigationBar.hairlineWidth(for: self)
        shadowImageView.frame = CGRect(
            x: 0,
            y: max(0, container.bounds.height - hairline),
            width: container.bounds.width,
            height: hairline
        )
    }

    /// Hides only the navigation bar's content. The bar itself remains in the hierarchy,
    /// which is what makes a hidden-to-visible transition continuous.
    public func monsterSetContentHidden(_ hidden: Bool) {
        contentView?.alpha = hidden ? 0 : 1
    }

    /// Source-compatible spelling for the Objective-C API.
    public func monster_setContentHidden(_ hidden: Bool) {
        monsterSetContentHidden(hidden)
    }

    /// Source-compatible spelling for the Objective-C background container property.
    public var monster_backgroundView: UIView? {
        monsterBackgroundView
    }

    private var overlayContainer: UIView {
        if let overlayContainerReference { return overlayContainerReference }
        return subviews.first(where: { view in
            view !== fakeView && view !== backgroundImageView && view !== shadowImageView
        }) ?? self
    }

    private var contentView: UIView? {
        if let value = allSubviews(in: self).first(where: {
            String(describing: type(of: $0)).contains("NavigationBarContentView")
        }) {
            return value
        }
        return allSubviews(in: self).first(where: {
            String(describing: type(of: $0)).contains("ContentView")
        })
    }

    private func configureOverlayViews() {
        overlayContainerReference = subviews.first
        ensureOverlayViews()
        // Prevent UIKit from inserting its own background and shadow layers.
        super.setBackgroundImage(UIImage(), for: .default)
        super.shadowImage = UIImage()
    }

    private func ensureOverlayViews() {
        if let reference = overlayContainerReference, reference !== self, reference.superview !== self {
            overlayContainerReference = nil
        }
        if overlayContainerReference == nil {
            overlayContainerReference = subviews.first(where: { view in
                view !== fakeView && view !== backgroundImageView && view !== shadowImageView
            })
        }
        let container = overlayContainer
        if fakeView.superview !== container {
            fakeView.removeFromSuperview()
            container.insertSubview(fakeView, at: 0)
        }
        if backgroundImageView.superview !== container {
            backgroundImageView.removeFromSuperview()
            container.insertSubview(backgroundImageView, aboveSubview: fakeView)
        }
        if shadowImageView.superview !== container {
            shadowImageView.removeFromSuperview()
            container.insertSubview(shadowImageView, aboveSubview: backgroundImageView)
        }
    }

    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha >= 0.01 else { return nil }
        guard let hit = super.hitTest(point, with: event) else { return nil }
        let name = String(describing: type(of: hit)).replacingOccurrences(of: "_", with: "")
        let contentNames = ["UINavigationBarContentView", "UIButtonBarStackView", "UIKit.NavigationBarContentView", String(describing: type(of: self))]
        if contentNames.contains(name) {
            let backgroundAlpha = backgroundImageView.image == nil ? fakeView.alpha : backgroundImageView.alpha
            if backgroundAlpha < 0.01 { return nil }
        }
        return hit
    }

    private static func hairlineWidth(for view: UIView) -> CGFloat {
        let scale = view.window?.screen.scale ?? view.traitCollection.displayScale
        return scale > 0 ? 1 / scale : 1
    }

    private func allSubviews(in view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap { allSubviews(in: $0) }
    }
}

private var monsterSpecifiedTextColorKey: UInt8 = 0

public extension UILabel {
    /// A temporary color used by the navigation transition when UIKit rebuilds title labels.
    var monsterSpecifiedTextColor: UIColor? {
        get {
            _ = UILabel.installMonsterAttributedTextSwizzle
            return objc_getAssociatedObject(self, &monsterSpecifiedTextColorKey) as? UIColor
        }
        set {
            _ = UILabel.installMonsterAttributedTextSwizzle
            objc_setAssociatedObject(self, &monsterSpecifiedTextColorKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    var monster_specifiedTextColor: UIColor? {
        get { monsterSpecifiedTextColor }
        set { monsterSpecifiedTextColor = newValue }
    }

    private static let installMonsterAttributedTextSwizzle: Void = {
        let originalSelector = NSSelectorFromString("setAttributedText:")
        let swizzledSelector = #selector(UILabel.monster_setAttributedText(_:))
        guard let original = class_getInstanceMethod(UILabel.self, originalSelector),
              let swizzled = class_getInstanceMethod(UILabel.self, swizzledSelector) else { return }
        method_exchangeImplementations(original, swizzled)
    }()

    @objc private func monster_setAttributedText(_ attributedText: NSAttributedString?) {
        var value = attributedText
        if let color = monsterSpecifiedTextColor, let attributedText {
            let mutable = NSMutableAttributedString(attributedString: attributedText)
            mutable.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: mutable.length))
            value = mutable
        }
        monster_setAttributedText(value)
    }
}
