Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Script:BaseDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Script:FavoritesFile = Join-Path $Script:BaseDir "favorites.json"

. (Join-Path $Script:BaseDir "Core\Logger.ps1")
. (Join-Path $Script:BaseDir "Core\PluginLoader.ps1")
. (Join-Path $Script:BaseDir "Core\Updater.ps1")
. (Join-Path $Script:BaseDir "Core\ToolRunner.ps1")

Invoke-JJTLogCleanup

# ============================================================================
# THEME  —  "Tactical Diagnostics Console"
# Matte graphite base, blaze-amber signal accent, monospace HUD readouts.
# Deliberately not the default near-black/acid-green look.
# ============================================================================
$Theme = @{
    Bg            = [System.Drawing.Color]::FromArgb(12, 15, 18)
    Panel         = [System.Drawing.Color]::FromArgb(21, 24, 28)
    PanelAlt      = [System.Drawing.Color]::FromArgb(27, 31, 36)
    Border        = [System.Drawing.Color]::FromArgb(42, 47, 53)
    Accent        = [System.Drawing.Color]::FromArgb(255, 122, 26)   # blaze amber (signature)
    AccentDim     = [System.Drawing.Color]::FromArgb(184, 90, 18)
    TextPrimary   = [System.Drawing.Color]::FromArgb(232, 234, 237)
    TextSecondary = [System.Drawing.Color]::FromArgb(139, 146, 153)
    Console       = [System.Drawing.Color]::FromArgb(255, 176, 110)  # warm amber console text
    Danger        = [System.Drawing.Color]::FromArgb(255, 71, 87)
    Info          = [System.Drawing.Color]::FromArgb(79, 195, 247)
    Success       = [System.Drawing.Color]::FromArgb(62, 207, 142)
    SelectionBg   = [System.Drawing.Color]::FromArgb(46, 27, 11)
}

# Cascadia Mono ships with Windows Terminal / VS Code / Windows 11. If it isn't
# installed, WinForms silently substitutes a default font — no crash either way.
$FontBrand      = New-Object System.Drawing.Font("Cascadia Mono", 19, [System.Drawing.FontStyle]::Bold)
$FontTagline    = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Regular)
$FontHud        = New-Object System.Drawing.Font("Cascadia Mono", 9, [System.Drawing.FontStyle]::Bold)
$FontUi         = New-Object System.Drawing.Font("Segoe UI Semibold", 9.5)
$FontListHeader = New-Object System.Drawing.Font("Segoe UI Semibold", 8.5)
$FontListRow    = New-Object System.Drawing.Font("Segoe UI", 9)
$FontListRowBold = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$FontChip       = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
$FontConsole    = New-Object System.Drawing.Font("Cascadia Mono", 9)

function Load-Favorites {
    if (Test-Path $Script:FavoritesFile) { try { return @(Get-Content $Script:FavoritesFile -Raw | ConvertFrom-Json) } catch { return @() } }
    return @()
}
function Save-Favorites { param([array]$Favorites) $Favorites | ConvertTo-Json | Set-Content $Script:FavoritesFile }

function Append-Output {
    param([string]$Text, [System.Drawing.Color]$Color = $Theme.Console)
    $output.SelectionStart = $output.TextLength
    $output.SelectionLength = 0
    $output.SelectionColor = $Color
    $output.AppendText($Text + [Environment]::NewLine)
    $output.SelectionStart = $output.TextLength
    $output.ScrollToCaret()
}

function Set-RunningState {
    param([bool]$Running, [string]$ToolName = "")
    $toolList.Enabled = -not $Running
    $Script:CurrentRunningTool = $ToolName
    $Script:IsRunning = $Running

    # Buttons are kept Enabled=$true always and "disabled" purely via our own
    # colors instead — WinForms' native disabled-button rendering ignores custom
    # ForeColor and paints a muddy system gray that's unreadable on a dark button
    # (this is what caused the unreadable "black on black" Cancel button).
    if ($Running) {
        $btnRun.BackColor = $Theme.PanelAlt
        $btnRun.ForeColor = $Theme.TextSecondary
        $btnRun.FlatAppearance.BorderColor = $Theme.Border

        $btnCancel.BackColor = $Theme.Panel
        $btnCancel.ForeColor = $Theme.Danger
        $btnCancel.FlatAppearance.BorderColor = $Theme.Danger
        $btnCancel.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(60, 20, 20)
    } else {
        $btnRun.BackColor = $Theme.Accent
        $btnRun.ForeColor = $Theme.Bg
        $btnRun.FlatAppearance.BorderColor = $Theme.Accent

        $btnCancel.BackColor = $Theme.Panel
        $btnCancel.ForeColor = $Theme.TextSecondary
        $btnCancel.FlatAppearance.BorderColor = $Theme.Border
        $btnCancel.FlatAppearance.MouseOverBackColor = $Theme.PanelAlt
    }
}

function Run-Tool {
    param($Tool)

    if ($Tool.Confirm) {
        $msg = if ($Tool.ConfirmMessage) { $Tool.ConfirmMessage } else { "'$($Tool.Name)' makes changes to this machine. Continue?" }
        $result = [System.Windows.Forms.MessageBox]::Show($msg, "JayJaysToolkit - Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($result -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    }

    Write-JJTLog "RUN: $($Tool.Name) [$($Tool.Path)]"
    Append-Output ""
    Append-Output "> $($Tool.Name)" $Theme.TextPrimary
    Append-Output "  plugin  : $($Tool.Plugin)" $Theme.TextSecondary
    Append-Output "  started : $(Get-Date -Format 'HH:mm:ss')" $Theme.TextSecondary
    Append-Output "  path    : $($Tool.Path)" $Theme.TextSecondary
    Append-Output ""

    try {
        if ($Tool.ExecutionMode -eq "Interactive") {
            if ($Tool.Extension -eq ".ps1") {
                $args = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$($Tool.Path)`" $($Tool.Arguments)"
                if ($Tool.RunAsAdmin) { Start-Process powershell.exe -Verb RunAs -WorkingDirectory $Tool.WorkingDirectory -ArgumentList $args }
                else { Start-Process powershell.exe -WorkingDirectory $Tool.WorkingDirectory -ArgumentList $args }
                Append-Output "Launched interactive PowerShell window." $Theme.Info
                return
            }
            elseif ($Tool.Extension -in ".bat", ".cmd") {
                $args = "/k `"$($Tool.Path)`" $($Tool.Arguments)"
                if ($Tool.RunAsAdmin) { Start-Process cmd.exe -Verb RunAs -WorkingDirectory $Tool.WorkingDirectory -ArgumentList $args }
                else { Start-Process cmd.exe -WorkingDirectory $Tool.WorkingDirectory -ArgumentList $args }
                Append-Output "Launched interactive CMD window." $Theme.Info
                return
            }
        }

        if ($Tool.ExecutionMode -eq "External" -or $Tool.Extension -in ".exe", ".msi", ".url") {
            if ($Tool.Extension -eq ".url") { Start-Process $Tool.Path }
            elseif ($Tool.Extension -eq ".msi") { Start-Process msiexec.exe -Verb RunAs -ArgumentList "/i `"$($Tool.Path)`" $($Tool.Arguments)" }
            elseif ($Tool.Extension -eq ".ps1") {
                $args = "-NoProfile -ExecutionPolicy Bypass -File `"$($Tool.Path)`" $($Tool.Arguments)"
                if ($Tool.RunAsAdmin) { Start-Process powershell.exe -Verb RunAs -WorkingDirectory $Tool.WorkingDirectory -ArgumentList $args }
                else { Start-Process powershell.exe -WorkingDirectory $Tool.WorkingDirectory -ArgumentList $args }
            }
            elseif ($Tool.RunAsAdmin) { Start-Process -FilePath $Tool.Path -Verb RunAs -WorkingDirectory $Tool.WorkingDirectory -ArgumentList $Tool.Arguments }
            else { Start-Process -FilePath $Tool.Path -WorkingDirectory $Tool.WorkingDirectory -ArgumentList $Tool.Arguments }
            Append-Output "Launched external tool." $Theme.Info
            return
        }

        if ($Tool.Extension -notin ".ps1", ".bat", ".cmd") {
            Append-Output "Unsupported internal type." $Theme.Danger
            return
        }

        # Console mode: async so the UI never freezes (see Core\ToolRunner.ps1).
        Set-RunningState -Running $true -ToolName $Tool.Name
        Start-JJTConsoleTool -Tool $Tool
    } catch {
        Append-Output "FAILED: $($_.Exception.Message)" $Theme.Danger
        Set-RunningState -Running $false
    }
}

# ============================================================================
# FORM
# ============================================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "JayJaysToolkit - Field Technician Platform"
$form.Size = New-Object System.Drawing.Size(1340, 820)
$form.MinimumSize = New-Object System.Drawing.Size(1020, 620)
$form.StartPosition = "CenterScreen"
$form.BackColor = $Theme.Bg
$form.ForeColor = $Theme.TextPrimary
$form.Font = $FontUi

# --- Top accent strip (signature hazard-amber rail) ---
$accentStrip = New-Object System.Windows.Forms.Panel
$accentStrip.BackColor = $Theme.Accent
$accentStrip.Dock = "Top"
$accentStrip.Height = 3
$form.Controls.Add($accentStrip)

# --- Brand wordmark ---
$title = New-Object System.Windows.Forms.Label
$title.Text = "J A Y J A Y S   T O O L K I T"
$title.Font = $FontBrand
$title.ForeColor = $Theme.Accent
$title.BackColor = [System.Drawing.Color]::Transparent
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(25, 16)
$form.Controls.Add($title)

$versionBadge = New-Object System.Windows.Forms.Label
$versionText = try { "v" + (Get-Content (Join-Path $Script:BaseDir "VERSION") -Raw).Trim() } catch { "" }
$versionBadge.Text = $versionText
$versionBadge.Font = $FontChip
$versionBadge.ForeColor = $Theme.Bg
$versionBadge.BackColor = $Theme.Accent
$versionBadge.AutoSize = $false
$versionBadge.Size = New-Object System.Drawing.Size(48, 16)
$versionBadge.TextAlign = "MiddleCenter"
$versionBadge.Location = New-Object System.Drawing.Point(320, 22)
$form.Controls.Add($versionBadge)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "F I E L D   T E C H N I C I A N   P L A T F O R M"
$subtitle.Font = $FontTagline
$subtitle.ForeColor = $Theme.TextSecondary
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(27, 50)
$form.Controls.Add($subtitle)

# --- HUD status strip (signature element): live ready/running indicator + counts + clock ---
$hudDot = New-Object System.Windows.Forms.Panel
$hudDot.Size = New-Object System.Drawing.Size(9, 9)
$hudDot.Location = New-Object System.Drawing.Point(870, 24)
$hudDot.BackColor = $Theme.Success
$hudDot.Anchor = "Top,Right"
$form.Controls.Add($hudDot)

$hudLabel = New-Object System.Windows.Forms.Label
$hudLabel.Text = "READY"
$hudLabel.Font = $FontHud
$hudLabel.ForeColor = $Theme.Success
$hudLabel.AutoSize = $true
$hudLabel.Location = New-Object System.Drawing.Point(885, 20)
$hudLabel.Anchor = "Top,Right"
$form.Controls.Add($hudLabel)

$hudCounts = New-Object System.Windows.Forms.Label
$hudCounts.Text = "[ 0 PLUGINS ] [ 0 TOOLS ]"
$hudCounts.Font = $FontHud
$hudCounts.ForeColor = $Theme.TextSecondary
$hudCounts.AutoSize = $true
$hudCounts.Location = New-Object System.Drawing.Point(1000, 20)
$hudCounts.Anchor = "Top,Right"
$form.Controls.Add($hudCounts)

$hudClock = New-Object System.Windows.Forms.Label
$hudClock.Text = "00:00:00"
$hudClock.Font = $FontHud
$hudClock.ForeColor = $Theme.TextSecondary
$hudClock.AutoSize = $true
$hudClock.Location = New-Object System.Drawing.Point(1200, 20)
$hudClock.Anchor = "Top,Right"
$form.Controls.Add($hudClock)

$hudRule = New-Object System.Windows.Forms.Panel
$hudRule.BackColor = $Theme.Border
$hudRule.Height = 1
$hudRule.Location = New-Object System.Drawing.Point(25, 44)
$hudRule.Size = New-Object System.Drawing.Size(1280, 1)
$hudRule.Anchor = "Top,Left,Right"
$form.Controls.Add($hudRule)

# --- Search / filter row ---
$search = New-Object System.Windows.Forms.TextBox
$search.Location = New-Object System.Drawing.Point(25, 90)
$search.Size = New-Object System.Drawing.Size(390, 30)
$search.BackColor = $Theme.Panel
$search.ForeColor = $Theme.TextPrimary
$search.BorderStyle = "FixedSingle"
$search.Font = $FontUi
$search.Anchor = "Top,Left"
$form.Controls.Add($search)

$searchHint = New-Object System.Windows.Forms.Label
$searchHint.Text = "SEARCH"
$searchHint.Font = $FontChip
$searchHint.ForeColor = $Theme.TextSecondary
$searchHint.AutoSize = $true
$searchHint.Location = New-Object System.Drawing.Point(25, 74)
$searchHint.Anchor = "Top,Left"
$form.Controls.Add($searchHint)

$category = New-Object System.Windows.Forms.ComboBox
$category.Location = New-Object System.Drawing.Point(430, 90)
$category.Size = New-Object System.Drawing.Size(230, 30)
$category.DropDownStyle = "DropDownList"
$category.FlatStyle = "Flat"
$category.BackColor = $Theme.Panel
$category.ForeColor = $Theme.TextPrimary
$category.Font = $FontUi
$category.Anchor = "Top,Left"
$form.Controls.Add($category)

$catHint = New-Object System.Windows.Forms.Label
$catHint.Text = "CATEGORY"
$catHint.Font = $FontChip
$catHint.ForeColor = $Theme.TextSecondary
$catHint.AutoSize = $true
$catHint.Location = New-Object System.Drawing.Point(430, 74)
$catHint.Anchor = "Top,Left"
$form.Controls.Add($catHint)

$pluginBox = New-Object System.Windows.Forms.ComboBox
$pluginBox.Location = New-Object System.Drawing.Point(675, 90)
$pluginBox.Size = New-Object System.Drawing.Size(230, 30)
$pluginBox.DropDownStyle = "DropDownList"
$pluginBox.FlatStyle = "Flat"
$pluginBox.BackColor = $Theme.Panel
$pluginBox.ForeColor = $Theme.TextPrimary
$pluginBox.Font = $FontUi
$pluginBox.Anchor = "Top,Left"
$form.Controls.Add($pluginBox)

$plugHint = New-Object System.Windows.Forms.Label
$plugHint.Text = "PLUGIN"
$plugHint.Font = $FontChip
$plugHint.ForeColor = $Theme.TextSecondary
$plugHint.AutoSize = $true
$plugHint.Location = New-Object System.Drawing.Point(675, 74)
$plugHint.Anchor = "Top,Left"
$form.Controls.Add($plugHint)

# --- Tool list (owner-drawn for full theme control + favorite marker + admin chip) ---
$toolList = New-Object System.Windows.Forms.ListView
$toolList.Location = New-Object System.Drawing.Point(25, 130)
$toolList.Size = New-Object System.Drawing.Size(710, 480)
$toolList.View = "Details"
$toolList.FullRowSelect = $true
$toolList.GridLines = $false
$toolList.HeaderStyle = "Nonclickable"
$toolList.OwnerDraw = $true
$toolList.BackColor = $Theme.Panel
$toolList.ForeColor = $Theme.TextPrimary
$toolList.BorderStyle = "FixedSingle"
$toolList.Anchor = "Top,Bottom,Left,Right"
$toolList.Columns.Add("TOOL", 210) | Out-Null
$toolList.Columns.Add("PLUGIN", 120) | Out-Null
$toolList.Columns.Add("CATEGORY", 105) | Out-Null
$toolList.Columns.Add("ADMIN", 58) | Out-Null
$toolList.Columns.Add("TYPE", 45) | Out-Null
$toolList.Columns.Add("DESCRIPTION", 260) | Out-Null
$form.Controls.Add($toolList)

$toolList.Add_DrawColumnHeader({
    param($s, $e)
    $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush($Theme.PanelAlt)), $e.Bounds)
    $textBrush = New-Object System.Drawing.SolidBrush($Theme.Accent)
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.LineAlignment = "Center"
    $e.Graphics.DrawString($e.Header.Text, $FontListHeader, $textBrush, [System.Drawing.RectangleF]::new($e.Bounds.X + 8, $e.Bounds.Y, $e.Bounds.Width - 8, $e.Bounds.Height), $fmt)
    $pen = New-Object System.Drawing.Pen($Theme.Accent, 2)
    $e.Graphics.DrawLine($pen, $e.Bounds.Left, $e.Bounds.Bottom - 1, $e.Bounds.Right, $e.Bounds.Bottom - 1)
})

$toolList.Add_DrawItem({ param($s, $e) $e.DrawDefault = $false })

$toolList.Add_DrawSubItem({
    param($s, $e)
    $tool = $e.Item.Tag
    $isSelected = $e.Item.Selected
    $rowBg = if ($isSelected) { $Theme.SelectionBg } elseif ($e.ItemIndex % 2 -eq 0) { $Theme.Panel } else { $Theme.PanelAlt }
    $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush($rowBg)), $e.Bounds)

    $fmt = New-Object System.Drawing.StringFormat
    $fmt.LineAlignment = "Center"
    $fmt.Trimming = "EllipsisCharacter"

    switch ($e.ColumnIndex) {
        0 {
            $textX = $e.Bounds.X + 8
            if ($tool -and ($Script:Favorites -contains $tool.RelativePath)) {
                $dotBrush = New-Object System.Drawing.SolidBrush($Theme.Accent)
                $cy = $e.Bounds.Y + [int]($e.Bounds.Height / 2) - 3
                $e.Graphics.FillEllipse($dotBrush, $e.Bounds.X + 2, $cy, 6, 6)
                $textX = $e.Bounds.X + 16
            }
            $font = if ($isSelected) { $FontListRowBold } else { $FontListRow }
            $textColor = if ($isSelected) { $Theme.Accent } else { $Theme.TextPrimary }
            $rect = [System.Drawing.RectangleF]::new($textX, $e.Bounds.Y, $e.Bounds.Right - $textX - 4, $e.Bounds.Height)
            $e.Graphics.DrawString($e.SubItem.Text, $font, (New-Object System.Drawing.SolidBrush($textColor)), $rect, $fmt)
        }
        3 {
            if ($tool -and $tool.RunAsAdmin) {
                $chipW = 46
                $chipH = 15
                $chipX = $e.Bounds.X + 4
                $chipY = $e.Bounds.Y + [int](($e.Bounds.Height - $chipH) / 2)
                $chipRect = New-Object System.Drawing.Rectangle($chipX, $chipY, $chipW, $chipH)
                $e.Graphics.FillRectangle((New-Object System.Drawing.SolidBrush($Theme.Bg)), $chipRect)
                $e.Graphics.DrawRectangle((New-Object System.Drawing.Pen($Theme.Accent, 1)), $chipRect)
                $chipFmt = New-Object System.Drawing.StringFormat
                $chipFmt.Alignment = "Center"
                $chipFmt.LineAlignment = "Center"
                $e.Graphics.DrawString("ADMIN", $FontChip, (New-Object System.Drawing.SolidBrush($Theme.Accent)), [System.Drawing.RectangleF]$chipRect, $chipFmt)
            }
        }
        4 {
            $ext = if ($tool) { $tool.Extension.TrimStart('.').ToUpper() } else { $e.SubItem.Text }
            $rect = [System.Drawing.RectangleF]::new($e.Bounds.X + 4, $e.Bounds.Y, $e.Bounds.Width - 4, $e.Bounds.Height)
            $e.Graphics.DrawString($ext, $FontChip, (New-Object System.Drawing.SolidBrush($Theme.TextSecondary)), $rect, $fmt)
        }
        default {
            $textColor = if ($isSelected) { $Theme.TextPrimary } else { $Theme.TextSecondary }
            $rect = [System.Drawing.RectangleF]::new($e.Bounds.X + 6, $e.Bounds.Y, $e.Bounds.Width - 10, $e.Bounds.Height)
            $e.Graphics.DrawString($e.SubItem.Text, $FontListRow, (New-Object System.Drawing.SolidBrush($textColor)), $rect, $fmt)
        }
    }

    $bottomPen = New-Object System.Drawing.Pen($Theme.Border, 1)
    $e.Graphics.DrawLine($bottomPen, $e.Bounds.Left, $e.Bounds.Bottom - 1, $e.Bounds.Right, $e.Bounds.Bottom - 1)
    $e.DrawDefault = $false
})

# --- Live console output ---
$consoleHint = New-Object System.Windows.Forms.Label
$consoleHint.Text = "> OUTPUT"
$consoleHint.Font = $FontChip
$consoleHint.ForeColor = $Theme.TextSecondary
$consoleHint.AutoSize = $true
$consoleHint.Location = New-Object System.Drawing.Point(755, 112)
$consoleHint.Anchor = "Top,Left"
$form.Controls.Add($consoleHint)

$output = New-Object System.Windows.Forms.RichTextBox
$output.Location = New-Object System.Drawing.Point(755, 130)
$output.Size = New-Object System.Drawing.Size(555, 480)
$output.ReadOnly = $true
$output.WordWrap = $false
$output.ScrollBars = "Both"
$output.BorderStyle = "FixedSingle"
$output.BackColor = $Theme.Bg
$output.ForeColor = $Theme.Console
$output.Font = $FontConsole
$output.Anchor = "Top,Bottom,Left,Right"
$form.Controls.Add($output)

# --- Status line + action buttons ---
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "READY"
$statusLabel.Font = $FontHud
$statusLabel.ForeColor = $Theme.Success
$statusLabel.AutoSize = $true
$statusLabel.Location = New-Object System.Drawing.Point(25, 618)
$statusLabel.Anchor = "Bottom,Left"
$form.Controls.Add($statusLabel)

function New-JJTButton {
    param([string]$Text, [int]$X, [int]$Y, [int]$W, [bool]$Primary = $false)
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Location = New-Object System.Drawing.Point($X, $Y)
    $btn.Size = New-Object System.Drawing.Size($W, 36)
    $btn.Font = $FontUi
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 1
    $btn.Anchor = "Bottom,Left"
    $btn.Cursor = "Hand"
    if ($Primary) {
        $btn.BackColor = $Theme.Accent
        $btn.ForeColor = $Theme.Bg
        $btn.FlatAppearance.BorderColor = $Theme.Accent
        $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(255, 148, 66)
        $btn.FlatAppearance.MouseDownBackColor = $Theme.AccentDim
    } else {
        $btn.BackColor = $Theme.Panel
        $btn.ForeColor = $Theme.TextPrimary
        $btn.FlatAppearance.BorderColor = $Theme.Border
        $btn.FlatAppearance.MouseOverBackColor = $Theme.PanelAlt
        $btn.FlatAppearance.MouseDownBackColor = $Theme.Border
    }
    $form.Controls.Add($btn)
    return $btn
}

$btnRun      = New-JJTButton -Text "RUN"          -X 25   -Y 650 -W 90  -Primary $true
$btnCancel   = New-JJTButton -Text "CANCEL"       -X 125  -Y 650 -W 90

$btnFav      = New-JJTButton -Text "FAVORITE"     -X 225  -Y 650 -W 100
$btnReload   = New-JJTButton -Text "RELOAD"       -X 335  -Y 650 -W 95
$btnPlugins  = New-JJTButton -Text "PLUGINS"      -X 440  -Y 650 -W 95
$btnUpdate   = New-JJTButton -Text "UPDATE"       -X 545  -Y 650 -W 90
$btnClear    = New-JJTButton -Text "CLEAR"        -X 755  -Y 650 -W 110
$btnCopy     = New-JJTButton -Text "COPY OUTPUT"  -X 875  -Y 650 -W 130

# ============================================================================
# DATA / FILTERS
# ============================================================================
$Script:AllTools = @()
$Script:AllPlugins = @()
$Script:Favorites = Load-Favorites
$Script:IsRunning = $false
$Script:CurrentRunningTool = ""

function Refresh-Filters {
    $category.Items.Clear()
    $category.Items.Add("All Categories") | Out-Null
    $category.Items.Add("Favorites") | Out-Null
    $Script:AllTools | Select-Object -ExpandProperty Category -Unique | Sort-Object | ForEach-Object { $category.Items.Add($_) | Out-Null }
    $category.SelectedIndex = 0

    $pluginBox.Items.Clear()
    $pluginBox.Items.Add("All Plugins") | Out-Null
    $Script:AllPlugins | Select-Object -ExpandProperty Name -Unique | Sort-Object | ForEach-Object { $pluginBox.Items.Add($_) | Out-Null }
    $pluginBox.SelectedIndex = 0
}

function Refresh-ToolList {
    $toolList.BeginUpdate()
    $toolList.Items.Clear()
    $q = $search.Text.ToLower()
    $cat = $category.SelectedItem
    $plug = $pluginBox.SelectedItem
    $items = $Script:AllTools

    if ($cat -and $cat -ne "All Categories") {
        if ($cat -eq "Favorites") { $items = $items | Where-Object { $Script:Favorites -contains $_.RelativePath } }
        else { $items = $items | Where-Object { $_.Category -eq $cat } }
    }
    if ($plug -and $plug -ne "All Plugins") { $items = $items | Where-Object { $_.Plugin -eq $plug } }
    if ($q) { $items = $items | Where-Object { $_.Name.ToLower().Contains($q) -or $_.Category.ToLower().Contains($q) -or $_.Plugin.ToLower().Contains($q) -or $_.Description.ToLower().Contains($q) } }

    foreach ($t in ($items | Sort-Object Plugin, Category, Name)) {
        $li = New-Object System.Windows.Forms.ListViewItem($t.Name)
        $li.SubItems.Add($t.Plugin) | Out-Null
        $li.SubItems.Add($t.Category) | Out-Null
        $li.SubItems.Add($(if ($t.RunAsAdmin) { "Admin" } else { "" })) | Out-Null
        $li.SubItems.Add($t.Extension) | Out-Null
        $li.SubItems.Add($t.Description) | Out-Null
        $li.Tag = $t
        $toolList.Items.Add($li) | Out-Null
    }
    $toolList.EndUpdate()
}

function Load-Platform {
    $Script:AllPlugins = @(Get-JJTPlugins)
    $Script:AllTools = @(Get-JJTTools)
    Refresh-Filters
    Refresh-ToolList
    $hudCounts.Text = "[ $($Script:AllPlugins.Count) PLUGINS ] [ $($Script:AllTools.Count) TOOLS ]"
    Append-Output "Loaded $($Script:AllPlugins.Count) plugins and $($Script:AllTools.Count) tools." $Theme.Info
}

# ============================================================================
# TIMER — polls async tool output AND drives the HUD (clock + pulsing status dot)
# ============================================================================
$Script:PulsePhase = $false
$pollTimer = New-Object System.Windows.Forms.Timer
$pollTimer.Interval = 150
$pollTimer.Add_Tick({
    # --- HUD clock ---
    $hudClock.Text = Get-Date -Format "HH:mm:ss"

    # --- HUD / status running indicator (pulses amber while a tool runs) ---
    if ($Script:IsRunning) {
        $Script:PulsePhase = -not $Script:PulsePhase
        $hudDot.BackColor = if ($Script:PulsePhase) { $Theme.Accent } else { $Theme.AccentDim }
        $hudLabel.Text = "RUNNING"
        $hudLabel.ForeColor = $Theme.Accent
        $statusLabel.Text = "RUNNING: $($Script:CurrentRunningTool)..."
        $statusLabel.ForeColor = $Theme.Accent
    } else {
        $hudDot.BackColor = $Theme.Success
        $hudLabel.Text = "READY"
        $hudLabel.ForeColor = $Theme.Success
        $statusLabel.Text = "READY"
        $statusLabel.ForeColor = $Theme.Success
    }

    # --- drain async console-tool output queue ---
    if (-not $Script:JJT_RunState.Process) { return }
    $events = Receive-JJTToolOutput
    foreach ($e in $events) {
        switch ($e.Type) {
            "Out" { Append-Output $e.Text $Theme.Console }
            "Err" { Append-Output "ERR: $($e.Text)" $Theme.Danger }
            "Exit" {
                Append-Output ""
                Append-Output "Exit Code: $($e.Text)" $Theme.Info
                Append-Output "Finished: $(Get-Date)" $Theme.TextSecondary
                Set-RunningState -Running $false
            }
        }
    }
})
$pollTimer.Start()

# ============================================================================
# EVENTS
# ============================================================================
$search.Add_TextChanged({ Refresh-ToolList })
$category.Add_SelectedIndexChanged({ Refresh-ToolList })
$pluginBox.Add_SelectedIndexChanged({ Refresh-ToolList })
$toolList.Add_DoubleClick({ if ($toolList.SelectedItems.Count -gt 0 -and -not $Script:IsRunning) { Run-Tool $toolList.SelectedItems[0].Tag } })
$btnRun.Add_Click({ if (-not $Script:IsRunning -and $toolList.SelectedItems.Count -gt 0) { Run-Tool $toolList.SelectedItems[0].Tag } })
$btnCancel.Add_Click({
    if (-not $Script:IsRunning) { return }
    Stop-JJTRunningTool
    Append-Output ""
    Append-Output "Cancelled by user." $Theme.Danger
    Set-RunningState -Running $false
})
$btnFav.Add_Click({
    if ($toolList.SelectedItems.Count -gt 0) {
        $t = $toolList.SelectedItems[0].Tag
        if ($Script:Favorites -contains $t.RelativePath) { $Script:Favorites = @($Script:Favorites | Where-Object { $_ -ne $t.RelativePath }) }
        else { $Script:Favorites = @($Script:Favorites + $t.RelativePath) }
        Save-Favorites $Script:Favorites
        Refresh-ToolList
    }
})
$btnReload.Add_Click({ Load-Platform })
$btnPlugins.Add_Click({ Start-Process explorer.exe (Join-Path $Script:BaseDir "Plugins") })
$btnUpdate.Add_Click({ Invoke-JJTUpdate })
$btnClear.Add_Click({ $output.Clear() })
$btnCopy.Add_Click({ if ($output.Text) { [System.Windows.Forms.Clipboard]::SetText($output.Text) } })

$form.Add_FormClosing({
    if ($Script:IsRunning) { Stop-JJTRunningTool }
    $pollTimer.Stop()
})

Load-Platform
Set-RunningState -Running $false
[void]$form.ShowDialog()
