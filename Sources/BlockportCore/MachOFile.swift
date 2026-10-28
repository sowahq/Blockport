import Foundation

/// A thin 64-bit Mach-O binary, edited in memory.
public struct MachOFile {
    public enum Failure: Error, Equatable {
        case notThin64Bit
        case truncated
        case missingBuildVersion
        case insufficientHeaderSpace(needed: Int, available: Int)
    }

    /// `LC_BUILD_VERSION` platform identifiers.
    public enum Platform: UInt32 {
        case iOS = 2
        case macCatalyst = 6
    }

    private enum LoadCommand {
        static let segment64: UInt32 = 0x19
        static let loadDylib: UInt32 = 0xC
        static let buildVersion: UInt32 = 0x32
        static let encryptionInfo64: UInt32 = 0x2C
        static let versionMinIPhoneOS: UInt32 = 0x25
    }

    private static let magic64: UInt32 = 0xFEED_FACF
    private static let headerSize = 32
    private static let numberOfCommandsOffset = 16
    private static let sizeOfCommandsOffset = 20
    private static let segmentHeaderSize = 72
    private static let sectionSize = 80
    private static let sectionOffsetField = 48
    private static let dylibCommandSize = 24
    private static let pointerAlignment = 8
    private static let versionMinSize = 16
    private static let buildVersionSize = 24

    public private(set) var data: Data

    public init(data: Data) throws {
        guard data.count >= Self.headerSize else { throw Failure.truncated }
        self.data = data
        guard read(at: 0) == Self.magic64 else { throw Failure.notThin64Bit }
    }

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    /// Writes the binary over `url`, keeping the file's permissions (and so
    /// its executable bit).
    public func save(to url: URL) throws {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        try data.write(to: url)
        if let permissions = attributes?[.posixPermissions] {
            try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
        }
    }

    /// True when `data` starts with the thin 64-bit Mach-O magic.
    public static func isThin64Bit(_ data: Data) -> Bool {
        data.count >= 4 && data.prefix(4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) } == magic64
    }

    public var platform: Platform? {
        buildVersionOffset.flatMap { Platform(rawValue: read(at: $0 + 8)) }
    }

    public var minimumOS: UInt32? {
        buildVersionOffset.map { read(at: $0 + 12) }
    }

    /// True when an `LC_ENCRYPTION_INFO_64` command reports FairPlay
    /// encryption (`cryptid` set).
    public var isEncrypted: Bool {
        commands.contains { $0.command == LoadCommand.encryptionInfo64 && read(at: $0.offset + 16) != 0 }
    }

    /// Paths of the dynamic libraries the binary loads.
    public var dylibs: [String] {
        commands.filter { $0.command == LoadCommand.loadDylib }.compactMap { command in
            let nameOffset = Int(read(at: command.offset + 8))
            let bytes = data[(command.offset + nameOffset)..<(command.offset + Int(command.size))]
            return String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8)
        }
    }

    /// Sets the platform in `LC_BUILD_VERSION`, keeping the SDK version. A
    /// legacy `LC_VERSION_MIN_IPHONEOS` is converted to `LC_BUILD_VERSION`,
    /// using 8 bytes of the free space after the load commands.
    public mutating func setPlatform(_ platform: Platform, minimumOS: UInt32) throws {
        if let offset = buildVersionOffset {
            write(platform.rawValue, at: offset + 8)
            write(minimumOS, at: offset + 12)
            return
        }
        guard let versionMin = commands.first(where: { $0.command == LoadCommand.versionMinIPhoneOS }) else {
            throw Failure.missingBuildVersion
        }
        let growth = Self.buildVersionSize - Self.versionMinSize
        let commandsEnd = Self.headerSize + Int(read(at: Self.sizeOfCommandsOffset))
        let available = firstSectionOffset - commandsEnd
        guard growth <= available else { throw Failure.insufficientHeaderSpace(needed: growth, available: available) }

        let sdk = read(at: versionMin.offset + 12)
        var buildVersion = Data()
        for value in [LoadCommand.buildVersion, UInt32(Self.buildVersionSize), platform.rawValue, minimumOS, sdk, 0] {
            withUnsafeBytes(of: value.littleEndian) { buildVersion.append(contentsOf: $0) }
        }
        let following = data[(versionMin.offset + Self.versionMinSize)..<commandsEnd]
        data.replaceSubrange(versionMin.offset..<(commandsEnd + growth), with: buildVersion + following)
        write(read(at: Self.sizeOfCommandsOffset) + UInt32(growth), at: Self.sizeOfCommandsOffset)
    }

    /// Appends an `LC_LOAD_DYLIB` command for `path` in the free space after
    /// the load commands, unless the binary already loads it.
    public mutating func addDylib(_ path: String) throws {
        guard !dylibs.contains(path) else { return }
        var name = Array(path.utf8) + [0]
        let size = (Self.dylibCommandSize + name.count + Self.pointerAlignment - 1) / Self.pointerAlignment * Self.pointerAlignment
        name += Array(repeating: 0, count: size - Self.dylibCommandSize - name.count)
        let commandsEnd = Self.headerSize + Int(read(at: Self.sizeOfCommandsOffset))
        let available = firstSectionOffset - commandsEnd
        guard size <= available else { throw Failure.insufficientHeaderSpace(needed: size, available: available) }

        var command = Data()
        for value in [LoadCommand.loadDylib, UInt32(size), UInt32(Self.dylibCommandSize), 2, 0x1_0000, 0x1_0000] {
            withUnsafeBytes(of: value.littleEndian) { command.append(contentsOf: $0) }
        }
        command.append(contentsOf: name)
        data.replaceSubrange(commandsEnd..<(commandsEnd + size), with: command)
        write(read(at: Self.numberOfCommandsOffset) + 1, at: Self.numberOfCommandsOffset)
        write(read(at: Self.sizeOfCommandsOffset) + UInt32(size), at: Self.sizeOfCommandsOffset)
    }

    private var commands: [(command: UInt32, offset: Int, size: UInt32)] {
        var result: [(UInt32, Int, UInt32)] = []
        var offset = Self.headerSize
        for _ in 0..<read(at: Self.numberOfCommandsOffset) {
            guard offset + 8 <= data.count else { break }
            let size = read(at: offset + 4)
            result.append((read(at: offset), offset, size))
            offset += Int(size)
        }
        return result
    }

    private var buildVersionOffset: Int? {
        commands.first { $0.command == LoadCommand.buildVersion }?.offset
    }

    /// The file offset of the first section with contents: load commands may
    /// grow up to it.
    private var firstSectionOffset: Int {
        let offsets = commands.filter { $0.command == LoadCommand.segment64 }.flatMap { segment in
            let count = Int(read(at: segment.offset + 64))
            return (0..<count).map { index in
                Int(read(at: segment.offset + Self.segmentHeaderSize + index * Self.sectionSize + Self.sectionOffsetField))
            }
        }
        return offsets.filter { $0 > 0 }.min() ?? data.count
    }

    private func read(at offset: Int) -> UInt32 {
        data[offset..<(offset + 4)].withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
    }

    private mutating func write(_ value: UInt32, at offset: Int) {
        withUnsafeBytes(of: value.littleEndian) { data.replaceSubrange(offset..<(offset + 4), with: $0) }
    }
}
