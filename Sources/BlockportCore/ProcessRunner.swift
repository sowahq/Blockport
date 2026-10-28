import Foundation

/// Runs command-line tools and reports their failures.
enum ProcessRunner {
    struct Failure: Error, CustomStringConvertible {
        let command: String
        let status: Int32
        let output: String

        var description: String { "\(command) failed (\(status)): \(output)" }
    }

    /// Runs `executable` and returns its standard output.
    @discardableResult
    static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: outputData, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            let command = ([executable] + arguments).joined(separator: " ")
            throw Failure(command: command, status: process.terminationStatus, output: String(decoding: errorData, as: UTF8.self) + text)
        }
        return text
    }
}
