import Foundation
import Security
import Testing
@testable import BlockportRuntime

struct KeyStoreTests {
    private func query(tag: String, data: String? = nil) -> KeyQuery {
        KeyQuery(attributes: KeyAttributes(tag: Data(tag.utf8), keyType: "42"), data: data.map { Data($0.utf8) })
    }

    @Test func storeFollowsKeychainSemantics() throws {
        var store = KeyStore()
        let first = try store.add(query(tag: "a", data: "one"))
        #expect(throws: KeychainError.duplicateItem) { try store.add(query(tag: "a", data: "two")) }
        #expect(throws: KeychainError.parameter) { try store.add(query(tag: "b")) }

        #expect(try store.find(query(tag: "a")) == [first])
        #expect(throws: KeychainError.itemNotFound) { try store.find(query(tag: "missing")) }

        let byReference = KeyQuery(attributes: KeyAttributes(), persistentReference: StoredKey.id(fromPersistentReference: first.persistentReference))
        #expect(try store.find(byReference) == [first])

        try store.update(query(tag: "a"), data: Data("new".utf8))
        #expect(try store.find(query(tag: "a")).first?.data == Data("new".utf8))

        try store.delete(query(tag: "a"))
        #expect(throws: KeychainError.itemNotFound) { try store.delete(query(tag: "a")) }
    }

    @Test func storeSurvivesEncoding() throws {
        var store = KeyStore()
        _ = try store.add(query(tag: "device", data: "key"))
        let decoded = try JSONDecoder().decode(KeyStore.self, from: JSONEncoder().encode(store))
        #expect(decoded.keys == store.keys)
        var next = decoded
        #expect(try next.add(query(tag: "other", data: "key")).id == 2)
    }

    @Test(arguments: [
        (Data("blockport-key:".utf8) + Data([0, 0, 0, 0, 0, 0, 0, 7]), UInt64?.some(7)),
        (Data("blockport-key:".utf8) + Data([7]), nil),
        (Data("other:".utf8) + Data([0, 0, 0, 0, 0, 0, 0, 7]), nil),
    ])
    func persistentReferencesRoundTrip(reference: Data, expected: UInt64?) {
        #expect(StoredKey.id(fromPersistentReference: reference) == expected)
    }

    @Test func classlessQueriesSelectIssuedPersistentReferences() {
        let issued = StoredKey(id: 1, attributes: KeyAttributes(), data: Data()).persistentReference
        let cases: [(Data, UInt64?)] = [(issued, 1), (Data("genp-reference".utf8), nil)]
        for (reference, expected) in cases {
            let decoded = KeyQuery(KeychainDictionary([kSecValuePersistentRef as String: reference]))
            #expect(decoded?.persistentReference == expected)
        }
    }

    @Test func rsaPublicKeysBecomeReferences() throws {
        let url = try #require(Bundle.module.url(forResource: "rsa_public_key", withExtension: "der", subdirectory: "Fixtures"))
        let key = StoredKey(id: 1, attributes: KeyAttributes(keyType: "42"), data: try Data(contentsOf: url))
        #expect(KeyStore.secKey(for: key) != nil)
        #expect(KeyStore.secKey(for: StoredKey(id: 2, attributes: KeyAttributes(), data: Data("bad".utf8))) == nil)
    }
}
