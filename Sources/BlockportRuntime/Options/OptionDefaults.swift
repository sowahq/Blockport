import Foundation

/// Option values Blockport applies once, before the game first reads them.
///
/// The values are written when `version` is newer than the one recorded in
/// the app's defaults, so a player's later changes are kept until the set of
/// defaults itself changes.
enum OptionDefaults {
    static let version = 3
    static let recordedVersionKey = "BlockportOptionDefaultsVersion"

    static let values: [(key: String, value: String, reason: String)] = [
        ("gfx_ui_profile", "0", "classic interface instead of the touch-oriented Pocket profile"),
        ("graphics_mode", "0", "Simple graphics, the lightest mode, instead of Fancy or Vibrant Visuals"),
        ("gfx_vsync", "1", "frames paced to the display, which also lowers CPU use"),
        ("gfx_fullscreen", "0", "the game sizes itself from the screen when it believes it is full screen; the runtime handles full screen instead"),
    ]

    static var optionsFile: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appending(path: "games/com.mojang/minecraftpe/options.txt")
    }

    static func applied(to options: GameOptions) -> GameOptions {
        values.reduce(into: options) { $0.set($1.key, to: $1.value) }
    }

    /// Writes the defaults into `options.txt` if this version was not applied
    /// yet or the file does not exist, as in a new data folder; a missing
    /// file is created with only these values.
    static func applyIfNeeded(file: URL? = optionsFile, defaults: UserDefaults = .standard) {
        guard let file else { return }
        let missing = !FileManager.default.fileExists(atPath: file.path)
        guard missing || defaults.integer(forKey: recordedVersionKey) < version else { return }
        let current = (try? String(contentsOf: file, encoding: .utf8)).map(GameOptions.init(text:)) ?? GameOptions(text: "")
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try applied(to: current).text.write(to: file, atomically: true, encoding: .utf8)
            defaults.set(version, forKey: recordedVersionKey)
            Trace.event("options", "defaults v\(version) applied to \(file.path)")
        } catch {
            Trace.event("options", "defaults not applied: \(error)")
        }
    }
}
