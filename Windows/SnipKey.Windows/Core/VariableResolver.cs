using System.Globalization;
using System.Windows;

namespace SnipKey.WinApp.Core;

public sealed record ResolvedText(string Text, int? CursorOffset = null);

public sealed class VariableResolver
{
    private readonly Func<string> clipboardProvider;

    public VariableResolver(Func<string>? clipboardProvider = null)
    {
        this.clipboardProvider = clipboardProvider ?? SystemClipboard;
    }

    public ResolvedText Resolve(string template)
    {
        var result = template
            .Replace("{date}", DateTime.Now.ToString("d", CultureInfo.CurrentCulture))
            .Replace("{time}", DateTime.Now.ToString("t", CultureInfo.CurrentCulture));

        if (result.Contains("{clipboard}", StringComparison.Ordinal))
        {
            result = result.Replace("{clipboard}", clipboardProvider(), StringComparison.Ordinal);
        }

        int? cursorOffset = null;
        var cursorIndex = result.IndexOf("{cursor}", StringComparison.Ordinal);
        if (cursorIndex >= 0)
        {
            cursorOffset = cursorIndex;
            result = result.Replace("{cursor}", string.Empty, StringComparison.Ordinal);
        }

        return new ResolvedText(result, cursorOffset);
    }

    private static string SystemClipboard()
    {
        try
        {
            return System.Windows.Clipboard.ContainsText() ? System.Windows.Clipboard.GetText() : string.Empty;
        }
        catch
        {
            return string.Empty;
        }
    }
}
