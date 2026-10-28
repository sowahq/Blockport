#if targetEnvironment(macCatalyst)
import BlockportShared
import UIKit

/// Makes the game window resizable at the game's aspect ratio, and enters
/// full screen when asked.
///
/// The game declares `UIRequiresFullScreen` and no scene manifest, so
/// Catalyst gives it a fixed iPad-sized window and posts no scene
/// notifications the runtime could wait for. The window is found by polling
/// the main queue, which starts running once `UIApplicationMain` does.
@MainActor
enum WindowFitting {
    private static let minimumSize = CGSize(width: 640, height: 360)
    private static let fullScreenPrimaryBehavior: UInt = 1 << 7
    private static let fullScreenStyle: UInt = 1 << 14
    private static let initialScreenFraction: CGFloat = 0.85
    private static let pollInterval: TimeInterval = 0.25
    private static let maximumAttempts = 120
    private static var fittedWindow = false

    static func install(mode: WindowMode) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { poll(mode: mode, attempt: 0) }
        }
    }

    private static func poll(mode: WindowMode, attempt: Int) {
        if !fittedWindow, let window = gameWindow() {
            fit(window)
            fittedWindow = true
        }
        if fittedWindow, let appKitWindow = AppKitBridge.visibleWindow(), let window = gameWindow() {
            configure(appKitWindow)
            switch mode {
            case .fullScreen: enterFullScreenWhenActive(appKitWindow, attempt: 0)
            case .window: sizeToScreen(window)
            }
            return
        }
        guard attempt < maximumAttempts else {
            Trace.event("window", "game window not found")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) {
            MainActor.assumeIsolated { poll(mode: mode, attempt: attempt + 1) }
        }
    }

    private static func gameWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow || $0.rootViewController != nil }
    }

    private static func fit(_ window: UIWindow) {
        if let restrictions = window.windowScene?.sizeRestrictions {
            restrictions.minimumSize = minimumSize
            restrictions.maximumSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
        if let titlebar = window.windowScene?.titlebar {
            titlebar.titleVisibility = .hidden
            titlebar.toolbar = nil
        }
        removeTitlebarInset(window)
        if let view = window.rootViewController?.view {
            FixedResolution.attach(view, to: window)
        }
    }

    /// Opens the window at a fraction of the screen, at the game's aspect.
    private static func sizeToScreen(_ window: UIWindow) {
        guard let scene = window.windowScene, let screen = AppKitBridge.mainScreenFrame()?.size, let game = FixedResolution.size else { return }
        let scale = min(screen.width / game.width, screen.height / game.height) * initialScreenFraction
        let size = CGSize(width: (game.width * scale).rounded(), height: (game.height * scale).rounded())
        let origin = CGPoint(x: ((screen.width - size.width) / 2).rounded(), y: ((screen.height - size.height) / 2).rounded())
        scene.requestGeometryUpdate(.Mac(systemFrame: CGRect(origin: origin, size: size))) { error in
            Trace.event("window", "geometry update refused: \(error)")
        }
    }

    /// Cancels the top safe-area inset Catalyst reserves for the title bar,
    /// which the game leaves empty.
    private static func removeTitlebarInset(_ window: UIWindow) {
        guard let controller = window.rootViewController else { return }
        controller.additionalSafeAreaInsets = UIEdgeInsets(top: -window.safeAreaInsets.top, left: 0, bottom: 0, right: 0)
    }

    /// Allows native full screen, shows the game under a transparent title
    /// bar, and keeps the window at the game's aspect ratio while resizing.
    private static func configure(_ window: NSObject) {
        let behavior = (window.value(forKey: "collectionBehavior") as? UInt) ?? 0
        window.setValue(behavior | fullScreenPrimaryBehavior, forKey: "collectionBehavior")
        window.setValue(true, forKey: "titlebarAppearsTransparent")
        if let size = FixedResolution.size {
            window.setValue(NSValue(cgSize: size), forKey: "contentAspectRatio")
        }
    }

    /// Toggling full screen while UIKit is still changing the app's state
    /// at launch raises "Unbalanced state change freezing/thawing", so the
    /// toggle waits until the app is active and has settled.
    private static func enterFullScreenWhenActive(_ window: NSObject, attempt: Int) {
        let settleDelay: TimeInterval = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) {
            MainActor.assumeIsolated {
                guard UIApplication.shared.applicationState == .active else {
                    if attempt < maximumAttempts { enterFullScreenWhenActive(window, attempt: attempt + 1) }
                    return
                }
                let style = (window.value(forKey: "styleMask") as? UInt) ?? 0
                guard style & fullScreenStyle == 0 else { return }
                window.perform(NSSelectorFromString("toggleFullScreen:"), with: nil)
                Trace.event("window", "entering full screen")
            }
        }
    }
}
#endif
