import Foundation

/// Signs the converted app with a local (ad hoc) signature.
///
/// A locally signed app runs without a developer account. macOS asks once
/// for access to the game's keychain item after each new signature, which
/// only happens when the game is installed or updated.
enum CodeSigner {
    static let codesign = "/usr/bin/codesign"

    static let entitlements = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
    <key>com.apple.security.cs.disable-library-validation</key><true/>
    <key>com.apple.security.cs.allow-jit</key><true/>
    <key>com.apple.security.network.client</key><true/>
    </dict></plist>
    """

    /// Signs every nested framework and library, then the app itself.
    static func sign(app: URL, workDirectory: URL) throws {
        let frameworks = app.appending(path: "Frameworks")
        let nested = (try? FileManager.default.contentsOfDirectory(at: frameworks, includingPropertiesForKeys: nil)) ?? []
        for item in nested.sorted(by: { $0.path < $1.path }) where ["framework", "dylib"].contains(item.pathExtension) {
            try ProcessRunner.run(codesign, ["--force", "--sign", "-", "--timestamp=none", item.path])
        }
        let entitlementsFile = workDirectory.appending(path: "entitlements.plist")
        try entitlements.write(to: entitlementsFile, atomically: true, encoding: .utf8)
        try ProcessRunner.run(codesign, ["--force", "--sign", "-", "--timestamp=none", "--entitlements", entitlementsFile.path, app.path])
        try ProcessRunner.run(codesign, ["--verify", "--deep", app.path])
    }

    /// The `application-identifier` entitlement of a signed binary.
    static func applicationIdentifier(of binary: URL) -> String? {
        guard
            let output = try? ProcessRunner.run(codesign, ["-d", "--entitlements", "-", "--xml", binary.path]),
            let plist = try? PropertyListSerialization.propertyList(from: Data(output.utf8), format: nil) as? [String: Any]
        else { return nil }
        return plist["application-identifier"] as? String
    }
}
