using XiaomiShare.Core;

namespace XiaomiShare.Helper;

public static class Program
{
    public static async Task Main(string[] args)
    {
        var cacheKey = GetArgument(args, "--share-files");
        if (string.IsNullOrWhiteSpace(cacheKey)) return;

        if (!await XiaomiPcManagerHelper.LaunchAsync(default).ConfigureAwait(false)) return;
        await XiaomiPcManagerHelper.SendCachedFilesAsync(cacheKey, TimeSpan.FromSeconds(5)).ConfigureAwait(false);
    }

    private static string? GetArgument(string[] args, string name)
    {
        for (var i = 0; i < args.Length - 1; i++)
        {
            if (string.Equals(args[i], name, StringComparison.OrdinalIgnoreCase))
                return args[i + 1];
        }
        return null;
    }
}
