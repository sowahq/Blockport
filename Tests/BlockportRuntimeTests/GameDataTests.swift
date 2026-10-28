import Foundation
import Testing
@testable import BlockportRuntime

struct GameDataTests {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "blockport-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func gameFolderMovesOnceIntoAnEmptyContainer() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let old = root.appending(path: "Documents/games/com.mojang")
        let new = root.appending(path: "GameData/Documents/games/com.mojang")
        try FileManager.default.createDirectory(at: old.appending(path: "minecraftWorlds/world"), withIntermediateDirectories: true)

        GameData.migrate(from: old, to: new)

        #expect(!FileManager.default.fileExists(atPath: old.path))
        #expect(FileManager.default.fileExists(atPath: new.appending(path: "minecraftWorlds/world").path))
    }

    @Test func existingDataIsNeverOverwritten() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let old = root.appending(path: "old")
        let new = root.appending(path: "new")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)
        try Data("kept".utf8).write(to: new.appending(path: "options.txt"))

        GameData.migrate(from: old, to: new)

        #expect(FileManager.default.fileExists(atPath: old.path))
        #expect(try String(contentsOf: new.appending(path: "options.txt"), encoding: .utf8) == "kept")
    }
}
