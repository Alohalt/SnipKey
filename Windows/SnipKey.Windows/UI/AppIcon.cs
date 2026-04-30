using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace SnipKey.WinApp.UI;

internal static class AppIcon
{
    private static readonly Uri ResourceUri = new("pack://application:,,,/Assets/app-icon.png", UriKind.Absolute);

    private static readonly Lazy<ImageSource?> CachedImageSource = new(LoadImageSource);

    public static ImageSource? ImageSource => CachedImageSource.Value;

    public static void ApplyTo(Window window)
    {
        if (ImageSource is not null)
        {
            window.Icon = ImageSource;
        }
    }

    public static Icon NotifyIcon()
    {
        var streamInfo = System.Windows.Application.GetResourceStream(ResourceUri);
        if (streamInfo is null)
        {
            return (Icon)SystemIcons.Application.Clone();
        }

        using var stream = streamInfo.Stream;
        using var bitmap = new Bitmap(stream);
        var iconHandle = bitmap.GetHicon();
        try
        {
            using var icon = Icon.FromHandle(iconHandle);
            return (Icon)icon.Clone();
        }
        finally
        {
            DestroyIcon(iconHandle);
        }
    }

    private static ImageSource? LoadImageSource()
    {
        var streamInfo = System.Windows.Application.GetResourceStream(ResourceUri);
        if (streamInfo is null)
        {
            return null;
        }

        using var stream = streamInfo.Stream;
        var image = new BitmapImage();
        image.BeginInit();
        image.CacheOption = BitmapCacheOption.OnLoad;
        image.StreamSource = stream;
        image.EndInit();
        image.Freeze();
        return image;
    }

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DestroyIcon(IntPtr handle);
}