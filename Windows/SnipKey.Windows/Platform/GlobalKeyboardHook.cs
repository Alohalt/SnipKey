using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace SnipKey.WinApp.Platform;

internal sealed class GlobalKeyEventArgs : EventArgs
{
    public GlobalKeyEventArgs(int virtualKeyCode, string text)
    {
        VirtualKeyCode = virtualKeyCode;
        Text = text;
    }

    public int VirtualKeyCode { get; }

    public string Text { get; }

    public bool Handled { get; set; }
}

internal sealed class GlobalKeyboardHook : IDisposable
{
    private NativeMethods.LowLevelKeyboardProc? callback;
    private IntPtr hookHandle;
    private bool isDisposed;

    public event EventHandler<GlobalKeyEventArgs>? KeyDown;

    public bool IsRunning => hookHandle != IntPtr.Zero;

    public void Start()
    {
        if (hookHandle != IntPtr.Zero)
        {
            return;
        }

        callback = HookCallback;
        using var process = Process.GetCurrentProcess();
        var moduleName = process.MainModule?.ModuleName;
        var moduleHandle = NativeMethods.GetModuleHandle(moduleName);
        hookHandle = NativeMethods.SetWindowsHookEx(NativeMethods.WhKeyboardLl, callback, moduleHandle, 0);
    }

    public void Stop()
    {
        if (hookHandle == IntPtr.Zero)
        {
            return;
        }

        NativeMethods.UnhookWindowsHookEx(hookHandle);
        hookHandle = IntPtr.Zero;
    }

    public void Dispose()
    {
        if (isDisposed)
        {
            return;
        }

        isDisposed = true;
        Stop();
    }

    private IntPtr HookCallback(int code, IntPtr wParam, IntPtr lParam)
    {
        if (code >= 0 && (wParam == (IntPtr)NativeMethods.WmKeyDown || wParam == (IntPtr)NativeMethods.WmSysKeyDown))
        {
            var keyInfo = Marshal.PtrToStructure<NativeMethods.KeyboardHookStruct>(lParam);
            if ((keyInfo.Flags & NativeMethods.LlkhfInjected) != NativeMethods.LlkhfInjected)
            {
                var eventArgs = new GlobalKeyEventArgs(
                    keyInfo.VirtualKeyCode,
                    ConvertVirtualKeyToText(keyInfo.VirtualKeyCode, keyInfo.ScanCode));
                KeyDown?.Invoke(this, eventArgs);

                if (eventArgs.Handled)
                {
                    return (IntPtr)1;
                }
            }
        }

        return NativeMethods.CallNextHookEx(hookHandle, code, wParam, lParam);
    }

    private static string ConvertVirtualKeyToText(int virtualKeyCode, int scanCode)
    {
        if (IsModifierKey(virtualKeyCode))
        {
            return string.Empty;
        }

        var keyState = new byte[256];
        if (!NativeMethods.GetKeyboardState(keyState))
        {
            return string.Empty;
        }

        keyState[NativeMethods.VkShift] = NativeMethods.IsKeyDown(NativeMethods.VkShift) ? (byte)0x80 : (byte)0;
        keyState[NativeMethods.VkControl] = NativeMethods.IsKeyDown(NativeMethods.VkControl) ? (byte)0x80 : (byte)0;
        keyState[NativeMethods.VkMenu] = NativeMethods.IsKeyDown(NativeMethods.VkMenu) ? (byte)0x80 : (byte)0;
        keyState[NativeMethods.VkCapital] = (byte)(NativeMethods.GetKeyState(NativeMethods.VkCapital) & 0x01);

        var buffer = new StringBuilder(8);
        var translatedLength = NativeMethods.ToUnicode(
            (uint)virtualKeyCode,
            (uint)scanCode,
            keyState,
            buffer,
            buffer.Capacity,
            0);

        return translatedLength > 0 ? buffer.ToString(0, translatedLength) : string.Empty;
    }

    private static bool IsModifierKey(int virtualKeyCode)
    {
        return virtualKeyCode is NativeMethods.VkShift
            or NativeMethods.VkLShift
            or NativeMethods.VkRShift
            or NativeMethods.VkControl
            or NativeMethods.VkLControl
            or NativeMethods.VkRControl
            or NativeMethods.VkMenu
            or NativeMethods.VkLMenu
            or NativeMethods.VkRMenu
            or NativeMethods.VkCapital
            or NativeMethods.VkLWin
            or NativeMethods.VkRWin;
    }
}
