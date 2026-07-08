# JAYJAYs IT Platform - PostInstall Templates

This folder installs standard free apps after Windows setup.

## Files

- `apps-standard.csv` - your standard app list
- `postinstall.ps1` - local/USB version
- `postinstall-github.ps1` - downloads the CSV from GitHub first
- `autounattend-snippet.xml` - sample FirstLogonCommands snippets

## Current standard apps

- Chrome
- 7-Zip
- Adobe Reader
- VLC
- Teams
- PowerToys
- Firefox
- GreenShot
- Notepad++
- Google Earth
- PowerShell 7

## GitHub command for autounattend.xml

```xml
<CommandLine>powershell -ExecutionPolicy Bypass -NoProfile -Command "irm https://raw.githubusercontent.com/jmjohnson5471/JayJaysToolkit/main/Templates/PostInstall/postinstall-github.ps1 | iex"</CommandLine>
```
