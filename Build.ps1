[CmdletBinding()]
param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Src = Join-Path $Root "src"
$Dist = Join-Path $Root "dist"
$Payload = Join-Path $Dist "payload"
$IdentityWork = Join-Path $Dist "identity-work"
$IdentityMsix = Join-Path $Dist "XiaomiShareShellExt.Identity.msix"
$CerPath = Join-Path $Dist "XiaomiShareShellExt.cer"
$PfxPath = Join-Path $Dist "XiaomiShareShellExt.temp.pfx"

function Find-WindowsSdkTool([string]$Name) {
    $kits = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\bin"
    if (-not (Test-Path $kits)) { throw "Windows SDK not found: $kits" }
    $tool = Get-ChildItem -Path $kits -Filter $Name -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\x64\\' } |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if (-not $tool) { throw "$Name not found in Windows SDK. Install Windows 11 SDK." }
    return $tool.FullName
}

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw ".NET SDK not found. Install .NET 9 SDK first."
}

Remove-Item $Dist -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path (Join-Path $Payload "XiaomiShare.ShellExt") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Payload "XiaomiShare.Helper") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Payload "Assets") -Force | Out-Null
New-Item -ItemType Directory -Path $IdentityWork -Force | Out-Null

Write-Host "[1/5] Building native-AOT shell extension..."
$ShellPublish = Join-Path $Dist "publish-shell"
dotnet publish (Join-Path $Src "XiaomiShare.ShellExt\XiaomiShare.ShellExt.csproj") -r win-x64 -c $Configuration -o $ShellPublish
if ($LASTEXITCODE -ne 0) { throw "ShellExt build failed." }
Copy-Item (Join-Path $ShellPublish "XiaomiShare.ShellExt.dll") (Join-Path $Payload "XiaomiShare.ShellExt\XiaomiShare.ShellExt.dll") -Force

Write-Host "[2/5] Building one-shot Xiaomi send helper..."
$HelperPublish = Join-Path $Dist "publish-helper"
dotnet publish (Join-Path $Src "XiaomiShare.Helper\XiaomiShare.Helper.csproj") -r win-x64 -c $Configuration -o $HelperPublish
if ($LASTEXITCODE -ne 0) { throw "XiaomiShare.Helper build failed." }
Copy-Item (Join-Path $HelperPublish "XiaomiShare.Helper.exe") (Join-Path $Payload "XiaomiShare.Helper\XiaomiShare.Helper.exe") -Force
Copy-Item (Join-Path $Src "SparsePackage\Assets\*") (Join-Path $Payload "Assets") -Force

Write-Host "[3/5] Building sparse identity package..."
Copy-Item (Join-Path $Src "SparsePackage\AppxManifest.xml") (Join-Path $IdentityWork "AppxManifest.xml") -Force
$MakeAppx = Find-WindowsSdkTool "makeappx.exe"
$SignTool = Find-WindowsSdkTool "signtool.exe"
& $MakeAppx pack /o /d $IdentityWork /nv /p $IdentityMsix
if ($LASTEXITCODE -ne 0) { throw "MakeAppx failed." }

Write-Host "[4/5] Creating a local signing certificate..."
$cert = New-SelfSignedCertificate `
    -Type Custom `
    -Subject "CN=XiaomiShareShellExt" `
    -FriendlyName "Xiaomi Share Shell Extension local signing" `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -KeyExportPolicy Exportable `
    -HashAlgorithm SHA256 `
    -KeyUsage DigitalSignature `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}") `
    -CertStoreLocation "Cert:\CurrentUser\My"

$passwordPlain = [Guid]::NewGuid().ToString("N")
$password = ConvertTo-SecureString $passwordPlain -AsPlainText -Force
try {
    Export-PfxCertificate -Cert $cert -FilePath $PfxPath -Password $password | Out-Null
    Export-Certificate -Cert $cert -FilePath $CerPath | Out-Null
    Set-Content -Path (Join-Path $Dist "certificate-thumbprint.txt") -Value $cert.Thumbprint -NoNewline

    Write-Host "[5/5] Signing sparse identity package..."
    & $SignTool sign /fd SHA256 /f $PfxPath /p $passwordPlain $IdentityMsix
    if ($LASTEXITCODE -ne 0) { throw "SignTool failed." }
}
finally {
    Remove-Item $PfxPath -Force -ErrorAction SilentlyContinue
    Remove-Item ("Cert:\CurrentUser\My\" + $cert.Thumbprint) -Force -ErrorAction SilentlyContinue
}
Remove-Item $ShellPublish -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $HelperPublish -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $IdentityWork -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Build complete:" -ForegroundColor Green
Write-Host "  Payload:  $Payload"
Write-Host "  Identity: $IdentityMsix"
Write-Host "  Public certificate: $CerPath"
Write-Host "Next: run .\Install.ps1"
