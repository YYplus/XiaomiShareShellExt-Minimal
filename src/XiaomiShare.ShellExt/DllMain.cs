using XiaomiShare.Core;
using ShellExtensions;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace XiaomiShare.ShellExt;

public static class DllMain
{
    private static readonly Guid PackagedClsid = new("E5DB1D6B-2057-4EFD-B087-EF638D07C6AF");

#pragma warning disable CA2255
    [ModuleInitializer]
#pragma warning restore CA2255
    public static void Initialize()
    {
        try
        {
            var folder = XiaomiPcManagerHelper.GetInstallPath();
            if (!Directory.Exists(folder)) return;

            ShellExtensionsClassFactory.RegisterInProcess(
                PackagedClsid,
                () => new ContextMenu(XiaomiPcManagerHelper.GetIconString()));
        }
        catch
        {
        }
    }

    [UnmanagedCallersOnly(EntryPoint = "DllCanUnloadNow")]
    private static int DllCanUnloadNow() => ShellExtensionsClassFactory.DllCanUnloadNow();

    [UnmanagedCallersOnly(EntryPoint = "DllGetClassObject")]
    private static unsafe int DllGetClassObject(Guid* clsid, Guid* riid, void** ppv) =>
        ShellExtensionsClassFactory.DllGetClassObject(clsid, riid, ppv);

    public static void SendToXiaomi(string[] files)
    {
        try
        {
            var root = Path.GetFullPath(Path.Combine(DllModule.BaseDirectory, ".."));
            var helper = Path.Combine(root, "XiaomiShare.Helper", "XiaomiShare.Helper.exe");
            if (!File.Exists(helper)) return;

            var key = FilesHelper.SaveFilesAsync(files, default).GetAwaiter().GetResult();
            if (string.IsNullOrEmpty(key)) return;

            Process.Start(new ProcessStartInfo
            {
                FileName = helper,
                Arguments = $"--share-files {key}",
                UseShellExecute = false,
                CreateNoWindow = true,
                WorkingDirectory = Path.GetDirectoryName(helper)!
            });
        }
        catch
        {
        }
    }
}
