#if targetEnvironment(macCatalyst)
import GameController

/// Makes the scroll wheel and trackpad scroll the game.
///
/// The game reads scrolling from the first (x) value of the mouse's scroll
/// handler, but on a Mac vertical scrolling arrives as y with x at 0. The
/// vertical amount is handed to the game as x when x is empty.
enum ScrollFix {
    typealias ScrollHandler = @convention(block) (GCControllerDirectionPad, Float, Float) -> Void

    static func install() {
        guard let cursorClass = NSClassFromString("GCDeviceCursor") else {
            Trace.event("input", "GCDeviceCursor not found")
            return
        }
        typealias SetHandler = @convention(c) (AnyObject, Selector, ScrollHandler?) -> Void
        let selector = NSSelectorFromString("setValueChangedHandler:")
        var original: SetHandler?
        let replacement: @convention(block) (AnyObject, ScrollHandler?) -> Void = { cursor, handler in
            original?(cursor, selector, handler.map(verticalAsHorizontal))
        }
        original = MethodReplacement.replace(selector, on: cursorClass, with: replacement)
            .map { unsafeBitCast($0, to: SetHandler.self) }
    }

    static func verticalAsHorizontal(_ handler: @escaping ScrollHandler) -> ScrollHandler {
        { pad, x, y in handler(pad, x != 0 ? x : y, 0) }
    }
}
#endif
