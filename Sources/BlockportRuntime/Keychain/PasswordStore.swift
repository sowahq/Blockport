import Foundation
import Security

/// A generic password held in the vault.
struct StoredPassword: Equatable, Codable {
    var attributes: [KeychainAttribute]
    var secret: Data

    func value(of attribute: GenericPasswordAttribute) -> Data? {
        attributes.first { $0.tag == attribute.tag }?.value
    }

    /// The uniqueness key of a generic password: its service and account.
    var identity: [Data?] {
        [value(of: .service) ?? Data(), value(of: .account) ?? Data()]
    }
}

/// Generic passwords added by the game, held in the vault.
struct PasswordStore: Equatable, Codable {
    private(set) var items: [StoredPassword] = []

    mutating func add(_ query: GenericPasswordQuery) throws(KeychainError) {
        let item = StoredPassword(attributes: query.attributes, secret: query.secret ?? Data())
        guard !items.contains(where: { $0.identity == item.identity }) else { throw .duplicateItem }
        items.append(item)
    }

    func find(_ query: GenericPasswordQuery) throws(KeychainError) -> [StoredPassword] {
        let found = items.filter { Self.selects(query, $0) }.prefix(query.options.all ? Int.max : 1)
        guard !found.isEmpty else { throw .itemNotFound }
        return Array(found)
    }

    mutating func update(_ query: GenericPasswordQuery, changes: GenericPasswordQuery) throws(KeychainError) {
        let indices = items.indices.filter { Self.selects(query, items[$0]) }
        guard !indices.isEmpty else { throw .itemNotFound }
        for index in indices {
            for change in changes.attributes {
                items[index].attributes.removeAll { $0.tag == change.tag }
                items[index].attributes.append(change)
            }
            if let secret = changes.secret {
                items[index].secret = secret
            }
        }
    }

    mutating func delete(_ query: GenericPasswordQuery) throws(KeychainError) {
        let count = items.count
        items.removeAll { Self.selects(query, $0) }
        guard items.count != count else { throw .itemNotFound }
    }

    static func parts(of item: StoredPassword, options: ResultOptions, accessGroup: String?) -> ResultParts {
        var parts = ResultParts(data: item.secret)
        guard options.attributes else { return parts }
        parts.attributes[kSecClass as String] = kSecClassGenericPassword
        parts.attributes[kSecAttrAccessGroup as String] = accessGroup
        for attribute in GenericPasswordAttribute.allCases {
            if let value = item.value(of: attribute) {
                parts.attributes[attribute.key as String] = attribute.value(from: value)
            }
        }
        return parts
    }

    private static func selects(_ query: GenericPasswordQuery, _ item: StoredPassword) -> Bool {
        query.attributes.allSatisfy { wanted in item.attributes.contains(wanted) }
    }
}
