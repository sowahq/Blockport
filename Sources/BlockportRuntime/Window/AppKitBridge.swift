#if targetEnvironment(macCatalyst)
import UIKit

/// AppKit objects reached through the Objective-C runtime, because Catalyst
/// apps do not link AppKit.
@MainActor
enum AppKitBridge {
    static func windows() -> [NSObject] {
        guard
            let applicationClass = NSClassFromString("NSApplication") as? NSObject.Type,
            let application = applicationClass.value(forKey: "sharedApplication") as? NSObject,
            let windows = application.value(forKey: "windows") as? [NSObject]
        else { return [] }
        return windows
    }

    static func visibleWindow() -> NSObject? {
        windows().first { ($0.value(forKey: "visible") as? Bool) == true }
    }

    /// The center of the key window in global display coordinates (origin at
    /// the top-left of the primary display), as CoreGraphics expects.
    static func keyWindowCenter() -> CGPoint? {
        guard
            let window = windows().first(where: { ($0.value(forKey: "keyWindow") as? Bool) == true }) ?? visibleWindow(),
            let frame = (window.value(forKey: "frame") as? NSValue)?.cgRectValue,
            let screenClass = NSClassFromString("NSScreen") as? NSObject.Type,
            let primary = (screenClass.value(forKey: "screens") as? [NSObject])?.first,
            let primaryFrame = (primary.value(forKey: "frame") as? NSValue)?.cgRectValue
        else { return nil }
        return CGPoint(x: frame.midX, y: primaryFrame.height - frame.midY)
    }

    /// The main screen's frame, in points with the origin at the bottom left.
    static func mainScreenFrame() -> CGRect? {
        guard
            let screenClass = NSClassFromString("NSScreen") as? NSObject.Type,
            let screen = screenClass.value(forKey: "mainScreen") as? NSObject
        else { return nil }
        return (screen.value(forKey: "frame") as? NSValue)?.cgRectValue
    }

    /// The area a full-screen window gets on the main screen: its frame
    /// without the camera housing at the top.
    static func fullScreenSize() -> CGSize? {
        guard
            let screenClass = NSClassFromString("NSScreen") as? NSObject.Type,
            let screen = screenClass.value(forKey: "mainScreen") as? NSObject,
            let frame = (screen.value(forKey: "frame") as? NSValue)?.cgRectValue
        else { return nil }
        var insets = UIEdgeInsets.zero
        (screen.value(forKey: "safeAreaInsets") as? NSValue)?.getValue(&insets, size: MemoryLayout<UIEdgeInsets>.size)
        return CGSize(width: frame.width, height: frame.height - insets.top)
    }
}
#endif
