# JayJaysToolkit

PowerShell-only, plugin-based, GitHub-hosted field technician platform.

## Install from any internet-connected computer

```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/jmjohnson5471/JayJaysToolkit/main/install.ps1 | iex"
```

## Run locally

```powershell
.\Start.ps1
```

or:

```text
Start-JayJaysToolkit.bat
```

## Architecture

```text
Core/
Plugins/
  CoreWindows/
    plugin.json
    Tools/
  BackupRestore/
  Networking/
  Microsoft365/
  Security/
  PortableApps/
  Sysinternals/
  RMMRemoteSupport/
  OSDCloud/
  VendorTools/
  ThirdPartyLaunchers/
```

Each plugin has its own `plugin.json`, tools, and metadata. See `docs/Plugins.md`
for the full tool metadata schema (including the `Confirm` safety flag) and how to
add your own plugin.

## What's new in 2.1

- **No more freezing.** Tools run asynchronously with live streaming output and a
  Cancel button — the window stays responsive even during a multi-minute SFC/DISM run.
- **Confirmation prompts** before anything destructive or disruptive runs (network
  resets, forced app closures, data overwrites, service restarts on your own remote
  support tool, etc).
- **Safer updates.** Update checks the remote version first, asks for confirmation,
  verifies the download, and preserves any custom plugins you've added locally.
- **Admin badges** in the tool list so you know at a glance what will trigger a UAC
  prompt.
- See `CHANGELOG.md` for the full list.

## Included plugin groups

- Core Windows
- Backup and Restore
- Networking
- Microsoft 365
- Security
- Portable Apps
- Sysinternals
- RMM and Remote Support
- OSDCloud
- Vendor Tools
- Third Party Launchers

## Third-party launchers

The toolkit includes a launcher for:

```powershell
irm https://christitus.com/win | iex
```

It requires confirmation before running.


## PortableApps path fix

Portable tools now download to the toolkit-managed folder instead of the user's Desktop:

```text
PortableApps/
```

This fixes systems where Desktop is redirected to OneDrive or missing.
