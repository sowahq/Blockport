import Foundation
import Testing
@testable import BlockportRuntime

struct OptionDefaultsTests {
    @Test func optionsKeepUnrelatedLinesAndReplaceKnownKeys() {
        var options = GameOptions(text: "graphics_mode:2\nkeyboard_type_0_key.chat:84,13\n")
        options.set("graphics_mode", to: "1")
        options.set("gfx_ui_profile", to: "0")
        #expect(options.text == "graphics_mode:1\nkeyboard_type_0_key.chat:84,13\ngfx_ui_profile:0\n")
        #expect(options.value("keyboard_type_0_key.chat") == "84,13")
    }

    @Test func defaultsAreAppliedOncePerVersion() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "options.txt")
        let suite = "blockport.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        OptionDefaults.applyIfNeeded(file: file, defaults: defaults)
        var options = GameOptions(text: try String(contentsOf: file, encoding: .utf8))
        #expect(options.value("graphics_mode") == "0")
        #expect(options.value("gfx_ui_profile") == "0")

        options.set("graphics_mode", to: "2")
        try options.text.write(to: file, atomically: true, encoding: .utf8)
        OptionDefaults.applyIfNeeded(file: file, defaults: defaults)
        #expect(GameOptions(text: try String(contentsOf: file, encoding: .utf8)).value("graphics_mode") == "2")
        try FileManager.default.removeItem(at: file)
        OptionDefaults.applyIfNeeded(file: file, defaults: defaults)
        #expect(GameOptions(text: try String(contentsOf: file, encoding: .utf8)).value("graphics_mode") == "0")
    }
}
