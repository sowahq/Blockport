import BlockportShared
import Foundation

/// Starts the installed game with launch settings, logging its output.
public enum GameLauncher {
    /// Launches `game` and calls `onExit` with its exit status when it ends.
    public static func launch(
        _ game: InstalledGame,
        settings: LaunchSettings,
        locations: Locations,
        onExit: @escaping @Sendable (Int32) -> Void
    ) throws -> Process {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: locations.log.deletingLastPathComponent(), withIntermediateDirectories: true)
        fileManager.createFile(atPath: locations.log.path, contents: nil)
        let log = try FileHandle(forWritingTo: locations.log)

        let process = Process()
        process.executableURL = game.executable
        var environment = ProcessInfo.processInfo.environment.merging(settings.environment) { _, setting in setting }
        environment[GameDataLocation.environmentKey] = locations.gameData.path
        process.environment = environment
        process.standardOutput = log
        process.standardError = log
        process.terminationHandler = { finished in
            try? log.close()
            onExit(finished.terminationStatus)
        }
        try process.run()
        return process
    }
}
