using ShellExtensions;
using ShellExtensions.Helpers;

namespace XiaomiShare.ShellExt;

public sealed class ContextMenu : ExplorerCommand
{
    private readonly string icon;

    public ContextMenu(string icon)
    {
        this.icon = icon;
    }

    public override string? GetIcon(ShellItemArray shellItems) => icon;

    public override string? GetTitle(ShellItemArray shellItems) => "使用小米互传发送";

    public override ExplorerCommandState GetState(
        ShellItemArray shellItems,
        bool fOkToBeSlow,
        out bool pending)
    {
        pending = false;

        if (ServiceProvider.GetService<IContextMenuTypeAccessor>() is { } accessor &&
            (accessor.ContextMenuType == ContextMenuType.ModernContextMenu ||
             accessor.ContextMenuType == ContextMenuType.Unknown))
        {
            return ExplorerCommandState.ECS_ENABLED;
        }

        return ExplorerCommandState.ECS_HIDDEN;
    }

    public override void Invoke(ExplorerCommandInvokeEventArgs args)
    {
        var files = args.ShellItems
            .Select(item => item.FullPath)
            .Where(path => !string.IsNullOrWhiteSpace(path))
            .ToArray();

        if (files.Length > 0)
            DllMain.SendToXiaomi(files);
    }
}
