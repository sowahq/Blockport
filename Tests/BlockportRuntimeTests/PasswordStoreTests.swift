import Foundation
import Security
import Testing
@testable import BlockportRuntime

struct PasswordStoreTests {
    private func query(service: String, account: String? = nil, secret: String? = nil, all: Bool = false) -> GenericPasswordQuery {
        var attributes = [KeychainAttribute(tag: GenericPasswordAttribute.service.tag, value: Data(service.utf8))]
        if let account {
            attributes.append(KeychainAttribute(tag: GenericPasswordAttribute.account.tag, value: Data(account.utf8)))
        }
        return GenericPasswordQuery(attributes: attributes, secret: secret.map { Data($0.utf8) }, options: ResultOptions(data: true, all: all))
    }

    @Test func storeFollowsKeychainSemantics() throws {
        var store = PasswordStore()
        try store.add(query(service: "PF", account: "PF_Account", secret: "one"))
        try store.add(query(service: "PF", account: "PF_Account_key", secret: "two"))
        #expect(throws: KeychainError.duplicateItem) { try store.add(query(service: "PF", account: "PF_Account", secret: "x")) }

        #expect(try store.find(query(service: "PF", account: "PF_Account")).map(\.secret) == [Data("one".utf8)])
        #expect(try store.find(query(service: "PF", all: true)).count == 2)
        #expect(throws: KeychainError.itemNotFound) { try store.find(query(service: "missing")) }

        try store.update(query(service: "PF", account: "PF_Account"), changes: GenericPasswordQuery(attributes: [], secret: Data("new".utf8)))
        #expect(try store.find(query(service: "PF", account: "PF_Account")).first?.secret == Data("new".utf8))

        try store.delete(query(service: "PF"))
        #expect(store.items.isEmpty)
        #expect(throws: KeychainError.itemNotFound) { try store.delete(query(service: "PF")) }
    }

    @Test func attributesAreReportedWithTheAccessGroup() throws {
        let item = StoredPassword(
            attributes: [
                KeychainAttribute(tag: GenericPasswordAttribute.account.tag, value: Data("AccessGroupDetection".utf8)),
                KeychainAttribute(tag: GenericPasswordAttribute.generic.tag, value: Data("id".utf8)),
            ],
            secret: Data("secret".utf8)
        )
        let parts = PasswordStore.parts(of: item, options: ResultOptions(attributes: true), accessGroup: "TEAM.com.example")
        #expect(parts.attributes[kSecAttrAccessGroup as String] as? String == "TEAM.com.example")
        #expect(parts.attributes[kSecAttrAccount as String] as? String == "AccessGroupDetection")
        #expect(parts.attributes[kSecAttrGeneric as String] as? Data == Data("id".utf8))
    }

    @Test func vaultSurvivesEncoding() throws {
        var vault = Vault()
        try vault.passwords.add(query(service: "MCPEDeviceID", secret: "id"))
        _ = try vault.keys.add(KeyQuery(attributes: KeyAttributes(label: "com.microsoft.xal.deviceid"), data: Data("key".utf8)))
        #expect(try JSONDecoder().decode(Vault.self, from: JSONEncoder().encode(vault)) == vault)
    }
}
