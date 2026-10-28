import Foundation
import Synchronization

/// Every secret the game stores, kept in memory and saved as a single item
/// in the login keychain.
///
/// One item means macOS asks at most once for keychain access when the app's
/// signature changes, instead of once per secret, and the game's frequent
/// keychain calls never leave the process.
struct Vault: Equatable, Codable {
    var passwords = PasswordStore()
    var keys = KeyStore()
}

let sharedVault = Mutex(VaultPersistence.load())

/// Reads the shared vault.
func readVault<Result>(_ body: (Vault) throws(KeychainError) -> Result) throws(KeychainError) -> Result {
    try sharedVault.withLock { vault throws(KeychainError) in try body(vault) }
}

/// Changes the shared vault and saves it when it changed.
func mutateVault<Result>(_ body: (inout Vault) throws(KeychainError) -> Result) throws(KeychainError) -> Result {
    try sharedVault.withLock { vault throws(KeychainError) in
        let before = vault
        let result = try body(&vault)
        if vault != before {
            VaultPersistence.save(vault)
        }
        return result
    }
}

/// Loads and saves the vault as one generic password in the login keychain.
enum VaultPersistence {
    static let item = LoginKeychainItem(service: "blockport.vault", account: "vault")

    static func load() -> Vault {
        let data: Data
        do {
            data = try item.read()
        } catch {
            if error != .itemNotFound { Trace.event("keychain", "vault not loaded: \(error.status)") }
            return Vault()
        }
        guard let vault = try? JSONDecoder().decode(Vault.self, from: data) else {
            Trace.event("keychain", "vault unreadable, starting empty")
            return Vault()
        }
        return vault
    }

    static func save(_ vault: Vault) {
        do {
            try item.write(JSONEncoder().encode(vault))
        } catch let error as KeychainError {
            Trace.event("keychain", "vault not saved: \(error.status)")
        } catch {
            Trace.event("keychain", "vault not encoded: \(error)")
        }
    }
}
