# Changelog

## 2.2.4

- Fixed the unreadable "black on black" CANCEL button. WinForms' native disabled-
  button rendering ignores custom `ForeColor` and paints a muddy system gray
  regardless of theme, which is what caused it. RUN/CANCEL are now always kept
  natively enabled and their color is driven entirely by the app's own
  ready/running state instead, so the text stays legible in both states (CANCEL
  now shows a clearly dimmed gray when idle and a bright red border/text while a
  tool is actually running and cancellable).

## 2.2.3

- **Quick Backup User Folders**: saying "N" at the confirmation step used to just
  cancel the whole backup. Now it loops back to the destination picker so you can
  choose somewhere else, with a clear three-way prompt: **Y** = start the backup
  here, **N** = pick a different destination, **C** = cancel entirely.

## 2.2.2

- **Quick Backup User Folders** rebuilt as a numbered drive picker: it now lists
  every attached drive (flagging removable/flash, fixed, and network drives, with
  free space shown) so you pick a number instead of typing a path, still supports
  typing a NAS path manually, and — most importantly — now shows the chosen
  destination back and requires an explicit Y/N confirmation before anything
  copies. Nothing runs silently against a default anymore.

## 2.2.1

- **Quick Backup User Folders** now prompts for a destination instead of always
  saving to the local Desktop — accepts a flash drive letter, a NAS/network path
  (`\\server\share\folder`), a mapped drive, or any local folder. Validates the
  path is actually writable (not just that the folder can be created — some UNC
  paths report success on `New-Item` but still fail to write) and re-prompts if
  it isn't reachable, instead of failing partway through the backup.
  (`Full Backup Migration` already had this prompt; it was only missing here.)

## 2.2.0 — "Tactical Diagnostics Console" visual overhaul

- New theme: matte graphite background, blaze-amber signal accent (not the default
  near-black/acid-green look), Cascadia Mono + Segoe UI Semibold type pairing.
- New HUD status strip under the header: live clock, plugin/tool counts, and a
  pulsing READY/RUNNING indicator dot.
- Tool list is now fully owner-drawn: dark themed header and rows (no more stock
  white ListView chrome), amber dot marks favorites, bordered "ADMIN" chip replaces
  the plain text badge, alternating row shading, hairline row dividers.
- Output console switched from plain TextBox to a colorized RichTextBox — normal
  output in amber, errors in red, meta/info lines (exit code, launch notices) in
  steel blue.
- Buttons restyled: flat, sharp-edged, primary RUN button filled in accent amber,
  CANCEL outlined in red, secondary actions in dark panel with amber hover border.
- Version badge next to the wordmark, reading `VERSION` at startup.

## 2.1.0

**Reliability**
- The window no longer freezes while a tool runs. Console-mode tools now execute
  asynchronously (`Core/ToolRunner.ps1`) with output streamed live via a poll timer,
  instead of blocking the UI thread on `WaitForExit()`.
- Added a **Cancel** button to stop a running tool (kills the full process tree, not
  just the parent shell).
- The app now cleans up any still-running tool if you close the window mid-run,
  instead of leaving an orphaned process behind.

**Safety**
- Destructive/disruptive tools (Winsock Reset, CHKDSK schedule, Restart Explorer,
  Windows Update repair, Office Quick Repair, Teams cache clear, Clear Temp Files,
  Restore Migration Backup, RustDesk service restart) now show a confirmation dialog
  before running. See `Confirm` / `ConfirmMessage` in `docs/Plugins.md`.
- The **Update** button now checks the remote version first (skips if already
  current), asks for confirmation, verifies the download before touching anything,
  and preserves any custom plugin folders you've added locally instead of wiping
  them on update.
- Plugin/tool JSON parse failures are now logged instead of silently ignored, so a
  typo in a manifest doesn't just make a tool quietly vanish.

**UI**
- Tools that need admin rights now show an **Admin** badge in the list.
- Added a status bar (Ready / Running: *ToolName*...).
- Window and controls are now resizable/anchored instead of a fixed size.
- Output box reliably auto-scrolls to the latest line.

**Cleanup**
- Removed the legacy top-level `Tools/` folder, which duplicated (and had drifted
  from) the real `Plugins/*/Tools/` structure and was never actually loaded by the
  app. Its 3 unique tools (Computer Info, Quick Backup User Folders, the fuller
  Restore Checklist HTML export) were migrated into the correct plugins first.
- Removed several orphaned/mislabeled files sitting loose in `Plugins/` and
  `Plugins/SystemInfoPlus/` (including a `README.txt` that actually contained raw
  JSON, and a `.json` file that actually contained a full PowerShell script). None
  of these were ever read by the app — the loader only scans `Plugins/*/Tools/`.
- Logger now supports levels (Info/Warn/Error) and auto-trims logs older than 30 days.
- Reformatted the dense one-line backup/restore scripts for readability (same
  behavior).
- Added `PSScriptAnalyzerSettings.psd1` and a `Tests/` Pester skeleton covering the
  plugin/tool discovery logic.
