[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA "Programs\XiaomiShareShellExt"),
    [switch]$ElevatedChild
)

$ErrorActionPreference = "Stop"

trap {
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($ElevatedChild) { Read-Host "Press Enter to close" | Out-Null }
    exit 1
}

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $PSCommandPath + '"'), '-ElevatedChild')
    if ($PSBoundParameters.ContainsKey('InstallRoot')) {
        $args += @('-InstallRoot', ('"' + $InstallRoot + '"'))
    }

    $process = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $args -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Elevated installer failed with exit code $($process.ExitCode)."
    }
    exit 0
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

$upstream = Get-AppxPackage -Name $UpstreamPackageName -ErrorAction SilentlyContinue
if ($upstream) {
    throw "The original MiDropShellExtForWindows11 package is still installed. Uninstall it first, then run this script again."
}

Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -ErrorAction Stop }

$oldThumbprintPath = Join-Path $InstallRoot "certificate-thumbprint.txt"
if (Test-Path $oldThumbprintPath) {
    $oldThumbprint = (Get-Content $oldThumbprintPath -Raw).Trim()
    if ($oldThumbprint) {
        Remove-Item ("Cert:\LocalMachine\TrustedPeople\" + $oldThumbprint) -Force -ErrorAction SilentlyContinue
        Remove-Item ("Cert:\CurrentUser\TrustedPeople\" + $oldThumbprint) -Force -ErrorAction SilentlyContinue
    }
}

New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
Copy-Item (Join-Path $Payload "*") $InstallRoot -Recurse -Force
Copy-Item $CerPath (Join-Path $InstallRoot "XiaomiShareShellExt.cer") -Force
Copy-Item $ThumbprintFile (Join-Path $InstallRoot "certificate-thumbprint.txt") -Force

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
Write-Host "Installed XiaomiShareShellExt.Minimal successfully." -ForegroundColor Green
Write-Host "Developer Mode is not required."
Write-Host "If the command is not visible yet, restart Explorer or sign out/in."

if ($ElevatedChild) { Read-Host "Press Enter to close" | Out-Null }
