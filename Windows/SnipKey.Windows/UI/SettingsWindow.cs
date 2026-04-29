using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Win32;
using SnipKey.WinApp.Core;
using WpfButton = System.Windows.Controls.Button;
using WpfColor = System.Windows.Media.Color;
using WpfHorizontalAlignment = System.Windows.HorizontalAlignment;
using WpfListBox = System.Windows.Controls.ListBox;
using WpfMessageBox = System.Windows.MessageBox;
using WpfOpenFileDialog = Microsoft.Win32.OpenFileDialog;
using WpfOrientation = System.Windows.Controls.Orientation;
using WpfSaveFileDialog = Microsoft.Win32.SaveFileDialog;
using WpfTextBox = System.Windows.Controls.TextBox;

namespace SnipKey.WinApp.UI;

internal sealed class SettingsWindow : Window
{
    private readonly SnippetStore store;
    private readonly WpfTextBox searchBox = new();
    private readonly WpfListBox snippetList = new();
    private readonly WpfTextBox triggerBox = new();
    private readonly WpfTextBox replacementBox = new();
    private readonly TextBlock statusText = new();
    private Guid? selectedSnippetId;

    public SettingsWindow(SnippetStore store)
    {
        this.store = store;

        Title = "SnipKey Settings";
        Width = 880;
        Height = 600;
        MinWidth = 720;
        MinHeight = 480;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Content = BuildLayout();

        searchBox.TextChanged += (_, _) => RefreshSnippetList(selectedSnippetId);
        snippetList.SelectionChanged += (_, _) => LoadSelectedSnippet();

        RefreshSnippetList();
    }

    private UIElement BuildLayout()
    {
        var root = new Grid
        {
            Margin = new Thickness(16)
        };
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(280) });
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var leftPanel = BuildLeftPanel();
        Grid.SetColumn(leftPanel, 0);
        root.Children.Add(leftPanel);

        var rightPanel = BuildRightPanel();
        Grid.SetColumn(rightPanel, 1);
        root.Children.Add(rightPanel);

        statusText.Margin = new Thickness(0, 12, 0, 0);
        statusText.Foreground = new SolidColorBrush(WpfColor.FromRgb(91, 99, 112));
        Grid.SetColumnSpan(statusText, 2);
        Grid.SetRow(statusText, 1);
        root.Children.Add(statusText);

        return root;
    }

    private UIElement BuildLeftPanel()
    {
        var panel = new DockPanel
        {
            Margin = new Thickness(0, 0, 16, 0)
        };

        var title = new TextBlock
        {
            Text = "Keys",
            FontSize = 18,
            FontWeight = FontWeights.SemiBold,
            Margin = new Thickness(0, 0, 0, 10)
        };
        DockPanel.SetDock(title, Dock.Top);
        panel.Children.Add(title);

        searchBox.Height = 32;
        searchBox.Margin = new Thickness(0, 0, 0, 10);
        searchBox.VerticalContentAlignment = VerticalAlignment.Center;
        searchBox.ToolTip = "Search trigger or replacement";
        DockPanel.SetDock(searchBox, Dock.Top);
        panel.Children.Add(searchBox);

        var toolbar = new StackPanel
        {
            Orientation = WpfOrientation.Horizontal,
            Margin = new Thickness(0, 0, 0, 10)
        };
        toolbar.Children.Add(MakeButton("New", AddSnippet));
        toolbar.Children.Add(MakeButton("Import", ImportSnippets));
        toolbar.Children.Add(MakeButton("Export", ExportSnippets));
        DockPanel.SetDock(toolbar, Dock.Top);
        panel.Children.Add(toolbar);

        snippetList.DisplayMemberPath = nameof(SettingsSnippetItem.DisplayText);
        panel.Children.Add(snippetList);

        return panel;
    }

    private UIElement BuildRightPanel()
    {
        var panel = new Grid();
        panel.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        panel.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        panel.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        panel.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        panel.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var title = new TextBlock
        {
            Text = "Details",
            FontSize = 18,
            FontWeight = FontWeights.SemiBold,
            Margin = new Thickness(0, 0, 0, 18)
        };
        panel.Children.Add(title);

        var triggerLabel = new TextBlock
        {
            Text = "Trigger",
            Margin = new Thickness(0, 0, 0, 6),
            FontWeight = FontWeights.SemiBold
        };
        Grid.SetRow(triggerLabel, 1);
        panel.Children.Add(triggerLabel);

        triggerBox.Height = 34;
        triggerBox.Margin = new Thickness(0, 22, 0, 16);
        triggerBox.VerticalContentAlignment = VerticalAlignment.Center;
        Grid.SetRow(triggerBox, 1);
        panel.Children.Add(triggerBox);

        var replacementLabel = new TextBlock
        {
            Text = "Replacement",
            Margin = new Thickness(0, 0, 0, 6),
            FontWeight = FontWeights.SemiBold
        };
        Grid.SetRow(replacementLabel, 2);
        panel.Children.Add(replacementLabel);

        replacementBox.AcceptsReturn = true;
        replacementBox.AcceptsTab = true;
        replacementBox.TextWrapping = TextWrapping.Wrap;
        replacementBox.VerticalScrollBarVisibility = ScrollBarVisibility.Auto;
        replacementBox.Margin = new Thickness(0, 22, 0, 16);
        Grid.SetRow(replacementBox, 2);
        Grid.SetRowSpan(replacementBox, 2);
        panel.Children.Add(replacementBox);

        var buttons = new StackPanel
        {
            Orientation = WpfOrientation.Horizontal,
            HorizontalAlignment = WpfHorizontalAlignment.Right,
            Margin = new Thickness(0, 12, 0, 0)
        };
        buttons.Children.Add(MakeButton("Delete", DeleteSelectedSnippet));
        buttons.Children.Add(MakeButton("Save", SaveSelectedSnippet));
        Grid.SetRow(buttons, 4);
        panel.Children.Add(buttons);

        return panel;
    }

    private static WpfButton MakeButton(string text, Action action)
    {
        var button = new WpfButton
        {
            Content = text,
            MinWidth = 72,
            Height = 32,
            Margin = new Thickness(0, 0, 8, 0),
            Padding = new Thickness(12, 0, 12, 0)
        };
        button.Click += (_, _) => action();
        return button;
    }

    private void RefreshSnippetList(Guid? preferredSelection = null)
    {
        var filter = searchBox.Text.Trim();
        var items = store.Snippets
            .Where(snippet => string.IsNullOrEmpty(filter)
                || snippet.Trigger.Contains(filter, StringComparison.OrdinalIgnoreCase)
                || snippet.Replacement.Contains(filter, StringComparison.OrdinalIgnoreCase))
            .OrderBy(snippet => snippet.Trigger, StringComparer.CurrentCultureIgnoreCase)
            .Select(snippet => new SettingsSnippetItem(snippet.Clone()))
            .ToList();

        snippetList.ItemsSource = items;

        var selectedItem = items.FirstOrDefault(item => item.Snippet.Id == preferredSelection)
            ?? items.FirstOrDefault(item => item.Snippet.Id == selectedSnippetId)
            ?? items.FirstOrDefault();
        snippetList.SelectedItem = selectedItem;

        if (selectedItem is null)
        {
            selectedSnippetId = null;
            triggerBox.Text = string.Empty;
            replacementBox.Text = string.Empty;
        }
    }

    private void LoadSelectedSnippet()
    {
        if (snippetList.SelectedItem is not SettingsSnippetItem item)
        {
            return;
        }

        selectedSnippetId = item.Snippet.Id;
        triggerBox.Text = item.Snippet.Trigger;
        replacementBox.Text = item.Snippet.Replacement;
        statusText.Text = string.Empty;
    }

    private void AddSnippet()
    {
        var trigger = store.NextAvailableTrigger();
        var snippet = new Snippet
        {
            Trigger = trigger,
            Replacement = string.Empty
        };

        if (!store.AddSnippet(snippet))
        {
            statusText.Text = "Could not create a new Key.";
            return;
        }

        RefreshSnippetList(snippet.Id);
        triggerBox.Focus();
        triggerBox.SelectAll();
        statusText.Text = "New Key created.";
    }

    private void SaveSelectedSnippet()
    {
        if (selectedSnippetId is null)
        {
            AddSnippet();
            return;
        }

        var trigger = triggerBox.Text.Trim();
        var validationError = store.ValidationError(trigger, selectedSnippetId.Value);
        if (validationError is not null)
        {
            statusText.Text = ValidationMessage(validationError.Value);
            return;
        }

        var existingSnippet = store.Snippets.FirstOrDefault(snippet => snippet.Id == selectedSnippetId.Value);
        var snippet = new Snippet
        {
            Id = selectedSnippetId.Value,
            Trigger = trigger,
            Replacement = replacementBox.Text,
            GroupId = existingSnippet?.GroupId,
            AcceptanceCount = existingSnippet?.AcceptanceCount ?? 0
        };

        if (!store.UpdateSnippet(snippet))
        {
            statusText.Text = "Could not save this Key.";
            return;
        }

        RefreshSnippetList(snippet.Id);
        statusText.Text = "Saved.";
    }

    private void DeleteSelectedSnippet()
    {
        if (selectedSnippetId is null)
        {
            return;
        }

        var result = WpfMessageBox.Show(this, "Delete this Key?", "SnipKey", MessageBoxButton.YesNo, MessageBoxImage.Question);
        if (result != MessageBoxResult.Yes)
        {
            return;
        }

        store.DeleteSnippet(selectedSnippetId.Value);
        selectedSnippetId = null;
        RefreshSnippetList();
        statusText.Text = "Deleted.";
    }

    private void ImportSnippets()
    {
        var dialog = new WpfOpenFileDialog
        {
            Filter = "SnipKey JSON (*.json)|*.json|All files (*.*)|*.*"
        };

        if (dialog.ShowDialog(this) != true)
        {
            return;
        }

        try
        {
            store.ImportData(dialog.FileName);
            RefreshSnippetList();
            statusText.Text = "Imported.";
        }
        catch (Exception exception)
        {
            statusText.Text = "Import failed: " + exception.Message;
        }
    }

    private void ExportSnippets()
    {
        var dialog = new WpfSaveFileDialog
        {
            FileName = "snippets.json",
            Filter = "SnipKey JSON (*.json)|*.json|All files (*.*)|*.*"
        };

        if (dialog.ShowDialog(this) != true)
        {
            return;
        }

        try
        {
            store.ExportData(dialog.FileName);
            statusText.Text = "Exported.";
        }
        catch (Exception exception)
        {
            statusText.Text = "Export failed: " + exception.Message;
        }
    }

    private static string ValidationMessage(SnippetTriggerRules.ValidationError validationError)
    {
        return validationError switch
        {
            SnippetTriggerRules.ValidationError.Empty => "Trigger cannot be empty.",
            SnippetTriggerRules.ValidationError.InvalidCharacters => "Trigger can only contain letters, digits, and underscores.",
            SnippetTriggerRules.ValidationError.Duplicate => "Trigger already exists.",
            _ => "Invalid trigger."
        };
    }
}

internal sealed class SettingsSnippetItem
{
    public SettingsSnippetItem(Snippet snippet)
    {
        Snippet = snippet;
    }

    public Snippet Snippet { get; }

    public string DisplayText
    {
        get
        {
            var preview = Snippet.Replacement
                .Replace("\r", " ", StringComparison.Ordinal)
                .Replace("\n", " ", StringComparison.Ordinal)
                .Trim();
            if (preview.Length > 48)
            {
                preview = preview[..48] + "...";
            }

            return string.IsNullOrEmpty(preview) ? "#" + Snippet.Trigger : $"#{Snippet.Trigger}  {preview}";
        }
    }
}
