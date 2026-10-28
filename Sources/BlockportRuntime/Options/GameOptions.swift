import Foundation

/// The game's `options.txt`: one `key:value` pair per line.
struct GameOptions: Equatable {
    private(set) var lines: [String]

    init(text: String) {
        lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.last == "" { lines.removeLast() }
    }

    var text: String {
        lines.joined(separator: "\n") + "\n"
    }

    func value(_ key: String) -> String? {
        lines.lazy.compactMap { Self.split($0) }.first { $0.key == key }?.value
    }

    /// Sets `key` to `value`, replacing an existing line or appending one.
    mutating func set(_ key: String, to value: String) {
        let line = "\(key):\(value)"
        if let index = lines.firstIndex(where: { Self.split($0)?.key == key }) {
            lines[index] = line
        } else {
            lines.append(line)
        }
    }

    private static func split(_ line: String) -> (key: String, value: String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        return (String(line[..<colon]), String(line[line.index(after: colon)...]))
    }
}
