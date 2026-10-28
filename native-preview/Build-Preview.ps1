#Requires -Version 5.1
[CmdletBinding()]
param([string]$TimestampUrl = "http://timestamp.digicert.com")
$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$stage = Join-Path $PSScriptRoot "dist\stage"
$dist = Join-Path $PSScriptRoot "dist"
$msix = Join-Path $dist "XiaomiShareNativeMenu.Preview.msix"
$cer = Join-Path $dist "XiaomiShareNativeMenu.Preview.cer"
$pfx = Join-Path $dist "preview-key.pfx"
$subject = "CN=XiaomiShareNativeMenuPreview"

function Find-SdkTool([string]$name) {
    $sdk = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\bin"
    if (-not (Test-Path -LiteralPath $sdk)) { throw "Windows SDK tools not installed: $sdk" }
    $exe = Get-ChildItem -LiteralPath $sdk -Filter $name -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\x64\\' } |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if (-not $exe) { throw "Missing Windows SDK tool: $name" }
    return $exe.FullName
}

$makeappx = Find-SdkTool "makeappx.exe"
$signtool = Find-SdkTool "signtool.exe"
Remove-Item -LiteralPath $dist -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path (Join-Path $stage "Assets") -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "AppxManifest.xml") -Destination (Join-Path $stage "AppxManifest.xml")
Copy-Item -Path (Join-Path $repo "src\SparsePackage\Assets\*") -Destination (Join-Path $stage "Assets") -Force

$cert = $null
try {
    $cert = New-SelfSignedCertificate -Type Custom -Subject $subject -FriendlyName "Xiaomi original menu test package" -KeyAlgorithm RSA -KeyLength 2048 -KeyExportPolicy Exportable -HashAlgorithm SHA256 -KeyUsage DigitalSignature -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}") -CertStoreLocation "Cert:\CurrentUser\My" -ErrorAction Stop
    $passwordPlain = [guid]::NewGuid().ToString("N")
    $password = ConvertTo-SecureString $passwordPlain -AsPlainText -Force
    Export-PfxCertificate -Cert $cert -FilePath $pfx -Password $password | Out-Null
    Export-Certificate -Cert $cert -FilePath $cer | Out-Null

    # /nv is needed because COM DLL and application EXE are intentionally external to this identity package.
    & $makeappx pack /o /d $stage /nv /p $msix
    if ($LASTEXITCODE -ne 0) { throw "MakeAppx failed: $LASTEXITCODE" }
    & $signtool sign /fd SHA256 /f $pfx /p $passwordPlain /tr $TimestampUrl /td SHA256 $msix
    if ($LASTEXITCODE -ne 0) { throw "SignTool failed: $LASTEXITCODE" }

    Write-Host "Preview MSIX and public certificate created in $dist"
}
finally {
    Remove-Item -LiteralPath $pfx -Force -ErrorAction SilentlyContinue
    if ($cert) {
        Remove-Item -LiteralPath ("Cert:\CurrentUser\My\" + $cert.Thumbprint) -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}
