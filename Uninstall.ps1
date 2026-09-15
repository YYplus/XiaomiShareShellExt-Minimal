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
        throw "Elevated uninstaller failed with exit code $($process.ExitCode)."
    }
    exit 0
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
if ($ElevatedChild) { Read-Host "Press Enter to close" | Out-Null }
