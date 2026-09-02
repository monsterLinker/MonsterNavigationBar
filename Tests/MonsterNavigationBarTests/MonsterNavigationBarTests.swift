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
}
