using System.Drawing;
using System.Windows;
using System.Windows.Threading;
using SnipKey.WinApp.Core;
using SnipKey.WinApp.Platform;
using SnipKey.WinApp.UI;
using Forms = System.Windows.Forms;
using MessageBox = System.Windows.MessageBox;

namespace SnipKey.WinApp;

internal sealed class AppController : IDisposable
{
    private readonly SnippetStore store = new();
    private readonly ClipboardHistoryStore clipboardHistoryStore = new();
    private readonly AppLanguageStore languageStore = new();
    private readonly SnippetEngine engine = new();
    private readonly KeyboardMonitor keyboardMonitor = new();
    private readonly TextReplacer textReplacer = new();
    private readonly CompletionWindow completionWindow;
    private readonly ClipboardMonitor clipboardMonitor;
    private readonly DispatcherTimer outsideClickTimer = new();
    private readonly Icon trayIcon = AppIcon.NotifyIcon();

    private Forms.NotifyIcon? notifyIcon;
    private Forms.ToolStripMenuItem? enabledMenuItem;
    private SettingsWindow? settingsWindow;
    private ClipboardHistoryWindow? clipboardHistoryWindow;
    private AboutWindow? aboutWindow;
    private IntPtr replacementTargetWindow;
    private bool isDisposed;
    private bool isEnabled = true;
    private bool isPresentingClipboardSuggestion;
    private bool wasMouseDown;

    public AppController()
    {
        completionWindow = new CompletionWindow(languageStore);
        clipboardMonitor = new ClipboardMonitor(clipboardHistoryStore);

        store.Changed += (_, _) => engine.UpdateSnippets(store.Snippets);
        engine.UpdateSnippets(store.Snippets);

        languageStore.Changed += (_, _) => RebuildTrayMenu();
        clipboardMonitor.RecordAdded += OnClipboardRecordAdded;
        textReplacer.ClipboardWriteRequested += clipboardMonitor.IgnoreNextCopy;

        keyboardMonitor.QueryChanged += OnQueryChanged;
        keyboardMonitor.TriggerCompleted += OnTriggerCompleted;
        keyboardMonitor.Cancelled += () => completionWindow.HidePopup();
        keyboardMonitor.SelectionRequested += OnSelectionRequested;
        keyboardMonitor.SelectionConfirmed += OnSelectionConfirmed;

        completionWindow.SnippetConfirmed += snippet => ConfirmSnippet(snippet, keyboardMonitor.CurrentBufferLength, replacementTargetWindow);

        outsideClickTimer.Interval = TimeSpan.FromMilliseconds(50);
        outsideClickTimer.Tick += (_, _) => WatchForOutsideCompletionClick();
    }

    public void Start()
    {
        SetupTrayIcon();
        keyboardMonitor.Start();
        clipboardMonitor.Start();
        outsideClickTimer.Start();

        if (!keyboardMonitor.IsRunning)
        {
            notifyIcon?.ShowBalloonTip(3000, "SnipKey", languageStore.Text(L10nKey.TrayKeyboardWarning), Forms.ToolTipIcon.Warning);
        }

        ShowOnboardingIfNeeded();
    }

    public void Dispose()
    {
        if (isDisposed)
        {
            return;
        }

        isDisposed = true;
        outsideClickTimer.Stop();
        clipboardMonitor.Dispose();
        keyboardMonitor.Dispose();
        completionWindow.Close();
        settingsWindow?.Close();
        clipboardHistoryWindow?.Close();
        aboutWindow?.Close();
        notifyIcon?.Dispose();
        trayIcon.Dispose();
    }

    private void SetupTrayIcon()
    {
        notifyIcon = new Forms.NotifyIcon
        {
            Icon = trayIcon,
            Text = "SnipKey",
            Visible = true
        };
        notifyIcon.DoubleClick += (_, _) => ShowSettings();
        RebuildTrayMenu();
    }

    private void RebuildTrayMenu()
    {
        if (notifyIcon is null)
        {
            return;
        }

        var oldMenu = notifyIcon.ContextMenuStrip;
        var contextMenu = new Forms.ContextMenuStrip();

        enabledMenuItem = new Forms.ToolStripMenuItem(languageStore.Text(L10nKey.MenuEnable))
        {
            Checked = isEnabled,
            CheckOnClick = true
        };
        enabledMenuItem.CheckedChanged += (_, _) => SetEnabled(enabledMenuItem.Checked);

        contextMenu.Items.Add(enabledMenuItem);
        contextMenu.Items.Add(new Forms.ToolStripSeparator());
        contextMenu.Items.Add(new Forms.ToolStripMenuItem(languageStore.Text(L10nKey.MenuKeyboardDiagnosticsEllipsis), image: null, onClick: (_, _) => ShowKeyboardDiagnostics()));
        contextMenu.Items.Add(new Forms.ToolStripMenuItem(languageStore.Text(L10nKey.MenuSettingsEllipsis), image: null, onClick: (_, _) => ShowSettings()));
        contextMenu.Items.Add(new Forms.ToolStripMenuItem(languageStore.Text(L10nKey.MenuClipboardHistoryEllipsis), image: null, onClick: (_, _) => ShowClipboardHistory()));
        contextMenu.Items.Add(new Forms.ToolStripMenuItem(languageStore.Text(L10nKey.MenuReloadKeys), image: null, onClick: (_, _) => ReloadStore()));
        contextMenu.Items.Add(new Forms.ToolStripMenuItem(languageStore.Text(L10nKey.MenuAboutEllipsis), image: null, onClick: (_, _) => ShowAbout()));
        contextMenu.Items.Add(new Forms.ToolStripSeparator());
        contextMenu.Items.Add(new Forms.ToolStripMenuItem(languageStore.Text(L10nKey.MenuQuitSnipKey), image: null, onClick: (_, _) => System.Windows.Application.Current.Shutdown()));

        notifyIcon.ContextMenuStrip = contextMenu;
        oldMenu?.Dispose();
    }

    private void SetEnabled(bool enabled)
    {
        if (isEnabled == enabled)
        {
            return;
        }

        isEnabled = enabled;
        completionWindow.HidePopup();

        if (enabled)
        {
            keyboardMonitor.Start();
            clipboardMonitor.Start();
        }
        else
        {
            keyboardMonitor.Stop();
            clipboardMonitor.Stop();
        }
    }

    private void ReloadStore()
    {
        store.Load();
        notifyIcon?.ShowBalloonTip(1500, "SnipKey", languageStore.Text(L10nKey.TrayKeysReloaded), Forms.ToolTipIcon.Info);
    }

    private void ShowSettings(Guid? selectingSnippetId = null, bool showGuide = false)
    {
        if (settingsWindow is not { IsVisible: true })
        {
            settingsWindow = new SettingsWindow(store, clipboardHistoryStore, languageStore, ShowClipboardHistory, ShowAbout);
            settingsWindow.Closed += (_, _) => settingsWindow = null;
            settingsWindow.Show();
        }

        if (selectingSnippetId is not null)
        {
            settingsWindow.SelectSnippet(selectingSnippetId.Value);
        }

        settingsWindow.Activate();

        if (showGuide)
        {
            settingsWindow.ShowGuide();
        }
    }

    private void ShowClipboardHistory()
    {
        if (clipboardHistoryWindow is { IsVisible: true })
        {
            clipboardHistoryWindow.Activate();
            return;
        }

        clipboardHistoryWindow = new ClipboardHistoryWindow(clipboardHistoryStore, languageStore, CreateSnippetFromClipboardRecord);
        clipboardHistoryWindow.Closed += (_, _) => clipboardHistoryWindow = null;
        clipboardHistoryWindow.Show();
        clipboardHistoryWindow.Activate();
    }

    private void ShowAbout()
    {
        if (aboutWindow is { IsVisible: true })
        {
            aboutWindow.Activate();
            return;
        }

        aboutWindow = new AboutWindow(languageStore);
        aboutWindow.Closed += (_, _) => aboutWindow = null;
        aboutWindow.Show();
        aboutWindow.Activate();
    }

    private void ShowKeyboardDiagnostics()
    {
        MessageBox.Show(
            languageStore.Text(L10nKey.KeyboardDiagnosticsMessage),
            languageStore.Text(L10nKey.KeyboardDiagnosticsTitle),
            MessageBoxButton.OK,
            MessageBoxImage.Information);
    }

    private void ShowOnboardingIfNeeded()
    {
        if (languageStore.HasShownOnboardingGuide)
        {
            return;
        }

        languageStore.MarkOnboardingGuideShown();
        System.Windows.Application.Current.Dispatcher.BeginInvoke(() => ShowSettings(showGuide: true));
    }

    private void OnClipboardRecordAdded(ClipboardRecord record)
    {
        var existingSnippet = store.Snippets.FirstOrDefault(snippet => snippet.Replacement == record.Content);
        if (existingSnippet is not null)
        {
            clipboardHistoryStore.MarkCreatedSnippet(record.Id, existingSnippet.Id);
            return;
        }

        if (!clipboardHistoryStore.ShouldSuggestKey(record) || isPresentingClipboardSuggestion)
        {
            return;
        }

        clipboardHistoryStore.MarkPrompted(record.Id);
        isPresentingClipboardSuggestion = true;
        System.Windows.Application.Current.Dispatcher.BeginInvoke(() => PresentClipboardSuggestion(record));
    }

    private void PresentClipboardSuggestion(ClipboardRecord record)
    {
        try
        {
            var response = MessageBox.Show(
                languageStore.Format(L10nKey.ClipboardSuggestionMessageFormat, ClipboardPreview(record.Content)),
                languageStore.Format(L10nKey.ClipboardSuggestionTitleFormat, record.CopyCount),
                MessageBoxButton.YesNo,
                MessageBoxImage.Information);

            if (response == MessageBoxResult.Yes)
            {
                CreateSnippetFromClipboardRecord(record);
            }
        }
        finally
        {
            isPresentingClipboardSuggestion = false;
        }
    }

    private void CreateSnippetFromClipboardRecord(ClipboardRecord record)
    {
        var existingSnippet = store.Snippets.FirstOrDefault(snippet => snippet.Replacement == record.Content);
        if (existingSnippet is not null)
        {
            clipboardHistoryStore.MarkCreatedSnippet(record.Id, existingSnippet.Id);
            ShowSettings(existingSnippet.Id);
            return;
        }

        var snippet = ClipboardSnippetFactory.MakeSnippet(record.Content, store.Snippets);
        if (!store.AddSnippet(snippet))
        {
            return;
        }

        clipboardHistoryStore.MarkCreatedSnippet(record.Id, snippet.Id);
        ShowSettings(snippet.Id);
    }

    private static string ClipboardPreview(string content)
    {
        var flattened = content
            .Replace("\r", " ", StringComparison.Ordinal)
            .Replace("\n", " ", StringComparison.Ordinal)
            .Trim();
        return flattened.Length > 120 ? flattened[..120] + "..." : flattened;
    }

    private void OnQueryChanged(string query)
    {
        if (!isEnabled)
        {
            return;
        }

        var matches = engine.Match(query);
        if (matches.Count == 0)
        {
            completionWindow.HidePopup();
            return;
        }

        CaptureReplacementTargetWindow();
        completionWindow.ShowSnippets(matches, CaretPositionProvider.GetPopupPoint());
    }

    private void OnTriggerCompleted(string trigger, int deletionCount)
    {
        CaptureReplacementTargetWindow();
        completionWindow.HidePopup();

        var snippet = engine.FindExact(trigger);
        if (snippet is null)
        {
            return;
        }

        ConfirmSnippet(snippet, deletionCount, replacementTargetWindow);
    }

    private void OnSelectionRequested(KeyboardMonitor.SelectionDirection direction)
    {
        if (direction == KeyboardMonitor.SelectionDirection.Up)
        {
            completionWindow.MoveSelectionUp();
        }
        else
        {
            completionWindow.MoveSelectionDown();
        }
    }

    private void OnSelectionConfirmed()
    {
        var selectedSnippet = completionWindow.SelectedSnippet;
        if (selectedSnippet is null)
        {
            return;
        }

        ConfirmSnippet(selectedSnippet, keyboardMonitor.CurrentBufferLength, replacementTargetWindow);
    }

    private void ConfirmSnippet(Snippet snippet, int deletionCount, IntPtr targetWindow)
    {
        completionWindow.HidePopup();
        keyboardMonitor.Reset();
        store.RecordAcceptance(snippet.Id);
        _ = ReplaceSnippetAsync(deletionCount, snippet.Replacement, targetWindow);
    }

    private async Task ReplaceSnippetAsync(int deletionCount, string replacement, IntPtr targetWindow)
    {
        try
        {
            await textReplacer.ReplaceAsync(deletionCount, replacement, targetWindow).ConfigureAwait(true);
        }
        catch (Exception exception)
        {
            notifyIcon?.ShowBalloonTip(3000, "SnipKey", languageStore.Format(L10nKey.TrayReplacementFailedFormat, exception.Message), Forms.ToolTipIcon.Error);
        }
    }

    private void CaptureReplacementTargetWindow()
    {
        var foregroundWindow = NativeMethods.GetForegroundWindow();
        if (!NativeMethods.IsCurrentProcessWindow(foregroundWindow))
        {
            replacementTargetWindow = foregroundWindow;
        }
    }

    private void WatchForOutsideCompletionClick()
    {
        var isMouseDown = NativeMethods.IsKeyDown(NativeMethods.VkLButton)
            || NativeMethods.IsKeyDown(NativeMethods.VkRButton)
            || NativeMethods.IsKeyDown(NativeMethods.VkMButton);

        if (!completionWindow.IsPopupVisible)
        {
            wasMouseDown = isMouseDown;
            return;
        }

        if (isMouseDown && !wasMouseDown && NativeMethods.GetCursorPos(out var point))
        {
            if (!completionWindow.ContainsScreenPoint(point.X, point.Y))
            {
                keyboardMonitor.Reset();
                completionWindow.HidePopup();
            }
        }

        wasMouseDown = isMouseDown;
    }
}