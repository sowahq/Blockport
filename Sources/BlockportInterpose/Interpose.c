#include <Security/SecItem.h>
#include <Security/SecKey.h>
#include <TargetConditionals.h>
#include <os/proc.h>
#include <sched.h>
#include <stdlib.h>

extern OSStatus blockport_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result);
extern OSStatus blockport_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result);
extern OSStatus blockport_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate);
extern OSStatus blockport_SecItemDelete(CFDictionaryRef query);
extern size_t blockport_os_proc_available_memory(void);
extern OSStatus blockport_SecKeyGeneratePair(CFDictionaryRef parameters, SecKeyRef *publicKey, SecKeyRef *privateKey);
#include "BlockportInterpose.h"
#include "BlockportNative.h"

typedef struct {
    const void *replacement;
    const void *original;
} Interpose;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
__attribute__((used, section("__DATA,__interpose")))
static const Interpose interposers[] = {
    {(const void *)blockport_SecItemAdd, (const void *)SecItemAdd},
    {(const void *)blockport_SecItemCopyMatching, (const void *)SecItemCopyMatching},
    {(const void *)blockport_SecItemUpdate, (const void *)SecItemUpdate},
    {(const void *)blockport_SecItemDelete, (const void *)SecItemDelete},
    {(const void *)blockport_SecKeyGeneratePair, (const void *)SecKeyGeneratePair},
    {(const void *)blockport_sched_yield, (const void *)sched_yield},
    {(const void *)blockport_getaddrinfo, (const void *)getaddrinfo},
    {(const void *)blockport_exit, (const void *)exit},
    {(const void *)blockport_NSSearchPathForDirectoriesInDomains, (const void *)NSSearchPathForDirectoriesInDomains},
#if TARGET_OS_MACCATALYST
    {(const void *)blockport_os_proc_available_memory, (const void *)os_proc_available_memory},
#endif
};
#pragma clang diagnostic pop

__attribute__((constructor))
static void start(void) {
    blockport_native_configure();
    blockport_runtime_start();
}
