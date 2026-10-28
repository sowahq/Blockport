import Foundation
import Testing
@testable import BlockportCore

struct MachOFileTests {
    /// Compiles a minimal iOS executable, the shape of the game's binaries.
    private func iOSExecutable(in directory: URL, minimumOS: String = "14.0") throws -> URL {
        let source = directory.appending(path: "main.c")
        let binary = directory.appending(path: "main")
        try "int main(void) { return 0; }\n".write(to: source, atomically: true, encoding: .utf8)
        try ProcessRunner.run("/usr/bin/xcrun", ["--sdk", "iphoneos", "clang", "-target", "arm64-apple-ios\(minimumOS)", source.path, "-o", binary.path])
        return binary
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "blockport-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func convertsAniOSBinaryToCatalystAndLoadsTheRuntime() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let binary = try iOSExecutable(in: directory)

        var file = try MachOFile(contentsOf: binary)
        #expect(file.platform == .iOS)
        #expect(!file.isEncrypted)
        try file.setPlatform(.macCatalyst, minimumOS: Installer.catalystMinimumOS)
        try file.addDylib(Installer.runtimeLoadPath)
        try file.addDylib(Installer.runtimeLoadPath)
        try file.save(to: binary)

        #expect(FileManager.default.isExecutableFile(atPath: binary.path))
        let reread = try MachOFile(contentsOf: binary)
        #expect(reread.platform == .macCatalyst)
        #expect(reread.minimumOS == Installer.catalystMinimumOS)
        #expect(reread.dylibs.filter { $0 == Installer.runtimeLoadPath }.count == 1)

        let loadCommands = try ProcessRunner.run("/usr/bin/otool", ["-l", binary.path])
        #expect(loadCommands.contains("platform 6"))
        #expect(loadCommands.contains("minos 14.0"))
        #expect(try ProcessRunner.run("/usr/bin/otool", ["-L", binary.path]).contains(Installer.runtimeLoadPath))
    }

    @Test func convertsTheLegacyVersionCommand() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let binary = try iOSExecutable(in: directory, minimumOS: "11.0")
        #expect(try ProcessRunner.run("/usr/bin/otool", ["-l", binary.path]).contains("LC_VERSION_MIN_IPHONEOS"))

        var file = try MachOFile(contentsOf: binary)
        try file.setPlatform(.macCatalyst, minimumOS: Installer.catalystMinimumOS)
        try file.addDylib(Installer.runtimeLoadPath)
        try file.save(to: binary)

        let loadCommands = try ProcessRunner.run("/usr/bin/otool", ["-l", binary.path])
        #expect(!loadCommands.contains("LC_VERSION_MIN_IPHONEOS"))
        #expect(loadCommands.contains("platform 6"))
        #expect(try MachOFile(contentsOf: binary).dylibs.contains(Installer.runtimeLoadPath))
        #expect(try ProcessRunner.run("/usr/bin/codesign", ["--force", "--sign", "-", binary.path]).isEmpty)
    }

    @Test(arguments: [Data(), Data([0xCA, 0xFE, 0xBA, 0xBE] + Array(repeating: 0, count: 28))])
    func rejectsOtherFiles(data: Data) {
        #expect(throws: MachOFile.Failure.self) { try MachOFile(data: data) }
        #expect(!MachOFile.isThin64Bit(data))
    }
}
