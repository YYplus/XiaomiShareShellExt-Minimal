# Vendor-native Xiaomi PC Manager 6.x menu — isolated preview

This is an **unmerged experiment**, not a replacement for `XiaomiShareShellExt.Minimal`.

Observed layout on XiaomiPCManager **6.0.0.39**:

- Factory `ExplorerCommandHandler`: `{504d69c0-cb52-48df-b5b5-7161829fabc8}` for both files and directories.
- Registered COM server: `<version>\MiSmartShare\MiDropShellExt.dll`.
- Main executable: `<version>\XiaomiPCManager.exe`.
- `MiSmartShare\MiPcContinuity.exe` does **not** exist.

The original "Show more options → 使用小米互传发送" succeeds on this machine. This proof of concept **does not** replay `WM_COPYDATA` or launch a third-party helper. Instead, it registers the factory's own CLSID and DLL in a temporary signed sparse package. The app identity points to the **version root** (`-ExternalLocation`), while the COM DLL's manifest path points into `MiSmartShare`.

## What this test changes

- Adds a **separate** package named `XiaomiShareNativeMenu.Preview` and its own publicly trusted **local preview signing certificate**.
- Adds an additional Windows 11 first-level menu entry backed by the factory DLL.
- Does not modify any Xiaomi binary, vendor HKLM CLSID/verb entry, existing `XiaomiShareShellExt.Minimal` registration, or system security settings.
- Windows Explorer may show **two first-level items** until the old preview/test package is removed. This is expected.

## Install the GitHub Actions artifact

From the `Build vendor native menu preview` Actions run, download `XiaomiShareNativeMenu-Preview`, extract it, and open **Windows PowerShell as administrator** in its directory:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Preview.ps1
```

The installer verifies the Xiaomi vendor COM path, both factory menu CLSIDs, executable layout, and preview certificate subject. It refuses to install on a different layout. Install **only after reviewing the script and build source**; the preview uses a locally generated signing certificate.

Test **one file first**, then a directory and multiple files. The menu might have the same display name as the original plugin because the vendor supplies the title. If no menu appears, sign out/in or restart Explorer. If the menu appears but does not invoke sending, collect the exact behavior and revert the preview.

## Uninstall

In the same extracted folder, open administrator Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-Preview.ps1
```

The uninstaller unregisters the **preview identity only** and removes its own certificate using the shipped `.cer` fingerprint and expected subject. It does not touch either of the other two Xiaomi menu registrations. Sign out/in if Explorer does not refresh.

## Technical caveats

- This is a native-COM integration **hypothesis**, not validated yet on XiaomiPCManager 6.0.0.39. The legacy menu working proves the factory handler works in its original context, not necessarily within the packaged COM surrogate.
- When Xiaomi updates to a new version directory, the preview's `ExternalLocation` must be re-registered. This experiment intentionally avoids automatic repair.
- No changes to the Rust patcher or its embedded third-party binary are included here. Integrate only after first-level menu functionality and cleanup are confirmed on a real Windows system.
- This project deliberately does **not** disable antivirus/Defender, enable Developer Mode, mutate any existing Xiaomi registry key, or copy vendor binaries.
