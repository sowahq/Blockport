import Foundation

/// Builds a macOS `.icns` icon from a square PNG.
enum IconConverter {
    /// Point sizes of a macOS icon set; each also has a @2x variant.
    static let pointSizes = [16, 32, 128, 256, 512]

    /// Writes `icns` from `png`, including only the sizes the image can fill
    /// without being enlarged.
    static func makeIcns(from png: URL, to icns: URL, workDirectory: URL) throws {
        let source = try pixelWidth(of: png)
        let iconset = workDirectory.appending(path: "AppIcon.iconset")
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        for (name, pixels) in variants() where pixels <= source {
            let output = iconset.appending(path: "\(name).png")
            try ProcessRunner.run("/usr/bin/sips", ["-z", "\(pixels)", "\(pixels)", png.path, "--out", output.path])
        }
        try ProcessRunner.run("/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o", icns.path])
    }

    static func variants() -> [(name: String, pixels: Int)] {
        pointSizes.flatMap { size in
            [("icon_\(size)x\(size)", size), ("icon_\(size)x\(size)@2x", size * 2)]
        }
    }

    private static func pixelWidth(of png: URL) throws -> Int {
        let output = try ProcessRunner.run("/usr/bin/sips", ["-g", "pixelWidth", png.path])
        guard let width = output.split(whereSeparator: \.isWhitespace).last.flatMap({ Int($0) }) else {
            throw Installer.Failure.invalidApp(String(localized: "unreadable app icon"))
        }
        return width
    }
}
