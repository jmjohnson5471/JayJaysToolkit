# JayJaysToolkit

PowerShell-only, GitHub-hosted technician toolkit. No compiled EXE required.

## Install from any internet-connected computer

```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/jmjohnson5471/JayJaysToolkit/main/install.ps1 | iex"
```

## Run locally

```powershell
.\Start.ps1
```

or double-click:

```text
Start-JayJaysToolkit.bat
```

## Why PowerShell-only?

Unsigned EXEs are more likely to be flagged by antivirus. This version keeps everything as inspectable PowerShell, BAT, CMD, JSON, and optional portable tools.

## Update

Click **Update** inside the GUI to pull the latest files from GitHub.

## Add tools

Drop `.ps1`, `.bat`, `.cmd`, `.exe`, `.msi`, or `.url` files under `Tools\<Category>`.
Add a matching `.json` file for metadata.


## Backup and Restore

This build includes the full Backup and Restore category:

- Full Backup Migration
- Restore Migration Backup
- Quick Backup User Folders
- Restore Checklist HTML Export

These tools appear automatically in the GUI under **Backup and Restore**.


## Interactive backup/restore fix

Backup and restore tools are now set to `ExecutionMode: Interactive`.

This is important because those scripts use prompts like `Read-Host` and long-running `robocopy` output. They now launch in their own PowerShell window and remain open instead of hanging inside the embedded live console.
