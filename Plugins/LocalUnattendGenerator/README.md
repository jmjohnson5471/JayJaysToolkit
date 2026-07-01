# LocalUnattendGenerator Plugin

Copy the `LocalUnattendGenerator` folder into:

```text
JayJaysToolkit\Plugins\
```

Then click **Reload** in JayJaysToolkit.

Tool added:

```text
Windows Imaging > Launch Local Unattend Generator
```

This opens a fully local HTML generator for starter `autounattend.xml` files.

Notes:

- This is intentionally simpler than the Schneegans online generator.
- Disk wipe/partitioning is intentionally omitted for safety.
- Test generated files in a VM before using on production devices.
