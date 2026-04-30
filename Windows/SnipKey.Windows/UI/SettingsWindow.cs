using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Win32;
using SnipKey.WinApp.Core;
using Button = System.Windows.Controls.Button;
using Brushes = System.Windows.Media.Brushes;
using ComboBox = System.Windows.Controls.ComboBox;
using FontFamily = System.Windows.Media.FontFamily;
using HorizontalAlignment = System.Windows.HorizontalAlignment;
using ListBox = System.Windows.Controls.ListBox;
using MessageBox = System.Windows.MessageBox;
using OpenFileDialog = Microsoft.Win32.OpenFileDialog;
using Orientation = System.Windows.Controls.Orientation;
using SaveFileDialog = Microsoft.Win32.SaveFileDialog;
using TextBox = System.Windows.Controls.TextBox;

namespace SnipKey.WinApp.UI;

internal sealed class SettingsWindow : Window
{
    private readonly SnippetStore store;
    private readonly ClipboardHistoryStore clipboardHistoryStore;
    private readonly AppLanguageStore languageStore;
    private readonly Action openClipboardHistory;
    private readonly Action openAbout;
    private TextBlock countText = new();
    private TextBlock groupCountText = new();
    private TextBlock searchPlaceholder = new();
    private TextBlock statusText = new();
    private TextBlock triggerHelpText = new();
    private TextBlock detailSubtitleText = new();
    private TextBox searchBox = new();
    private ListBox groupList = new();
    private ListBox snippetList = new();
    private TextBox triggerBox = new();
    private TextBox replacementBox = new();
    private ComboBox groupBox = new();
    private Guid? selectedGroupId;
    private Guid? selectedSnippetId;
    private bool isRefreshing;

    public SettingsWindow(
        SnippetStore store,
        ClipboardHistoryStore clipboardHistoryStore,
        AppLanguageStore languageStore,
        Action openClipboardHistory,
        Action openAbout)
    {
        this.store = store;
        this.clipboardHistoryStore = clipboardHistoryStore;
        this.languageStore = languageStore;
        this.openClipboardHistory = openClipboardHistory;
        this.openAbout = openAbout;

        Width = 1180;
        Height = 720;
        MinWidth = 980;
        MinHeight = 620;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = UiTheme.WindowBackgroundBrush;
        FontFamily = new FontFamily("Segoe UI Variable, Segoe UI");
        UseLayoutRounding = true;
        SnapsToDevicePixels = true;
        AppIcon.ApplyTo(this);

        store.Changed += OnStoreChanged;
        clipboardHistoryStore.Changed += OnClipboardStoreChanged;
        languageStore.Changed += OnLanguageChanged;
        Closed += OnClosed;

        CreateReusableControls();
        Content = BuildLayout();
        RefreshAll();
    }

    private void CreateReusableControls(string searchText = "")
    {
        countText = new TextBlock();
        groupCountText = new TextBlock();
        searchPlaceholder = new TextBlock();
        statusText = new TextBlock();
        triggerHelpText = new TextBlock();
        detailSubtitleText = new TextBlock();
        searchBox = new TextBox { Text = searchText };
        groupList = new ListBox();
        snippetList = new ListBox();
        triggerBox = new TextBox();
        replacementBox = new TextBox();
        groupBox = new ComboBox();

        searchBox.TextChanged += (_, _) =>
        {
            RefreshSnippetList(selectedSnippetId);
            UpdateSearchPlaceholder();
        };
        searchBox.GotKeyboardFocus += (_, _) => UpdateSearchPlaceholder();
        searchBox.LostKeyboardFocus += (_, _) => UpdateSearchPlaceholder();
        snippetList.SelectionChanged += (_, _) => LoadSelectedSnippet();
        groupList.SelectionChanged += (_, _) => SelectGroupFromList();
        triggerBox.TextChanged += (_, _) => UpdateTriggerHelp();
    }

    public void SelectSnippet(Guid snippetId)
    {
        var snippet = store.Snippets.FirstOrDefault(candidate => candidate.Id == snippetId);
        if (snippet is null)
        {
            return;
        }

        searchBox.Text = string.Empty;
        selectedGroupId = snippet.GroupId;
        selectedSnippetId = snippetId;
        RefreshAll(snippetId);
        Activate();
    }

    public void ShowGuide()
    {
        var guide = new GuideWindow(languageStore)
        {
            Owner = this
        };
        guide.Show();
        guide.Activate();
    }

    private UIElement BuildLayout()
    {
        Title = languageStore.Text(L10nKey.SettingsTitle);

        var root = new Grid
        {
            Background = UiTheme.WindowBackgroundBrush
        };
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(260) });
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(334) });
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var sidebar = BuildSidebar();
        Grid.SetColumn(sidebar, 0);
        root.Children.Add(sidebar);

        var browser = BuildBrowser();
        Grid.SetColumn(browser, 1);
        root.Children.Add(browser);

        var details = BuildDetails();
        Grid.SetColumn(details, 2);
        root.Children.Add(details);

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
        Grid.SetColumnSpan(statusBar, 3);
        Grid.SetRow(statusBar, 1);
        root.Children.Add(statusBar);

        return root;
    }

    private UIElement BuildSidebar()
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
            Text = languageStore.Text(L10nKey.SettingsSidebarSubtitle),
            FontSize = 12,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(1, 4, 0, 0),
            Foreground = UiTheme.TextSecondaryBrush
        });
        header.Children.Add(BuildMetrics());
        header.Children.Add(BuildLanguagePicker());
        DockPanel.SetDock(header, Dock.Top);
        panel.Children.Add(header);

        var tools = BuildTools();
        DockPanel.SetDock(tools, Dock.Bottom);
        panel.Children.Add(tools);

        var groupHeader = new Grid
        {
            Margin = new Thickness(0, 4, 0, 8)
        };
        groupHeader.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        groupHeader.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        groupHeader.Children.Add(new TextBlock
        {
            Text = languageStore.Text(L10nKey.SettingsGroups),
            FontSize = 12,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextSecondaryBrush,
            VerticalAlignment = VerticalAlignment.Center
        });
        var newGroupButton = MakeButton("+", AddGroup, ButtonTone.Secondary, new Thickness(0), minWidth: 34);
        newGroupButton.ToolTip = languageStore.Text(L10nKey.SettingsNewGroup);
        Grid.SetColumn(newGroupButton, 1);
        groupHeader.Children.Add(newGroupButton);
        DockPanel.SetDock(groupHeader, Dock.Top);
        panel.Children.Add(groupHeader);

        groupList.BorderThickness = new Thickness(0);
        groupList.Background = Brushes.Transparent;
        groupList.ItemTemplate = BuildGroupItemTemplate();
        groupList.ItemContainerStyle = UiTheme.SettingsListItemStyle();
        groupList.SetValue(ScrollViewer.HorizontalScrollBarVisibilityProperty, ScrollBarVisibility.Disabled);
        panel.Children.Add(groupList);

        return chrome;
    }

    private UIElement BuildMetrics()
    {
        var summary = new Border
        {
            CornerRadius = new CornerRadius(10),
            Margin = new Thickness(0, 14, 0, 12),
            Padding = new Thickness(12, 10, 12, 10),
            Background = UiTheme.SurfaceBrush,
            BorderBrush = UiTheme.HairlineBrush,
            BorderThickness = new Thickness(1),
            Effect = UiTheme.Shadow(10, 2, 0.04)
        };

        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.Children.Add(Metric(languageStore.Text(L10nKey.SettingsTotalKeys), countText));
        var groupMetric = Metric(languageStore.Text(L10nKey.SettingsMetricGroups), groupCountText);
        Grid.SetColumn(groupMetric, 1);
        grid.Children.Add(groupMetric);
        summary.Child = grid;
        return summary;
    }

    private UIElement Metric(string title, TextBlock value)
    {
        var stack = new StackPanel();
        stack.Children.Add(new TextBlock
        {
            Text = title,
            FontSize = 11,
            Foreground = UiTheme.TextSecondaryBrush
        });
        value.FontSize = 18;
        value.FontWeight = FontWeights.SemiBold;
        value.Foreground = UiTheme.AccentTextBrush;
        stack.Children.Add(value);
        return stack;
    }

    private UIElement BuildLanguagePicker()
    {
        var panel = new StackPanel
        {
            Margin = new Thickness(0, 0, 0, 12)
        };
        panel.Children.Add(new TextBlock
        {
            Text = languageStore.Text(L10nKey.LanguageTitle),
            FontSize = 12,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextSecondaryBrush,
            Margin = new Thickness(0, 0, 0, 6)
        });
        var comboBox = new ComboBox
        {
            Height = 34,
            ItemsSource = AppLanguageOption.All,
            DisplayMemberPath = nameof(AppLanguageOption.Name),
            SelectedValuePath = nameof(AppLanguageOption.Language),
            SelectedValue = languageStore.Language,
            Style = UiTheme.ComboBoxStyle()
        };
        comboBox.SelectionChanged += (_, _) =>
        {
            if (comboBox.SelectedItem is AppLanguageOption option)
            {
                languageStore.SetLanguage(option.Language);
            }
        };
        panel.Children.Add(comboBox);
        return panel;
    }

    private UIElement BuildTools()
    {
        var panel = new StackPanel
        {
            Margin = new Thickness(0, 12, 0, 0)
        };
        panel.Children.Add(new TextBlock
        {
            Text = languageStore.Text(L10nKey.SettingsTools),
            FontSize = 12,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextSecondaryBrush,
            Margin = new Thickness(0, 0, 0, 8)
        });
        panel.Children.Add(MakeButton(languageStore.Text(L10nKey.SettingsRenameGroup), RenameSelectedGroup, ButtonTone.Secondary, new Thickness(0, 0, 0, 8), stretch: true));
        panel.Children.Add(MakeButton(languageStore.Text(L10nKey.SettingsDeleteGroup), DeleteSelectedGroup, ButtonTone.Danger, new Thickness(0, 0, 0, 8), stretch: true));
        panel.Children.Add(MakeButton(languageStore.Text(L10nKey.SettingsClipboardHistory), openClipboardHistory, ButtonTone.Secondary, new Thickness(0, 0, 0, 8), stretch: true));
        panel.Children.Add(MakeButton(languageStore.Text(L10nKey.SettingsGuide), ShowGuide, ButtonTone.Secondary, new Thickness(0, 0, 0, 8), stretch: true));
        panel.Children.Add(MakeButton(languageStore.Text(L10nKey.SettingsAbout), openAbout, ButtonTone.Secondary, new Thickness(0), stretch: true));
        return panel;
    }

    private UIElement BuildBrowser()
    {
        var panel = new DockPanel
        {
            Margin = new Thickness(18, 18, 18, 14)
        };

        var header = new StackPanel
        {
            Margin = new Thickness(0, 0, 0, 12)
        };
        header.Children.Add(new TextBlock
        {
            Text = languageStore.Text(L10nKey.SettingsBrowse),
            FontSize = 20,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextPrimaryBrush
        });
        header.Children.Add(BuildSearchBox());
        header.Children.Add(BuildSnippetToolbar());
        DockPanel.SetDock(header, Dock.Top);
        panel.Children.Add(header);

        snippetList.BorderThickness = new Thickness(0);
        snippetList.Background = Brushes.Transparent;
        snippetList.ItemTemplate = BuildSnippetItemTemplate();
        snippetList.ItemContainerStyle = UiTheme.SettingsListItemStyle();
        snippetList.SetValue(ScrollViewer.HorizontalScrollBarVisibilityProperty, ScrollBarVisibility.Disabled);
        panel.Children.Add(snippetList);

        return new Border
        {
            Background = UiTheme.Brush(255, 255, 255, 0.34),
            BorderBrush = UiTheme.HairlineBrush,
            BorderThickness = new Thickness(0, 0, 1, 0),
            Child = panel
        };
    }

    private UIElement BuildSearchBox()
    {
        searchBox.Height = 36;
        searchBox.Margin = new Thickness(0);
        searchBox.VerticalContentAlignment = VerticalAlignment.Center;
        searchBox.Style = UiTheme.TextBoxStyle(10, new Thickness(12, 4, 12, 4));
        searchBox.ToolTip = languageStore.Text(L10nKey.SettingsSearchPlaceholder);

        searchPlaceholder.Text = languageStore.Text(L10nKey.SettingsSearchPlaceholder);
        searchPlaceholder.FontSize = 13;
        searchPlaceholder.Foreground = UiTheme.TextSecondaryBrush;
        searchPlaceholder.Opacity = 0.72;
        searchPlaceholder.Margin = new Thickness(13, 0, 0, 0);
        searchPlaceholder.VerticalAlignment = VerticalAlignment.Center;
        searchPlaceholder.IsHitTestVisible = false;

        var host = new Grid
        {
            Height = 36,
            Margin = new Thickness(0, 12, 0, 10)
        };
        host.Children.Add(searchBox);
        host.Children.Add(searchPlaceholder);
        return host;
    }

    private UIElement BuildSnippetToolbar()
    {
        var toolbar = new StackPanel
        {
            Orientation = Orientation.Horizontal
        };
        toolbar.Children.Add(MakeButton(languageStore.Text(L10nKey.SettingsNewKey), AddSnippet, ButtonTone.Primary, new Thickness(0, 0, 8, 0)));
        toolbar.Children.Add(MakeButton(languageStore.Text(L10nKey.CommonImport), ImportSnippets, ButtonTone.Secondary, new Thickness(0, 0, 8, 0)));
        toolbar.Children.Add(MakeButton(languageStore.Text(L10nKey.CommonExport), ExportSnippets, ButtonTone.Secondary, new Thickness(0)));
        return toolbar;
    }

    private UIElement BuildDetails()
    {
        var panel = new Grid
        {
            Margin = new Thickness(26, 24, 26, 18)
        };
        panel.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
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
            Text = languageStore.Text(L10nKey.SettingsDetails),
            FontSize = 22,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextPrimaryBrush
        });
        detailSubtitleText.FontSize = 12;
        detailSubtitleText.Margin = new Thickness(0, 4, 0, 0);
        detailSubtitleText.Foreground = UiTheme.TextSecondaryBrush;
        header.Children.Add(detailSubtitleText);
        panel.Children.Add(header);

        var triggerSection = new StackPanel
        {
            Margin = new Thickness(0, 0, 0, 16)
        };
        triggerSection.Children.Add(SectionLabel(languageStore.Text(L10nKey.SettingsTriggerTitle)));
        triggerSection.Children.Add(BuildTriggerEditor());
        triggerHelpText.FontSize = 12;
        triggerHelpText.Margin = new Thickness(0, 7, 0, 0);
        triggerHelpText.Foreground = UiTheme.TextSecondaryBrush;
        triggerSection.Children.Add(triggerHelpText);
        Grid.SetRow(triggerSection, 1);
        panel.Children.Add(triggerSection);

        var groupSection = new StackPanel
        {
            Margin = new Thickness(0, 0, 0, 16)
        };
        groupSection.Children.Add(SectionLabel(languageStore.Text(L10nKey.SettingsGroupTitle)));
        groupBox.Height = 34;
        groupBox.DisplayMemberPath = nameof(GroupAssignmentItem.Name);
        groupBox.SelectedValuePath = nameof(GroupAssignmentItem.GroupId);
        groupBox.Style = UiTheme.ComboBoxStyle();
        groupSection.Children.Add(groupBox);
        Grid.SetRow(groupSection, 2);
        panel.Children.Add(groupSection);

        var replacementSection = new Grid();
        replacementSection.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        replacementSection.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        var replacementHeader = new StackPanel
        {
            Margin = new Thickness(0, 0, 0, 6)
        };
        replacementHeader.Children.Add(SectionLabel(languageStore.Text(L10nKey.SettingsReplacementTitle)));
        replacementHeader.Children.Add(new TextBlock
        {
            Text = languageStore.Text(L10nKey.SettingsReplacementSubtitle),
            FontSize = 12,
            Margin = new Thickness(0, 3, 0, 0),
            Foreground = UiTheme.TextSecondaryBrush
        });
        replacementSection.Children.Add(replacementHeader);

        replacementBox.AcceptsReturn = true;
        replacementBox.AcceptsTab = true;
        replacementBox.TextWrapping = TextWrapping.Wrap;
        replacementBox.VerticalScrollBarVisibility = ScrollBarVisibility.Auto;
        replacementBox.MinHeight = 240;
        replacementBox.Style = UiTheme.TextBoxStyle(10);
        Grid.SetRow(replacementBox, 1);
        replacementSection.Children.Add(replacementBox);
        Grid.SetRow(replacementSection, 3);
        panel.Children.Add(replacementSection);

        var bottom = new Grid
        {
            Margin = new Thickness(0, 12, 0, 0)
        };
        bottom.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        bottom.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        bottom.Children.Add(new TextBlock
        {
            Text = languageStore.Text(L10nKey.SettingsVariablesSubtitle),
            FontSize = 12,
            Foreground = UiTheme.TextSecondaryBrush,
            VerticalAlignment = VerticalAlignment.Center,
            TextWrapping = TextWrapping.Wrap
        });
        var buttons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right
        };
        buttons.Children.Add(MakeButton(languageStore.Text(L10nKey.SettingsDeleteKey), DeleteSelectedSnippet, ButtonTone.Danger, new Thickness(0, 0, 8, 0)));
        buttons.Children.Add(MakeButton(languageStore.Text(L10nKey.CommonSave), SaveSelectedSnippet, ButtonTone.Primary, new Thickness(0)));
        Grid.SetColumn(buttons, 1);
        bottom.Children.Add(buttons);
        Grid.SetRow(bottom, 4);
        panel.Children.Add(bottom);

        return panel;
    }

    private static UIElement SectionLabel(string text)
    {
        return new TextBlock
        {
            Text = text,
            Margin = new Thickness(0, 0, 0, 6),
            FontSize = 12,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextSecondaryBrush
        };
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
            FontFamily = new FontFamily("Consolas"),
            FontSize = 20,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.AccentTextBrush,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 8, 0)
        });

        triggerBox.BorderThickness = new Thickness(0);
        triggerBox.Background = Brushes.Transparent;
        triggerBox.Foreground = UiTheme.TextPrimaryBrush;
        triggerBox.CaretBrush = UiTheme.AccentBrush;
        triggerBox.FontFamily = new FontFamily("Consolas");
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

    private void RefreshAll(Guid? preferredSelection = null)
    {
        isRefreshing = true;
        Title = languageStore.Text(L10nKey.SettingsTitle);
        countText.Text = store.Snippets.Count.ToString(languageStore.Language.Culture());
        groupCountText.Text = store.Groups.Count.ToString(languageStore.Language.Culture());
        RefreshGroupList();
        RefreshGroupAssignment();
        isRefreshing = false;
        RefreshSnippetList(preferredSelection);
        UpdateSearchPlaceholder();
        UpdateTriggerHelp();
    }

    private void RefreshGroupList()
    {
        var items = new List<SettingsGroupItem>
        {
            new(null, languageStore.Text(L10nKey.SettingsAllKeys), languageStore.Text(L10nKey.SettingsAllTextExpansions), store.Snippets.Count)
        };
        items.AddRange(store.Groups
            .OrderBy(group => group.Name, StringComparer.CurrentCultureIgnoreCase)
            .Select(group => new SettingsGroupItem(
                group.Id,
                group.Name,
                languageStore.Format(L10nKey.SettingsResultCountFormat, store.Snippets.Count(snippet => snippet.GroupId == group.Id)),
                store.Snippets.Count(snippet => snippet.GroupId == group.Id))));

        groupList.ItemsSource = items;
        groupList.SelectedItem = items.FirstOrDefault(item => item.GroupId == selectedGroupId) ?? items[0];
    }

    private void RefreshGroupAssignment()
    {
        var items = new List<GroupAssignmentItem>
        {
            new(null, languageStore.Text(L10nKey.SettingsUngrouped))
        };
        items.AddRange(store.Groups
            .OrderBy(group => group.Name, StringComparer.CurrentCultureIgnoreCase)
            .Select(group => new GroupAssignmentItem(group.Id, group.Name)));
        groupBox.ItemsSource = items;
    }

    private void RefreshSnippetList(Guid? preferredSelection = null)
    {
        if (isRefreshing)
        {
            return;
        }

        var filter = searchBox.Text.Trim();
        var snippets = store.Snippets.AsEnumerable();
        if (selectedGroupId is not null)
        {
            snippets = snippets.Where(snippet => snippet.GroupId == selectedGroupId);
        }

        var items = snippets
            .Where(snippet => string.IsNullOrEmpty(filter)
                || snippet.Trigger.Contains(filter, StringComparison.OrdinalIgnoreCase)
                || snippet.Replacement.Contains(filter, StringComparison.OrdinalIgnoreCase))
            .OrderBy(snippet => snippet.Trigger, StringComparer.CurrentCultureIgnoreCase)
            .Select(snippet => new SettingsSnippetItem(snippet.Clone(), GroupName(snippet.GroupId), languageStore.Text(L10nKey.SettingsEmptyReplacement)))
            .ToList();

        snippetList.ItemsSource = items;
        var selectedItem = items.FirstOrDefault(item => item.Snippet.Id == preferredSelection)
            ?? items.FirstOrDefault(item => item.Snippet.Id == selectedSnippetId)
            ?? items.FirstOrDefault();
        snippetList.SelectedItem = selectedItem;

        if (selectedItem is null)
        {
            ClearEditor();
        }
        else
        {
            LoadSelectedSnippet();
        }
    }

    private void SelectGroupFromList()
    {
        if (isRefreshing || groupList.SelectedItem is not SettingsGroupItem item)
        {
            return;
        }

        selectedGroupId = item.GroupId;
        selectedSnippetId = null;
        RefreshSnippetList();
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
            ClearEditor();
            return;
        }

        selectedSnippetId = item.Snippet.Id;
        triggerBox.Text = item.Snippet.Trigger;
        replacementBox.Text = item.Snippet.Replacement;
        SelectGroupAssignment(item.Snippet.GroupId);
        detailSubtitleText.Text = languageStore.Text(L10nKey.SettingsEditSelectedKey);
        SetEditorEnabled(true);
        statusText.Text = string.Empty;
        UpdateTriggerHelp();
    }

    private void ClearEditor()
    {
        selectedSnippetId = null;
        triggerBox.Text = string.Empty;
        replacementBox.Text = string.Empty;
        SelectGroupAssignment(null);
        detailSubtitleText.Text = languageStore.Text(L10nKey.SettingsSelectKeySubtitle);
        SetEditorEnabled(false);
        triggerHelpText.Text = languageStore.Text(L10nKey.SettingsSelectKeyTitle);
    }

    private void SetEditorEnabled(bool enabled)
    {
        triggerBox.IsEnabled = enabled;
        replacementBox.IsEnabled = enabled;
        groupBox.IsEnabled = enabled;
    }

    private void SelectGroupAssignment(Guid? groupId)
    {
        groupBox.SelectedItem = groupBox.Items.OfType<GroupAssignmentItem>().FirstOrDefault(item => item.GroupId == groupId)
            ?? groupBox.Items.OfType<GroupAssignmentItem>().FirstOrDefault();
    }

    private void UpdateTriggerHelp()
    {
        if (selectedSnippetId is null)
        {
            return;
        }

        var validationError = store.ValidationError(triggerBox.Text.Trim(), selectedSnippetId.Value);
        triggerHelpText.Text = validationError is null
            ? languageStore.Text(L10nKey.SettingsTriggerHelp)
            : ValidationMessage(validationError.Value);
        triggerHelpText.Foreground = validationError is null ? UiTheme.TextSecondaryBrush : UiTheme.DangerBrush;
    }

    private void AddSnippet()
    {
        var snippet = new Snippet
        {
            Trigger = store.NextAvailableTrigger(),
            Replacement = languageStore.Text(L10nKey.SettingsDefaultReplacement),
            GroupId = selectedGroupId
        };

        if (!store.AddSnippet(snippet))
        {
            statusText.Text = languageStore.Text(L10nKey.SettingsCouldNotCreateKey);
            return;
        }

        selectedSnippetId = snippet.Id;
        RefreshAll(snippet.Id);
        triggerBox.Focus();
        triggerBox.SelectAll();
        statusText.Text = languageStore.Text(L10nKey.SettingsNewKeyCreated);
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
            GroupId = (groupBox.SelectedItem as GroupAssignmentItem)?.GroupId,
            AcceptanceCount = existingSnippet?.AcceptanceCount ?? 0
        };

        if (!store.UpdateSnippet(snippet))
        {
            statusText.Text = languageStore.Text(L10nKey.SettingsCouldNotSaveKey);
            return;
        }

        RefreshAll(snippet.Id);
        statusText.Text = languageStore.Text(L10nKey.SettingsSaved);
    }

    private void DeleteSelectedSnippet()
    {
        if (selectedSnippetId is null)
        {
            return;
        }

        var snippetId = selectedSnippetId.Value;
        var result = MessageBox.Show(this, languageStore.Text(L10nKey.SettingsDeleteKeyMessage), languageStore.Text(L10nKey.SettingsDeleteKeyTitle), MessageBoxButton.YesNo, MessageBoxImage.Question);
        if (result != MessageBoxResult.Yes)
        {
            return;
        }

        store.DeleteSnippet(snippetId);
        clipboardHistoryStore.ClearCreatedSnippetAssociation(snippetId);
        selectedSnippetId = null;
        RefreshAll();
        statusText.Text = languageStore.Text(L10nKey.SettingsDeleted);
    }

    private void AddGroup()
    {
        var name = TextInputDialog.Show(
            this,
            languageStore.Text(L10nKey.SettingsNewGroup),
            languageStore.Text(L10nKey.SettingsGroupTitle),
            store.NextAvailableGroupName(languageStore.Text(L10nKey.SettingsDefaultGroupName)),
            languageStore);
        if (string.IsNullOrWhiteSpace(name))
        {
            return;
        }

        var group = store.AddGroup(name);
        selectedGroupId = group.Id;
        RefreshAll();
    }

    private void RenameSelectedGroup()
    {
        if (selectedGroupId is null)
        {
            return;
        }

        var group = store.Groups.FirstOrDefault(candidate => candidate.Id == selectedGroupId.Value);
        if (group is null)
        {
            return;
        }

        var name = TextInputDialog.Show(this, languageStore.Text(L10nKey.SettingsRenameGroup), languageStore.Text(L10nKey.SettingsGroupTitle), group.Name, languageStore);
        if (string.IsNullOrWhiteSpace(name))
        {
            return;
        }

        store.RenameGroup(group.Id, name);
        RefreshAll();
    }

    private void DeleteSelectedGroup()
    {
        if (selectedGroupId is null)
        {
            return;
        }

        var result = MessageBox.Show(this, languageStore.Text(L10nKey.SettingsDeleteGroupMessage), languageStore.Text(L10nKey.SettingsDeleteGroupTitle), MessageBoxButton.YesNo, MessageBoxImage.Question);
        if (result != MessageBoxResult.Yes)
        {
            return;
        }

        store.DeleteGroup(selectedGroupId.Value);
        selectedGroupId = null;
        RefreshAll();
    }

    private void ImportSnippets()
    {
        var dialog = new OpenFileDialog
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
            selectedGroupId = null;
            RefreshAll();
            statusText.Text = languageStore.Text(L10nKey.SettingsImported);
        }
        catch (Exception exception)
        {
            statusText.Text = languageStore.Format(L10nKey.SettingsImportFailedFormat, exception.Message);
        }
    }

    private void ExportSnippets()
    {
        var dialog = new SaveFileDialog
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
            statusText.Text = languageStore.Text(L10nKey.SettingsExported);
        }
        catch (Exception exception)
        {
            statusText.Text = languageStore.Format(L10nKey.SettingsExportFailedFormat, exception.Message);
        }
    }

    private string ValidationMessage(SnippetTriggerRules.ValidationError validationError)
    {
        return validationError switch
        {
            SnippetTriggerRules.ValidationError.Empty => languageStore.Text(L10nKey.SettingsTriggerEmpty),
            SnippetTriggerRules.ValidationError.InvalidCharacters => languageStore.Text(L10nKey.SettingsTriggerInvalid),
            SnippetTriggerRules.ValidationError.Duplicate => languageStore.Text(L10nKey.SettingsTriggerDuplicate),
            _ => languageStore.Text(L10nKey.SettingsTriggerInvalidGeneric)
        };
    }

    private string GroupName(Guid? groupId)
    {
        if (groupId is null)
        {
            return languageStore.Text(L10nKey.SettingsUngrouped);
        }

        return store.Groups.FirstOrDefault(group => group.Id == groupId.Value)?.Name
            ?? languageStore.Text(L10nKey.SettingsUngrouped);
    }

    private void OnStoreChanged(object? sender, EventArgs eventArgs)
    {
        Dispatcher.Invoke(() => RefreshAll(selectedSnippetId));
    }

    private void OnClipboardStoreChanged(object? sender, EventArgs eventArgs)
    {
        Dispatcher.Invoke(() => statusText.Text = ClipboardStatusText());
    }

    private void OnLanguageChanged(object? sender, EventArgs eventArgs)
    {
        Dispatcher.Invoke(() =>
        {
            var searchText = searchBox.Text;
            var selectedSnippet = selectedSnippetId;
            CreateReusableControls(searchText);
            Content = BuildLayout();
            RefreshAll(selectedSnippet);
        });
    }

    private void OnClosed(object? sender, EventArgs eventArgs)
    {
        store.Changed -= OnStoreChanged;
        clipboardHistoryStore.Changed -= OnClipboardStoreChanged;
        languageStore.Changed -= OnLanguageChanged;
        Closed -= OnClosed;
    }

    private string ClipboardStatusText()
    {
        return clipboardHistoryStore.Settings.IsMonitoringEnabled
            ? languageStore.Format(L10nKey.ClipboardHeaderEnabledFormat, ClipboardHistoryStore.DefaultMaxRecordCount)
            : languageStore.Text(L10nKey.ClipboardHeaderPaused);
    }

    private static Button MakeButton(string text, Action action, ButtonTone tone, Thickness margin, int minWidth = 72, bool stretch = false)
    {
        var button = new Button
        {
            Content = text,
            MinWidth = minWidth,
            Height = 32,
            Margin = margin,
            Padding = new Thickness(13, 0, 13, 0),
            HorizontalAlignment = stretch ? HorizontalAlignment.Stretch : HorizontalAlignment.Left,
            Style = UiTheme.ButtonStyle(tone)
        };
        button.Click += (_, _) => action();
        return button;
    }

    private static DataTemplate BuildSnippetItemTemplate()
    {
        var stack = new FrameworkElementFactory(typeof(StackPanel));

        var trigger = new FrameworkElementFactory(typeof(TextBlock));
        trigger.SetBinding(TextBlock.TextProperty, new System.Windows.Data.Binding(nameof(SettingsSnippetItem.TriggerText)));
        trigger.SetValue(TextBlock.FontFamilyProperty, new FontFamily("Consolas"));
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

        var group = new FrameworkElementFactory(typeof(TextBlock));
        group.SetBinding(TextBlock.TextProperty, new System.Windows.Data.Binding(nameof(SettingsSnippetItem.GroupName)));
        group.SetValue(TextBlock.FontSizeProperty, 11.0);
        group.SetValue(TextBlock.ForegroundProperty, UiTheme.TextSecondaryBrush);
        group.SetValue(TextBlock.MarginProperty, new Thickness(0, 5, 0, 0));
        stack.AppendChild(group);

        return new DataTemplate
        {
            VisualTree = stack
        };
    }

    private static DataTemplate BuildGroupItemTemplate()
    {
        var stack = new FrameworkElementFactory(typeof(StackPanel));

        var title = new FrameworkElementFactory(typeof(TextBlock));
        title.SetBinding(TextBlock.TextProperty, new System.Windows.Data.Binding(nameof(SettingsGroupItem.Name)));
        title.SetValue(TextBlock.FontWeightProperty, FontWeights.SemiBold);
        title.SetValue(TextBlock.ForegroundProperty, UiTheme.TextPrimaryBrush);
        stack.AppendChild(title);

        var subtitle = new FrameworkElementFactory(typeof(TextBlock));
        subtitle.SetBinding(TextBlock.TextProperty, new System.Windows.Data.Binding(nameof(SettingsGroupItem.Subtitle)));
        subtitle.SetValue(TextBlock.FontSizeProperty, 12.0);
        subtitle.SetValue(TextBlock.ForegroundProperty, UiTheme.TextSecondaryBrush);
        subtitle.SetValue(TextBlock.MarginProperty, new Thickness(0, 4, 0, 0));
        stack.AppendChild(subtitle);

        return new DataTemplate
        {
            VisualTree = stack
        };
    }

    private sealed record AppLanguageOption(AppLanguage Language, string Name)
    {
        public static IReadOnlyList<AppLanguageOption> All { get; } =
        [
            new(AppLanguage.SimplifiedChinese, AppLanguage.SimplifiedChinese.PickerTitle()),
            new(AppLanguage.English, AppLanguage.English.PickerTitle())
        ];

        public override string ToString()
        {
            return Name;
        }
    }

    private sealed record GroupAssignmentItem(Guid? GroupId, string Name)
    {
        public override string ToString()
        {
            return Name;
        }
    }

    private sealed record SettingsGroupItem(Guid? GroupId, string Name, string Subtitle, int Count);

    private sealed class SettingsSnippetItem
    {
        private readonly string emptyReplacementText;

        public SettingsSnippetItem(Snippet snippet, string groupName, string emptyReplacementText)
        {
            Snippet = snippet;
            GroupName = groupName;
            this.emptyReplacementText = emptyReplacementText;
        }

        public Snippet Snippet { get; }

        public string GroupName { get; }

        public string TriggerText => "#" + Snippet.Trigger;

        public string PreviewText
        {
            get
            {
                var preview = FlattenedPreview(68);
                return string.IsNullOrEmpty(preview) ? emptyReplacementText : preview;
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
}