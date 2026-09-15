[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA "Programs\XiaomiShareShellExt")
)

$ErrorActionPreference = "Stop"

# Current Windows 11 MSIX validation checks self-signed package trust in the
# LocalMachine certificate store. Relaunch elevated when required.
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -InstallRoot `"$InstallRoot`""
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argLine -Wait
    exit $LASTEXITCODE
}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Dist = Join-Path $Root "dist"
$Payload = Join-Path $Dist "payload"
$IdentityMsix = Join-Path $Dist "XiaomiShareShellExt.Identity.msix"
$CerPath = Join-Path $Dist "XiaomiShareShellExt.cer"
$ThumbprintFile = Join-Path $Dist "certificate-thumbprint.txt"
$PackageName = "XiaomiShareShellExt.Minimal"
$UpstreamPackageName = "5f71dad9-3e77-4ada-9fad-12c2e761288f"

foreach ($required in @($Payload, $IdentityMsix, $CerPath, $ThumbprintFile)) {
    if (-not (Test-Path $required)) {
        throw "Missing build output: $required"
    }
}

# Avoid duplicate first-level Xiaomi commands if the upstream extension is installed.
$upstream = Get-AppxPackage -Name $UpstreamPackageName -ErrorAction SilentlyContinue
if ($upstream) {
    throw "The original MiDropShellExtForWindows11 package is still installed. Uninstall it first, then run this script again."
}

# Remove a previous registration of this minimal package, if any.
Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -ErrorAction Stop }

# Remove certificate from an older local build so rebuilds do not accumulate trust entries.
$oldThumbprintPath = Join-Path $InstallRoot "certificate-thumbprint.txt"
if (Test-Path $oldThumbprintPath) {
    $oldThumbprint = (Get-Content $oldThumbprintPath -Raw).Trim()
    if ($oldThumbprint) {
        Remove-Item ("Cert:\LocalMachine\TrustedPeople\" + $oldThumbprint) -Force -ErrorAction SilentlyContinue
        # Also clean the legacy CurrentUser location used by early builds.
        Remove-Item ("Cert:\CurrentUser\TrustedPeople\" + $oldThumbprint) -Force -ErrorAction SilentlyContinue
    }
}

New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
Copy-Item (Join-Path $Payload "*") $InstallRoot -Recurse -Force
Copy-Item $CerPath (Join-Path $InstallRoot "XiaomiShareShellExt.cer") -Force
Copy-Item $ThumbprintFile (Join-Path $InstallRoot "certificate-thumbprint.txt") -Force

# Trust only the public package-signing certificate. The private key is not distributed.
$imported = Import-Certificate -FilePath $CerPath -CertStoreLocation "Cert:\LocalMachine\TrustedPeople"
if (-not $imported) { throw "Failed to trust the local package certificate." }

try {
    Add-AppxPackage -Path $IdentityMsix -ExternalLocation $InstallRoot
}
catch {
    $newThumbprint = (Get-Content $ThumbprintFile -Raw).Trim()
    if ($newThumbprint) {
        Remove-Item ("Cert:\LocalMachine\TrustedPeople\" + $newThumbprint) -Force -ErrorAction SilentlyContinue
    }
    throw
}

Write-Host ""
Write-Host "Installed." -ForegroundColor Green
Write-Host "Only the Windows 11 primary context-menu command is registered."
Write-Host "Developer Mode is not required."
Write-Host "If the command is not visible yet, restart Explorer or sign out/in."
