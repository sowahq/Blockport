import Foundation
import Security

/// A `SecItem*` failure carried as its `OSStatus`.
struct KeychainError: Error, Equatable {
    let status: OSStatus

    static let itemNotFound = KeychainError(status: errSecItemNotFound)
    static let duplicateItem = KeychainError(status: errSecDuplicateItem)
    static let parameter = KeychainError(status: errSecParam)
    static let allocate = KeychainError(status: errSecAllocate)
}

/// A `SecItem*` dictionary bridged to Swift values.
struct KeychainDictionary {
    let values: [String: Any]

    init?(_ dictionary: CFDictionary?) {
        guard let values = dictionary as? [String: Any] else { return nil }
        self.values = values
    }

    init(_ values: [String: Any]) {
        self.values = values
    }

    func has(_ key: CFString, equalTo value: CFString) -> Bool {
        (values[key as String] as? String) == value as String
    }

    func flag(_ key: CFString) -> Bool {
        (values[key as String] as? Bool) ?? false
    }

    /// The bytes of a string (UTF-8) or data value.
    func bytes(_ key: CFString) -> Data? {
        switch values[key as String] {
        case let data as Data: data
        case let string as String: Data(string.utf8)
        default: nil
        }
    }

    /// The text of a string value, or the description of a number.
    func text(_ key: CFString) -> String? {
        switch values[key as String] {
        case let string as String: string
        case let number as NSNumber: number.stringValue
        default: nil
        }
    }
}

/// Which representations `SecItemCopyMatching` or `SecItemAdd` must return.
struct ResultOptions: Equatable {
    var data = false
    var attributes = false
    var reference = false
    var persistentReference = false
    var all = false

    init(data: Bool = false, attributes: Bool = false, reference: Bool = false, persistentReference: Bool = false, all: Bool = false) {
        self.data = data
        self.attributes = attributes
        self.reference = reference
        self.persistentReference = persistentReference
        self.all = all
    }

    init(_ dictionary: KeychainDictionary) {
        data = dictionary.flag(kSecReturnData)
        attributes = dictionary.flag(kSecReturnAttributes)
        reference = dictionary.flag(kSecReturnRef)
        persistentReference = dictionary.flag(kSecReturnPersistentRef)
        all = dictionary.has(kSecMatchLimit, equalTo: kSecMatchLimitAll)
    }

    /// True when the Security framework answers with an attribute dictionary:
    /// attributes were requested, or more than one representation.
    var needsDictionary: Bool {
        attributes || [data, reference, persistentReference].filter { $0 }.count > 1
    }
}

/// The representations of one matched item.
struct ResultParts {
    var attributes: [String: Any] = [:]
    var data: Data?
    var reference: AnyObject?
    var persistentReference: Data?

    func value(for options: ResultOptions) -> AnyObject? {
        guard options.needsDictionary else {
            if options.data { return data as NSData? }
            if options.reference { return reference }
            if options.persistentReference { return persistentReference as NSData? }
            return nil
        }
        var dictionary = options.attributes ? attributes : [:]
        if options.data { dictionary[kSecValueData as String] = data }
        if options.reference { dictionary[kSecValueRef as String] = reference }
        if options.persistentReference { dictionary[kSecValuePersistentRef as String] = persistentReference }
        return dictionary as NSDictionary
    }
}

enum KeychainResult {
    /// The `SecItemCopyMatching` value for matched items: an array when all
    /// matches were requested, otherwise the first item's value.
    static func value<Item>(
        for items: [Item],
        options: ResultOptions,
        parts: (Item) throws(KeychainError) -> ResultParts
    ) throws(KeychainError) -> AnyObject? {
        guard options.all else {
            guard let first = items.first else { return nil }
            return try parts(first).value(for: options)
        }
        var values: [AnyObject] = []
        for item in items {
            if let value = try parts(item).value(for: options) {
                values.append(value)
            }
        }
        return values as NSArray
    }
}
