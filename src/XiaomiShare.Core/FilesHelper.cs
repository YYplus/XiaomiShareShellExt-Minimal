using System.Text;

namespace XiaomiShare.Core;

public static class FilesHelper
{
    private static readonly string FilesCacheFolder = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "XiaomiShareShellExt",
        "ShareFiles");

    public static async Task<string> SaveFilesAsync(string[] files, CancellationToken cancellationToken)
    {
        DeleteExpiredFiles();
        Directory.CreateDirectory(FilesCacheFolder);

        var xiaomiFile = XiaomiPcManagerHelper.CreateXiaomiFile(files);
        if (string.IsNullOrEmpty(xiaomiFile)) return string.Empty;

        var key = Guid.NewGuid().ToString("N");
        try
        {
            var filePath = Path.Combine(FilesCacheFolder, key);
            await File.WriteAllTextAsync(filePath, xiaomiFile, Encoding.UTF8, cancellationToken);
            return key;
        }
        catch
        {
            return string.Empty;
        }
    }

    public static async Task<string> GetXiaomiFileAsync(string cacheKey, CancellationToken cancellationToken)
    {
        DeleteExpiredFiles();
        try
        {
            var filePath = Path.Combine(FilesCacheFolder, cacheKey);
            using var fileStream = new FileStream(
                filePath,
                FileMode.Open,
                FileAccess.Read,
                FileShare.Read | FileShare.Delete,
                4096,
                FileOptions.DeleteOnClose);
            using var reader = new StreamReader(fileStream, Encoding.UTF8, leaveOpen: true);
            return await reader.ReadToEndAsync(cancellationToken);
        }
        catch
        {
            return string.Empty;
        }
    }

    private static void DeleteExpiredFiles()
    {
        try
        {
            if (!Directory.Exists(FilesCacheFolder)) return;
            var now = DateTime.Now;
            foreach (var file in Directory.GetFiles(FilesCacheFolder))
            {
                try
                {
                    if ((now - File.GetCreationTime(file)).TotalHours > 12)
                        File.Delete(file);
                }
                catch { }
            }
        }
        catch { }
    }
}
