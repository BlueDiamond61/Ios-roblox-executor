# MobileBloxStudioKit

A small app-owned iOS dynamic framework for MobileBlox Studio.

## Included

- Lua/Luau source newline normalization
- Source line and character counts
- Safe local script filename formatting

This framework is for MobileBlox Studio's own editor and file-management features. It does not attach to, inject into, inspect, or modify other apps or game processes, and it does not execute Roblox payloads.

## Build

The framework target is defined in the repository's `project.yml` for XcodeGen. Generate the Xcode project on macOS with XcodeGen, then build the `MobileBloxStudio` app scheme. The app target links and embeds `MobileBloxStudioKit.framework`.

The repository has not been compiled or tested as part of this change.
