using System.Runtime.InteropServices;
using System.Windows;
using Forms = System.Windows.Forms;

namespace SnipKey.WinApp.Platform;

internal static class CaretPositionProvider
{
    public static System.Windows.Point GetPopupPoint()
    {
        var foregroundWindow = NativeMethods.GetForegroundWindow();
        if (foregroundWindow != IntPtr.Zero)
        {
            var threadId = NativeMethods.GetWindowThreadProcessId(foregroundWindow, out _);
            var info = new NativeMethods.GuiThreadInfo
            {
                Size = Marshal.SizeOf<NativeMethods.GuiThreadInfo>()
            };

            if (NativeMethods.GetGUIThreadInfo(threadId, ref info) && info.CaretWindow != IntPtr.Zero)
            {
                var point = new NativeMethods.NativePoint
                {
                    X = info.CaretRect.Left,
                    Y = info.CaretRect.Bottom
                };

                if (NativeMethods.ClientToScreen(info.CaretWindow, ref point))
                {
                    return new System.Windows.Point(point.X, point.Y + 8);
                }
            }
        }

        var cursor = Forms.Cursor.Position;
        return new System.Windows.Point(cursor.X + 12, cursor.Y + 20);
    }
}
