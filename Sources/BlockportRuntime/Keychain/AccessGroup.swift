import Foundation

/// The keychain access group reported back to the game.
///
/// The login keychain has no access groups, but the game and its Xbox Live
/// library read `kSecAttrAccessGroup` from returned attributes to learn
/// their Team ID prefix. The installer records the original
/// `application-identifier` entitlement in the bundle's Info.plist.
enum AccessGroup {
    static let infoKey = "BlockportApplicationIdentifier"

    static let applicationDefault: String? = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String
}
