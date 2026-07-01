# ToolRunner.ps1
#
# Runs "Console" mode tools (the ones whose output is captured and shown inside the
# app) WITHOUT blocking the WinForms UI thread.
#
# Previously Run-Tool called $process.WaitForExit() directly on the UI thread, which
# froze the entire window for the duration of the tool (SFC/DISM can run 5-15+ minutes).
# This module launches the process asynchronously, streams stdout/stderr into a
# thread-safe queue, and exposes a Cancel path. The GUI drains the queue on a
# System.Windows.Forms.Timer tick, so the UI thread is never blocked waiting on the
# child process.
#
# Interactive/External modes (which open their own window via Start-Process) were
# never blocking in the first place and are untouched here.

$Script:JJT_RunState = @{
    Process   = $null
    Queue     = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
    IsRunning = $false
    ToolName  = ""
    StartTime = $null
    ExitCode  = $null
}

function Start-JJTConsoleTool {
    param([Parameter(Mandatory = $true)][object]$Tool)

    if ($Script:JJT_RunState.IsRunning) {
        throw "A tool is already running. Wait for it to finish or cancel it first."
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    if ($Tool.Extension -eq ".ps1") {
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($Tool.Path)`" $($Tool.Arguments)"
    } elseif ($Tool.Extension -in ".bat", ".cmd") {
        $psi.FileName = "cmd.exe"
        $psi.Arguments = "/c `"$($Tool.Path)`" $($Tool.Arguments)"
    } else {
        throw "Unsupported internal execution type: $($Tool.Extension)"
    }

    $psi.WorkingDirectory = $Tool.WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $proc.EnableRaisingEvents = $true

    $queue = $Script:JJT_RunState.Queue

    $outAction = {
        if ($EventArgs.Data) { $Event.MessageData.Enqueue("OUT|" + $EventArgs.Data) }
    }
    $errAction = {
        if ($EventArgs.Data) { $Event.MessageData.Enqueue("ERR|" + $EventArgs.Data) }
    }
    $exitAction = {
        $Event.MessageData.Enqueue("EXIT|" + $Sender.ExitCode)
    }

    Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action $outAction -MessageData $queue | Out-Null
    Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived  -Action $errAction -MessageData $queue | Out-Null
    Register-ObjectEvent -InputObject $proc -EventName Exited             -Action $exitAction -MessageData $queue | Out-Null

    $Script:JJT_RunState.IsRunning = $true
    $Script:JJT_RunState.ToolName  = $Tool.Name
    $Script:JJT_RunState.StartTime = Get-Date
    $Script:JJT_RunState.ExitCode  = $null
    $Script:JJT_RunState.Process   = $proc

    [void]$proc.Start()
    $proc.BeginOutputReadLine()
    $proc.BeginErrorReadLine()
}

function Receive-JJTToolOutput {
    # Drains everything queued since the last poll. Called from a UI-thread Timer tick.
    # Returns an ordered array of @{ Type = 'Out'|'Err'|'Exit'; Text = '...' }
    $queue = $Script:JJT_RunState.Queue
    $items = @()

    while ($queue.Count -gt 0) {
        $raw = $queue.Dequeue()
        $split = $raw -split '\|', 2
        $type = $split[0]
        $text = if ($split.Count -gt 1) { $split[1] } else { "" }

        if ($type -eq "EXIT") {
            $Script:JJT_RunState.IsRunning = $false
            $Script:JJT_RunState.ExitCode = $text
            $items += [PSCustomObject]@{ Type = "Exit"; Text = $text }
        } elseif ($type -eq "ERR") {
            $items += [PSCustomObject]@{ Type = "Err"; Text = $text }
        } else {
            $items += [PSCustomObject]@{ Type = "Out"; Text = $text }
        }
    }

    return $items
}

function Stop-JJTRunningTool {
    if (-not $Script:JJT_RunState.IsRunning -or -not $Script:JJT_RunState.Process) { return }

    $proc = $Script:JJT_RunState.Process
    try {
        # .Kill($true) (kill entire process tree) is only available on newer .NET;
        # Windows PowerShell 5.1 ships an older System.Diagnostics.Process, so fall
        # back to taskkill /T to make sure child processes (e.g. a spawned DISM/SFC
        # child) actually die too, not just the parent shell.
        try { $proc.Kill($true) }
        catch { Start-Process -FilePath "taskkill.exe" -ArgumentList "/PID $($proc.Id) /T /F" -WindowStyle Hidden -Wait }
    } catch {
        Write-JJTLog "Failed to stop running tool '$($Script:JJT_RunState.ToolName)': $($_.Exception.Message)" -Level Error
    } finally {
        $Script:JJT_RunState.IsRunning = $false
    }
}
