#if targetEnvironment(macCatalyst)
import Foundation

/// Silences the alert sound for key presses no responder handles.
///
/// The game reads the keyboard through `GCKeyboard`, so UIKit never consumes
/// the key events and AppKit beeps for each one. Only `keyDown:` reaching
/// `-[NSResponder noResponderFor:]` is silenced.
enum KeyBeepSuppression {
    static func install() {
        guard let responderClass = NSClassFromString("NSResponder") else { return }
        typealias NoResponder = @convention(c) (AnyObject, Selector, Selector) -> Void
        let selector = NSSelectorFromString("noResponderFor:")
        let keyDown = NSSelectorFromString("keyDown:")
        var original: NoResponder?
        let replacement: @convention(block) (AnyObject, Selector) -> Void = { responder, event in
            guard event != keyDown else { return }
            original?(responder, selector, event)
        }
        original = MethodReplacement.replace(selector, on: responderClass, with: replacement)
            .map { unsafeBitCast($0, to: NoResponder.self) }
    }
}
#endif
