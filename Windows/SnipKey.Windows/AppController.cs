using System.Drawing;
using System.Windows;
using SnipKey.WinApp.Core;
using SnipKey.WinApp.Platform;
using SnipKey.WinApp.UI;
using Forms = System.Windows.Forms;

namespace SnipKey.WinApp;

internal sealed class AppController : IDisposable
{
    private readonly SnippetStore store = new();
    private readonly SnippetEngine engine = new();
    private readonly KeyboardMonitor keyboardMonitor = new();
    private readonly TextReplacer textReplacer = new();
    private readonly CompletionWindow completionWindow = new();

    private Forms.NotifyIcon? notifyIcon;
    private Forms.ToolStripMenuItem? enabledMenuItem;
    private SettingsWindow? settingsWindow;
    private bool isDisposed;
    private bool isEnabled = true;

    public AppController()
    {
        store.Changed += (_, _) => engine.UpdateSnippets(store.Snippets);
        engine.UpdateSnippets(store.Snippets);

        keyboardMonitor.QueryChanged += OnQueryChanged;
        keyboardMonitor.TriggerCompleted += OnTriggerCompleted;
        keyboardMonitor.Cancelled += (_, _) => completionWindow.HidePopup();
        keyboardMonitor.SelectionRequested += OnSelectionRequested;
        keyboardMonitor.SelectionConfirmed += OnSelectionConfirmed;

        completionWindow.SnippetConfirmed += snippet => ConfirmSnippet(snippet, keyboardMonitor.CurrentBufferLength);
    }

    public void Start()
    {
        SetupTrayIcon();
        keyboardMonitor.Start();
        if (!keyboardMonitor.IsRunning)
        {
            notifyIcon?.ShowBalloonTip(
                3000,
                "SnipKey",
                "Keyboard monitoring could not start. Try running SnipKey again or checking Windows security settings.",
                Forms.ToolTipIcon.Warning);
        }
    }

    public void Dispose()
    {
        if (isDisposed)
        {
            return;
        }

        isDisposed = true;
        keyboardMonitor.Dispose();
        completionWindow.Close();
        settingsWindow?.Close();
        notifyIcon?.Dispose();
    }

    private void SetupTrayIcon()
    {
        enabledMenuItem = new Forms.ToolStripMenuItem("Enabled")
        {
            Checked = true,
            CheckOnClick = true
        };
        enabledMenuItem.CheckedChanged += (_, _) => SetEnabled(enabledMenuItem.Checked);

        var settingsItem = new Forms.ToolStripMenuItem("Settings...", image: null, onClick: (_, _) => ShowSettings());
        var reloadItem = new Forms.ToolStripMenuItem("Reload Keys", image: null, onClick: (_, _) => ReloadStore());
        var quitItem = new Forms.ToolStripMenuItem("Quit SnipKey", image: null, onClick: (_, _) => Application.Current.Shutdown());

        var contextMenu = new Forms.ContextMenuStrip();
        contextMenu.Items.Add(enabledMenuItem);
        contextMenu.Items.Add(new Forms.ToolStripSeparator());
        contextMenu.Items.Add(settingsItem);
        contextMenu.Items.Add(reloadItem);
        contextMenu.Items.Add(new Forms.ToolStripSeparator());
        contextMenu.Items.Add(quitItem);

        notifyIcon = new Forms.NotifyIcon
        {
            Icon = SystemIcons.Application,
            Text = "SnipKey",
            ContextMenuStrip = contextMenu,
            Visible = true
        };
        notifyIcon.DoubleClick += (_, _) => ShowSettings();
    }

    private void SetEnabled(bool enabled)
    {
        isEnabled = enabled;
        completionWindow.HidePopup();

        if (enabled)
        {
            keyboardMonitor.Start();
        }
        else
        {
            keyboardMonitor.Stop();
        }
    }

    private void ReloadStore()
    {
        store.Load();
        notifyIcon?.ShowBalloonTip(1500, "SnipKey", "Keys reloaded.", Forms.ToolTipIcon.Info);
    }

    private void ShowSettings()
    {
        if (settingsWindow is { IsVisible: true })
        {
            settingsWindow.Activate();
            return;
        }

        settingsWindow = new SettingsWindow(store);
        settingsWindow.Closed += (_, _) => settingsWindow = null;
        settingsWindow.Show();
        settingsWindow.Activate();
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

        completionWindow.ShowSnippets(matches, CaretPositionProvider.GetPopupPoint());
    }

    private void OnTriggerCompleted(string trigger, int deletionCount)
    {
        completionWindow.HidePopup();

        var snippet = engine.FindExact(trigger);
        if (snippet is null)
        {
            return;
        }

        ConfirmSnippet(snippet, deletionCount);
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

        ConfirmSnippet(selectedSnippet, keyboardMonitor.CurrentBufferLength);
    }

    private void ConfirmSnippet(Snippet snippet, int deletionCount)
    {
        completionWindow.HidePopup();
        keyboardMonitor.Reset();
        store.RecordAcceptance(snippet.Id);
        _ = ReplaceSnippetAsync(deletionCount, snippet.Replacement);
    }

    private async Task ReplaceSnippetAsync(int deletionCount, string replacement)
    {
        try
        {
            await textReplacer.ReplaceAsync(deletionCount, replacement).ConfigureAwait(true);
        }
        catch (Exception exception)
        {
            notifyIcon?.ShowBalloonTip(3000, "SnipKey", "Text replacement failed: " + exception.Message, Forms.ToolTipIcon.Error);
        }
    }
}
