import Foundation

/// Where the game keeps its worlds, options and sign-in files: the
/// equivalent of an iOS app container, instead of the user's Documents.
public enum GameDataLocation {
    public static let environmentKey = "BLOCKPORT_DATA_DIR"

    /// `~/Library/Application Support/Blockport/GameData`.
    public static func defaultDirectory(home: URL) -> URL {
        home.appending(path: "Library/Application Support/Blockport/GameData")
    }

    /// The directory the game sees as its Documents folder.
    public static func documents(in container: URL) -> URL {
        container.appending(path: "Documents")
    }
}
