using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using SnipKey.WinApp.Core;
using Button = System.Windows.Controls.Button;
using CheckBox = System.Windows.Controls.CheckBox;
using FontFamily = System.Windows.Media.FontFamily;
using HorizontalAlignment = System.Windows.HorizontalAlignment;
using Orientation = System.Windows.Controls.Orientation;

namespace SnipKey.WinApp.UI;

internal sealed class ClipboardHistoryWindow : Window
{
    private readonly ClipboardHistoryStore historyStore;
    private readonly AppLanguageStore languageStore;
    private readonly Action<ClipboardRecord> createSnippet;
    private TextBlock subtitleText = new();
    private TextBlock recordCountText = new();
    private TextBlock statusText = new();
    private TextBlock thresholdText = new();
    private CheckBox monitoringCheckBox = new();
    private Slider thresholdSlider = new();
    private StackPanel recordsPanel = new();
    private bool isRefreshing;

    public ClipboardHistoryWindow(ClipboardHistoryStore historyStore, AppLanguageStore languageStore, Action<ClipboardRecord> createSnippet)
    {
        this.historyStore = historyStore;
        this.languageStore = languageStore;
        this.createSnippet = createSnippet;

        Title = languageStore.Text(L10nKey.ClipboardTitle);
        Width = 720;
        Height = 580;
        MinWidth = 620;
        MinHeight = 460;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = UiTheme.WindowBackgroundBrush;
        FontFamily = new FontFamily("Segoe UI Variable, Segoe UI");
        UseLayoutRounding = true;
        SnapsToDevicePixels = true;
        AppIcon.ApplyTo(this);
        CreateReusableControls();
        Content = BuildLayout();

        historyStore.Changed += OnStoreChanged;
        languageStore.Changed += OnLanguageChanged;
        Refresh();
    }

    private void CreateReusableControls()
    {
        subtitleText = new TextBlock();
        recordCountText = new TextBlock();
        statusText = new TextBlock();
        thresholdText = new TextBlock();
        monitoringCheckBox = new CheckBox();
        thresholdSlider = new Slider();
        recordsPanel = new StackPanel();
    }

    protected override void OnClosed(EventArgs eventArgs)
    {
        historyStore.Changed -= OnStoreChanged;
        languageStore.Changed -= OnLanguageChanged;
        base.OnClosed(eventArgs);
    }

    private UIElement BuildLayout()
    {
        var root = new Grid
        {
            Margin = new Thickness(20)
        };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

        var header = new Grid
        {
            Margin = new Thickness(0, 0, 0, 14)
        };
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var titleStack = new StackPanel();
        titleStack.Children.Add(new TextBlock
        {
            Text = languageStore.Text(L10nKey.ClipboardTitle),
            FontSize = 24,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextPrimaryBrush
        });
        subtitleText.FontSize = 12;
        subtitleText.Margin = new Thickness(1, 4, 0, 0);
        subtitleText.Foreground = UiTheme.TextSecondaryBrush;
        titleStack.Children.Add(subtitleText);
        header.Children.Add(titleStack);

        var headerButtons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right
        };
        headerButtons.Children.Add(MakeButton(languageStore.Text(L10nKey.ClipboardClearRecords), ClearRecords, ButtonTone.Danger, new Thickness(0, 0, 8, 0)));
        headerButtons.Children.Add(MakeButton(languageStore.Text(L10nKey.CommonClose), Close, ButtonTone.Secondary, new Thickness(0)));
        Grid.SetColumn(headerButtons, 1);
        header.Children.Add(headerButtons);
        root.Children.Add(header);

        var settings = BuildSettingsPanel();
        Grid.SetRow(settings, 1);
        root.Children.Add(settings);

        var scroller = new ScrollViewer
        {
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            Content = recordsPanel
        };
        Grid.SetRow(scroller, 2);
        root.Children.Add(scroller);

        return root;
    }

    private UIElement BuildSettingsPanel()
    {
        var panel = new Border
        {
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(14),
            Margin = new Thickness(0, 0, 0, 14),
            Background = UiTheme.SurfaceBrush,
            BorderBrush = UiTheme.HairlineBrush,
            BorderThickness = new Thickness(1),
            Effect = UiTheme.Shadow(10, 2, 0.04)
        };

        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var metrics = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Margin = new Thickness(0, 0, 0, 12)
        };
        metrics.Children.Add(Metric(languageStore.Text(L10nKey.ClipboardRecordMetric), recordCountText));
        metrics.Children.Add(Metric(languageStore.Text(L10nKey.ClipboardStatusMetric), statusText));
        metrics.Children.Add(Metric(languageStore.Text(L10nKey.ClipboardThresholdMetric), thresholdText));
        Grid.SetColumnSpan(metrics, 2);
        grid.Children.Add(metrics);

        monitoringCheckBox.Margin = new Thickness(0, 4, 20, 0);
        monitoringCheckBox.Content = languageStore.Text(L10nKey.ClipboardMonitoringToggleTitle);
        monitoringCheckBox.Checked += (_, _) => UpdateMonitoringSetting(true);
        monitoringCheckBox.Unchecked += (_, _) => UpdateMonitoringSetting(false);
        Grid.SetRow(monitoringCheckBox, 1);
        grid.Children.Add(monitoringCheckBox);

        var thresholdPanel = new StackPanel();
        thresholdPanel.Children.Add(new TextBlock
        {
            Text = languageStore.Text(L10nKey.ClipboardThresholdTitle),
            FontSize = 12,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextSecondaryBrush
        });
        thresholdSlider.Minimum = 2;
        thresholdSlider.Maximum = 10;
        thresholdSlider.TickFrequency = 1;
        thresholdSlider.IsSnapToTickEnabled = true;
        thresholdSlider.ValueChanged += (_, _) => UpdateThresholdSetting();
        thresholdPanel.Children.Add(thresholdSlider);
        Grid.SetRow(thresholdPanel, 1);
        Grid.SetColumn(thresholdPanel, 1);
        grid.Children.Add(thresholdPanel);

        panel.Child = grid;
        return panel;
    }

    private UIElement Metric(string title, TextBlock valueText)
    {
        var stack = new StackPanel
        {
            Margin = new Thickness(0, 0, 24, 0)
        };
        stack.Children.Add(new TextBlock
        {
            Text = title,
            FontSize = 11,
            Foreground = UiTheme.TextSecondaryBrush
        });
        valueText.FontSize = 16;
        valueText.FontWeight = FontWeights.SemiBold;
        valueText.Foreground = UiTheme.TextPrimaryBrush;
        stack.Children.Add(valueText);
        return stack;
    }

    private void Refresh()
    {
        isRefreshing = true;
        Title = languageStore.Text(L10nKey.ClipboardTitle);
        subtitleText.Text = historyStore.Settings.IsMonitoringEnabled
            ? languageStore.Format(L10nKey.ClipboardHeaderEnabledFormat, ClipboardHistoryStore.DefaultMaxRecordCount)
            : languageStore.Text(L10nKey.ClipboardHeaderPaused);
        recordCountText.Text = historyStore.Records.Count.ToString(languageStore.Language.Culture());
        statusText.Text = historyStore.Settings.IsMonitoringEnabled
            ? languageStore.Text(L10nKey.ClipboardStatusOn)
            : languageStore.Text(L10nKey.ClipboardStatusOff);
        thresholdText.Text = languageStore.Format(L10nKey.ClipboardTimesFormat, historyStore.Settings.SuggestionThreshold);
        monitoringCheckBox.Content = languageStore.Text(L10nKey.ClipboardMonitoringToggleTitle);
        monitoringCheckBox.IsChecked = historyStore.Settings.IsMonitoringEnabled;
        thresholdSlider.Value = historyStore.Settings.SuggestionThreshold;
        isRefreshing = false;

        RefreshRecords();
    }

    private void RefreshRecords()
    {
        recordsPanel.Children.Clear();
        recordsPanel.Children.Add(new TextBlock
        {
            Text = languageStore.Text(L10nKey.ClipboardRecentCopiesTitle),
            FontSize = 17,
            FontWeight = FontWeights.SemiBold,
            Margin = new Thickness(0, 0, 0, 8),
            Foreground = UiTheme.TextPrimaryBrush
        });

        if (historyStore.Records.Count == 0)
        {
            recordsPanel.Children.Add(new Border
            {
                CornerRadius = new CornerRadius(10),
                Padding = new Thickness(18),
                Background = UiTheme.SurfaceBrush,
                BorderBrush = UiTheme.HairlineBrush,
                BorderThickness = new Thickness(1),
                Child = new TextBlock
                {
                    Text = languageStore.Text(L10nKey.ClipboardEmptyTitle) + "\n" + languageStore.Text(L10nKey.ClipboardEmptySubtitle),
                    TextAlignment = TextAlignment.Center,
                    TextWrapping = TextWrapping.Wrap,
                    Foreground = UiTheme.TextSecondaryBrush
                }
            });
            return;
        }

        foreach (var record in historyStore.Records)
        {
            recordsPanel.Children.Add(RecordRow(record));
        }
    }

    private UIElement RecordRow(ClipboardRecord record)
    {
        var card = new Border
        {
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(14),
            Margin = new Thickness(0, 0, 0, 8),
            Background = UiTheme.SurfaceBrush,
            BorderBrush = UiTheme.HairlineBrush,
            BorderThickness = new Thickness(1)
        };

        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var textStack = new StackPanel();
        textStack.Children.Add(new TextBlock
        {
            Text = RecordTitle(record),
            FontSize = 14,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextPrimaryBrush,
            TextTrimming = TextTrimming.CharacterEllipsis
        });
        textStack.Children.Add(new TextBlock
        {
            Text = LastCopiedDescription(record) + " · " + languageStore.Format(L10nKey.ClipboardCopiedTimesFormat, record.CopyCount),
            FontSize = 12,
            Margin = new Thickness(0, 3, 0, 8),
            Foreground = UiTheme.TextSecondaryBrush
        });
        textStack.Children.Add(new TextBlock
        {
            Text = BodyPreview(record.Content),
            MaxHeight = 64,
            TextWrapping = TextWrapping.Wrap,
            Foreground = UiTheme.TextSecondaryBrush
        });
        grid.Children.Add(textStack);

        var buttons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            VerticalAlignment = VerticalAlignment.Top,
            Margin = new Thickness(16, 0, 0, 0)
        };
        buttons.Children.Add(MakeButton(languageStore.Text(L10nKey.ClipboardDeleteRecord), () => historyStore.DeleteRecord(record.Id), ButtonTone.Danger, new Thickness(0, 0, 8, 0)));
        buttons.Children.Add(MakeButton(record.SnippetCreatedAt is null ? languageStore.Text(L10nKey.ClipboardNewKey) : languageStore.Text(L10nKey.ClipboardCreatedKey), () => createSnippet(record), ButtonTone.Primary, new Thickness(0), record.SnippetCreatedAt is null));
        Grid.SetColumn(buttons, 1);
        grid.Children.Add(buttons);

        card.Child = grid;
        return card;
    }

    private string LastCopiedDescription(ClipboardRecord record)
    {
        var local = record.LastCopiedAt.ToLocalTime();
        var time = local.ToString("t", languageStore.Language.Culture());
        if (local.Date == DateTimeOffset.Now.Date)
        {
            return languageStore.Format(L10nKey.ClipboardTodayFormat, time);
        }

        if (local.Date == DateTimeOffset.Now.Date.AddDays(-1))
        {
            return languageStore.Format(L10nKey.ClipboardYesterdayFormat, time);
        }

        return local.ToString("g", languageStore.Language.Culture());
    }

    private static string RecordTitle(ClipboardRecord record)
    {
        var trimmed = record.Content.Trim();
        var firstLine = trimmed.Split('\n', 2)[0].Trim();
        return firstLine.Length > 48 ? firstLine[..48] + "..." : firstLine;
    }

    private static string BodyPreview(string content)
    {
        var flattened = content.Replace("\r", " ", StringComparison.Ordinal).Replace("\n", " ", StringComparison.Ordinal).Trim();
        return flattened.Length > 180 ? flattened[..180] + "..." : flattened;
    }

    private void UpdateMonitoringSetting(bool enabled)
    {
        if (isRefreshing)
        {
            return;
        }

        historyStore.UpdateSettings(new ClipboardSettings
        {
            IsMonitoringEnabled = enabled,
            SuggestionThreshold = historyStore.Settings.SuggestionThreshold
        });
    }

    private void UpdateThresholdSetting()
    {
        if (isRefreshing)
        {
            return;
        }

        historyStore.UpdateSettings(new ClipboardSettings
        {
            IsMonitoringEnabled = historyStore.Settings.IsMonitoringEnabled,
            SuggestionThreshold = (int)Math.Round(thresholdSlider.Value)
        });
    }

    private void ClearRecords()
    {
        if (historyStore.Records.Count == 0)
        {
            return;
        }

        historyStore.ClearHistory();
    }

    private void OnStoreChanged(object? sender, EventArgs eventArgs)
    {
        Dispatcher.Invoke(Refresh);
    }

    private void OnLanguageChanged(object? sender, EventArgs eventArgs)
    {
        Dispatcher.Invoke(() =>
        {
            CreateReusableControls();
            Content = BuildLayout();
            Refresh();
        });
    }

    private static Button MakeButton(string text, Action action, ButtonTone tone, Thickness margin, bool isEnabled = true)
    {
        var button = new Button
        {
            Content = text,
            MinWidth = 86,
            Height = 32,
            Margin = margin,
            Padding = new Thickness(12, 0, 12, 0),
            IsEnabled = isEnabled,
            Style = UiTheme.ButtonStyle(tone)
        };
        button.Click += (_, _) => action();
        return button;
    }
}