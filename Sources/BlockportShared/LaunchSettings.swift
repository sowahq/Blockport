import CoreGraphics
import Foundation

/// Options the launcher passes to the runtime through the environment.
public struct LaunchSettings: Equatable, Codable, Sendable {
    enum Key {
        static let windowMode = "BLOCKPORT_WINDOW_MODE"
        static let renderScale = "BLOCKPORT_RENDER_SCALE"
        static let resolution = "BLOCKPORT_RESOLUTION"
        static let frameRate = "BLOCKPORT_FPS"
        static let batteryFrameRate = "BLOCKPORT_BATTERY_FPS"
        static let yield = "BLOCKPORT_YIELD"
    }

    public static let renderScaleRange = 0.5...3.0
    public static let defaultBatteryFrameRate = 60
    static let minimumResolutionSide = 320

    public var windowMode: WindowMode
    /// Pixels rendered per point, or `nil` for the display's native scale.
    /// Lower values trade sharpness for GPU time.
    public var renderScale: Double?
    /// The fixed size in points the game renders at, or `nil` for the
    /// screen's full-screen area.
    public var resolution: CGSize?
    /// Frames per second on power adapter, or `nil` for the display's range.
    public var frameRate: Int?
    /// Frames per second on battery or in Low Power Mode, or `nil` to run as
    /// on power adapter.
    public var batteryFrameRate: Int?
    /// Lets idle chunk-streaming threads sleep instead of spinning.
    public var yieldBackoff: Bool

    public init(
        windowMode: WindowMode = .fullScreen,
        renderScale: Double? = nil,
        resolution: CGSize? = nil,
        frameRate: Int? = nil,
        batteryFrameRate: Int? = defaultBatteryFrameRate,
        yieldBackoff: Bool = true
    ) {
        self.windowMode = windowMode
        self.renderScale = renderScale
        self.resolution = resolution
        self.frameRate = frameRate
        self.batteryFrameRate = batteryFrameRate
        self.yieldBackoff = yieldBackoff
    }

    public init(environment: [String: String]) {
        self.init(
            windowMode: environment[Key.windowMode].flatMap(WindowMode.init(rawValue:)) ?? .fullScreen,
            renderScale: environment[Key.renderScale].flatMap(Double.init).flatMap { Self.renderScaleRange.contains($0) ? $0 : nil },
            resolution: environment[Key.resolution].flatMap(Self.size(from:)),
            frameRate: environment[Key.frameRate].flatMap(Self.positive),
            batteryFrameRate: environment[Key.batteryFrameRate].map(Self.positive) ?? Self.defaultBatteryFrameRate,
            yieldBackoff: environment[Key.yield] != "spin"
        )
    }

    /// The environment that makes the runtime read these settings back.
    public var environment: [String: String] {
        var environment = [
            Key.windowMode: windowMode.rawValue,
            Key.batteryFrameRate: String(batteryFrameRate ?? 0),
        ]
        environment[Key.renderScale] = renderScale.map { String($0) }
        environment[Key.resolution] = resolution.map { "\(Int($0.width))x\(Int($0.height))" }
        environment[Key.frameRate] = frameRate.map(String.init)
        environment[Key.yield] = yieldBackoff ? nil : "spin"
        return environment
    }

    /// The fixed frame rate to run at, or `nil` for the display's range.
    public func frameRate(onBattery: Bool, lowPower: Bool) -> Int? {
        (onBattery || lowPower ? batteryFrameRate : nil) ?? frameRate
    }

    /// Parses `WIDTHxHEIGHT` in points.
    static func size(from text: String) -> CGSize? {
        let parts = text.lowercased().split(separator: "x").compactMap { Int($0) }
        guard parts.count == 2, parts.allSatisfy({ $0 >= minimumResolutionSide }) else { return nil }
        return CGSize(width: parts[0], height: parts[1])
    }

    private static func positive(_ text: String) -> Int? {
        Int(text).flatMap { $0 > 0 ? $0 : nil }
    }
}
