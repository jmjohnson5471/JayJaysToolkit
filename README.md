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

Each plugin has its own `plugin.json`, tools, and metadata.

## Tool metadata

Each tool can have a matching `.json` file:

```json
{
  "Name": "BitLocker Status",
  "Category": "BitLocker",
  "Description": "Shows BitLocker status.",
  "RunAsAdmin": true,
  "Hidden": false,
  "Arguments": "",
  "ExecutionMode": "Console"
}
```

Execution modes:

- `Console` — output appears in the live console
- `Interactive` — opens its own PowerShell/CMD window for prompts
- `External` — launches GUI apps, EXEs, URLs, MSI installers, etc.

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
