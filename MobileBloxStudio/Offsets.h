#ifndef MOBILEBLOX_OFFSETS_H
#define MOBILEBLOX_OFFSETS_H

/*
 * Version metadata only.
 * This header intentionally contains no Roblox memory addresses,
 * executable patch data, or injection definitions.
 */

#define MOBILEBLOX_TARGET_ROBLOX_VERSION "2745.1338"
#define MOBILEBLOX_OFFSETS_PROFILE_NAME "metadata-only"
#define MOBILEBLOX_OFFSETS_PROFILE_VERIFIED 0

typedef struct {
    const char *version;
    const char *profileName;
    int isVerified;
} MobileBloxOffsetsProfile;

static const MobileBloxOffsetsProfile MobileBloxCurrentProfile = {
    MOBILEBLOX_TARGET_ROBLOX_VERSION,
    MOBILEBLOX_OFFSETS_PROFILE_NAME,
    MOBILEBLOX_OFFSETS_PROFILE_VERIFIED
};

#endif
