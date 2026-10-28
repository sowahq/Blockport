#if targetEnvironment(macCatalyst)
import CMacDisplay
import UIKit

/// Captures the cursor whenever the game asks for pointer lock.
///
/// The game reads mouse movement from `GCMouse` and requests capture through
/// `prefersPointerLocked`, which Catalyst does not enforce for a windowed
/// app: the cursor keeps moving and leaves the window. The runtime follows
/// the game's requests and locks the cursor itself, releasing it while
/// another application is active.
@MainActor
enum PointerLock {
    private static var requested = false
    private static var locked = false
    /// The game asks for a pointer-lock update on every mouse move, and
    /// UIKit re-resolves the scene's lock state each time. Only changes are
    /// forwarded, plus a periodic refresh.
    private static let refreshInterval: CFTimeInterval = 0.5
    private static var lastForwarded: CFTimeInterval = 0

    static func install() {
        typealias Update = @convention(c) (UIViewController, Selector) -> Void
        let selector = #selector(UIViewController.setNeedsUpdateOfPrefersPointerLocked)
        var original: Update?
        let replacement: @convention(block) (UIViewController) -> Void = { controller in
            MainActor.assumeIsolated {
                let wanted = controller.prefersPointerLocked
                let now = CACurrentMediaTime()
                guard wanted != requested || now - lastForwarded >= refreshInterval else { return }
                requested = wanted
                lastForwarded = now
                original?(controller, selector)
                apply()
            }
        }
        original = MethodReplacement.replace(selector, on: UIViewController.self, with: replacement)
            .map { unsafeBitCast($0, to: Update.self) }

        let center = NotificationCenter.default
        for name in [UIApplication.didBecomeActiveNotification, UIApplication.willResignActiveNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { apply() }
            }
        }
    }

    private static func apply() {
        let shouldLock = requested && UIApplication.shared.applicationState == .active
        guard shouldLock != locked else { return }
        locked = shouldLock
        let display = BlockportMainDisplay()
        if shouldLock {
            if let center = AppKitBridge.keyWindowCenter() {
                BlockportWarpCursor(center)
            }
            BlockportAssociateMouseAndCursor(0)
            BlockportHideCursor(display)
        } else {
            BlockportAssociateMouseAndCursor(1)
            BlockportShowCursor(display)
        }
        Trace.event("input", "pointer \(shouldLock ? "locked" : "released")")
    }
}
#endif
