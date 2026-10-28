#ifndef BLOCKPORTNATIVE_H
#define BLOCKPORTNATIVE_H

#include <CoreFoundation/CoreFoundation.h>
#include <netdb.h>
#include <stdbool.h>

/// Configures the native replacements from the environment; called once by
/// the library constructor before the runtime starts.
void blockport_native_configure(void);

/// Records that UIKit has delivered the termination callbacks, so the game
/// has saved and a later `exit` can skip static destructors.
void blockport_mark_terminating(void);

/// Exits without running static destructors.
void blockport_exit_now(int status) __attribute__((noreturn));

/// Makes the game's Documents folder `path` from now on.
void blockport_set_documents_directory(const char *path);

/// Foundation's directory lookup, declared without Objective-C headers.
CFArrayRef NSSearchPathForDirectoriesInDomains(unsigned long directory, unsigned long domainMask, bool expandTilde);

CFArrayRef blockport_NSSearchPathForDirectoriesInDomains(unsigned long directory, unsigned long domainMask, bool expandTilde);
int blockport_sched_yield(void);
int blockport_getaddrinfo(const char *node, const char *service, const struct addrinfo *hints, struct addrinfo **result);
void blockport_exit(int status) __attribute__((noreturn));

#endif
