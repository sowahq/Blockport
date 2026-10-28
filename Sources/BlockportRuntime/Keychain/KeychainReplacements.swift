import Foundation
import Security

/// Out-parameter type of `SecItemAdd` and `SecItemCopyMatching`.
public typealias KeychainResultPointer = UnsafeMutablePointer<Unmanaged<AnyObject>?>

/// Replacements for the four `SecItem*` functions, installed through the
/// dyld interpose table in `BlockportInterpose`.
///
/// Generic passwords and keys live in the vault, saved as one login keychain
/// item. Other item classes are forwarded unchanged.
enum KeychainReplacements {
    static func add(_ attributes: CFDictionary?, _ result: KeychainResultPointer?) -> OSStatus {
        result?.pointee = nil
        guard let dictionary = KeychainDictionary(attributes) else { return forwardAdd(attributes, result) }
        if let query = GenericPasswordQuery(dictionary) {
            return report("SecItemAdd[genp]", query.summary) { () throws(KeychainError) in
                try mutateVault { vault throws(KeychainError) in try vault.passwords.add(query) }
            }
        }
        if let query = KeyQuery(dictionary) {
            return report("SecItemAdd[keys]", query.summary) { () throws(KeychainError) in
                let key = try mutateVault { vault throws(KeychainError) in try vault.keys.add(query) }
                try write(KeychainResult.value(for: [key], options: query.options, parts: { key throws(KeychainError) in
                    try KeyStore.parts(of: key, options: query.options)
                }), to: result)
            }
        }
        return forwardAdd(attributes, result)
    }

    static func copyMatching(_ query: CFDictionary?, _ result: KeychainResultPointer?) -> OSStatus {
        result?.pointee = nil
        guard let dictionary = KeychainDictionary(query) else { return forwardCopyMatching(query, result) }
        if let decoded = GenericPasswordQuery(dictionary) {
            return report("SecItemCopyMatching[genp]", decoded.summary) { () throws(KeychainError) in
                let items = try readVault { vault throws(KeychainError) in try vault.passwords.find(decoded) }
                let accessGroup = decoded.accessGroup ?? AccessGroup.applicationDefault
                try write(KeychainResult.value(for: items, options: decoded.options, parts: { item throws(KeychainError) in
                    PasswordStore.parts(of: item, options: decoded.options, accessGroup: accessGroup)
                }), to: result)
            }
        }
        if let decoded = KeyQuery(dictionary) {
            return report("SecItemCopyMatching[keys]", decoded.summary) { () throws(KeychainError) in
                let keys = try readVault { vault throws(KeychainError) in try vault.keys.find(decoded) }
                try write(KeychainResult.value(for: keys, options: decoded.options, parts: { key throws(KeychainError) in
                    try KeyStore.parts(of: key, options: decoded.options)
                }), to: result)
            }
        }
        return forwardCopyMatching(query, result)
    }

    static func update(_ query: CFDictionary?, _ changes: CFDictionary?) -> OSStatus {
        guard let dictionary = KeychainDictionary(query), let changes, let changeDictionary = KeychainDictionary(changes) else {
            return forwardUpdate(query, changes)
        }
        if let decoded = GenericPasswordQuery(dictionary) {
            let update = GenericPasswordQuery(attributes: GenericPasswordQuery.attributes(of: changeDictionary), secret: changeDictionary.bytes(kSecValueData))
            return report("SecItemUpdate[genp]", decoded.summary) { () throws(KeychainError) in
                try mutateVault { vault throws(KeychainError) in try vault.passwords.update(decoded, changes: update) }
            }
        }
        if let decoded = KeyQuery(dictionary) {
            return report("SecItemUpdate[keys]", decoded.summary) { () throws(KeychainError) in
                try mutateVault { vault throws(KeychainError) in
                    try vault.keys.update(decoded, data: changeDictionary.bytes(kSecValueData))
                }
            }
        }
        return forwardUpdate(query, changes)
    }

    static func delete(_ query: CFDictionary?) -> OSStatus {
        guard let dictionary = KeychainDictionary(query) else { return forwardDelete(query) }
        if let decoded = GenericPasswordQuery(dictionary) {
            return report("SecItemDelete[genp]", decoded.summary) { () throws(KeychainError) in
                try mutateVault { vault throws(KeychainError) in try vault.passwords.delete(decoded) }
            }
        }
        if let decoded = KeyQuery(dictionary) {
            return report("SecItemDelete[keys]", decoded.summary) { () throws(KeychainError) in
                try mutateVault { vault throws(KeychainError) in try vault.keys.delete(decoded) }
            }
        }
        return forwardDelete(query)
    }

    private static func write(_ value: AnyObject?, to result: KeychainResultPointer?) {
        guard let result, let value else { return }
        result.pointee = .passRetained(value)
    }

    private static func report(_ function: String, _ summary: String, _ body: () throws(KeychainError) -> Void) -> OSStatus {
        let status: OSStatus
        do {
            try body()
            status = errSecSuccess
        } catch {
            status = error.status
        }
        Trace.event("keychain", "\(function) -> \(status) \(summary)")
        return status
    }

    private static func forwardAdd(_ attributes: CFDictionary?, _ result: KeychainResultPointer?) -> OSStatus {
        guard let attributes else { return errSecParam }
        return forwarded("SecItemAdd", attributes, result) { SecItemAdd(attributes, $0) }
    }

    private static func forwardCopyMatching(_ query: CFDictionary?, _ result: KeychainResultPointer?) -> OSStatus {
        guard let query else { return errSecParam }
        return forwarded("SecItemCopyMatching", query, result) { SecItemCopyMatching(query, $0) }
    }

    private static func forwardUpdate(_ query: CFDictionary?, _ changes: CFDictionary?) -> OSStatus {
        guard let query, let changes else { return errSecParam }
        let status = SecItemUpdate(query, changes)
        Trace.event("keychain", "SecItemUpdate -> \(status) \(query)")
        return status
    }

    private static func forwardDelete(_ query: CFDictionary?) -> OSStatus {
        guard let query else { return errSecParam }
        let status = SecItemDelete(query)
        Trace.event("keychain", "SecItemDelete -> \(status) \(query)")
        return status
    }

    private static func forwarded(
        _ function: String,
        _ dictionary: CFDictionary,
        _ result: KeychainResultPointer?,
        _ call: (UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    ) -> OSStatus {
        var value: CFTypeRef?
        let status = result == nil ? call(nil) : call(&value)
        write(value, to: result)
        Trace.event("keychain", "\(function) -> \(status) \(dictionary)")
        return status
    }
}

@_cdecl("blockport_SecItemAdd")
public func blockportSecItemAdd(_ attributes: CFDictionary?, _ result: KeychainResultPointer?) -> OSStatus {
    KeychainReplacements.add(attributes, result)
}

@_cdecl("blockport_SecItemCopyMatching")
public func blockportSecItemCopyMatching(_ query: CFDictionary?, _ result: KeychainResultPointer?) -> OSStatus {
    KeychainReplacements.copyMatching(query, result)
}

@_cdecl("blockport_SecItemUpdate")
public func blockportSecItemUpdate(_ query: CFDictionary?, _ changes: CFDictionary?) -> OSStatus {
    KeychainReplacements.update(query, changes)
}

@_cdecl("blockport_SecItemDelete")
public func blockportSecItemDelete(_ query: CFDictionary?) -> OSStatus {
    KeychainReplacements.delete(query)
}
