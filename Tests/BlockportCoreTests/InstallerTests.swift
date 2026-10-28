import Foundation
import Testing
@testable import BlockportCore

struct InstallerTests {
    @Test func infoPlistBecomesAResizableMacGame() {
        let original: [String: Any] = [
            "CFBundleExecutable": "minecraftpe",
            "UIRequiresFullScreen": true,
            "UIDeviceFamily": [1, 2],
            "UISupportedInterfaceOrientations": ["UIInterfaceOrientationLandscapeLeft"],
        ]
        let patched = InfoPlistPatch.apply(to: original, applicationIdentifier: "TEAM.com.mojang.minecraftpe")
        #expect(patched["CFBundleExecutable"] as? String == "minecraftpe")
        #expect(patched["UIRequiresFullScreen"] as? Bool == false)
        #expect(patched["UIDeviceFamily"] as? [Int] == [2, 6])
        #expect((patched["UISupportedInterfaceOrientations"] as? [String])?.count == 4)
        #expect(patched["LSApplicationCategoryType"] as? String == "public.app-category.games")
        #expect(patched[InfoPlistPatch.applicationIdentifierKey] as? String == "TEAM.com.mojang.minecraftpe")
    }

    @Test func strippingRemovesSignaturesAndLicencesOnly() throws {
        let fileManager = FileManager.default
        let app = fileManager.temporaryDirectory.appending(path: "blockport-tests-\(UUID().uuidString)/Game.app")
        defer { try? fileManager.removeItem(at: app.deletingLastPathComponent()) }
        let files = ["Info.plist", "SC_Info/game.sinf", "_CodeSignature/CodeResources", "embedded.mobileprovision", "Frameworks/A.framework/SC_Info/A.supf", "Frameworks/A.framework/A"]
        for file in files {
            let url = app.appending(path: file)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: url)
        }
        try Installer.strip(app)
        let remaining = files.filter { fileManager.fileExists(atPath: app.appending(path: $0).path) }
        #expect(remaining == ["Info.plist", "Frameworks/A.framework/A"])
    }

    @Test func payloadMustHoldExactlyOneApp() throws {
        let payload = FileManager.default.temporaryDirectory.appending(path: "blockport-tests-\(UUID().uuidString)/Payload")
        defer { try? FileManager.default.removeItem(at: payload.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: payload.appending(path: "Game.app"), withIntermediateDirectories: true)
        #expect(try Installer.findApp(in: payload).lastPathComponent == "Game.app")
        try FileManager.default.createDirectory(at: payload.appending(path: "Other.app"), withIntermediateDirectories: true)
        #expect(throws: Installer.Failure.self) { try Installer.findApp(in: payload) }
    }
}

struct RuntimeLocatorTests {
    @Test func environmentWinsAndCommandLineToolsHaveNoBundledRuntime() {
        #expect(RuntimeLocator.runtime(environment: ["BLOCKPORT_RUNTIME": "/tmp/runtime.dylib"])?.path == "/tmp/runtime.dylib")
        #expect(RuntimeLocator.runtime(bundle: Bundle(for: BundleMarker.self), environment: [:]) == nil)
    }

    @Test func installRefusesARuntimeForAnotherPlatform() throws {
        let notCatalyst = URL(fileURLWithPath: "/usr/lib/libobjc.A.dylib")
        let locations = Locations(applicationSupport: FileManager.default.temporaryDirectory, logs: FileManager.default.temporaryDirectory)
        #expect(throws: Installer.Failure.invalidRuntime(notCatalyst.path)) {
            try Installer.install(ipa: notCatalyst, runtime: notCatalyst, locations: locations) { _ in }
        }
    }
}

private final class BundleMarker {}

struct IconConverterTests {
    @Test func iconsAreNeverEnlarged() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "blockport-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let png = directory.appending(path: "art.png")
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Resources/AppIcon-1024.png")
        try ProcessRunner.run("/usr/bin/sips", ["-z", "600", "600", source.path, "--out", png.path])
        let icns = directory.appending(path: "AppIcon.icns")

        try IconConverter.makeIcns(from: png, to: icns, workDirectory: directory)

        let iconset = try FileManager.default.contentsOfDirectory(atPath: directory.appending(path: "AppIcon.iconset").path)
        #expect(iconset.count == IconConverter.variants().filter { $0.pixels <= 600 }.count)
        #expect(!iconset.contains("icon_512x512@2x.png"))
        #expect(FileManager.default.fileExists(atPath: icns.path))
    }
}
