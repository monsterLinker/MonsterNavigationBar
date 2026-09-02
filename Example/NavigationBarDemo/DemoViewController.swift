import UIKit
import MonsterNavigationBar

/// The main playground mirrors the controls from the upstream Objective-C demo.
final class DemoViewController: UIViewController {
    private let shadowHiddenSwitch = UISwitch()
    private let barHiddenSwitch = UISwitch()
    private let blackStyleSwitch = UISwitch()
    private let colorSegment = UISegmentedControl(items: ["White", "Black", "Red", "Green", "Blue"])
    private let alphaSlider = UISlider()
    private let alphaComponent = UILabel()
    private let imageSwitch = UISwitch()
    private let swipeBackSwitch = UISwitch()
    private let statusLabel = UILabel()

    private let configuredBarColor: UIColor?
    private let configuredBarStyle: UIBarStyle?
    private let configuredBarAlpha: CGFloat?
    private let configuredBarHidden: Bool?
    private let configuredShadowHidden: Bool?
    private let configuredBarImage: UIImage?

    init(
        barColor: UIColor? = nil,
        barStyle: UIBarStyle? = nil,
        barAlpha: CGFloat? = nil,
        barHidden: Bool? = nil,
        shadowHidden: Bool? = nil,
        barImage: UIImage? = nil
    ) {
        configuredBarColor = barColor
        configuredBarStyle = barStyle
        configuredBarAlpha = barAlpha
        configuredBarHidden = barHidden
        configuredShadowHidden = shadowHidden
        configuredBarImage = barImage
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        configuredBarColor = nil
        configuredBarStyle = nil
        configuredBarAlpha = nil
        configuredBarHidden = nil
        configuredShadowHidden = nil
        configuredBarImage = nil
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = navigationController?.viewControllers.count == 1 ? "Monster Navigation Bar" : "Demo \(navigationController?.viewControllers.count ?? 0)"
        view.backgroundColor = .systemGroupedBackground
        applyConfiguredNavigationBar()
        configureNavigationItem()
        configureContent()
        refreshControls()
    }

    private func applyConfiguredNavigationBar() {
        monsterBarStyle = configuredBarStyle ?? .default
        monsterBarTintColor = configuredBarColor ?? UIColor.white.withAlphaComponent(0.8)
        monsterTintColor = monsterBarStyle == .black ? .white : .black
        monsterBarAlpha = configuredBarAlpha ?? 1
        monsterBarHidden = configuredBarHidden ?? false
        monsterBarShadowHidden = configuredShadowHidden ?? false
        monsterBarImage = configuredBarImage
        monsterTitleTextAttributes = [.foregroundColor: monsterTintColor ?? .black]
    }

    private func configureNavigationItem() {
        if navigationController?.viewControllers.count == 1 {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Next",
                style: .plain,
                target: self,
                action: #selector(pushToNext)
            )
        }
    }

    private func configureContent() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let heading = UILabel()
        heading.text = "Navigation bar transitions"
        heading.font = .preferredFont(forTextStyle: .title2)
        heading.textColor = .label
        stack.addArrangedSubview(heading)

        let description = UILabel()
        description.text = "这些控件对应上游 Demo 的样式和转场测试。设置后 push 或滚动页面观察导航栏变化。"
        description.font = .preferredFont(forTextStyle: .subheadline)
        description.textColor = .secondaryLabel
        description.numberOfLines = 0
        stack.addArrangedSubview(description)

        stack.addArrangedSubview(makeButton(title: "Push To Next", color: .systemBlue, action: #selector(pushToNext)))
        stack.addArrangedSubview(makeButton(title: "Dynamic Gradient", color: .systemOrange, action: #selector(pushDynamicGradient)))
        stack.addArrangedSubview(makeButton(title: "Present Gradient", color: .systemGreen, action: #selector(presentGradient)))
        stack.addArrangedSubview(makeButton(title: "Dismiss", color: .systemGreen, action: #selector(dismissPresented)))
        stack.addArrangedSubview(makeButton(title: "Stack Operations", color: .systemPurple, action: #selector(pushStackOperations)))

        stack.addArrangedSubview(makeSwitchRow(title: "Shadow Hidden", control: shadowHiddenSwitch, action: #selector(shadowHiddenChanged)))
        stack.addArrangedSubview(makeSwitchRow(title: "Bar Hidden", control: barHiddenSwitch, action: #selector(barHiddenChanged)))
        stack.addArrangedSubview(makeSwitchRow(title: "Black Bar Style", control: blackStyleSwitch, action: #selector(blackStyleChanged)))
        stack.addArrangedSubview(makeSwitchRow(title: "Image Background", control: imageSwitch, action: #selector(imageChanged)))
        stack.addArrangedSubview(makeSwitchRow(title: "Swipe Back Enabled", control: swipeBackSwitch, action: #selector(swipeBackChanged)))

        let colorLabel = UILabel()
        colorLabel.text = "Bar Tint Color"
        colorLabel.font = .preferredFont(forTextStyle: .body)
        stack.addArrangedSubview(colorLabel)
        colorSegment.selectedSegmentIndex = 0
        colorSegment.addTarget(self, action: #selector(colorChanged), for: .valueChanged)
        stack.addArrangedSubview(colorSegment)

        let alphaRow = UIStackView()
        alphaRow.axis = .horizontal
        alphaRow.alignment = .center
        alphaRow.spacing = 10
        let alphaLabel = UILabel()
        alphaLabel.text = "Bar Alpha"
        alphaLabel.font = .preferredFont(forTextStyle: .body)
        alphaSlider.minimumValue = 0
        alphaSlider.maximumValue = 1
        alphaSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        alphaComponent.widthAnchor.constraint(equalToConstant: 48).isActive = true
        alphaComponent.textAlignment = .right
        alphaRow.addArrangedSubview(alphaLabel)
        alphaRow.addArrangedSubview(alphaSlider)
        alphaRow.addArrangedSubview(alphaComponent)
        stack.addArrangedSubview(alphaRow)

        let statusTitle = UILabel()
        statusTitle.text = "Current values"
        statusTitle.font = .preferredFont(forTextStyle: .headline)
        stack.addArrangedSubview(statusTitle)
        statusLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        stack.addArrangedSubview(statusLabel)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }

    private func refreshControls() {
        shadowHiddenSwitch.isOn = monsterBarShadowHidden
        barHiddenSwitch.isOn = monsterBarHidden
        blackStyleSwitch.isOn = monsterBarStyle == .black
        imageSwitch.isOn = monsterBarImage != nil
        swipeBackSwitch.isOn = monsterSwipeBackEnabled
        alphaSlider.value = Float(monsterBarAlpha)
        alphaComponent.text = String(format: "%.2f", monsterBarAlpha)
        statusLabel.text = "style: \(monsterBarStyle == .black ? "black" : "default")\n" +
            "alpha: \(String(format: "%.2f", monsterBarAlpha))\n" +
            "bar hidden: \(monsterBarHidden)\n" +
            "shadow hidden: \(monsterBarShadowHidden)\n" +
            "image: \(monsterBarImage != nil)\n" +
            "swipe back: \(monsterSwipeBackEnabled)"
    }

    private func makeButton(title: String, color: UIColor, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = color
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 11, left: 16, bottom: 11, right: 16)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeSwitchRow(title: String, control: UISwitch, action: Selector) -> UIStackView {
        let label = UILabel()
        label.text = title
        label.font = .preferredFont(forTextStyle: .body)
        control.addTarget(self, action: action, for: .valueChanged)
        let row = UIStackView(arrangedSubviews: [label, control])
        row.alignment = .center
        row.distribution = .fill
        return row
    }

    private func selectedColor() -> UIColor {
        switch colorSegment.selectedSegmentIndex {
        case 1: return UIColor(white: 0.11, alpha: 0.729)
        case 2: return UIColor.systemRed.withAlphaComponent(0.7)
        case 3: return UIColor.systemGreen.withAlphaComponent(0.7)
        case 4: return UIColor.systemBlue.withAlphaComponent(0.8)
        default: return UIColor(white: 0.97, alpha: 0.8)
        }
    }

    private func applyCurrentBarConfiguration() {
        monsterBarStyle = blackStyleSwitch.isOn ? .black : .default
        monsterBarTintColor = selectedColor()
        monsterTintColor = blackStyleSwitch.isOn ? .white : .black
        monsterTitleTextAttributes = [.foregroundColor: monsterTintColor ?? .black]
        monsterBarHidden = barHiddenSwitch.isOn
        monsterBarShadowHidden = shadowHiddenSwitch.isOn
        monsterBarImage = imageSwitch.isOn ? makeBarImage() : nil
        monsterBarAlpha = CGFloat(alphaSlider.value)
        monsterSetNeedsUpdateNavigationBar()
        refreshControls()
    }

    @objc private func sliderValueChanged() { applyCurrentBarConfiguration() }
    @objc private func shadowHiddenChanged() { applyCurrentBarConfiguration() }
    @objc private func barHiddenChanged() { applyCurrentBarConfiguration() }
    @objc private func blackStyleChanged() { applyCurrentBarConfiguration() }
    @objc private func colorChanged() { applyCurrentBarConfiguration() }
    @objc private func imageChanged() { applyCurrentBarConfiguration() }

    @objc private func swipeBackChanged() {
        monsterSwipeBackEnabled = swipeBackSwitch.isOn
        refreshControls()
    }

    @objc private func pushToNext() {
        let next = DemoViewController(
            barColor: selectedColor(),
            barStyle: blackStyleSwitch.isOn ? .black : .default,
            barAlpha: CGFloat(alphaSlider.value),
            barHidden: barHiddenSwitch.isOn,
            shadowHidden: shadowHiddenSwitch.isOn,
            barImage: imageSwitch.isOn ? makeBarImage() : nil
        )
        next.monsterSwipeBackEnabled = swipeBackSwitch.isOn
        navigationController?.pushViewController(next, animated: true)
    }

    @objc private func pushDynamicGradient() {
        navigationController?.pushViewController(GradientDemoViewController(), animated: true)
    }

    @objc private func presentGradient() {
        let gradient = GradientDemoViewController()
        let nav = MonsterNavigationController(rootViewController: gradient)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func pushStackOperations() {
        navigationController?.pushViewController(DetailViewController(), animated: true)
    }

    @objc private func dismissPresented() {
        guard presentingViewController != nil else { return }
        dismiss(animated: true)
    }

    private func makeBarImage() -> UIImage {
        let size = CGSize(width: 600, height: 120)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: size.width * 0.5, y: 0, width: size.width * 0.5, height: size.height))
        }
    }
}

/// Exercises changing every per-controller value while a push/pop is running.
final class DetailViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Contrasting page"
        view.backgroundColor = .systemBackground
        monsterBarTintColor = UIColor.systemPink.withAlphaComponent(0.88)
        monsterTintColor = .white
        monsterBlackBarStyle = true
        monsterBarShadowHidden = true
        monsterSplitNavigationBarTransition = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let label = UILabel()
        label.text = "向右边缘侧滑返回，观察粉色和前一页背景的连续过渡。"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        stack.addArrangedSubview(label)

        let popButton = UIButton(type: .system)
        popButton.setTitle("Pop To Root", for: .normal)
        popButton.addTarget(self, action: #selector(popToRoot), for: .touchUpInside)
        stack.addArrangedSubview(popButton)

        let redirectButton = UIButton(type: .system)
        redirectButton.setTitle("Redirect This Stack", for: .normal)
        redirectButton.addTarget(self, action: #selector(redirectStack), for: .touchUpInside)
        stack.addArrangedSubview(redirectButton)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func popToRoot() {
        navigationController?.popToRootViewController(animated: true)
    }

    @objc private func redirectStack() {
        navigationController?.redirect(to: DemoViewController(), target: self, animated: true)
    }
}

/// Matches the upstream dynamic-gradient table demo without requiring a bundled image.
final class GradientDemoViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let headerView = UIImageView(image: GradientDemoViewController.makeHeaderImage())
    private var gradientProgress: CGFloat = -1
    private var didSetInitialInset = false

    override func loadView() {
        view = tableView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Dynamic Gradient Bar"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.separatorStyle = .singleLine
        tableView.insertSubview(headerView, at: 0)
        headerView.clipsToBounds = true
        headerView.contentMode = .scaleAspectFill
        headerView.isUserInteractionEnabled = false

        monsterBarAlpha = 0
        monsterBarStyle = .black
        monsterTintColor = .white
        monsterTitleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0)]
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Close",
            style: .plain,
            target: self,
            action: #selector(close)
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let imageHeight = headerHeight
        if !didSetInitialInset {
            var inset = UIEdgeInsets.zero
            inset.top = imageHeight
            inset.bottom = view.safeAreaInsets.bottom
            tableView.contentInset = inset
            tableView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: inset.bottom, right: 0)
            tableView.contentOffset = CGPoint(x: 0, y: -imageHeight)
            didSetInitialInset = true
        }
        headerView.frame = headerImageFrame
    }

    private var headerHeight: CGFloat {
        let image = headerView.image ?? UIImage()
        guard image.size.width > 0 else { return view.bounds.width }
        return image.size.height / image.size.width * view.bounds.width
    }

    private var headerImageFrame: CGRect {
        let progress = tableView.contentOffset.y + tableView.contentInset.top
        var frame = view.bounds
        var height = headerHeight
        if progress < 0 { height += -progress }
        if progress > 0 { frame.origin.y -= progress }
        frame.size.height = height
        return frame
    }

    @objc private func close() {
        if presentingViewController != nil {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 16 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = "click me"
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 60 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(DemoViewController(), animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let headerHeight = max(1, self.headerHeight - view.safeAreaInsets.top)
        let progress = scrollView.contentOffset.y + scrollView.contentInset.top
        let normalized = min(1, max(0, progress / headerHeight))
        let nextProgress = normalized * normalized * normalized * normalized
        if abs(nextProgress - gradientProgress) > 0.0001 {
            gradientProgress = nextProgress
            if gradientProgress < 0.1 {
                monsterBarStyle = .black
                monsterTintColor = .white
                monsterTitleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0)]
            } else {
                monsterBarStyle = .default
                monsterTintColor = .black
                monsterTitleTextAttributes = [.foregroundColor: UIColor.black.withAlphaComponent(gradientProgress)]
            }
            monsterBarAlpha = gradientProgress
            monsterSetNeedsUpdateNavigationBar()
        }
        headerView.frame = headerImageFrame
    }

    private static func makeHeaderImage() -> UIImage {
        let size = CGSize(width: 900, height: 600)
        return UIGraphicsImageRenderer(size: size).image { context in
            let colors = [
                UIColor.systemOrange.cgColor,
                UIColor.systemPink.cgColor,
                UIColor.systemIndigo.cgColor
            ] as CFArray
            let locations: [CGFloat] = [0, 0.48, 1]
            let space = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: space, colors: colors, locations: locations)!
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
            UIColor.white.withAlphaComponent(0.18).setFill()
            for index in 0..<8 {
                let rect = CGRect(x: CGFloat(index) * 150 - 90, y: 90 + CGFloat(index % 3) * 100, width: 240, height: 80)
                context.cgContext.fillEllipse(in: rect)
            }
        }
    }
}
