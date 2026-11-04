#ifndef MOBILEBLOX_VERSION_INFO_H
#define MOBILEBLOX_VERSION_INFO_H

#include <stdbool.h>
#include <string.h>
#include "Offsets.h"

typedef enum {
    MobileBloxVersionUnknown = 0,
    MobileBloxVersionMatches,
    MobileBloxVersionMismatch
} MobileBloxVersionStatus;

/*
 * Compares a version string supplied by the app or user.
 * This does not inspect or modify another application's process.
 */
static inline MobileBloxVersionStatus MobileBloxCheckVersion(const char *installedVersion) {
    if (installedVersion == NULL || installedVersion[0] == '\0') {
        return MobileBloxVersionUnknown;
    }

    return strcmp(installedVersion, MOBILEBLOX_TARGET_ROBLOX_VERSION) == 0
        ? MobileBloxVersionMatches
        : MobileBloxVersionMismatch;
}

static inline bool MobileBloxIsTargetVersion(const char *installedVersion) {
    return MobileBloxCheckVersion(installedVersion) == MobileBloxVersionMatches;
}

#endif
