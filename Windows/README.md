# MobileBlox Studio for Windows

A native Windows desktop companion for the MobileBlox Studio local Lua/Luau editor.

## Requirements

- Windows 10 or Windows 11
- Visual Studio 2022 with the .NET desktop development workload
- .NET 8 SDK

## Open and build

1. Open `MobileBloxStudio.Windows.sln` in Visual Studio.
2. Select the `MobileBloxStudio.Windows` project as the startup project.
3. Build and run with F5.

Or from a Developer PowerShell:

```powershell
dotnet build .\MobileBloxStudio.Windows.sln
dotnet run --project .\MobileBloxStudio.Windows\MobileBloxStudio.Windows.csproj
```

## Features

- Dark purple desktop workspace
- Lua/Luau text editor
- New, open, save, and save-as
- Local script library stored in Documents\MobileBloxStudio\Scripts
- Source preview and output console

This is a local editor and file manager. It does not inject into Roblox, attach to game processes, bypass platform protections, or execute exploit payloads. The preview button reports source statistics only.

The source has been added to the repository but has not been compiled or tested in this environment.
