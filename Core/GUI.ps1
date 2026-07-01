Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Script:BaseDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Script:ToolsDir = Join-Path $Script:BaseDir "Tools"
$Script:FavoritesFile = Join-Path $Script:BaseDir "favorites.json"

. (Join-Path $Script:BaseDir "Core\Logger.ps1")
. (Join-Path $Script:BaseDir "Core\PluginLoader.ps1")
. (Join-Path $Script:BaseDir "Core\Updater.ps1")

function Load-Favorites {
    if (Test-Path $Script:FavoritesFile) {
        try { return @(Get-Content $Script:FavoritesFile -Raw | ConvertFrom-Json) } catch { return @() }
    }
    return @()
}
function Save-Favorites { param([array]$Favorites) $Favorites | ConvertTo-Json | Set-Content $Script:FavoritesFile }

function Append-Output { param([string]$Text) $output.AppendText($Text + [Environment]::NewLine) }

function Run-Tool {
    param($Tool)
    Write-JJTLog "RUN: $($Tool.Name) [$($Tool.Path)]"
    Append-Output ""
    Append-Output "===== $($Tool.Name) ====="
    Append-Output "Started: $(Get-Date)"
    Append-Output "Path: $($Tool.Path)"
    Append-Output ""

    try {
        if ($Tool.ExecutionMode -eq "External" -or $Tool.Extension -in ".exe",".msi",".url") {
            if ($Tool.Extension -eq ".url") { Start-Process $Tool.Path }
            elseif ($Tool.Extension -eq ".msi") { Start-Process msiexec.exe -Verb RunAs -ArgumentList "/i `"$($Tool.Path)`" $($Tool.Arguments)" }
            elseif ($Tool.RunAsAdmin) { Start-Process -FilePath $Tool.Path -Verb RunAs -WorkingDirectory $Tool.WorkingDirectory -ArgumentList $Tool.Arguments }
            else { Start-Process -FilePath $Tool.Path -WorkingDirectory $Tool.WorkingDirectory -ArgumentList $Tool.Arguments }
            Append-Output "Launched external tool."
            return
        }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        if ($Tool.Extension -eq ".ps1") {
            $psi.FileName = "powershell.exe"
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($Tool.Path)`" $($Tool.Arguments)"
        } elseif ($Tool.Extension -in ".bat",".cmd") {
            $psi.FileName = "cmd.exe"
            $psi.Arguments = "/c `"$($Tool.Path)`" $($Tool.Arguments)"
        } else {
            Append-Output "Unsupported internal type."
            return
        }

        $psi.WorkingDirectory = $Tool.WorkingDirectory
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        [void]$p.Start()
        $stdOut = $p.StandardOutput.ReadToEnd()
        $stdErr = $p.StandardError.ReadToEnd()
        $p.WaitForExit()

        if ($stdOut) { Append-Output $stdOut.TrimEnd() }
        if ($stdErr) { Append-Output "ERRORS:"; Append-Output $stdErr.TrimEnd() }
        Append-Output ""
        Append-Output "Exit Code: $($p.ExitCode)"
        Append-Output "Finished: $(Get-Date)"
    } catch { Append-Output "FAILED: $($_.Exception.Message)" }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "JayJaysToolkit PowerShell Edition"
$form.Size = New-Object System.Drawing.Size(1250,760)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(25,25,25)
$form.ForeColor = [System.Drawing.Color]::White
$form.Font = New-Object System.Drawing.Font("Segoe UI",10)

$title = New-Object System.Windows.Forms.Label
$title.Text = "JayJaysToolkit"
$title.Font = New-Object System.Drawing.Font("Segoe UI",20,[System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(0,220,120)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(20,15)
$form.Controls.Add($title)

$search = New-Object System.Windows.Forms.TextBox
$search.Location = New-Object System.Drawing.Point(25,70)
$search.Size = New-Object System.Drawing.Size(390,32)
$search.BackColor = [System.Drawing.Color]::FromArgb(45,45,45)
$search.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($search)

$category = New-Object System.Windows.Forms.ComboBox
$category.Location = New-Object System.Drawing.Point(430,70)
$category.Size = New-Object System.Drawing.Size(230,32)
$category.DropDownStyle = "DropDownList"
$category.BackColor = [System.Drawing.Color]::FromArgb(45,45,45)
$category.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($category)

$toolList = New-Object System.Windows.Forms.ListView
$toolList.Location = New-Object System.Drawing.Point(25,115)
$toolList.Size = New-Object System.Drawing.Size(635,520)
$toolList.View = "Details"
$toolList.FullRowSelect = $true
$toolList.GridLines = $true
$toolList.BackColor = [System.Drawing.Color]::FromArgb(35,35,35)
$toolList.ForeColor = [System.Drawing.Color]::White
$toolList.Columns.Add("Tool",230) | Out-Null
$toolList.Columns.Add("Category",150) | Out-Null
$toolList.Columns.Add("Type",70) | Out-Null
$toolList.Columns.Add("Description",300) | Out-Null
$form.Controls.Add($toolList)

$output = New-Object System.Windows.Forms.TextBox
$output.Location = New-Object System.Drawing.Point(680,115)
$output.Size = New-Object System.Drawing.Size(540,520)
$output.Multiline = $true
$output.ScrollBars = "Both"
$output.ReadOnly = $true
$output.WordWrap = $false
$output.BackColor = [System.Drawing.Color]::FromArgb(10,10,10)
$output.ForeColor = [System.Drawing.Color]::FromArgb(0,220,120)
$output.Font = New-Object System.Drawing.Font("Consolas",9)
$form.Controls.Add($output)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Run"
$btnRun.Location = New-Object System.Drawing.Point(25,650)
$btnRun.Size = New-Object System.Drawing.Size(90,38)
$form.Controls.Add($btnRun)

$btnFav = New-Object System.Windows.Forms.Button
$btnFav.Text = "Favorite"
$btnFav.Location = New-Object System.Drawing.Point(125,650)
$btnFav.Size = New-Object System.Drawing.Size(100,38)
$form.Controls.Add($btnFav)

$btnReload = New-Object System.Windows.Forms.Button
$btnReload.Text = "Reload"
$btnReload.Location = New-Object System.Drawing.Point(235,650)
$btnReload.Size = New-Object System.Drawing.Size(100,38)
$form.Controls.Add($btnReload)

$btnFolder = New-Object System.Windows.Forms.Button
$btnFolder.Text = "Tools"
$btnFolder.Location = New-Object System.Drawing.Point(345,650)
$btnFolder.Size = New-Object System.Drawing.Size(90,38)
$form.Controls.Add($btnFolder)

$btnUpdate = New-Object System.Windows.Forms.Button
$btnUpdate.Text = "Update"
$btnUpdate.Location = New-Object System.Drawing.Point(445,650)
$btnUpdate.Size = New-Object System.Drawing.Size(90,38)
$form.Controls.Add($btnUpdate)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Clear Output"
$btnClear.Location = New-Object System.Drawing.Point(680,650)
$btnClear.Size = New-Object System.Drawing.Size(120,38)
$form.Controls.Add($btnClear)

$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Text = "Copy Output"
$btnCopy.Location = New-Object System.Drawing.Point(810,650)
$btnCopy.Size = New-Object System.Drawing.Size(120,38)
$form.Controls.Add($btnCopy)

$Script:AllTools = @()
$Script:Favorites = Load-Favorites

function Refresh-Categories {
    $category.Items.Clear()
    $category.Items.Add("All") | Out-Null
    $category.Items.Add("Favorites") | Out-Null
    $Script:AllTools | Select-Object -ExpandProperty Category -Unique | Sort-Object | ForEach-Object { $category.Items.Add($_) | Out-Null }
    $category.SelectedIndex = 0
}

function Refresh-ToolList {
    $toolList.Items.Clear()
    $q = $search.Text.ToLower()
    $cat = $category.SelectedItem
    $items = $Script:AllTools

    if ($cat -and $cat -ne "All") {
        if ($cat -eq "Favorites") { $items = $items | Where-Object { $Script:Favorites -contains $_.RelativePath } }
        else { $items = $items | Where-Object { $_.Category -eq $cat } }
    }
    if ($q) {
        $items = $items | Where-Object { $_.Name.ToLower().Contains($q) -or $_.Category.ToLower().Contains($q) -or $_.Description.ToLower().Contains($q) }
    }

    foreach ($t in $items) {
        $prefix = if ($Script:Favorites -contains $t.RelativePath) { "★ " } else { "" }
        $li = New-Object System.Windows.Forms.ListViewItem($prefix + $t.Name)
        $li.SubItems.Add($t.Category) | Out-Null
        $li.SubItems.Add($t.Extension) | Out-Null
        $li.SubItems.Add($t.Description) | Out-Null
        $li.Tag = $t
        $toolList.Items.Add($li) | Out-Null
    }
}

function Load-ToolsToUI {
    $Script:AllTools = @(Get-JJTTools)
    Refresh-Categories
    Refresh-ToolList
}

$search.Add_TextChanged({ Refresh-ToolList })
$category.Add_SelectedIndexChanged({ Refresh-ToolList })
$toolList.Add_DoubleClick({ if ($toolList.SelectedItems.Count -gt 0) { Run-Tool $toolList.SelectedItems[0].Tag } })
$btnRun.Add_Click({ if ($toolList.SelectedItems.Count -gt 0) { Run-Tool $toolList.SelectedItems[0].Tag } })
$btnFav.Add_Click({
    if ($toolList.SelectedItems.Count -gt 0) {
        $t = $toolList.SelectedItems[0].Tag
        if ($Script:Favorites -contains $t.RelativePath) { $Script:Favorites = @($Script:Favorites | Where-Object { $_ -ne $t.RelativePath }) }
        else { $Script:Favorites = @($Script:Favorites + $t.RelativePath) }
        Save-Favorites $Script:Favorites
        Refresh-ToolList
    }
})
$btnReload.Add_Click({ Load-ToolsToUI })
$btnFolder.Add_Click({ Start-Process explorer.exe $Script:ToolsDir })
$btnUpdate.Add_Click({ Invoke-JJTUpdate })
$btnClear.Add_Click({ $output.Clear() })
$btnCopy.Add_Click({ if ($output.Text) { [System.Windows.Forms.Clipboard]::SetText($output.Text) } })

Load-ToolsToUI
[void]$form.ShowDialog()
