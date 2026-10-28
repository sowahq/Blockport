import Foundation

/// Finds the Catalyst build of the runtime library the installer embeds.
public enum RuntimeLocator {
    static let environmentKey = "BLOCKPORT_RUNTIME"

    /// The library `BLOCKPORT_RUNTIME` points to, or the one bundled in the
    /// launcher app. Command-line tools have no bundle of their own: their
    /// directory holds build products for other platforms.
    public static func runtime(bundle: Bundle = .main, environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        if let path = environment[environmentKey] {
            return URL(fileURLWithPath: path)
        }
        guard bundle.bundleURL.pathExtension == "app" else { return nil }
        return bundle.url(forResource: "libBlockportRuntime", withExtension: "dylib")
    }
}
