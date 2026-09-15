[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA "Programs\XiaomiShareShellExt")
)

$ErrorActionPreference = "Stop"

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -InstallRoot `"$InstallRoot`""
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argLine -Wait
    exit $LASTEXITCODE
}

$PackageName = "XiaomiShareShellExt.Minimal"
$thumbprint = $null
$thumbprintPath = Join-Path $InstallRoot "certificate-thumbprint.txt"
if (Test-Path $thumbprintPath) {
    $thumbprint = (Get-Content $thumbprintPath -Raw).Trim()
}

Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -ErrorAction Stop }

if ($thumbprint) {
    Remove-Item ("Cert:\LocalMachine\TrustedPeople\" + $thumbprint) -Force -ErrorAction SilentlyContinue
    # Also clean the legacy CurrentUser location used by early builds.
    Remove-Item ("Cert:\CurrentUser\TrustedPeople\" + $thumbprint) -Force -ErrorAction SilentlyContinue
}

Remove-Item (Join-Path $env:LOCALAPPDATA "XiaomiShareShellExt") -Recurse -Force -ErrorAction SilentlyContinue
try {
    Remove-Item $InstallRoot -Recurse -Force -ErrorAction Stop
}
catch {
    Write-Warning "The shell DLL is still loaded. Restart Explorer or sign out, then delete: $InstallRoot"
}

Write-Host "Unregistered XiaomiShareShellExt.Minimal." -ForegroundColor Green
