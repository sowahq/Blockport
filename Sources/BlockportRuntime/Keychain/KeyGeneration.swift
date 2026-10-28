import CryptoKit
import Foundation
import Security

/// Replacement for `SecKeyGeneratePair`.
///
/// The Xbox Live library generates a permanent key pair as its device proof
/// key. Permanent keys need the data protection keychain, so the pair is
/// generated in memory and both halves are recorded in the vault with the
/// attributes the keychain would have assigned, including the application
/// label (SHA-1 of the public key) used to look them up later.
enum KeyGeneration {
    struct Request {
        let parameters: [String: Any]
        let privateAttributes: [String: Any]
        let publicAttributes: [String: Any]

        init(_ dictionary: KeychainDictionary) {
            parameters = dictionary.values
            privateAttributes = dictionary.values[kSecPrivateKeyAttrs as String] as? [String: Any] ?? [:]
            publicAttributes = dictionary.values[kSecPublicKeyAttrs as String] as? [String: Any] ?? [:]
        }

        /// Parameters for `SecKeyCreateRandomKey` without any request to
        /// store the keys.
        var transientParameters: [String: Any] {
            var transient = parameters
            transient[kSecAttrIsPermanent as String] = false
            transient[kSecPrivateKeyAttrs as String] = Self.transient(privateAttributes)
            transient[kSecPublicKeyAttrs as String] = Self.transient(publicAttributes)
            transient.removeValue(forKey: kSecAttrAccessGroup as String)
            transient.removeValue(forKey: kSecAttrTokenID as String)
            return transient
        }

        func isPermanent(_ attributes: [String: Any]) -> Bool {
            (attributes[kSecAttrIsPermanent as String] as? Bool) ?? (parameters[kSecAttrIsPermanent as String] as? Bool) ?? false
        }

        /// Attributes recorded for one half: the half's own attributes over
        /// the shared parameters.
        func storedAttributes(_ half: [String: Any], keyClass: CFString, applicationLabel: Data) -> KeyAttributes {
            let merged = KeychainDictionary(parameters.merging(half) { _, own in own })
            var attributes = KeyAttributes(merged)
            attributes.keyClass = keyClass as String
            attributes.applicationLabel = attributes.applicationLabel ?? applicationLabel
            return attributes
        }

        private static func transient(_ attributes: [String: Any]) -> [String: Any] {
            var transient = attributes
            transient[kSecAttrIsPermanent as String] = false
            transient.removeValue(forKey: kSecAttrAccessGroup as String)
            return transient
        }
    }

    static func generatePair(_ request: Request) throws(KeychainError) -> (publicKey: SecKey, privateKey: SecKey) {
        guard
            let privateKey = SecKeyCreateRandomKey(request.transientParameters as CFDictionary, nil),
            let publicKey = SecKeyCopyPublicKey(privateKey),
            let privateData = SecKeyCopyExternalRepresentation(privateKey, nil) as Data?,
            let publicData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
        else { throw .parameter }

        let applicationLabel = Data(Insecure.SHA1.hash(data: publicData))
        let halves: [([String: Any], CFString, Data)] = [
            (request.privateAttributes, kSecAttrKeyClassPrivate, privateData),
            (request.publicAttributes, kSecAttrKeyClassPublic, publicData),
        ]
        for (attributes, keyClass, data) in halves where request.isPermanent(attributes) {
            let stored = request.storedAttributes(attributes, keyClass: keyClass, applicationLabel: applicationLabel)
            try mutateVault { vault throws(KeychainError) in
                _ = try vault.keys.add(KeyQuery(attributes: stored, data: data))
            }
            Trace.event("keychain", "SecKeyGeneratePair stored \(KeyQuery(attributes: stored).summary)")
        }
        return (publicKey, privateKey)
    }
}

/// Out-parameter type of `SecKeyGeneratePair`.
public typealias KeyResultPointer = UnsafeMutablePointer<Unmanaged<SecKey>?>

@_cdecl("blockport_SecKeyGeneratePair")
public func blockportSecKeyGeneratePair(_ parameters: CFDictionary?, _ publicKey: KeyResultPointer?, _ privateKey: KeyResultPointer?) -> OSStatus {
    publicKey?.pointee = nil
    privateKey?.pointee = nil
    guard let dictionary = KeychainDictionary(parameters) else { return errSecParam }
    do {
        let pair = try KeyGeneration.generatePair(KeyGeneration.Request(dictionary))
        publicKey?.pointee = .passRetained(pair.publicKey)
        privateKey?.pointee = .passRetained(pair.privateKey)
        Trace.event("keychain", "SecKeyGeneratePair -> 0")
        return errSecSuccess
    } catch {
        Trace.event("keychain", "SecKeyGeneratePair -> \(error.status) \(dictionary.values)")
        return error.status
    }
}
