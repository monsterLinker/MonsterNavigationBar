import UIKit

public extension UINavigationController {
    /// Replaces the stack from the target controller onward with `controller`.
    func redirect(to controller: UIViewController, animated: Bool) {
        redirect(to: controller, target: topViewController, animated: animated)
    }

    /// Replaces the stack from `target` onward with `controller`.
    func redirect(to controller: UIViewController, target: UIViewController?, animated: Bool) {
        var children = viewControllers
        let index = target.flatMap { targetController in
            children.firstIndex { $0 === targetController }
        } ?? children.indices.last
        guard let index else { return }
        children.removeSubrange(index..<children.count)
        children.append(controller)
        if children.count > 1 {
            controller.hidesBottomBarWhenPushed = hidesBottomBarWhenPushed
        }
        setViewControllers(children, animated: animated)
    }

    // Source-compatible Objective-C spellings.
    func redirectToViewController(_ controller: UIViewController, animated: Bool) {
        redirect(to: controller, animated: animated)
    }

    func redirectToViewController(_ controller: UIViewController, target: UIViewController, animated: Bool) {
        redirect(to: controller, target: target, animated: animated)
    }
}
