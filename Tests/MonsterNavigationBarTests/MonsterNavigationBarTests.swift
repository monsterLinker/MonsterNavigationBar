import XCTest
import UIKit
@testable import MonsterNavigationBar

final class MonsterNavigationBarTests: XCTestCase {
    func testControllerDefaultsAndComputedBackground() {
        let controller = UIViewController()

        XCTAssertEqual(controller.monsterBarAlpha, 1)
        XCTAssertFalse(controller.monsterBarHidden)
        XCTAssertTrue(controller.monsterBackInteractive)
        XCTAssertTrue(controller.monsterSwipeBackEnabled)
        XCTAssertTrue(controller.monsterClickBackEnabled)
        XCTAssertFalse(controller.monsterLiquidGlassBarButtonEnabled)
        XCTAssertEqual(controller.monsterTintColor, UINavigationBar.appearance().tintColor ?? .black)
        XCTAssertNotNil(controller.monsterTitleTextAttributes[.foregroundColor])
        XCTAssertNotNil(controller.monsterComputedBarTintColor)
        XCTAssertNil(controller.monsterComputedBarImage)
    }

    func testImageTakesPriorityOverColorAndHiddenClearsColor() {
        let controller = UIViewController()
        controller.monsterBarTintColor = .red
        XCTAssertNil(controller.monsterComputedBarImage)
        XCTAssertEqual(controller.monsterComputedBarTintColor, .red)

        controller.monsterBarImage = UIImage()
        XCTAssertNotNil(controller.monsterComputedBarImage)
        XCTAssertNil(controller.monsterComputedBarTintColor)

        controller.monsterBarHidden = true
        XCTAssertEqual(controller.monsterBarAlpha, 0)
        XCTAssertEqual(controller.monsterComputedBarTintColor, .clear)
        XCTAssertEqual(controller.monsterComputedBarShadowAlpha, 0)
    }

    func testVisibleNavigationBarAppliesConfiguredColorAndImageLayers() throws {
        let root = UIViewController()
        root.monsterBarTintColor = .systemRed
        let navigationController = MonsterNavigationController(rootViewController: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        navigationController.view.layoutIfNeeded()

        let bar = try XCTUnwrap(navigationController.navigationBar as? MonsterNavigationBar)
        XCTAssertEqual(bar.barTintColor, .systemRed)
        XCTAssertEqual(bar.fakeView.contentView.backgroundColor, .systemRed)
        XCTAssertEqual(bar.fakeView.alpha, 1, accuracy: 0.001)
        XCTAssertNil(bar.backgroundImageView.image)
        XCTAssertTrue(bar.fakeView.superview === bar.monsterBackgroundView)
        let colorIndex = try XCTUnwrap(bar.monsterBackgroundView?.subviews.firstIndex { $0 === bar.monsterColorOverlayView })
        let fakeIndex = try XCTUnwrap(bar.monsterBackgroundView?.subviews.firstIndex { $0 === bar.fakeView })
        XCTAssertGreaterThan(colorIndex, fakeIndex)

        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        root.monsterBarImage = image
        root.monsterSetNeedsUpdateNavigationBar()
        XCTAssertTrue(bar.backgroundImageView.image === image)
        XCTAssertEqual(bar.backgroundImageView.alpha, 1, accuracy: 0.001)
        XCTAssertEqual(bar.fakeView.alpha, 0, accuracy: 0.001)
        XCTAssertTrue(bar.backgroundImageView.superview === bar.monsterBackgroundView)
    }

    func testRedirectReplacesStackFromTarget() {
        let first = UIViewController()
        let second = UIViewController()
        let third = UIViewController()
        let replacement = UIViewController()
        let navigation = UINavigationController(rootViewController: first)
        navigation.setViewControllers([first, second, third], animated: false)

        navigation.redirect(to: replacement, target: second, animated: false)

        XCTAssertEqual(navigation.viewControllers.count, 2)
        XCTAssertTrue(navigation.viewControllers[0] === first)
        XCTAssertTrue(navigation.viewControllers[1] === replacement)
    }

    #if compiler(>=6.2)
    func testLiquidGlassBarButtonStyleUpdatesExistingItemsAndGroups() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Liquid Glass navigation buttons require iOS 26")
        }

        let controller = UIViewController()
        let leftItem = UIBarButtonItem(title: "Left")
        let rightItem = UIBarButtonItem(title: "Right")
        let backItem = UIBarButtonItem(title: "Back")
        let groupItem = UIBarButtonItem(title: "Group")
        let representativeItem = UIBarButtonItem(title: "More")
        let pinnedItem = UIBarButtonItem(title: "Pinned")
        controller.navigationItem.leftBarButtonItem = leftItem
        controller.navigationItem.rightBarButtonItem = rightItem
        controller.navigationItem.backBarButtonItem = backItem
        controller.navigationItem.centerItemGroups = [
            UIBarButtonItemGroup(
                barButtonItems: [groupItem],
                representativeItem: representativeItem
            )
        ]
        controller.navigationItem.pinnedTrailingGroup = UIBarButtonItemGroup(
            barButtonItems: [pinnedItem],
            representativeItem: nil
        )

        controller.monsterLiquidGlassBarButtonEnabled = false
        XCTAssertTrue(leftItem.hidesSharedBackground)
        XCTAssertTrue(rightItem.hidesSharedBackground)
        XCTAssertTrue(backItem.hidesSharedBackground)
        XCTAssertTrue(groupItem.hidesSharedBackground)
        XCTAssertTrue(representativeItem.hidesSharedBackground)
        XCTAssertTrue(pinnedItem.hidesSharedBackground)

        controller.monsterLiquidGlassBarButtonEnabled = true
        XCTAssertFalse(leftItem.hidesSharedBackground)
        XCTAssertFalse(rightItem.hidesSharedBackground)
        XCTAssertFalse(backItem.hidesSharedBackground)
        XCTAssertFalse(groupItem.hidesSharedBackground)
        XCTAssertFalse(representativeItem.hidesSharedBackground)
        XCTAssertFalse(pinnedItem.hidesSharedBackground)
    }

    func testNavigationControllerAppliesLiquidGlassStyleToItemsAddedLater() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Liquid Glass navigation buttons require iOS 26")
        }

        let controller = UIViewController()
        controller.monsterLiquidGlassBarButtonEnabled = false
        let item = UIBarButtonItem(title: "Later")
        controller.navigationItem.rightBarButtonItem = item
        let navigationController = MonsterNavigationController(rootViewController: controller)
        navigationController.loadViewIfNeeded()

        navigationController.updateNavigationBar(for: controller)

        XCTAssertTrue(item.hidesSharedBackground)
    }

    func testLiquidGlassStyleUpdatesVisibleSystemBackItem() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Liquid Glass navigation buttons require iOS 26")
        }

        let root = UIViewController()
        root.title = "Root"
        let detail = UIViewController()
        detail.monsterLiquidGlassBarButtonEnabled = false
        let navigationController = MonsterNavigationController(rootViewController: root)
        navigationController.pushViewController(detail, animated: false)

        let backItem = try XCTUnwrap(detail.navigationItem.leftBarButtonItem)
        XCTAssertTrue(backItem === detail.monsterManagedBackBarButtonItem)
        XCTAssertEqual(backItem.title, "Root")
        let button = try XCTUnwrap(backItem.customView as? UIButton)
        XCTAssertEqual(button.configuration?.title, "Root")
        XCTAssertTrue(backItem.hidesSharedBackground)
        XCTAssertTrue(button.allTargets.contains { ($0 as AnyObject) === navigationController })
        XCTAssertTrue(button.actions(forTarget: navigationController, forControlEvent: .touchUpInside)?.contains("handleManagedBackButton") == true)

        detail.monsterLiquidGlassBarButtonEnabled = true
        XCTAssertFalse(backItem.hidesSharedBackground)

        detail.monsterClickBackEnabled = false
        navigationController.perform(NSSelectorFromString("handleManagedBackButton"))
        XCTAssertTrue(navigationController.topViewController === detail)

        detail.monsterClickBackEnabled = true
        navigationController.perform(NSSelectorFromString("handleManagedBackButton"))
        XCTAssertTrue(navigationController.topViewController === root)
    }

    func testSetViewControllersPreparesSystemBackItemStyle() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Liquid Glass navigation buttons require iOS 26")
        }

        let root = UIViewController()
        let detail = UIViewController()
        detail.monsterLiquidGlassBarButtonEnabled = false
        let navigationController = MonsterNavigationController()

        navigationController.setViewControllers([root, detail], animated: false)

        let backItem = try XCTUnwrap(detail.navigationItem.leftBarButtonItem)
        XCTAssertTrue(backItem === detail.monsterManagedBackBarButtonItem)
        XCTAssertTrue(backItem.hidesSharedBackground)
    }
    #endif
}
