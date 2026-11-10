using XiaomiShare.Core;

var root = Path.Combine(Path.GetTempPath(), "XiaomiSharePathTests_" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(root);

try
{
    var cases = new (string Product, string Version, string NestedDllDir, string Executable)[]
    {
        ("XiaomiPCManager", "6.0.0.39", "MiSmartShare", "XiaomiPCManager.exe"),
        ("XiaomiPCManager", "5.8.1.130", "", "XiaomiPCManager.exe"),
        ("HyperConnect", "2.0.0.429", Path.Combine("resources", "native-interconnect", "win32"), "hyperConnect.exe"),
        ("PcContinuity", "1.1.2.36", "", "MiPcContinuity.exe"),
    };

    foreach (var test in cases)
    {
        var version = Path.Combine(root, test.Product, test.Version);
        var dllDirectory = Path.Combine(version, test.NestedDllDir);
        Directory.CreateDirectory(dllDirectory);
        File.WriteAllText(Path.Combine(version, test.Executable), "");

        var found = XiaomiPcManagerHelper.FindInstallDirectory(dllDirectory);
        if (!string.Equals(found, version, StringComparison.OrdinalIgnoreCase))
            throw new Exception($"{test.Product} {test.Version}: expected {version}, found {found}");

        Console.WriteLine($"PASS {test.Product} {test.Version}");
    }

    var unmatched = Path.Combine(root, "Uninstalled", "MiSmartShare");
    Directory.CreateDirectory(unmatched);
    File.WriteAllText(Path.Combine(unmatched, "MiDropShellExt.dll"), "");
    if (XiaomiPcManagerHelper.FindInstallDirectory(unmatched) != string.Empty)
        throw new Exception("An orphaned COM DLL must not be treated as a valid executable installation");

    Console.WriteLine("PASS orphaned COM DLL");
}
finally
{
    Directory.Delete(root, recursive: true);
}
