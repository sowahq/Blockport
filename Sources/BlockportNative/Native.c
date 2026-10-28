#include "BlockportNative.h"

#include <mach/mach_time.h>
#include <pthread.h>
#include <sched.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

/// The game's chunk-streaming workers spin on sched_yield between jobs and
/// rarely block, burning over two cores mostly in the kernel. A worker that
/// yields again within `spin_gap` sixteen times in a row sleeps for 50 µs:
/// long enough to free the core, short enough not to delay new jobs.
/// BLOCKPORT_YIELD=spin keeps the original behaviour.
static bool yield_backoff = true;
static uint64_t spin_gap_ticks;
static const uint32_t spin_streak = 16;
static const struct timespec backoff_sleep = {0, 50000};
static const char streaming_pool_prefix[] = "Streaming Pool";

/// The game resolves the placeholder host "Error" every frame when it cannot
/// format a network interface address (seen with VPN tunnels); macOS takes
/// five seconds to fail that lookup, freezing the game.
static const char placeholder_host[] = "Error";

static atomic_bool terminating;

/// The game finds its data folder with NSSearchPathForDirectoriesInDomains;
/// without a sandbox that is the user's own Documents. Only the user-domain
/// Documents lookup is redirected, to the folder set by the runtime.
static const unsigned long document_directory = 9;
static const unsigned long user_domain_mask = 1;
static _Atomic(CFStringRef) documents_path;

void blockport_native_configure(void) {
    const char *mode = getenv("BLOCKPORT_YIELD");
    yield_backoff = !(mode && strcmp(mode, "spin") == 0);
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    spin_gap_ticks = 20000ULL * timebase.denom / timebase.numer;
}

int blockport_sched_yield(void) {
    static __thread struct {
        bool named;
        bool streaming;
        uint32_t streak;
        uint64_t last;
    } thread;
    if (!thread.named) {
        char name[64] = "";
        pthread_getname_np(pthread_self(), name, sizeof(name));
        thread.named = name[0] != 0;
        thread.streaming = strncmp(name, streaming_pool_prefix, sizeof(streaming_pool_prefix) - 1) == 0;
    }
    if (yield_backoff && thread.streaming) {
        uint64_t now = mach_absolute_time();
        thread.streak = now - thread.last < spin_gap_ticks ? thread.streak + 1 : 0;
        thread.last = now;
        if (thread.streak >= spin_streak) {
            nanosleep(&backoff_sleep, NULL);
            thread.last = mach_absolute_time();
            return 0;
        }
    }
    return sched_yield();
}

int blockport_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **result) {
    if (node && strcmp(node, placeholder_host) == 0) {
        return EAI_NONAME;
    }
    return getaddrinfo(node, service, hints, result);
}

void blockport_set_documents_directory(const char *path) {
    CFStringRef value = CFStringCreateWithCString(NULL, path, kCFStringEncodingUTF8);
    CFStringRef previous = atomic_exchange(&documents_path, value);
    if (previous) {
        CFRelease(previous);
    }
}

CFArrayRef blockport_NSSearchPathForDirectoriesInDomains(unsigned long directory, unsigned long domainMask, bool expandTilde) {
    CFStringRef path = atomic_load(&documents_path);
    if (path && directory == document_directory && (domainMask & user_domain_mask)) {
        const void *values[] = {path};
        return CFAutorelease(CFArrayCreate(NULL, values, 1, &kCFTypeArrayCallBacks));
    }
    return NSSearchPathForDirectoriesInDomains(directory, domainMask, expandTilde);
}

void blockport_mark_terminating(void) {
    atomic_store(&terminating, true);
}

void blockport_exit_now(int status) {
    _exit(status);
}

/// After termination the game's still-running threads make static
/// destructors crash and hang in its crash handler, leaving a windowless
/// process behind; the game has already saved by then.
void blockport_exit(int status) {
    if (atomic_load(&terminating)) {
        blockport_exit_now(status);
    }
    exit(status);
}
