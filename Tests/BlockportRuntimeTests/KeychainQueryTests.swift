import Foundation
import Security
import Testing
@testable import BlockportRuntime

struct KeychainQueryTests {
    @Test(arguments: [
        (ResultOptions(), false),
        (ResultOptions(data: true), false),
        (ResultOptions(reference: true), false),
        (ResultOptions(attributes: true), true),
        (ResultOptions(reference: true, persistentReference: true), true),
    ])
    func dictionaryIsNeededForAttributesOrSeveralRepresentations(options: ResultOptions, expected: Bool) {
        #expect(options.needsDictionary == expected)
    }

    @Test func resultOptionsReadReturnFlagsAndLimit() {
        let dictionary = KeychainDictionary([
            kSecReturnData as String: true,
            kSecReturnPersistentRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ])
        #expect(ResultOptions(dictionary) == ResultOptions(data: true, persistentReference: true, all: true))
    }

    @Test func singleValuesAndDictionariesFollowTheOptions() throws {
        let parts = ResultParts(
            attributes: [kSecAttrService as String: "service"],
            data: Data("secret".utf8),
            persistentReference: Data("reference".utf8)
        )
        #expect(parts.value(for: ResultOptions(data: true)) as? Data == Data("secret".utf8))
        #expect(parts.value(for: ResultOptions()) == nil)

        let dictionary = try #require(parts.value(for: ResultOptions(data: true, attributes: true)) as? [String: Any])
        #expect(dictionary[kSecAttrService as String] as? String == "service")
        #expect(dictionary[kSecValueData as String] as? Data == Data("secret".utf8))
        #expect(dictionary[kSecValuePersistentRef as String] == nil)
    }

    @Test func allMatchesAreReturnedAsAnArray() throws {
        let value = try KeychainResult.value(for: ["a", "b"], options: ResultOptions(data: true, all: true)) { item throws(KeychainError) in
            ResultParts(data: Data(item.utf8))
        }
        #expect(value as? [Data] == [Data("a".utf8), Data("b".utf8)])
    }

    @Test func genericPasswordQueriesDecodeTheirAttributes() {
        let dictionary = KeychainDictionary([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "MCPEDeviceID",
            kSecAttrGeneric as String: "MCPEDeviceID",
            kSecValueData as String: Data("id".utf8),
        ])
        let query = GenericPasswordQuery(dictionary)
        #expect(query?.attributes == [
            KeychainAttribute(tag: fourCharacterCode("svce"), value: Data("MCPEDeviceID".utf8)),
            KeychainAttribute(tag: fourCharacterCode("gena"), value: Data("MCPEDeviceID".utf8)),
        ])
        #expect(query?.secret == Data("id".utf8))
        #expect(GenericPasswordQuery(KeychainDictionary([kSecAttrService as String: "x"])) == nil)
    }

    @Test(arguments: GenericPasswordAttribute.allCases)
    func attributeTagsMatchSecurityKeyNames(attribute: GenericPasswordAttribute) {
        let name = attribute.key as String
        #expect(withUnsafeBytes(of: attribute.tag.bigEndian) { String(decoding: $0, as: UTF8.self) } == name)
    }
}
