#if targetEnvironment(macCatalyst)
import BlockportShared
import UIKit

/// Sets the game's render loop rate: up to the display's 120 Hz on power,
/// a lower rate on battery or in Low Power Mode.
///
/// The game creates its display link in `startAnimation` with the legacy
/// frame interval, which pins it to 60 Hz on ProMotion displays.
@MainActor
enum FrameRate {
    private static let controllerClassNames = ["minecraftpeViewControllerImpl", "minecraftpeViewControllerBase"]
    private static let displayRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
    private static weak var controller: NSObject?
    private static var settings = LaunchSettings()

    static func install(settings: LaunchSettings) {
        self.settings = settings
        guard let controllerClass = controllerClassNames.lazy.compactMap(NSClassFromString).first else {
            Trace.event("render", "game view controller not found")
            return
        }
        typealias StartAnimation = @convention(c) (NSObject, Selector) -> Void
        let selector = NSSelectorFromString("startAnimation")
        var original: StartAnimation?
        let replacement: @convention(block) (NSObject) -> Void = { target in
            original?(target, selector)
            MainActor.assumeIsolated {
                controller = target
                apply()
            }
        }
        original = MethodReplacement.replace(selector, on: controllerClass, with: replacement)
            .map { unsafeBitCast($0, to: StartAnimation.self) }

        UIDevice.current.isBatteryMonitoringEnabled = true
        for name in [UIDevice.batteryStateDidChangeNotification, Notification.Name.NSProcessInfoPowerStateDidChange] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { apply() }
            }
        }
    }

    static func range(settings: LaunchSettings, onBattery: Bool, lowPower: Bool) -> CAFrameRateRange {
        guard let rate = settings.frameRate(onBattery: onBattery, lowPower: lowPower) else { return displayRange }
        let fps = Float(rate)
        return CAFrameRateRange(minimum: fps, maximum: fps, preferred: fps)
    }

    private static func apply() {
        let selector = NSSelectorFromString("displayLink")
        guard let controller, controller.responds(to: selector),
              let link = controller.perform(selector)?.takeUnretainedValue() as? CADisplayLink else { return }
        let onBattery = UIDevice.current.batteryState == .unplugged
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        link.preferredFrameRateRange = range(settings: settings, onBattery: onBattery, lowPower: lowPower)
        Trace.event("render", "display link \(link.preferredFrameRateRange.preferred ?? 0) Hz (battery \(onBattery), low power \(lowPower))")
    }
}
#endif
