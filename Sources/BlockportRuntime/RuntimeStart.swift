import BlockportShared
import Foundation
#if targetEnvironment(macCatalyst)
import UIKit
#endif

/// Entry point called by the library constructor in `BlockportInterpose` when
/// dyld loads the runtime into the game.
@_cdecl("blockport_runtime_start")
public func blockportRuntimeStart() {
    let settings = LaunchSettings(environment: ProcessInfo.processInfo.environment)
    Trace.event("runtime", "loaded, window mode \(settings.windowMode.rawValue), render scale \(settings.renderScale.map { "\($0)" } ?? "native")")
    GameData.install(environment: ProcessInfo.processInfo.environment)
    OptionDefaults.applyIfNeeded()
    #if targetEnvironment(macCatalyst)
    settings.renderScale.map(RenderScale.install)
    KeyBeepSuppression.install()
    ScrollFix.install()
    CleanExit.install()
    MainActor.assumeIsolated {
        InputRepair.install()
        FrameRate.install(settings: settings)
        let size = settings.resolution ?? AppKitBridge.fullScreenSize() ?? UIScreen.main.bounds.size
        FixedResolution.install(size: size, renderScale: settings.renderScale)
        PointerLock.install()
        WindowFitting.install(mode: settings.windowMode)
    }
    #endif
}
