using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Win32;
using SnipKey.WinApp.Core;
using WpfButton = System.Windows.Controls.Button;
using WpfBrushes = System.Windows.Media.Brushes;
using WpfFontFamily = System.Windows.Media.FontFamily;
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
    private readonly TextBlock countText = new();
    private readonly TextBlock searchPlaceholder = new();
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
        Width = 980;
        Height = 640;
        MinWidth = 820;
        MinHeight = 540;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = UiTheme.WindowBackgroundBrush;
        FontFamily = new WpfFontFamily("Segoe UI Variable, Segoe UI");
        UseLayoutRounding = true;
        SnapsToDevicePixels = true;
        Content = BuildLayout();

        searchBox.TextChanged += (_, _) =>
        {
            RefreshSnippetList(selectedSnippetId);
            UpdateSearchPlaceholder();
        };
        searchBox.GotKeyboardFocus += (_, _) => UpdateSearchPlaceholder();
        searchBox.LostKeyboardFocus += (_, _) => UpdateSearchPlaceholder();
        snippetList.SelectionChanged += (_, _) => LoadSelectedSnippet();

        RefreshSnippetList();
        UpdateSearchPlaceholder();
    }

    private UIElement BuildLayout()
    {
        var root = new Grid
        {
            Background = UiTheme.WindowBackgroundBrush
        };
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(308) });
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var leftPanel = BuildLeftPanel();
        Grid.SetColumn(leftPanel, 0);
        root.Children.Add(leftPanel);

        var rightPanel = BuildRightPanel();
        Grid.SetColumn(rightPanel, 1);
        root.Children.Add(rightPanel);

        statusText.Foreground = UiTheme.TextSecondaryBrush;
        statusText.FontSize = 12;
        statusText.VerticalAlignment = VerticalAlignment.Center;

        var statusBar = new Border
        {
            MinHeight = 34,
            Padding = new Thickness(18, 0, 18, 0),
            Background = UiTheme.Brush(255, 255, 255, 0.62),
            BorderBrush = UiTheme.HairlineBrush,
            BorderThickness = new Thickness(0, 1, 0, 0),
            Child = statusText
        };
        Grid.SetColumnSpan(statusBar, 2);
        Grid.SetRow(statusBar, 1);
        root.Children.Add(statusBar);

        return root;
    }

    private UIElement BuildLeftPanel()
    {
        var panel = new DockPanel();

        var chrome = new Border
        {
            Background = UiTheme.SidebarBrush,
            BorderBrush = UiTheme.HairlineBrush,
            BorderThickness = new Thickness(0, 0, 1, 0),
            Padding = new Thickness(18, 18, 18, 14),
            Child = panel
        };

        var header = new StackPanel
        {
            Margin = new Thickness(0, 0, 0, 14)
        };

        header.Children.Add(new TextBlock
        {
            Text = "SnipKey",
            FontSize = 25,
            FontWeight = FontWeights.Bold,
            Foreground = UiTheme.TextPrimaryBrush
        });
        header.Children.Add(new TextBlock
        {
            Text = "Keys",
            FontSize = 12,
            Margin = new Thickness(1, 3, 0, 0),
            Foreground = UiTheme.TextSecondaryBrush
        });

        var summary = new Border
        {
            CornerRadius = new CornerRadius(12),
            Margin = new Thickness(0, 14, 0, 0),
            Padding = new Thickness(12, 10, 12, 10),
            Background = UiTheme.SurfaceBrush,
            BorderBrush = UiTheme.HairlineBrush,
            BorderThickness = new Thickness(1),
            Effect = UiTheme.Shadow(10, 2, 0.04)
        };

        var summaryLayout = new Grid();
        summaryLayout.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        summaryLayout.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        summaryLayout.Children.Add(new TextBlock
        {
            Text = "Total Keys",
            FontSize = 12,
            Foreground = UiTheme.TextSecondaryBrush,
            VerticalAlignment = VerticalAlignment.Center
        });
        countText.FontSize = 18;
        countText.FontWeight = FontWeights.SemiBold;
        countText.Foreground = UiTheme.AccentTextBrush;
        Grid.SetColumn(countText, 1);
        summaryLayout.Children.Add(countText);
        summary.Child = summaryLayout;
        header.Children.Add(summary);

        DockPanel.SetDock(header, Dock.Top);
        panel.Children.Add(header);

        var searchHost = BuildSearchBox();
        DockPanel.SetDock(searchHost, Dock.Top);
        panel.Children.Add(searchHost);

        var toolbar = new StackPanel
        {
            Orientation = WpfOrientation.Horizontal,
            Margin = new Thickness(0, 0, 0, 12)
        };
        toolbar.Children.Add(MakeButton("New", AddSnippet, ButtonTone.Primary, new Thickness(0, 0, 8, 0)));
        toolbar.Children.Add(MakeButton("Import", ImportSnippets, ButtonTone.Secondary, new Thickness(0, 0, 8, 0)));
        toolbar.Children.Add(MakeButton("Export", ExportSnippets, ButtonTone.Secondary, new Thickness(0)));
        DockPanel.SetDock(toolbar, Dock.Top);
        panel.Children.Add(toolbar);

        snippetList.BorderThickness = new Thickness(0);
        snippetList.Background = WpfBrushes.Transparent;
        snippetList.ItemTemplate = BuildSnippetItemTemplate();
        snippetList.ItemContainerStyle = UiTheme.SettingsListItemStyle();
        snippetList.SetValue(ScrollViewer.HorizontalScrollBarVisibilityProperty, ScrollBarVisibility.Disabled);
        panel.Children.Add(snippetList);

        return chrome;
    }

    private UIElement BuildRightPanel()
    {
        var panel = new Grid
        {
            Margin = new Thickness(26, 24, 26, 18)
        };
        panel.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        panel.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        panel.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        panel.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var header = new StackPanel
        {
            Margin = new Thickness(0, 0, 0, 20)
        };
        header.Children.Add(new TextBlock
        {
            Text = "Details",
            FontSize = 22,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextPrimaryBrush
        });
        header.Children.Add(new TextBlock
        {
            Text = "Edit the selected Key.",
            FontSize = 12,
            Margin = new Thickness(0, 4, 0, 0),
            Foreground = UiTheme.TextSecondaryBrush
        });
        panel.Children.Add(header);

        var triggerSection = new StackPanel
        {
            Margin = new Thickness(0, 0, 0, 18)
        };
        triggerSection.Children.Add(new TextBlock
        {
            Text = "Trigger",
            Margin = new Thickness(0, 0, 0, 6),
            FontSize = 12,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextSecondaryBrush
        });

        triggerSection.Children.Add(BuildTriggerEditor());
        Grid.SetRow(triggerSection, 1);
        panel.Children.Add(triggerSection);

        var replacementSection = new Grid();
        replacementSection.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        replacementSection.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        replacementSection.Children.Add(new TextBlock
        {
            Text = "Replacement",
            Margin = new Thickness(0, 0, 0, 6),
            FontSize = 12,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextSecondaryBrush
        });

        replacementBox.AcceptsReturn = true;
        replacementBox.AcceptsTab = true;
        replacementBox.TextWrapping = TextWrapping.Wrap;
        replacementBox.VerticalScrollBarVisibility = ScrollBarVisibility.Auto;
        replacementBox.MinHeight = 240;
        replacementBox.Style = UiTheme.TextBoxStyle(12);
        Grid.SetRow(replacementBox, 1);
        replacementSection.Children.Add(replacementBox);
        Grid.SetRow(replacementSection, 2);
        panel.Children.Add(replacementSection);

        var buttons = new StackPanel
        {
            Orientation = WpfOrientation.Horizontal,
            HorizontalAlignment = WpfHorizontalAlignment.Right,
            Margin = new Thickness(0, 12, 0, 0)
        };
        buttons.Children.Add(MakeButton("Delete", DeleteSelectedSnippet, ButtonTone.Danger, new Thickness(0, 0, 8, 0)));
        buttons.Children.Add(MakeButton("Save", SaveSelectedSnippet, ButtonTone.Primary, new Thickness(0)));
        Grid.SetRow(buttons, 3);
        panel.Children.Add(buttons);

        return panel;
    }

    private UIElement BuildSearchBox()
    {
        searchBox.Height = 36;
        searchBox.Margin = new Thickness(0);
        searchBox.VerticalContentAlignment = VerticalAlignment.Center;
        searchBox.Style = UiTheme.TextBoxStyle(12, new Thickness(12, 4, 12, 4));
        searchBox.ToolTip = "Search trigger or replacement";

        searchPlaceholder.Text = "Search Keys";
        searchPlaceholder.FontSize = 13;
        searchPlaceholder.Foreground = UiTheme.TextSecondaryBrush;
        searchPlaceholder.Opacity = 0.72;
        searchPlaceholder.Margin = new Thickness(13, 0, 0, 0);
        searchPlaceholder.VerticalAlignment = VerticalAlignment.Center;
        searchPlaceholder.IsHitTestVisible = false;

        var host = new Grid
        {
            Height = 36,
            Margin = new Thickness(0, 0, 0, 10)
        };
        host.Children.Add(searchBox);
        host.Children.Add(searchPlaceholder);
        return host;
    }

    private UIElement BuildTriggerEditor()
    {
        var editor = new Border
        {
            Height = 46,
            CornerRadius = new CornerRadius(10),
            Background = UiTheme.SurfaceBrush,
            BorderBrush = UiTheme.HairlineBrush,
            BorderThickness = new Thickness(1),
            Padding = new Thickness(12, 0, 12, 0)
        };

        var layout = new Grid();
        layout.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        layout.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });

        layout.Children.Add(new TextBlock
        {
            Text = "#",
            FontFamily = new WpfFontFamily("Consolas"),
            FontSize = 20,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.AccentTextBrush,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 8, 0)
        });

        triggerBox.BorderThickness = new Thickness(0);
        triggerBox.Background = WpfBrushes.Transparent;
        triggerBox.Foreground = UiTheme.TextPrimaryBrush;
        triggerBox.CaretBrush = UiTheme.AccentBrush;
        triggerBox.FontFamily = new WpfFontFamily("Consolas");
        triggerBox.FontSize = 20;
        triggerBox.FontWeight = FontWeights.SemiBold;
        triggerBox.Padding = new Thickness(0, 1, 0, 0);
        triggerBox.VerticalContentAlignment = VerticalAlignment.Center;
        triggerBox.VerticalAlignment = VerticalAlignment.Center;
        triggerBox.FocusVisualStyle = null;
        triggerBox.GotKeyboardFocus += (_, _) => editor.BorderBrush = UiTheme.AccentBrush;
        triggerBox.LostKeyboardFocus += (_, _) => editor.BorderBrush = UiTheme.HairlineBrush;
        editor.MouseLeftButtonDown += (_, _) => triggerBox.Focus();
        Grid.SetColumn(triggerBox, 1);
        layout.Children.Add(triggerBox);

        editor.Child = layout;
        return editor;
    }

    private static WpfButton MakeButton(string text, Action action, ButtonTone tone, Thickness margin)
    {
        var button = new WpfButton
        {
            Content = text,
            MinWidth = 72,
            Height = 32,
            Margin = margin,
            Padding = new Thickness(13, 0, 13, 0),
            Style = UiTheme.ButtonStyle(tone)
        };
        button.Click += (_, _) => action();
        return button;
    }

    private static DataTemplate BuildSnippetItemTemplate()
    {
        var stack = new FrameworkElementFactory(typeof(StackPanel));
        stack.SetValue(StackPanel.MarginProperty, new Thickness(0));

        var trigger = new FrameworkElementFactory(typeof(TextBlock));
        trigger.SetBinding(TextBlock.TextProperty, new System.Windows.Data.Binding(nameof(SettingsSnippetItem.TriggerText)));
        trigger.SetValue(TextBlock.FontFamilyProperty, new WpfFontFamily("Consolas"));
        trigger.SetValue(TextBlock.FontWeightProperty, FontWeights.SemiBold);
        trigger.SetValue(TextBlock.ForegroundProperty, UiTheme.AccentTextBrush);
        stack.AppendChild(trigger);

        var preview = new FrameworkElementFactory(typeof(TextBlock));
        preview.SetBinding(TextBlock.TextProperty, new System.Windows.Data.Binding(nameof(SettingsSnippetItem.PreviewText)));
        preview.SetValue(TextBlock.FontSizeProperty, 12.0);
        preview.SetValue(TextBlock.ForegroundProperty, UiTheme.TextSecondaryBrush);
        preview.SetValue(TextBlock.TextTrimmingProperty, TextTrimming.CharacterEllipsis);
        preview.SetValue(TextBlock.MarginProperty, new Thickness(0, 5, 0, 0));
        stack.AppendChild(preview);

        return new DataTemplate
        {
            VisualTree = stack
        };
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
        countText.Text = items.Count.ToString(System.Globalization.CultureInfo.CurrentCulture);

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

    private void UpdateSearchPlaceholder()
    {
        searchPlaceholder.Visibility = string.IsNullOrWhiteSpace(searchBox.Text) && !searchBox.IsKeyboardFocusWithin
            ? Visibility.Visible
            : Visibility.Collapsed;
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

    public string TriggerText => "#" + Snippet.Trigger;

    public string PreviewText
    {
        get
        {
            var preview = FlattenedPreview(68);
            return string.IsNullOrEmpty(preview) ? "Empty replacement" : preview;
        }
    }

    private string FlattenedPreview(int maxLength)
    {
        var preview = Snippet.Replacement
            .Replace("\r", " ", StringComparison.Ordinal)
            .Replace("\n", " ", StringComparison.Ordinal)
            .Trim();
        return preview.Length > maxLength ? preview[..maxLength] + "..." : preview;
    }
}
