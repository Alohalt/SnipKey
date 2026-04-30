using System.Windows;
using System.Windows.Interop;
using SnipKey.WinApp.Core;
using Clipboard = System.Windows.Clipboard;

namespace SnipKey.WinApp.Platform;

internal sealed class ClipboardMonitor : IDisposable
{
    private readonly struct IgnoredMutation
    {
        public IgnoredMutation(string content, DateTime expiresAt)
        {
            Content = content;
            ExpiresAt = expiresAt;
        }

        public string Content { get; }

        public DateTime ExpiresAt { get; }
    }

    private readonly ClipboardHistoryStore historyStore;
    private readonly TimeSpan ignoredDuration;
    private readonly List<IgnoredMutation> ignoredMutations = [];
    private HwndSource? source;
    private uint lastKnownSequenceNumber;
    private bool isDisposed;

    public ClipboardMonitor(ClipboardHistoryStore historyStore, TimeSpan? ignoredDuration = null)
    {
        this.historyStore = historyStore;
        this.ignoredDuration = ignoredDuration ?? TimeSpan.FromSeconds(2);
    }

    public event Action<ClipboardRecord>? RecordAdded;

    public bool IsRunning => source is not null;

    public void Start()
    {
        if (source is not null)
        {
            return;
        }

        var parameters = new HwndSourceParameters("SnipKeyClipboardMonitor")
        {
            Width = 0,
            Height = 0,
            WindowStyle = 0
        };
        source = new HwndSource(parameters);
        source.AddHook(WndProc);
        lastKnownSequenceNumber = NativeMethods.GetClipboardSequenceNumber();
        NativeMethods.AddClipboardFormatListener(source.Handle);
    }

    public void Stop()
    {
        if (source is null)
        {
            return;
        }

        NativeMethods.RemoveClipboardFormatListener(source.Handle);
        source.RemoveHook(WndProc);
        source.Dispose();
        source = null;
        ignoredMutations.Clear();
    }

    public void IgnoreNextCopy(string? content)
    {
        if (string.IsNullOrEmpty(content))
        {
            return;
        }

        PruneIgnoredMutations();
        ignoredMutations.Add(new IgnoredMutation(content, DateTime.UtcNow.Add(ignoredDuration)));
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

    private IntPtr WndProc(IntPtr hwnd, int message, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (message == NativeMethods.WmClipboardUpdate)
        {
            HandleClipboardChanged();
            handled = false;
        }

        return IntPtr.Zero;
    }

    private void HandleClipboardChanged()
    {
        if (!historyStore.Settings.IsMonitoringEnabled)
        {
            lastKnownSequenceNumber = NativeMethods.GetClipboardSequenceNumber();
            return;
        }

        var currentSequenceNumber = NativeMethods.GetClipboardSequenceNumber();
        if (currentSequenceNumber == lastKnownSequenceNumber)
        {
            return;
        }

        lastKnownSequenceNumber = currentSequenceNumber;
        var content = ReadClipboardText();
        if (!ShouldRecord(content))
        {
            return;
        }

        var record = historyStore.RecordCopy(content);
        if (record is not null)
        {
            RecordAdded?.Invoke(record);
        }
    }

    private bool ShouldRecord(string content)
    {
        if (string.IsNullOrWhiteSpace(content))
        {
            return false;
        }

        PruneIgnoredMutations();
        var ignoredIndex = ignoredMutations.FindIndex(mutation => mutation.Content == content);
        if (ignoredIndex >= 0)
        {
            ignoredMutations.RemoveAt(ignoredIndex);
            return false;
        }

        return true;
    }

    private static string ReadClipboardText()
    {
        try
        {
            return Clipboard.ContainsText() ? Clipboard.GetText() : string.Empty;
        }
        catch
        {
            return string.Empty;
        }
    }

    private void PruneIgnoredMutations()
    {
        var now = DateTime.UtcNow;
        ignoredMutations.RemoveAll(mutation => mutation.ExpiresAt <= now);
    }
}