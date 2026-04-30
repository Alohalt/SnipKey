using SnipKey.WinApp.Core;

namespace SnipKey.WinApp.Platform;

internal sealed class KeyboardMonitor : IDisposable
{
    private readonly GlobalKeyboardHook hook = new();
    private readonly char triggerPrefix = '#';
    private string buffer = string.Empty;
    private bool isCapturing;

    public enum SelectionDirection
    {
        Up,
        Down
    }

    public KeyboardMonitor()
    {
        hook.KeyDown += OnKeyDown;
    }

    public event Action<string>? QueryChanged;

    public event Action<string, int>? TriggerCompleted;

    public event Action? Cancelled;

    public event Action<SelectionDirection>? SelectionRequested;

    public event Action? SelectionConfirmed;

    public bool IsRunning => hook.IsRunning;

    public int CurrentBufferLength => buffer.Length;

    public void Start()
    {
        hook.Start();
    }

    public void Stop()
    {
        hook.Stop();
        Reset();
    }

    public void Reset()
    {
        buffer = string.Empty;
        isCapturing = false;
    }

    public void Dispose()
    {
        hook.Dispose();
    }

    private void OnKeyDown(object? sender, GlobalKeyEventArgs eventArgs)
    {
        if (NativeMethods.IsCurrentProcessForeground())
        {
            CancelCapture(notify: isCapturing);
            return;
        }

        if (HasShortcutModifier())
        {
            CancelCapture(notify: isCapturing);
            return;
        }

        if (!isCapturing)
        {
            if (eventArgs.Text == triggerPrefix.ToString())
            {
                isCapturing = true;
                buffer = triggerPrefix.ToString();
                QueryChanged?.Invoke(string.Empty);
            }

            return;
        }

        switch (eventArgs.VirtualKeyCode)
        {
            case NativeMethods.VkEscape:
                CancelCapture(notify: true);
                return;
            case NativeMethods.VkTab:
            case NativeMethods.VkReturn:
                eventArgs.Handled = true;
                SelectionConfirmed?.Invoke();
                return;
            case NativeMethods.VkUp:
                eventArgs.Handled = true;
                SelectionRequested?.Invoke(SelectionDirection.Up);
                return;
            case NativeMethods.VkDown:
                eventArgs.Handled = true;
                SelectionRequested?.Invoke(SelectionDirection.Down);
                return;
            case NativeMethods.VkBack:
                HandleBackspace();
                return;
        }

        if (string.IsNullOrEmpty(eventArgs.Text))
        {
            return;
        }

        var character = eventArgs.Text[0];
        if (SnippetTriggerRules.IsAllowedCharacter(character))
        {
            buffer += character;
            QueryChanged?.Invoke(buffer[1..]);
            return;
        }

        if (character == triggerPrefix)
        {
            buffer = triggerPrefix.ToString();
            QueryChanged?.Invoke(string.Empty);
            return;
        }

        CompleteTrigger(eventArgs.Text);
    }

    private static bool HasShortcutModifier()
    {
        return NativeMethods.IsKeyDown(NativeMethods.VkControl)
            || NativeMethods.IsKeyDown(NativeMethods.VkMenu)
            || NativeMethods.IsKeyDown(NativeMethods.VkLWin)
            || NativeMethods.IsKeyDown(NativeMethods.VkRWin);
    }

    private void HandleBackspace()
    {
        if (buffer.Length > 1)
        {
            buffer = buffer[..^1];
            QueryChanged?.Invoke(buffer[1..]);
            return;
        }

        CancelCapture(notify: true);
    }

    private void CompleteTrigger(string terminatorText)
    {
        var completedTrigger = TriggerContextAnalyzer.CompletedTriggerIn(buffer + terminatorText);
        Reset();

        if (completedTrigger is null)
        {
            Cancelled?.Invoke();
            return;
        }

        TriggerCompleted?.Invoke(completedTrigger.Value.Trigger, completedTrigger.Value.DeletionCount);
    }

    private void CancelCapture(bool notify)
    {
        Reset();
        if (notify)
        {
            Cancelled?.Invoke();
        }
    }
}
