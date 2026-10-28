import BlockportNative
import BlockportShared
import Foundation

/// Gives the game its own Documents folder, inside its data container,
/// instead of the user's Documents.
///
/// The game finds the folder with `NSSearchPathForDirectoriesInDomains`
/// (redirected in `BlockportInterpose`) and Foundation code with
/// `FileManager.urls(for:in:)`, both answered here for the user-domain
/// Documents directory only.
enum GameData {
    static let gameFolder = "games/com.mojang"

    /// Redirects the Documents folder and returns it.
    @discardableResult
    static func install(environment: [String: String]) -> URL {
        let fileManager = FileManager.default
        let container = environment[GameDataLocation.environmentKey].map { URL(fileURLWithPath: $0) }
            ?? GameDataLocation.defaultDirectory(home: URL(fileURLWithPath: NSHomeDirectory()))
        let documents = GameDataLocation.documents(in: container)
        try? fileManager.createDirectory(at: documents, withIntermediateDirectories: true)
        if let userDocuments = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            migrate(from: userDocuments.appending(path: gameFolder), to: documents.appending(path: gameFolder))
        }
        documents.path.withCString(blockport_set_documents_directory)
        redirectFileManager(to: documents)
        Trace.event("data", "documents at \(documents.path)")
        return documents
    }

    /// Moves the game's folder from the user's Documents, once: only when it
    /// exists there and nothing exists at the destination yet.
    static func migrate(from old: URL, to new: URL) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: old.path), !fileManager.fileExists(atPath: new.path) else { return }
        do {
            try fileManager.createDirectory(at: new.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: old, to: new)
            Trace.event("data", "moved \(old.path) to \(new.path)")
        } catch {
            Trace.event("data", "game data not moved: \(error)")
        }
    }

    private static func redirectFileManager(to documents: URL) {
        typealias URLsForDirectory = @convention(c) (FileManager, Selector, UInt, UInt) -> NSArray
        let selector = #selector(FileManager.urls(for:in:))
        let documentDirectory = FileManager.SearchPathDirectory.documentDirectory.rawValue
        let userDomain = FileManager.SearchPathDomainMask.userDomainMask.rawValue
        var original: URLsForDirectory?
        let replacement: @convention(block) (FileManager, UInt, UInt) -> NSArray = { manager, directory, domains in
            if directory == documentDirectory, domains & userDomain != 0 {
                return [documents as NSURL] as NSArray
            }
            return original?(manager, selector, directory, domains) ?? NSArray()
        }
        original = MethodReplacement.replace(selector, on: FileManager.self, with: replacement)
            .map { unsafeBitCast($0, to: URLsForDirectory.self) }
    }
}
