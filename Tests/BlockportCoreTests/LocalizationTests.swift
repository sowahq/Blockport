import Foundation
import Testing

/// Checks the launcher's translations against each other and against the
/// literal strings in the sources.
struct LocalizationTests {
    private static let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let localization = packageRoot.appending(path: "Localization")
    static let languages = ["en", "fr", "de", "es"]

    private static func strings(_ language: String) throws -> [String: String] {
        let url = localization.appending(path: "\(language).lproj/Localizable.strings")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try #require(plist as? [String: String])
    }

    private static func specifiers(_ text: String) -> [String] {
        text.matches(of: /%(@|lld)/).map { String($0.output.0) }
    }

    @Test(arguments: languages)
    func everyLanguageTranslatesEveryKeyWithTheSameSpecifiers(language: String) throws {
        let reference = try Self.strings("en")
        let translation = try Self.strings(language)
        #expect(Set(translation.keys) == Set(reference.keys))
        for (key, value) in translation {
            #expect(Self.specifiers(value) == Self.specifiers(key), "\(language): \(key)")
        }
    }

    @Test func everyLiteralInTheSourcesHasAKey() throws {
        let reference = try Self.strings("en")
        let sources = ["Sources/BlockportLauncher", "Sources/BlockportCore"].map { Self.packageRoot.appending(path: $0) }
        let call = /(?:Text|Label|Button|Picker|Toggle|section|accessibilityLabel|String\(localized:)\(\s*"([^"\\]*)"/
        let ternary = /(?:Text|Label)\([a-zA-Z.]+ \? "([^"\\]*)" : "([^"\\]*)"/
        var missing: [String] = []
        var checked = 0
        for directory in sources {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "swift" }
            for file in files {
                let source = try String(contentsOf: file, encoding: .utf8)
                let literals = source.matches(of: call).map { String($0.output.1) }
                    + source.matches(of: ternary).flatMap { [String($0.output.1), String($0.output.2)] }
                checked += literals.count
                missing += literals.filter { reference[$0] == nil }.map { "\(file.lastPathComponent): \($0)" }
            }
        }
        #expect(checked > 40, "only \(checked) literals found: the patterns no longer match the sources")
        #expect(missing.isEmpty, "\(missing)")
    }
}
