using System.Runtime.InteropServices;
using System.Windows;
using SnipKey.WinApp.Core;

namespace SnipKey.WinApp.Platform;

internal sealed class TextReplacer
{
    private readonly VariableResolver variableResolver = new();

    public async Task ReplaceAsync(int deleteCount, string replacement)
    {
        var resolved = variableResolver.Resolve(replacement);
        SendRepeatedKey(NativeMethods.VkBack, deleteCount);
        await Task.Delay(50).ConfigureAwait(true);

        var previousClipboard = TryGetClipboardData();
        try
        {
            Clipboard.SetDataObject(resolved.Text, copy: true);
            SendPasteChord();

            if (resolved.CursorOffset is not null)
            {
                await Task.Delay(50).ConfigureAwait(true);
                var charactersToMoveBack = Math.Max(0, resolved.Text.Length - resolved.CursorOffset.Value);
                SendRepeatedKey(NativeMethods.VkLeft, charactersToMoveBack);
            }
        }
        finally
        {
            await Task.Delay(500).ConfigureAwait(true);
            if (previousClipboard is not null)
            {
                Clipboard.SetDataObject(previousClipboard, copy: true);
            }
        }
    }

    private static IDataObject? TryGetClipboardData()
    {
        try
        {
            return Clipboard.GetDataObject();
        }
        catch
        {
            return null;
        }
    }

    private static void SendPasteChord()
    {
        SendKey(NativeMethods.VkControl, keyUp: false);
        SendKey(NativeMethods.VkV, keyUp: false);
        SendKey(NativeMethods.VkV, keyUp: true);
        SendKey(NativeMethods.VkControl, keyUp: true);
    }

    private static void SendRepeatedKey(int virtualKey, int count)
    {
        for (var index = 0; index < count; index += 1)
        {
            SendKey(virtualKey, keyUp: false);
            SendKey(virtualKey, keyUp: true);
        }
    }

    private static void SendKey(int virtualKey, bool keyUp)
    {
        var input = new NativeMethods.Input
        {
            Type = NativeMethods.InputKeyboard,
            Data = new NativeMethods.InputUnion
            {
                Keyboard = new NativeMethods.KeyboardInput
                {
                    VirtualKey = (ushort)virtualKey,
                    ScanCode = 0,
                    Flags = keyUp ? NativeMethods.KeyEventKeyUp : 0,
                    Time = 0,
                    ExtraInfo = UIntPtr.Zero
                }
            }
        };

        NativeMethods.SendInput(1, [input], Marshal.SizeOf<NativeMethods.Input>());
    }
}
