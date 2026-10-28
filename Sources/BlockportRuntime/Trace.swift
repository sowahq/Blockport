import Foundation

/// Writes runtime events to stderr when `BLOCKPORT_TRACE` is set.
enum Trace {
    static let isEnabled = ProcessInfo.processInfo.environment["BLOCKPORT_TRACE"] != nil

    static func event(_ source: String, _ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        FileHandle.standardError.write(Data("[blockport:\(source)] \(message())\n".utf8))
    }
}
