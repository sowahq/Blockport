#if targetEnvironment(macCatalyst)
@preconcurrency import GameController
import UIKit

/// Repairs mouse and keyboard input the game failed to set up.
///
/// The game installs its click and key handlers in `onConnectMouse:` and
/// `onConnectKeyboard:` of `KeyboardAndMouseHandler_apple`, for whichever
/// device is current at that moment. On a Mac the devices can connect before
/// the game observes them, leaving clicks or keys dead for the session, and
/// only the current mouse is set up, so a second mouse (a trackpad plus a USB
/// mouse) never clicks. The game's own setup is re-run for every device that
/// has no handler, presenting each mouse as the current one.
@MainActor
enum InputRepair {
    private static let handlerClassName = "KeyboardAndMouseHandler_apple"
    private static let connectMouse = NSSelectorFromString("onConnectMouse:")
    private static let connectKeyboard = NSSelectorFromString("onConnectKeyboard:")
    private static let repairDelays: [TimeInterval] = [2, 5, 10]

    private typealias Connect = @convention(c) (AnyObject, Selector, NSNotification) -> Void
    private typealias CurrentMouse = @convention(c) (AnyClass, Selector) -> GCMouse?
    private typealias AddObserver = @convention(c) (NotificationCenter, Selector, AnyObject, Selector, NSString?, AnyObject?) -> Void

    private static weak var handler: AnyObject?
    private static var originalConnectMouse: Connect?
    private static var originalConnectKeyboard: Connect?
    private static var mouseBeingSetUp: GCMouse?

    static func install() {
        guard let handlerClass = NSClassFromString(handlerClassName) else {
            Trace.event("input", "\(handlerClassName) not found")
            return
        }
        originalConnectMouse = captureHandler(connectMouse, on: handlerClass)
        originalConnectKeyboard = captureHandler(connectKeyboard, on: handlerClass)
        presentMouseBeingSetUpAsCurrent()
        captureHandlerOnRegistration()

        let names = [Notification.Name.GCMouseDidBecomeCurrent, .GCMouseDidConnect, .GCKeyboardDidConnect, UIApplication.didBecomeActiveNotification]
        for name in names {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                DispatchQueue.main.async { MainActor.assumeIsolated { repair() } }
            }
        }
        for delay in repairDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { MainActor.assumeIsolated { repair() } }
        }
    }

    private static func captureHandler(_ selector: Selector, on handlerClass: AnyClass) -> Connect? {
        var original: Connect?
        let replacement: @convention(block) (AnyObject, NSNotification) -> Void = { target, notification in
            MainActor.assumeIsolated { handler = target }
            original?(target, selector, notification)
        }
        original = MethodReplacement.replace(selector, on: handlerClass, with: replacement)
            .map { unsafeBitCast($0, to: Connect.self) }
        return original
    }

    private static func presentMouseBeingSetUpAsCurrent() {
        guard let metaclass = object_getClass(GCMouse.self) else { return }
        let selector = #selector(getter: GCMouse.current)
        var original: CurrentMouse?
        let replacement: @convention(block) (AnyClass) -> GCMouse? = { mouseClass in
            MainActor.assumeIsolated { mouseBeingSetUp } ?? original?(mouseClass, selector)
        }
        original = MethodReplacement.replace(selector, on: metaclass, with: replacement)
            .map { unsafeBitCast($0, to: CurrentMouse.self) }
    }

    /// Captures the handler when it registers for device notifications, in
    /// case its connect callbacks never run.
    private static func captureHandlerOnRegistration() {
        let selector = #selector(NotificationCenter.addObserver(_:selector:name:object:))
        var original: AddObserver?
        let replacement: @convention(block) (NotificationCenter, AnyObject, Selector, NSString?, AnyObject?) -> Void = { center, observer, observerSelector, name, object in
            original?(center, selector, observer, observerSelector, name, object)
            guard observerSelector == connectMouse || observerSelector == connectKeyboard else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if handler == nil { handler = observer }
                    repair()
                }
            }
        }
        original = MethodReplacement.replace(selector, on: NotificationCenter.self, with: replacement)
            .map { unsafeBitCast($0, to: AddObserver.self) }
    }

    private static func repair() {
        guard let handler else { return }
        for mouse in GCMouse.mice() where mouse.mouseInput?.leftButton.valueChangedHandler == nil {
            guard let originalConnectMouse else { break }
            mouseBeingSetUp = mouse
            originalConnectMouse(handler, connectMouse, Notification(name: .GCMouseDidConnect, object: mouse) as NSNotification)
            mouseBeingSetUp = nil
            Trace.event("input", "repaired mouse \(mouse.vendorName ?? "?")")
        }
        if let keyboard = GCKeyboard.coalesced, keyboard.keyboardInput?.keyChangedHandler == nil, let originalConnectKeyboard {
            originalConnectKeyboard(handler, connectKeyboard, Notification(name: .GCKeyboardDidConnect, object: keyboard) as NSNotification)
            Trace.event("input", "repaired keyboard")
        }
    }
}
#endif
