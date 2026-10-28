import Foundation

/// Changes to the game's Info.plist for running as a Mac app.
public enum InfoPlistPatch {
    public static let applicationIdentifierKey = "BlockportApplicationIdentifier"
    static let macDeviceFamily = 6
    static let iPadDeviceFamily = 2

    /// Returns `plist` patched:
    /// - resizable window: `UIRequiresFullScreen` off, every orientation;
    /// - Mac idiom (device family 6), so the game renders at the display's
    ///   pixels instead of an iPad interface scaled to 77%;
    /// - declared as a game, which enables macOS Game Mode in full screen;
    /// - the original application identifier, which the runtime reports as
    ///   the keychain access group;
    /// - a macOS icon file made from the game's own artwork.
    public static func apply(to plist: [String: Any], applicationIdentifier: String?, iconFile: String? = nil) -> [String: Any] {
        var patched = plist
        patched["UIRequiresFullScreen"] = false
        patched["UISupportedInterfaceOrientations"] = [
            "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight",
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationPortraitUpsideDown",
        ]
        patched["UIDeviceFamily"] = [iPadDeviceFamily, macDeviceFamily]
        patched["LSApplicationCategoryType"] = "public.app-category.games"
        patched["GCSupportsGameMode"] = true
        patched[applicationIdentifierKey] = applicationIdentifier
        if let iconFile {
            patched["CFBundleIconFile"] = iconFile
        }
        return patched
    }

    static func apply(toFile url: URL, applicationIdentifier: String?, iconFile: String?) throws {
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw Installer.Failure.invalidApp(String(localized: "Info.plist is not a dictionary"))
        }
        let patched = apply(to: plist, applicationIdentifier: applicationIdentifier, iconFile: iconFile)
        try PropertyListSerialization.data(fromPropertyList: patched, format: .binary, options: 0).write(to: url, options: .atomic)
    }
}
