using Microsoft.Win32;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace XiaomiShare.Core;

public static class XiaomiPcManagerHelper
{
    private static readonly IReadOnlyList<string> PcManagerRegKeys =
    [
        "{504d69c0-cb52-48df-b5b5-7161829fabc8}",
        "{1bca9901-05c3-4d01-8ad4-78da2eac9b3f}",
    ];

    public static string GetInstallPath()
    {
        try
        {
            foreach (var clsid in PcManagerRegKeys)
            {
                using var subKey = Registry.ClassesRoot.OpenSubKey($"CLSID\\{clsid}\\InprocServer32");
                if (subKey?.GetValue(null) is not string path || string.IsNullOrWhiteSpace(path))
                    continue;

                var folder = Path.GetDirectoryName(path);
                if (folder?.Contains("\\native-interconnect\\", StringComparison.OrdinalIgnoreCase) is true)
                {
                    while (!string.IsNullOrEmpty(folder))
                    {
                        if (File.Exists(Path.Combine(folder, "hyperConnect.exe"))) break;
                        folder = Path.GetDirectoryName(folder);
                    }
                }

                if (Directory.Exists(folder)) return folder;
            }
        }
        catch { }

        return string.Empty;
    }

    public static string GetExecuteFile()
    {
        var installPath = GetInstallPath();
        if (string.IsNullOrEmpty(installPath)) return string.Empty;

        var hyperConnect = Path.Combine(installPath, "hyperConnect.exe");
        if (File.Exists(hyperConnect)) return hyperConnect;

        var pcManager = Path.Combine(installPath, "XiaomiPcManager.exe");
        if (File.Exists(pcManager)) return pcManager;

        var continuity = Path.Combine(installPath, "MiPcContinuity.exe");
        if (File.Exists(continuity)) return continuity;

        return string.Empty;
    }

    public static string GetIconString()
    {
        var installPath = GetInstallPath();
        if (string.IsNullOrEmpty(installPath)) return string.Empty;

        var icon = Path.Combine(installPath, "Assets", "midrop_logo.ico");
        if (File.Exists(icon)) return icon;

        var executable = GetExecuteFile();
        return File.Exists(executable) ? $"{executable},0" : string.Empty;
    }

    public static Task<bool> LaunchAsync(CancellationToken cancellationToken)
    {
        if (FindMessageWindow() != 0) return Task.FromResult(true);

        var executable = GetExecuteFile();
        return string.IsNullOrEmpty(executable)
            ? Task.FromResult(false)
            : LaunchAsyncCore(executable, cancellationToken);
    }

    public static async Task<bool> SendCachedFilesAsync(string cacheKey, TimeSpan timeout)
    {
        var payload = await FilesHelper.GetXiaomiFileAsync(cacheKey, default).ConfigureAwait(false);
        return !string.IsNullOrEmpty(payload) && await SendFilesAsyncCore(payload, timeout).ConfigureAwait(false);
    }

    internal static string CreateXiaomiFile(string[] files)
    {
        var sb = new StringBuilder();
        foreach (var path in files)
        {
            if (string.IsNullOrWhiteSpace(path) || !Path.IsPathRooted(path)) continue;
            if (sb.Length > 0) sb.Append('|');
            sb.Append(path);
        }
        return sb.ToString();
    }

    private static Task<bool> LaunchAsyncCore(string executable, CancellationToken cancellationToken)
    {
        var tcs = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        var registration = cancellationToken.Register(() => tcs.TrySetCanceled(cancellationToken));

        var thread = new Thread(() =>
        {
            try
            {
                using var process = Process.Start(new ProcessStartInfo(executable)
                {
                    UseShellExecute = true
                });

                var deadline = DateTime.UtcNow.AddSeconds(15);
                while (!cancellationToken.IsCancellationRequested && DateTime.UtcNow < deadline)
                {
                    if (FindMessageWindow() != 0)
                    {
                        tcs.TrySetResult(true);
                        return;
                    }

                    if (process is { HasExited: true }) break;
                    Thread.Sleep(250);
                }
            }
            catch { }
            finally
            {
                registration.Dispose();
            }

            tcs.TrySetResult(false);
        })
        {
            IsBackground = true
        };
        thread.Start();
        return tcs.Task;
    }

    private static Task<bool> SendFilesAsyncCore(string payload, TimeSpan timeout)
    {
        if (string.IsNullOrEmpty(payload)) return Task.FromResult(false);
        var messageWindow = FindMessageWindow();
        if (messageWindow == 0) return Task.FromResult(false);

        var tcs = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        var thread = new Thread(() =>
        {
            try
            {
                unsafe
                {
                    fixed (char* ptr = payload)
                    {
                        var data = new COPYDATASTRUCT
                        {
                            dwData = 0,
                            cbData = payload.Length * 2,
                            lpData = (nint)ptr
                        };

                        var timeoutMs = (uint)Math.Clamp(timeout.TotalMilliseconds, 0, 15000);
                        var result = SendMessageTimeoutW(
                            messageWindow,
                            WM_COPYDATA,
                            (nint)1,
                            (nint)(&data),
                            0,
                            timeoutMs,
                            out _);
                        tcs.TrySetResult(result != 0);
                    }
                }
            }
            catch
            {
                tcs.TrySetResult(false);
            }
        })
        {
            IsBackground = true
        };
        thread.Start();
        return tcs.Task;
    }

    private static unsafe nint FindMessageWindow()
    {
        const string legacyClass = "XiaomiPCManager";
        const string continuityClass = "MiPcContinuity";

        fixed (char* className = legacyClass)
        {
            var hwnd = FindWindowW(className, null);
            if (hwnd != 0) return hwnd;
        }

        fixed (char* className = continuityClass)
        {
            var hwnd = FindWindowW(className, null);
            if (hwnd != 0) return hwnd;
        }

        return 0;
    }

    private const uint WM_COPYDATA = 0x004A;

    [DllImport("user32.dll", ExactSpelling = true)]
    private static unsafe extern nint FindWindowW(char* lpClassName, char* lpWindowName);

    [DllImport("user32.dll", ExactSpelling = true)]
    private static unsafe extern nint SendMessageTimeoutW(
        nint hWnd,
        uint Msg,
        nint wParam,
        nint lParam,
        uint fuFlags,
        uint uTimeout,
        out nint lpdwResult);

    private struct COPYDATASTRUCT
    {
        public nint dwData;
        public int cbData;
        public nint lpData;
    }
}
