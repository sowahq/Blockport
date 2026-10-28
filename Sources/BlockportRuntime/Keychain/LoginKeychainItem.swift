import CLegacyKeychain
import Foundation
import Security

/// One generic password in the login keychain, read and written through the
/// file-based keychain API.
///
/// In a Catalyst process without a Team ID every `SecItem*` call targets the
/// data protection keychain and fails with `errSecMissingEntitlement`, even
/// when the login keychain is named explicitly. The `SecKeychain*` API still
/// reaches the login keychain.
///
/// `@unchecked Sendable`: the state is immutable, and the `SecKeychain*` API is
/// thread-safe.
struct LoginKeychainItem: @unchecked Sendable {
    let service: String
    let account: String
    private let keychain: CFTypeRef?

    /// The item `service`/`account` in the default (login) keychain, named
    /// explicitly so lookups do not depend on the keychain search list.
    init(service: String, account: String) {
        self.service = service
        self.account = account
        var keychain: CFTypeRef?
        let status = BlockportKeychainCopyDefault(&keychain)
        if status != errSecSuccess { Trace.event("keychain", "SecKeychainCopyDefault -> \(status)") }
        self.keychain = keychain
    }

    func read() throws(KeychainError) -> Data {
        var length: UInt32 = 0
        var data: UnsafeMutableRawPointer?
        try check(find(length: &length, data: &data, item: nil))
        defer { BlockportKeychainItemFreeContent(nil, data) }
        return data.map { Data(bytes: $0, count: Int(length)) } ?? Data()
    }

    /// Replaces the item's secret, creating the item when it does not exist.
    func write(_ secret: Data) throws(KeychainError) {
        var item: CFTypeRef?
        let found = find(length: nil, data: nil, item: &item)
        let status = secret.withUnsafeBytes { bytes in
            if found == errSecSuccess, let item {
                return BlockportKeychainItemModifyAttributesAndData(item, nil, UInt32(bytes.count), bytes.baseAddress)
            }
            return withNames { service, serviceLength, account, accountLength in
                BlockportKeychainAddGenericPassword(keychain, serviceLength, service, accountLength, account, UInt32(bytes.count), bytes.baseAddress, nil)
            }
        }
        try check(status)
    }

    private func find(length: UnsafeMutablePointer<UInt32>?, data: UnsafeMutablePointer<UnsafeMutableRawPointer?>?, item: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        withNames { service, serviceLength, account, accountLength in
            BlockportKeychainFindGenericPassword(keychain, serviceLength, service, accountLength, account, length, data, item)
        }
    }

    private func withNames<Result>(_ body: (UnsafePointer<CChar>, UInt32, UnsafePointer<CChar>, UInt32) -> Result) -> Result {
        service.withCString { service in
            account.withCString { account in
                body(service, UInt32(strlen(service)), account, UInt32(strlen(account)))
            }
        }
    }

    private func check(_ status: OSStatus) throws(KeychainError) {
        if status != errSecSuccess { throw KeychainError(status: status) }
    }
}
