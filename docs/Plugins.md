# Plugins

To add a plugin:

```text
Plugins/MyPlugin/
  plugin.json
  Tools/
```

Example plugin.json:

```json
{
  "Id": "MyPlugin",
  "Name": "My Plugin",
  "Version": "1.0.0",
  "Description": "My custom toolkit plugin.",
  "Author": "Your Name",
  "Enabled": true
}
```

Drop `.ps1`, `.bat`, `.cmd`, `.exe`, `.msi`, or `.url` tools under the plugin's `Tools` folder.

## Tool metadata

Each tool can have a matching `.json` file (same name, `.json` extension):

```json
{
  "Name": "BitLocker Status",
  "Category": "BitLocker",
  "Description": "Shows BitLocker status.",
  "RunAsAdmin": true,
  "Hidden": false,
  "Arguments": "",
  "ExecutionMode": "Console",
  "Confirm": false,
  "ConfirmMessage": ""
}
```

- `RunAsAdmin` — tools that need it show an **Admin** badge in the tool list.
- `Confirm` — set to `true` for anything destructive or disruptive (deletes data,
  resets network/services, force-closes apps, etc). When `true`, the app shows a
  Yes/No dialog with `ConfirmMessage` before running the tool. Default is `false`.
- `ExecutionMode`:
  - `Console` — runs asynchronously and streams output live in the app without
    freezing the window. Use for anything that can take more than a second or two.
  - `Interactive` — opens its own PowerShell/CMD window (for tools that prompt).
  - `External` — launches GUI apps, EXEs, URLs, MSI installers.

## Linting and tests (Windows, optional)

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1

Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser
Invoke-Pester .\Tests\
```
