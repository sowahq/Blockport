#if targetEnvironment(macCatalyst)
import MetalKit
import Synchronization
import UIKit

/// Presents the game at a fixed resolution, scaled to fit its window.
///
/// The game reads the screen size once at launch and never again, since an
/// iPad's screen does not change size. It is therefore given a fixed screen
/// from the start, and its view keeps that size whatever the window does: a
/// scale transform fits it to the window. UIKit maps pointer locations
/// through the transform, so input stays aligned, and MetalKit never sees the
/// view change size, so the drawable stays consistent with the engine.
enum FixedResolution {
    private struct Screen {
        let size: CGSize
        let pixelScale: CGFloat
    }

    private static let screen = Mutex<Screen?>(nil)
    @MainActor private static weak var gameView: UIView?

    static var size: CGSize? {
        screen.withLock { $0?.size }
    }

    /// Reports `size` as the screen from now on.
    @MainActor
    static func install(size: CGSize, renderScale: Double?) {
        let pixelScale = renderScale.map { CGFloat($0) } ?? UIScreen.main.nativeScale
        screen.withLock { $0 = Screen(size: size, pixelScale: pixelScale) }
        replace(#selector(getter: UIScreen.bounds)) { original in
            screen.withLock { $0.map { CGRect(origin: .zero, size: $0.size) } } ?? original
        }
        replace(#selector(getter: UIScreen.nativeBounds)) { original in
            screen.withLock { current in
                current.map { CGRect(x: 0, y: 0, width: ($0.size.width * $0.pixelScale).rounded(), height: ($0.size.height * $0.pixelScale).rounded()) }
            } ?? original
        }
        Trace.event("screen", "fixed at \(size) x\(pixelScale)")
    }

    /// Keeps the game's root view at the fixed size, scaled and centred in
    /// `window`. UIKit's own attempts to move or resize the view are ignored:
    /// with a transform applied it lays the view out through frame, bounds
    /// and center in turn, which would undo the fit.
    @MainActor
    static func attach(_ view: UIView, to window: UIWindow) {
        guard size != nil else { return }
        gameView = view
        window.backgroundColor = .black
        if let metalView = view as? MTKView, let screen = screen.withLock({ $0 }) {
            metalView.autoResizeDrawable = false
            metalView.drawableSize = CGSize(width: (screen.size.width * screen.pixelScale).rounded(), height: (screen.size.height * screen.pixelScale).rounded())
        }
        ignoreRectLayout(#selector(setter: UIView.frame), of: view)
        ignoreRectLayout(#selector(setter: UIView.bounds), of: view)
        ignorePointLayout(#selector(setter: UIView.center), of: view)
        windowObservation = window.layer.observe(\.bounds, options: [.initial, .new]) { layer, _ in
            let bounds = layer.bounds
            MainActor.assumeIsolated { fit(in: bounds) }
        }
    }

    @MainActor private static var windowObservation: NSKeyValueObservation?
    @MainActor private static var fitting = false

    @MainActor
    private static func fit(in bounds: CGRect) {
        guard let view = gameView, let size else { return }
        fitting = true
        defer { fitting = false }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        view.transform = .identity
        view.bounds = CGRect(origin: .zero, size: size)
        view.center = CGPoint(x: bounds.midX, y: bounds.midY)
        view.transform = CGAffineTransform(scaleX: scale, y: scale)
    }

    /// UIKit layout reaches the game view only while the runtime fits it.
    @MainActor
    private static func acceptsLayout(of target: UIView) -> Bool {
        target !== gameView || fitting
    }

    @MainActor
    private static func ignoreRectLayout(_ selector: Selector, of view: UIView) {
        typealias Setter = @convention(c) (UIView, Selector, CGRect) -> Void
        var original: Setter?
        let replacement: @convention(block) (UIView, CGRect) -> Void = { target, value in
            MainActor.assumeIsolated {
                if acceptsLayout(of: target) { original?(target, selector, value) }
            }
        }
        original = MethodReplacement.replace(selector, on: type(of: view), with: replacement)
            .map { unsafeBitCast($0, to: Setter.self) }
    }

    @MainActor
    private static func ignorePointLayout(_ selector: Selector, of view: UIView) {
        typealias Setter = @convention(c) (UIView, Selector, CGPoint) -> Void
        var original: Setter?
        let replacement: @convention(block) (UIView, CGPoint) -> Void = { target, value in
            MainActor.assumeIsolated {
                if acceptsLayout(of: target) { original?(target, selector, value) }
            }
        }
        original = MethodReplacement.replace(selector, on: type(of: view), with: replacement)
            .map { unsafeBitCast($0, to: Setter.self) }
    }

    private typealias RectGetter = @convention(c) (UIScreen, Selector) -> CGRect

    private static func replace(_ selector: Selector, _ value: @escaping @Sendable (CGRect) -> CGRect) {
        var original: RectGetter?
        let replacement: @convention(block) (UIScreen) -> CGRect = { screen in
            value(original.map { $0(screen, selector) } ?? .zero)
        }
        original = MethodReplacement.replace(selector, on: UIScreen.self, with: replacement)
            .map { unsafeBitCast($0, to: RectGetter.self) }
    }
}
#endif
