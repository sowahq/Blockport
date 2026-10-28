#if targetEnvironment(macCatalyst)
import UIKit

/// Renders the game below the display's native resolution.
///
/// The game computes its first drawable from its view's `contentScaleFactor`
/// and later ones from `UIScreen.nativeBounds`, which `ScreenOverride` scales
/// the same way. Both report the requested scale from launch, so every
/// drawable is consistent; Core Animation stretches it over the window.
enum RenderScale {
    static func install(_ scale: Double) {
        let replacement: @convention(block) (UIView) -> CGFloat = { _ in CGFloat(scale) }
        MethodReplacement.replace(#selector(getter: UIView.contentScaleFactor), on: UIView.self, with: replacement)
        Trace.event("render", "content scale \(scale)")
    }
}
#endif
