# PluginLoader.Tests.ps1
#
# Run from repo root on a Windows machine with Pester 5 installed:
#   Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser
#   Invoke-Pester .\Tests\
#
# These tests build a throwaway plugin structure under $env:TEMP so they don't
# touch the real Plugins folder, then exercise Get-JJTPlugins / Get-JJTTools
# against it.

BeforeAll {
    $Script:BaseDir = Join-Path $env:TEMP ("JJT_Test_" + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $Script:BaseDir | Out-Null

    . (Join-Path $PSScriptRoot "..\Core\Logger.ps1")
    . (Join-Path $PSScriptRoot "..\Core\PluginLoader.ps1")

    # --- Well-formed plugin with one console tool ---
    $goodPlugin = Join-Path $Script:BaseDir "Plugins\GoodPlugin"
    New-Item -ItemType Directory -Force -Path (Join-Path $goodPlugin "Tools\Category") | Out-Null
    @{
        Id = "GoodPlugin"; Name = "Good Plugin"; Version = "1.0.0"
        Description = "A valid test plugin."; Author = "Test"; Enabled = $true
    } | ConvertTo-Json | Set-Content (Join-Path $goodPlugin "plugin.json")

    Set-Content (Join-Path $goodPlugin "Tools\Category\Sample Tool.ps1") "Write-Host 'hi'"
    @{
        Name = "Sample Tool"; Category = "Category"; Description = "A sample."
        RunAsAdmin = $false; Hidden = $false; Arguments = ""; ExecutionMode = "Console"
        Confirm = $true; ConfirmMessage = "Are you sure?"
    } | ConvertTo-Json | Set-Content (Join-Path $goodPlugin "Tools\Category\Sample Tool.json")

    # --- Malformed plugin manifest (should be skipped + logged, not throw) ---
    $badPlugin = Join-Path $Script:BaseDir "Plugins\BadPlugin"
    New-Item -ItemType Directory -Force -Path $badPlugin | Out-Null
    Set-Content (Join-Path $badPlugin "plugin.json") "{ not valid json "

    # --- Disabled plugin (should be excluded) ---
    $disabledPlugin = Join-Path $Script:BaseDir "Plugins\DisabledPlugin"
    New-Item -ItemType Directory -Force -Path (Join-Path $disabledPlugin "Tools") | Out-Null
    @{ Id = "DisabledPlugin"; Name = "Disabled Plugin"; Enabled = $false } |
        ConvertTo-Json | Set-Content (Join-Path $disabledPlugin "plugin.json")
}

AfterAll {
    Remove-Item $Script:BaseDir -Recurse -Force -ErrorAction SilentlyContinue
}

Describe "Get-JJTPlugins" {
    It "finds valid, enabled plugins" {
        $plugins = @(Get-JJTPlugins)
        ($plugins | Where-Object Id -eq "GoodPlugin").Count | Should -Be 1
    }

    It "excludes disabled plugins" {
        $plugins = @(Get-JJTPlugins)
        ($plugins | Where-Object Id -eq "DisabledPlugin").Count | Should -Be 0
    }

    It "skips malformed plugin manifests without throwing" {
        { @(Get-JJTPlugins) } | Should -Not -Throw
        $plugins = @(Get-JJTPlugins)
        ($plugins | Where-Object Id -eq "BadPlugin").Count | Should -Be 0
    }
}

Describe "Get-JJTTools" {
    It "discovers tools and merges JSON metadata" {
        $tools = @(Get-JJTTools)
        $tool = $tools | Where-Object Name -eq "Sample Tool"
        $tool | Should -Not -BeNullOrEmpty
        $tool.Category | Should -Be "Category"
        $tool.Confirm | Should -Be $true
        $tool.ConfirmMessage | Should -Be "Are you sure?"
        $tool.RunAsAdmin | Should -Be $false
    }

    It "defaults RunAsAdmin to true when a tool has no JSON metadata" {
        $noMetaDir = Join-Path $Script:BaseDir "Plugins\GoodPlugin\Tools\Category"
        Set-Content (Join-Path $noMetaDir "No Metadata Tool.ps1") "Write-Host 'no meta'"

        $tools = @(Get-JJTTools)
        $tool = $tools | Where-Object Name -eq "No Metadata Tool"
        $tool.RunAsAdmin | Should -Be $true
        $tool.Confirm | Should -Be $false
    }
}
