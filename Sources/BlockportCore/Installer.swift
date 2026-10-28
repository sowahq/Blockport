import Foundation

/// A converted game installed by Blockport.
public struct InstalledGame: Equatable, Sendable {
    public let app: URL
    public let executable: URL
    public let version: String

    /// Reads the installed app at `app`, or `nil` when there is none.
    public init?(app: URL) {
        guard
            let info = NSDictionary(contentsOf: app.appending(path: "Info.plist")) as? [String: Any],
            let executable = info["CFBundleExecutable"] as? String
        else { return nil }
        self.app = app
        self.executable = app.appending(path: executable)
        version = info["CFBundleShortVersionString"] as? String ?? "?"
    }
}

/// Converts a decrypted iOS IPA of the game into a Mac Catalyst app that
/// loads the Blockport runtime.
public enum Installer {
    public enum Step: Int, CaseIterable, Sendable {
        case extract, inspect, strip, convert, loadRuntime, patchInfo, sign, install

        public var title: String {
            switch self {
            case .extract: String(localized: "Extracting the IPA")
            case .inspect: String(localized: "Checking the app")
            case .strip: String(localized: "Removing iOS signatures")
            case .convert: String(localized: "Converting binaries for the Mac")
            case .loadRuntime: String(localized: "Adding the Blockport runtime")
            case .patchInfo: String(localized: "Configuring the app")
            case .sign: String(localized: "Signing")
            case .install: String(localized: "Installing")
            }
        }
    }

    public enum Failure: Error, Equatable, CustomStringConvertible {
        case invalidApp(String)
        case encrypted(String)
        case unsupportedBinary(String, MachOFile.Failure)
        case invalidRuntime(String)

        public var description: String {
            switch self {
            case .invalidApp(let reason): String(localized: "Invalid IPA: \(reason)")
            case .encrypted(let binary): String(localized: "\(binary) is still encrypted: a decrypted IPA is required.")
            case .unsupportedBinary(let binary, let failure): String(localized: "\(binary) cannot be converted (\(String(describing: failure)))")
            case .invalidRuntime(let path): String(localized: "\(path) is not a Mac Catalyst build of the runtime.")
            }
        }
    }

    static let runtimeName = "libBlockportRuntime.dylib"
    static let runtimeLoadPath = "@executable_path/Frameworks/\(runtimeName)"
    /// Mac Catalyst 14.0, the earliest version matching the game's iOS 14.
    static let catalystMinimumOS: UInt32 = 14 << 16
    static let strippedNames: Set<String> = ["SC_Info", "_CodeSignature", "embedded.mobileprovision"]
    /// Decrypted IPAs often lose the executable bit of their binaries.
    static let executablePermissions = 0o755

    /// Installs the game from `ipa`, replacing any previous installation.
    public static func install(
        ipa: URL,
        runtime: URL,
        locations: Locations,
        progress: @Sendable (Step) -> Void
    ) throws -> InstalledGame {
        guard (try? MachOFile(contentsOf: runtime))?.platform == .macCatalyst else {
            throw Failure.invalidRuntime(runtime.path)
        }
        let fileManager = FileManager.default
        let work = fileManager.temporaryDirectory.appending(path: "blockport-\(UUID().uuidString)")
        try fileManager.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: work) }

        progress(.extract)
        let extracted = work.appending(path: "ipa")
        try ProcessRunner.run("/usr/bin/ditto", ["-x", "-k", ipa.path, extracted.path])

        progress(.inspect)
        let app = try findApp(in: extracted.appending(path: "Payload"))
        guard let game = InstalledGame(app: app) else { throw Failure.invalidApp(String(localized: "unreadable Info.plist")) }
        let applicationIdentifier = CodeSigner.applicationIdentifier(of: game.executable)

        progress(.strip)
        try strip(app)

        progress(.convert)
        for binary in try machOFiles(in: app) {
            var file = try MachOFile(contentsOf: binary)
            if file.isEncrypted { throw Failure.encrypted(binary.lastPathComponent) }
            do {
                try file.setPlatform(.macCatalyst, minimumOS: catalystMinimumOS)
            } catch let failure as MachOFile.Failure {
                throw Failure.unsupportedBinary(binary.lastPathComponent, failure)
            }
            try file.save(to: binary)
            try FileManager.default.setAttributes([.posixPermissions: executablePermissions], ofItemAtPath: binary.path)
        }

        progress(.loadRuntime)
        try fileManager.copyItem(at: runtime, to: app.appending(path: "Frameworks/\(runtimeName)"))
        var executable = try MachOFile(contentsOf: game.executable)
        try executable.addDylib(runtimeLoadPath)
        try executable.save(to: game.executable)

        progress(.patchInfo)
        let iconFile = try addMacIcon(to: app, artwork: extracted.appending(path: "iTunesArtwork"), workDirectory: work)
        try InfoPlistPatch.apply(toFile: app.appending(path: "Info.plist"), applicationIdentifier: applicationIdentifier, iconFile: iconFile)

        progress(.sign)
        try CodeSigner.sign(app: app, workDirectory: work)

        progress(.install)
        let destination = locations.installedApp
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: app)
        } else {
            try fileManager.moveItem(at: app, to: destination)
        }
        guard let installed = InstalledGame(app: destination) else { throw Failure.invalidApp(String(localized: "unreadable installation")) }
        return installed
    }

    static let iconName = "AppIcon"

    /// Gives the app a macOS icon made from the game's own artwork: the
    /// store artwork at the IPA's root, or the largest icon in the bundle.
    /// Returns the icon file name, or `nil` when the IPA has no artwork.
    static func addMacIcon(to app: URL, artwork: URL, workDirectory: URL) throws -> String? {
        let fileManager = FileManager.default
        let largestBundleIcon = (try? fileManager.contentsOfDirectory(at: app, includingPropertiesForKeys: [.fileSizeKey]))?
            .filter { $0.lastPathComponent.hasPrefix(iconName) && $0.pathExtension == "png" }
            .max { fileSize($0) < fileSize($1) }
        guard let source = fileManager.fileExists(atPath: artwork.path) ? artwork : largestBundleIcon else { return nil }
        try IconConverter.makeIcns(from: source, to: app.appending(path: "\(iconName).icns"), workDirectory: workDirectory)
        return iconName
    }

    private static func fileSize(_ url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }

    static func findApp(in payload: URL) throws -> URL {
        let apps = (try? FileManager.default.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "app" } ?? []
        guard apps.count == 1, let app = apps.first else { throw Failure.invalidApp(String(localized: "the Payload folder must contain exactly one app")) }
        return app
    }

    /// Removes the iOS signatures and store licences, which do not apply
    /// to the converted app.
    static func strip(_ app: URL) throws {
        let fileManager = FileManager.default
        guard let items = fileManager.enumerator(at: app, includingPropertiesForKeys: nil) else { return }
        let stripped = items.compactMap { $0 as? URL }.filter { strippedNames.contains($0.lastPathComponent) }
        for item in stripped {
            try fileManager.removeItem(at: item)
        }
    }

    /// Every thin 64-bit Mach-O file in the bundle.
    static func machOFiles(in app: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let items = FileManager.default.enumerator(at: app, includingPropertiesForKeys: keys) else { return [] }
        return try items.compactMap { $0 as? URL }.filter { url in
            guard try url.resourceValues(forKeys: Set(keys)).isRegularFile == true else { return false }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            return MachOFile.isThin64Bit(try handle.read(upToCount: 4) ?? Data())
        }
    }
}
