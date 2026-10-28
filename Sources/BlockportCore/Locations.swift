import BlockportShared
import Foundation

/// Where Blockport keeps the installed game and its logs.
public struct Locations: Sendable {
    public let installedApp: URL
    public let log: URL
    public let gameData: URL

    public init(applicationSupport: URL, logs: URL) {
        installedApp = applicationSupport.appending(path: "Minecraft.app")
        log = logs.appending(path: "minecraft.log")
        gameData = applicationSupport.appending(path: "GameData")
    }

    public static var user: Locations {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return Locations(
            applicationSupport: library.appending(path: "Application Support/Blockport"),
            logs: library.appending(path: "Logs/Blockport")
        )
    }
}
