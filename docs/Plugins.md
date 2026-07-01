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
