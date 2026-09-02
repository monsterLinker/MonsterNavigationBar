# MonsterNavigationBar (Swift)

这是 [listenzz/HBDNavigationBar](https://github.com/listenzz/HBDNavigationBar) 的 Swift/UIKit 移植版，项目命名和公开 API。它解决的是导航控制器切换页面时导航栏状态突变的问题：背景颜色、背景图片、透明度、阴影、标题属性和按钮颜色都能在 push、pop 及交互式返回期间平滑过渡。

## 安装

将本仓库作为 Swift Package 添加到 Xcode，或在 `Package.swift` 中声明：

```swift
dependencies: [
    .package(url: "<your-repository-url>/MonsterNavigationBar.git", from: "1.0.0")
]
```

部署目标为 iOS 12 及以上。库不依赖第三方框架。

## 使用

```swift
import MonsterNavigationBar

let first = HomeViewController()
window?.rootViewController = MonsterNavigationController(rootViewController: first)
```

在页面中只设置与全局样式不同的属性：

```swift
final class DetailViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        monsterBarTintColor = UIColor(red: 0.08, green: 0.10, blue: 0.13, alpha: 0.86)
        monsterTintColor = .white
        monsterBlackBarStyle = true
        monsterBarShadowHidden = true
    }
}
```

## 运行 Demo

仓库包含一个可直接打开的 UIKit 示例工程：

```text
Example/NavigationBarDemo.xcodeproj
```

在 Xcode 中打开这个 `.xcodeproj`，选择 `NavigationBarDemo` scheme 和任意 iPhone Simulator，按 `Cmd + R` 运行即可。Demo 首页可以验证：

- push 到不同颜色的导航栏，并观察背景色、标题和按钮颜色的过渡；
- 调节导航栏透明度；
- 隐藏导航栏内容或阴影，切换黑色样式；
- 在白、黑、红、绿、蓝五种背景色之间切换，并切换图片背景；
- 开关侧滑返回，再从详情页边缘向右拖动返回；
- 打开 `Dynamic Gradient`，滚动表格观察导航栏透明度和标题颜色渐变；
- 打开 `Present Gradient` 测试模态导航控制器，打开 `Stack Operations` 测试 `popToRoot` 和 `redirect`。

也可以使用命令行只做编译检查（不需要签名）：

```bash
xcodebuild \
  -project Example/NavigationBarDemo.xcodeproj \
  -scheme NavigationBarDemo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/monster-demo-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

如果要通过命令行安装到已启动的模拟器，先在 Xcode 的 `Window > Devices and Simulators` 中创建并启动设备，再执行：

```bash
xcrun simctl install booted /tmp/monster-demo-derived/Build/Products/Debug-iphonesimulator/NavigationBarDemo.app
xcrun simctl launch booted com.example.NavigationBarDemo
```

可用配置包括 `monsterBarStyle`、`monsterBarTintColor`、`monsterBarImage`、`monsterTintColor`、`monsterTitleTextAttributes`、`monsterBarAlpha`、`monsterBarHidden`、`monsterBarShadowHidden`、`monsterBackInteractive`、`monsterSwipeBackEnabled`、`monsterClickBackEnabled` 和 `monsterSplitNavigationBarTransition`。源码同时保留了上游的下划线命名别名，例如 `monster_barAlpha`。

`monsterBarHidden` 只会让导航栏内容和背景透明，不会从视图层级移除导航栏，因此隐藏与显示仍可连续过渡。透明背景页面默认延伸到导航栏下方；需要在不透明背景上动态调低 `monsterBarAlpha` 时，设置 `extendedLayoutIncludesOpaqueBars = true`。

导航控制器仍可直接设置 `delegate`。内部会保留自己的转场协调器，并把 UIKit 的 delegate 回调转发给你；也可以直接使用公开的 `monsterDelegate` 属性。

当页面需要在返回前确认时，可以在导航控制器中覆盖 `shouldAllowBack(for:)`；返回 `false` 会同时拦截导航栏返回按钮和侧滑返回：

```swift
final class AppNavigationController: MonsterNavigationController {
    override func shouldAllowBack(for viewController: UIViewController) -> Bool {
        // 在这里显示确认 UI，并根据结果决定是否允许返回。
        return viewController.monsterBackInteractive
    }
}
```

如果需要全屏返回，可以复用 UIKit 系统侧滑 target。`MonsterNavigationController` 实现了 `handleNavigationTransition(_:)`，因此上游的全屏 pan 写法仍然适用：

```swift
let target = interactivePopGestureRecognizer?.delegate
let pan = UIPanGestureRecognizer(target: target, action: #selector(handleNavigationTransition(_:)))
pan.delegate = interactivePopGestureRecognizer?.delegate
view.addGestureRecognizer(pan)
interactivePopGestureRecognizer?.isEnabled = false
```

## 导航栈重定向

```swift
navigationController?.redirect(to: LoginViewController(), animated: true)
navigationController?.redirect(to: HomeViewController(), target: oldHome, animated: false)
```

## 迁移说明

- `MonsterNavigationBar` 始终保持 `isTranslucent == true`，这是平滑过渡所必需的。
- 背景计算优先级与上游一致：页面图片、页面颜色、全局图片、全局颜色、按 `barStyle` 推导的默认颜色。
- `monsterSetNeedsUpdateNavigationBar()` 用于滚动时动态修改 `monsterBarAlpha` 等值。
- 上游依赖 UIKit 私有视图来获得内容层；本移植版通过视图树查找同名容器，并在找不到时保持安全降级。
