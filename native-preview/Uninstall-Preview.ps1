#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
param()
$ErrorActionPreference = "Stop"
$packageName = "XiaomiShareNativeMenu.Preview"
$certPath = Join-Path $PSScriptRoot "$packageName.cer"

# Delete only the isolated preview identity. Never modify Xiaomi's native CLSID/verbs
# or the existing XiaomiShareShellExt.Minimal package.
Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-AppxPackage -Package $_.PackageFullName -ErrorAction Stop
}
if (Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue) {
    throw "Preview package registration still exists; certificate and vendor registry have not been touched."
}

if (Test-Path -LiteralPath $certPath -PathType Leaf) {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certPath)
    if ($cert.Subject -ne "CN=XiaomiShareNativeMenuPreview") {
        throw "Unexpected preview certificate. Refusing to remove any certificate."
    }
    $path = "Cert:\LocalMachine\TrustedPeople\$($cert.Thumbprint)"
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force -ErrorAction Stop
    }
}
else {
    Write-Warning "Preview .cer not found; the package was removed but the preview signing certificate may remain in TrustedPeople."
}

Write-Host "Preview package removed. The Xiaomi vendor right-click menu and the existing Minimal extension were not modified." -ForegroundColor Green
Write-Host "Restart Explorer or sign out/in if the first-level menu still shows a stale entry."
