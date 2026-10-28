import Foundation
import Security

/// Identifying attributes of a key; `nil` fields match anything in queries.
struct KeyAttributes: Equatable, Codable {
    var tag: Data?
    var applicationLabel: Data?
    var label: String?
    var keyType: String?
    var keyClass: String?

    init(tag: Data? = nil, applicationLabel: Data? = nil, label: String? = nil, keyType: String? = nil, keyClass: String? = nil) {
        self.tag = tag
        self.applicationLabel = applicationLabel
        self.label = label
        self.keyType = keyType
        self.keyClass = keyClass
    }

    init(_ dictionary: KeychainDictionary) {
        self.init(
            tag: dictionary.bytes(kSecAttrApplicationTag),
            applicationLabel: dictionary.bytes(kSecAttrApplicationLabel),
            label: dictionary.text(kSecAttrLabel),
            keyType: dictionary.text(kSecAttrKeyType),
            keyClass: dictionary.text(kSecAttrKeyClass)
        )
    }

    /// True when every attribute set in `self` equals the one in `stored`.
    func selects(_ stored: KeyAttributes) -> Bool {
        matches(tag, stored.tag)
            && matches(applicationLabel, stored.applicationLabel)
            && matches(label, stored.label)
            && matches(keyType, stored.keyType)
            && matches(keyClass, stored.keyClass)
    }

    private func matches<Value: Equatable>(_ wanted: Value?, _ actual: Value?) -> Bool {
        wanted == nil || wanted == actual
    }
}

struct StoredKey: Equatable, Codable {
    let id: UInt64
    let attributes: KeyAttributes
    var data: Data

    private static let referencePrefix = Data("blockport-key:".utf8)

    var persistentReference: Data {
        Self.referencePrefix + withUnsafeBytes(of: id.bigEndian) { Data($0) }
    }

    static func id(fromPersistentReference reference: Data) -> UInt64? {
        guard reference.starts(with: referencePrefix) else { return nil }
        let bytes = reference.dropFirst(referencePrefix.count)
        guard bytes.count == MemoryLayout<UInt64>.size else { return nil }
        return bytes.reduce(0) { $0 << 8 | UInt64($1) }
    }
}

/// A key request decoded from a `SecItem*` dictionary.
struct KeyQuery: Equatable {
    var attributes: KeyAttributes
    var persistentReference: UInt64?
    var data: Data?
    var options: ResultOptions

    init(attributes: KeyAttributes, persistentReference: UInt64? = nil, data: Data? = nil, options: ResultOptions = ResultOptions()) {
        self.attributes = attributes
        self.persistentReference = persistentReference
        self.data = data
        self.options = options
    }

    /// Decodes a key request, or `nil` for another item class. A request
    /// without `kSecClass` is still a key request when it selects a
    /// persistent reference issued by the store.
    init?(_ dictionary: KeychainDictionary) {
        let reference = dictionary.bytes(kSecValuePersistentRef).flatMap(StoredKey.id(fromPersistentReference:))
        guard reference != nil || dictionary.has(kSecClass, equalTo: kSecClassKey) else { return nil }
        self.init(
            attributes: KeyAttributes(dictionary),
            persistentReference: reference,
            data: dictionary.bytes(kSecValueData),
            options: ResultOptions(dictionary)
        )
    }

    func selects(_ key: StoredKey) -> Bool {
        (persistentReference.map { $0 == key.id } ?? true) && attributes.selects(key.attributes)
    }

    var summary: String {
        let fields: [(String, String?)] = [
            ("tag", attributes.tag.map { String(decoding: $0, as: UTF8.self) }),
            ("klbl", attributes.applicationLabel.map { $0.map { String(format: "%02x", $0) }.joined() }),
            ("labl", attributes.label),
            ("type", attributes.keyType),
            ("kcls", attributes.keyClass),
            ("ref", persistentReference.map(String.init)),
        ]
        return fields.compactMap { name, value in value.map { "\(name)=\($0)" } }.joined(separator: " ")
    }
}

/// Keys added through `SecItemAdd` or generated as permanent pairs.
///
/// Keys cannot be stored through the file-based keychain API from a Catalyst
/// process, so they live in the vault, kept as one login keychain item.
struct KeyStore: Equatable, Codable {
    private(set) var keys: [StoredKey] = []
    private var lastID: UInt64 = 0

    mutating func add(_ query: KeyQuery) throws(KeychainError) -> StoredKey {
        guard let data = query.data else { throw .parameter }
        var identity = query.attributes
        identity.label = nil
        guard !keys.contains(where: { identity.selects($0.attributes) }) else { throw .duplicateItem }
        lastID += 1
        let key = StoredKey(id: lastID, attributes: query.attributes, data: data)
        keys.append(key)
        return key
    }

    func find(_ query: KeyQuery) throws(KeychainError) -> [StoredKey] {
        let found = keys.filter(query.selects).prefix(query.options.all ? Int.max : 1)
        guard !found.isEmpty else { throw .itemNotFound }
        return Array(found)
    }

    mutating func update(_ query: KeyQuery, data: Data?) throws(KeychainError) {
        let indices = keys.indices.filter { query.selects(keys[$0]) }
        guard !indices.isEmpty else { throw .itemNotFound }
        if let data {
            indices.forEach { keys[$0].data = data }
        }
    }

    mutating func delete(_ query: KeyQuery) throws(KeychainError) {
        let count = keys.count
        keys.removeAll(where: query.selects)
        guard keys.count != count else { throw .itemNotFound }
    }

    static func parts(of key: StoredKey, options: ResultOptions) throws(KeychainError) -> ResultParts {
        var parts = ResultParts()
        if options.attributes {
            let values: [(CFString, Any?)] = [
                (kSecClass, kSecClassKey),
                (kSecAttrApplicationTag, key.attributes.tag),
                (kSecAttrApplicationLabel, key.attributes.applicationLabel),
                (kSecAttrLabel, key.attributes.label),
                (kSecAttrKeyType, key.attributes.keyType),
                (kSecAttrKeyClass, key.attributes.keyClass),
            ]
            for case let (name, value?) in values {
                parts.attributes[name as String] = value
            }
        }
        parts.data = key.data
        parts.persistentReference = key.persistentReference
        if options.reference {
            guard let reference = secKey(for: key) else { throw .parameter }
            parts.reference = reference
        }
        return parts
    }

    /// Creates a `SecKey` from the stored DER bytes; defaults to an RSA
    /// public key, the type the game adds.
    static func secKey(for key: StoredKey) -> SecKey? {
        let options: [String: Any] = [
            kSecAttrKeyType as String: key.attributes.keyType ?? (kSecAttrKeyTypeRSA as String),
            kSecAttrKeyClass as String: key.attributes.keyClass ?? (kSecAttrKeyClassPublic as String),
        ]
        return SecKeyCreateWithData(key.data as CFData, options as CFDictionary, nil)
    }
}
