# XiaomiShareShellExt-Minimal

一个仅实现 **Windows 11 一级右键菜单 →「使用小米互传发送」** 的最小版本。

基于 `cnbluefire/MiDropShellExtForWindows11` 的小米互传调用方式裁剪，并保留其对新版小米互联服务的兼容逻辑。

## 只包含什么

- Windows 11 现代一级右键菜单：`使用小米互传发送`
- 支持文件、多选文件和文件夹
- 点击菜单后启动一个一次性 helper，将选中路径交给小米电脑管家/小米互联服务
- helper 完成发送调用后退出，不常驻后台

## 明确不包含什么

- 不包含拖拽到屏幕顶部/触发角功能
- 不注册 Windows Share Target，因此不会出现在系统“共享”面板
- 不包含华为分享、荣耀分享
- 不添加开始菜单快捷方式或占位 App
- 不添加托盘程序、后台服务、计划任务
- 不恢复 Windows 10 经典右键菜单
- 不修改小米电脑管家文件

## 为什么仍然有 package identity

Windows 11 的现代一级 File Explorer 右键菜单使用 `IExplorerCommand`，并通过包清单中的 `windows.comServer` 与 `windows.fileExplorerContextMenus` 注册。微软当前要求这类命令具有 package identity。

本项目因此没有使用原项目的完整 `MiDropShellExt.Package` 安装方式，而改为 **sparse package / package with external location**：

- 程序二进制仍在普通目录中；
- identity package 只承担 Windows 所要求的身份和 Shell 注册；
- 不包含额外应用功能；
- `AppListEntry="none"`，因此不会生成开始菜单入口。

系统中仍会存在名为 `XiaomiShareShellExt.Minimal` 的 package identity。这一点无法在使用微软支持的 Win11 一级菜单机制时彻底去掉。

清单只显式声明 sparse/external-location 模式所需的 `runFullTrust` 与 `unvirtualizedResources`。`Get-AppxPackage` 可能另外显示 `internetClient`、`wifiData`、`cellularData`、`uniqueAppPackageCapability` 等系统派生 capability；它们不是本项目清单中额外申请的权限。

## 结构

```text
XiaomiShareShellExt.Minimal
        |
        +-- IExplorerCommand / COM
                |
                +-- XiaomiShare.ShellExt.dll
                        |
                        +-- 右键“使用小米互传发送”
                                |
                                +-- XiaomiShare.Helper.exe（一次性进程）
                                        |
                                        +-- hyperConnect.exe
                                            或 XiaomiPcManager.exe
                                            或 MiPcContinuity.exe
```

选中文件列表不会直接塞进命令行。Shell DLL 会先把列表写入 `%LOCALAPPDATA%\XiaomiShareShellExt\ShareFiles` 的短期缓存文件，再把随机 key 交给 helper，这样多选大量文件时不会受到 Windows 命令行长度限制。缓存文件在读取后删除，超过 12 小时的残留缓存也会自动清理。

## 构建要求

- Windows 11 x64
- Visual Studio 2022 Build Tools 或 Visual Studio 2022，包含 C++/NativeAOT 所需工具链
- Windows 11 SDK（需要 `MakeAppx.exe` 与 `SignTool.exe`）
- .NET 9 SDK
- PowerShell
- 首次构建时需要联网恢复 NuGet 包 `ShellExtensions 0.0.9`

## 构建

在 PowerShell 中进入项目根目录：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Build.ps1
```

`Build.ps1` 会：NativeAOT 编译 Shell DLL 和一次性 helper、生成 sparse identity MSIX、创建临时自签名代码签名证书、签名 MSIX，并删除构建时私钥，只保留安装所需的公开 `.cer`。

## 安装

如果已经安装原版 `MiDropShellExtForWindows11`，请先卸载它，否则两个扩展会同时注册一级“小米互传”菜单。安装脚本会检测原版包并停止，而不会擅自卸载它。

```powershell
.\Install.ps1
```

安装脚本会在需要时自动请求管理员权限（UAC），仅用于把本地 MSIX 的公开签名证书加入 `LocalMachine\TrustedPeople`。不需要开启 Windows 开发者模式。

默认普通程序文件安装到：

```text
%LOCALAPPDATA%\Programs\XiaomiShareShellExt
```

然后通过 `Add-AppxPackage -ExternalLocation ...` 注册 sparse package identity。

如果安装后一级右键菜单没有立刻刷新，重启 Explorer 或注销再登录即可。

## 卸载

```powershell
.\Uninstall.ps1
```

脚本会注销 package identity、删除本项目文件和缓存，并移除安装时导入到本地计算机 `TrustedPeople` 的公开证书。卸载脚本同样会在需要时请求管理员权限。

## 与原项目相比的关键裁剪

原项目后续版本包含/曾包含：Windows Share Target、开始菜单占位入口，以及华为/荣耀分享支持。本版本均移除，只留下小米互传一级右键菜单路径。

同时保留当前上游与新版小米互联服务相关的兼容逻辑：优先识别 `hyperConnect.exe`，其次识别 `XiaomiPcManager.exe` 和 `MiPcContinuity.exe`；对于 5.x 将 COM DLL 注册在 `native-interconnect` 子目录中的情况，会向上定位 `hyperConnect.exe`。消息窗口同时识别 `XiaomiPCManager` 和 `MiPcContinuity`。

## GitHub Actions 构建

Actions 直接从仓库中的 `src/` 构建，不再使用中间 `source.b64` 或 `source.zip`。构建完成后下载 `XiaomiShareShellExt-Minimal-win-x64` artifact，解压后运行 `Install.ps1` 即可。

## 上游与许可

Upstream: https://github.com/cnbluefire/MiDropShellExtForWindows11

上游项目采用 MIT License。本项目包含基于其实现思路修改的代码，因此保留原 MIT 许可和版权声明。见 `LICENSE` 与 `NOTICE.md`。
