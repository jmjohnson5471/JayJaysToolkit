$pluginRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$runner = Join-Path $pluginRoot "Engine\RunManagedApp.ps1"
& $runner -AppId "Rufus"
