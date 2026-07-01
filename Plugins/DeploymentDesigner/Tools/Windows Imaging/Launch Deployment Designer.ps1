$PluginRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$Html = Join-Path $PluginRoot "Web\DeploymentDesigner.html"
if (!(Test-Path $Html)) {
    Write-Host "Missing Deployment Designer HTML:" -ForegroundColor Red
    Write-Host $Html
    Read-Host "Press Enter to close"
    exit 1
}
Start-Process $Html
Write-Host "Opened JayJaysToolkit Deployment Designer."
