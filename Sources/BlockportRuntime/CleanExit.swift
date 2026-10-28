#if targetEnvironment(macCatalyst)
import BlockportNative
import UIKit

/// Ends the process once the game has saved.
///
/// UIKit ends the app with `exit`, whose static destructors crash under the
/// game's still-running threads and hang in its crash handler, leaving a
/// windowless process behind. Closing the last window also leaves AppKit
/// waiting instead of exiting. Once UIKit has delivered the termination
/// callbacks, the process exits immediately.
enum CleanExit {
    static func install() {
        typealias Terminate = @convention(c) (UIApplication, Selector, Int32) -> Void
        let selector = NSSelectorFromString("_terminateWithStatus:")
        var original: Terminate?
        let replacement: @convention(block) (UIApplication, Int32) -> Void = { application, status in
            blockport_mark_terminating()
            original?(application, selector, status)
            Trace.event("runtime", "termination callbacks done, exiting")
            blockport_exit_now(status)
        }
        original = MethodReplacement.replace(selector, on: UIApplication.self, with: replacement)
            .map { unsafeBitCast($0, to: Terminate.self) }
    }
}
#endif
