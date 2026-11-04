# MobileBlox iOS Studio

A native SwiftUI iPhone/iPad companion for organizing and editing local Lua text files.

This is a safe iOS rewrite of the **interface and file-workflow idea**, not a port of the Android executor. The original MobileBloxV2 repository describes itself as a Roblox script executor and includes work around bypassing Roblox's context system. This project intentionally does **not** include Roblox injection, execution, exploit APIs, dylibs, anti-cheat bypasses, or remote payload loading.

## Included

- Native SwiftUI interface with a dark purple studio theme
- Local script library saved in the app's Documents folder
- Create, rename, edit, and delete text files
- Import and export plain-text files with the iOS document picker
- Search and filter the local file browser by Lua and text files
- Grouped Lua/Text project sections
- Monospaced editor with a syntax-highlighted Lua preview
- In-app iOS setup and signing guide
- Local IPA archive vault: import, list, share, and delete `.ipa` files
- iPhone and iPad adaptive layout

## Open in Xcode

1. On a Mac, create a new **iOS App** project named `MobileBloxStudio` using SwiftUI.
2. Set the deployment target to iOS 16 or later.
3. Add the files in `MobileBloxStudio/` to the app target (ensure **Copy items if needed** is selected).
4. Build and run on an iPhone or iPad simulator/device.

The repository includes the Swift source files; it does not include a signed IPA or provisioning profile. Building and signing an iOS app requires Apple's Xcode toolchain and an Apple development signing setup.

## Project structure

- `MobileBloxStudio/MobileBloxStudioApp.swift` — app entry point
- `MobileBloxStudio/ContentView.swift` — library, editor, import/export UI
- `MobileBloxStudio/ScriptDocument.swift` — document type used for file export
- `MobileBloxStudio/StudioExtras.swift` — syntax preview and install/setup guide
- `MobileBloxStudio/PackageVaultView.swift` — local IPA archive storage and sharing

## Scope

The editor treats scripts as text. It does not run them in Roblox or attach to the Roblox app.

## IPA archive handling

The Package Vault stores `.ipa` files in the app's local Documents directory and supports sharing or deleting them. It does not unpack or alter app bundles, install apps, inject code, or execute payloads. iOS installation, developer trust, and certificate revocation remain controlled by Apple; the app does not offer an anti-revoke bypass or a restart-based trust workaround.
