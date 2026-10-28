import CoreGraphics
import Testing
@testable import BlockportShared

struct LaunchSettingsTests {
    @Test(arguments: [
        ("1470x924", CGSize?.some(CGSize(width: 1470, height: 924))),
        ("1920X1200", CGSize(width: 1920, height: 1200)),
        ("100x100", nil),
        ("1920", nil),
        ("wide", nil),
    ])
    func resolutionIsParsedInPoints(text: String, expected: CGSize?) {
        #expect(LaunchSettings.size(from: text) == expected)
    }

    @Test(arguments: [
        ([String: String](), false, false, Int?.none),
        ([:], true, false, 60),
        ([:], false, true, 60),
        (["BLOCKPORT_FPS": "90"], false, false, 90),
        (["BLOCKPORT_FPS": "90", "BLOCKPORT_BATTERY_FPS": "0"], true, false, 90),
        (["BLOCKPORT_BATTERY_FPS": "30"], true, false, 30),
    ])
    func frameRateFollowsThePowerSource(environment: [String: String], onBattery: Bool, lowPower: Bool, expected: Int?) {
        #expect(LaunchSettings(environment: environment).frameRate(onBattery: onBattery, lowPower: lowPower) == expected)
    }

    @Test(arguments: [
        LaunchSettings(),
        LaunchSettings(windowMode: .window, renderScale: 1.5, resolution: CGSize(width: 1680, height: 1050), frameRate: 120, batteryFrameRate: nil, yieldBackoff: false),
    ])
    func settingsSurviveTheEnvironment(settings: LaunchSettings) {
        #expect(LaunchSettings(environment: settings.environment) == settings)
    }

    @Test(arguments: [
        ([String: String](), WindowMode.fullScreen),
        (["BLOCKPORT_WINDOW_MODE": "window"], .window),
        (["BLOCKPORT_WINDOW_MODE": "unknown"], .fullScreen),
    ])
    func windowModeComesFromTheEnvironment(environment: [String: String], expected: WindowMode) {
        #expect(LaunchSettings(environment: environment).windowMode == expected)
    }

    @Test(arguments: [
        ([String: String](), Double?.none),
        (["BLOCKPORT_RENDER_SCALE": "1.5"], 1.5),
        (["BLOCKPORT_RENDER_SCALE": "0.1"], nil),
        (["BLOCKPORT_RENDER_SCALE": "fast"], nil),
    ])
    func renderScaleIsReadWithinItsRange(environment: [String: String], expected: Double?) {
        #expect(LaunchSettings(environment: environment).renderScale == expected)
    }
}
