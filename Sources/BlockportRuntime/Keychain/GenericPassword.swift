import Foundation
import Security

/// One attribute of a generic password, keyed by its four-character tag.
struct KeychainAttribute: Equatable, Codable {
    let tag: UInt32
    let value: Data
}

/// Generic password attributes the store understands.
enum GenericPasswordAttribute: CaseIterable {
    case service, account, generic, label, description, comment

    var key: CFString {
        switch self {
        case .service: kSecAttrService
        case .account: kSecAttrAccount
        case .generic: kSecAttrGeneric
        case .label: kSecAttrLabel
        case .description: kSecAttrDescription
        case .comment: kSecAttrComment
        }
    }

    /// The four-character tag, identical to the key name.
    var tag: UInt32 { fourCharacterCode(key as String) }

    var isData: Bool { self == .generic }

    func value(from bytes: Data) -> Any {
        isData ? bytes : String(decoding: bytes, as: UTF8.self)
    }
}

/// A generic password request decoded from a `SecItem*` dictionary.
struct GenericPasswordQuery: Equatable {
    var attributes: [KeychainAttribute]
    var secret: Data?
    var accessGroup: String?
    var options: ResultOptions

    init(attributes: [KeychainAttribute], secret: Data? = nil, accessGroup: String? = nil, options: ResultOptions = ResultOptions()) {
        self.attributes = attributes
        self.secret = secret
        self.accessGroup = accessGroup
        self.options = options
    }

    /// Decodes a generic password request, or `nil` for another item class.
    init?(_ dictionary: KeychainDictionary) {
        guard dictionary.has(kSecClass, equalTo: kSecClassGenericPassword) else { return nil }
        self.init(
            attributes: Self.attributes(of: dictionary),
            secret: dictionary.bytes(kSecValueData),
            accessGroup: dictionary.text(kSecAttrAccessGroup),
            options: ResultOptions(dictionary)
        )
    }

    static func attributes(of dictionary: KeychainDictionary) -> [KeychainAttribute] {
        GenericPasswordAttribute.allCases.compactMap { attribute in
            dictionary.bytes(attribute.key).map { KeychainAttribute(tag: attribute.tag, value: $0) }
        }
    }

    var summary: String {
        attributes.map { attribute in
            let tag = withUnsafeBytes(of: attribute.tag.bigEndian) { String(decoding: $0, as: UTF8.self) }
            return "\(tag)=\(String(decoding: attribute.value, as: UTF8.self))"
        }.joined(separator: " ")
    }
}

/// The big-endian `FourCharCode` of a four-character ASCII string.
func fourCharacterCode(_ text: String) -> UInt32 {
    text.utf8.reduce(0) { $0 << 8 | UInt32($1) }
}
