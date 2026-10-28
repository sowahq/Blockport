#ifndef CLEGACYKEYCHAIN_H
#define CLEGACYKEYCHAIN_H

#include <CoreFoundation/CoreFoundation.h>

CF_ASSUME_NONNULL_BEGIN

/// The file-based keychain API, declared under new names because the SDK
/// marks it unavailable for Mac Catalyst although Security exports it there.
OSStatus BlockportKeychainCopyDefault(CFTypeRef _Nullable *_Nonnull CF_RETURNS_RETAINED keychain)
    __asm__("_SecKeychainCopyDefault");

OSStatus BlockportKeychainFindGenericPassword(
    CFTypeRef _Nullable keychain,
    UInt32 serviceLength,
    const char *service,
    UInt32 accountLength,
    const char *account,
    UInt32 *_Nullable passwordLength,
    void *_Nullable *_Nullable passwordData,
    CFTypeRef _Nullable *_Nullable CF_RETURNS_RETAINED item)
    __asm__("_SecKeychainFindGenericPassword");

OSStatus BlockportKeychainAddGenericPassword(
    CFTypeRef _Nullable keychain,
    UInt32 serviceLength,
    const char *service,
    UInt32 accountLength,
    const char *account,
    UInt32 passwordLength,
    const void *_Nullable passwordData,
    CFTypeRef _Nullable *_Nullable CF_RETURNS_RETAINED item)
    __asm__("_SecKeychainAddGenericPassword");

OSStatus BlockportKeychainItemModifyAttributesAndData(
    CFTypeRef item,
    const void *_Nullable attributes,
    UInt32 length,
    const void *_Nullable data)
    __asm__("_SecKeychainItemModifyAttributesAndData");

OSStatus BlockportKeychainItemFreeContent(const void *_Nullable attributes, void *_Nullable data)
    __asm__("_SecKeychainItemFreeContent");

CF_ASSUME_NONNULL_END

#endif
