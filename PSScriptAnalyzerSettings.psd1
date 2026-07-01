@{
    # Run from repo root on a Windows machine with PSScriptAnalyzer installed:
    #   Install-Module PSScriptAnalyzer -Scope CurrentUser
    #   Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
    Severity = @('Error', 'Warning')

    ExcludeRules = @(
        # Tool scripts are intentionally short, direct command wrappers (e.g. "sfc /scannow").
        # Requiring comment-based help on every one-liner would add noise, not clarity.
        'PSProvideCommentHelp',
        # Plenty of tools legitimately just launch an .msc/.exe with no pipeline output.
        'PSUseShouldProcessForStateChangingFunctions'
    )

    Rules = @{
        PSAvoidUsingWriteHost = @{
            Enable = $false  # Console-mode tools intentionally write to host for live output in the app.
        }
        PSUseConsistentIndentation = @{
            Enable          = $true
            IndentationSize = 4
        }
    }
}
