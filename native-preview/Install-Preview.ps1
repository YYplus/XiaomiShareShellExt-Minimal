#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
param()
$ErrorActionPreference = "Stop"
$packageName = "XiaomiShareNativeMenu.Preview"
$clsid = "{504d69c0-cb52-48df-b5b5-7161829fabc8}"
$msixPath = Join-Path $PSScriptRoot "$packageName.msix"
$certPath = Join-Path $PSScriptRoot "$packageName.cer"
$comKey = "Registry::HKEY_CLASSES_ROOT\CLSID\$clsid\InprocServer32"

foreach ($path in @($msixPath, $certPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing preview artifact: $path" }
}

if (Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue) {
    throw "Preview already installed. To reinstall, run Uninstall-Preview.ps1 first."
}

# Resolve the *real* Xiaomi 6 installation; the COM DLL lives below the product executable.
$key = Get-Item -LiteralPath $comKey -ErrorAction Stop
$dll = [string]$key.GetValue("")
if (-not $dll -or -not (Test-Path -LiteralPath $dll -PathType Leaf)) {
    throw "Cannot locate vendor MiDropShellExt.dll in registered COM path: $dll"
}
$smartShare = Split-Path -Parent $dll
if ((Split-Path -Leaf $smartShare) -ine "MiSmartShare") {
    throw "Unsupported vendor DLL layout: $dll. Only XiaomiPCManager 6.x MiSmartShare layout is tested."
}
$versionDir = Split-Path -Parent $smartShare
$managerExe = Join-Path $versionDir "XiaomiPCManager.exe"
if (-not (Test-Path -LiteralPath $managerExe -PathType Leaf)) {
    throw "XiaomiPCManager.exe not found next to MiSmartShare: $versionDir"
}
foreach ($verb in @(
    "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\*\shell\MiDropExtMenu",
    "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\shell\MiDropExtMenu"
)) {
    $v = Get-Item -LiteralPath $verb -ErrorAction Stop
    if ([string]$v.GetValue("ExplorerCommandHandler") -ine $clsid) {
        throw "Unexpected vendor menu CLSID at $verb. Nothing was changed."
    }
}

$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)
if ($cert.Subject -ne "CN=XiaomiShareNativeMenuPreview") {
    throw "Unexpected preview certificate subject: $($cert.Subject)"
}
$trustedCertPath = "Cert:\LocalMachine\TrustedPeople\$($cert.Thumbprint)"
$addedTrust = -not (Test-Path -LiteralPath $trustedCertPath)
Write-Host "Vendor COM DLL:  $dll"
Write-Host "Native app EXE:  $managerExe"
Write-Host "ExternalLocation: $versionDir"
Write-Host "Vendor DLL signature status: $((Get-AuthenticodeSignature -FilePath $dll).Status)"
Write-Host "Installing ONLY a separate preview package; existing first-level package and vendor registry are preserved."

try {
    if ($addedTrust) {
        Import-Certificate -FilePath $certPath -CertStoreLocation "Cert:\LocalMachine\TrustedPeople" -ErrorAction Stop | Out-Null
    }
    Add-AppxPackage -Path $msixPath -ExternalLocation $versionDir -ErrorAction Stop
    $pkg = Get-AppxPackage -Name $packageName -ErrorAction Stop
    if (-not $pkg) { throw "Appx registration returned without creating preview package" }
    Write-Host "Installed preview: $($pkg.PackageFullName)" -ForegroundColor Green
    Write-Host "Try a single file from the FIRST-LEVEL context menu, then test a folder and multiple files."
    Write-Host "If the preview entry does not appear, sign out/in or restart Explorer."
}
catch {
    if ($addedTrust -and -not (Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $trustedCertPath -Force -ErrorAction SilentlyContinue
    }
    throw
}
