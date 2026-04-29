using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using SnipKey.WinApp.Core;
using SnipKey.WinApp.Platform;
using WpfBinding = System.Windows.Data.Binding;
using WpfBrushes = System.Windows.Media.Brushes;
using WpfFontFamily = System.Windows.Media.FontFamily;
using WpfHorizontalAlignment = System.Windows.HorizontalAlignment;
using WpfListBox = System.Windows.Controls.ListBox;
using WpfMouseEventArgs = System.Windows.Input.MouseEventArgs;
using WpfOrientation = System.Windows.Controls.Orientation;
using WpfPoint = System.Windows.Point;

namespace SnipKey.WinApp.UI;

internal sealed class CompletionWindow : Window
{
    private readonly WpfListBox listBox = new();
    private readonly TextBlock countText = new();

    public CompletionWindow()
    {
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        ShowActivated = false;
        Topmost = true;
        AllowsTransparency = true;
        Background = WpfBrushes.Transparent;
        SizeToContent = SizeToContent.WidthAndHeight;
        UseLayoutRounding = true;
        SnapsToDevicePixels = true;

        listBox.Width = 380;
        listBox.MaxHeight = 288;
        listBox.BorderThickness = new Thickness(0);
        listBox.Background = WpfBrushes.Transparent;
        listBox.ItemTemplate = BuildItemTemplate();
        listBox.ItemContainerStyle = UiTheme.CompletionListItemStyle();
        listBox.SetValue(ScrollViewer.HorizontalScrollBarVisibilityProperty, ScrollBarVisibility.Disabled);
        listBox.PreviewMouseMove += SelectItemUnderPointer;
        listBox.PreviewMouseLeftButtonUp += ConfirmItemUnderPointer;

        Content = new Border
        {
            CornerRadius = new CornerRadius(18),
            Padding = new Thickness(12),
            Background = UiTheme.PanelBrush(),
            BorderBrush = UiTheme.Brush(255, 255, 255, 0.72),
            BorderThickness = new Thickness(1),
            Effect = UiTheme.Shadow(26, 14, 0.16),
            Child = new DockPanel
            {
                LastChildFill = true,
                Children =
                {
                    BuildHeader(),
                    listBox
                }
            }
        };
    }

    public event Action<Snippet>? SnippetConfirmed;

    public Snippet? SelectedSnippet => listBox.SelectedItem is CompletionItem item ? item.Snippet : null;

    public void ShowSnippets(IReadOnlyList<Snippet> snippets, WpfPoint screenPoint)
    {
        if (snippets.Count == 0)
        {
            HidePopup();
            return;
        }

        listBox.ItemsSource = snippets.Select(snippet => new CompletionItem(snippet)).ToList();
        listBox.SelectedIndex = 0;
        countText.Text = snippets.Count.ToString(System.Globalization.CultureInfo.CurrentCulture);

        Left = Math.Max(0, screenPoint.X);
        Top = Math.Max(0, screenPoint.Y);

        if (!IsVisible)
        {
            Show();
        }
    }

    public void HidePopup()
    {
        Hide();
        listBox.ItemsSource = null;
    }

    public void MoveSelectionUp()
    {
        if (listBox.Items.Count == 0)
        {
            return;
        }

        listBox.SelectedIndex = listBox.SelectedIndex <= 0 ? listBox.Items.Count - 1 : listBox.SelectedIndex - 1;
        listBox.ScrollIntoView(listBox.SelectedItem);
    }

    public void MoveSelectionDown()
    {
        if (listBox.Items.Count == 0)
        {
            return;
        }

        listBox.SelectedIndex = (listBox.SelectedIndex + 1) % listBox.Items.Count;
        listBox.ScrollIntoView(listBox.SelectedItem);
    }

    protected override void OnSourceInitialized(EventArgs eventArgs)
    {
        base.OnSourceInitialized(eventArgs);

        var handle = new WindowInteropHelper(this).Handle;
        var extendedStyle = NativeMethods.GetWindowLong(handle, NativeMethods.GwlExStyle);
        NativeMethods.SetWindowLong(
            handle,
            NativeMethods.GwlExStyle,
            extendedStyle | NativeMethods.WsExNoActivate | NativeMethods.WsExToolWindow);
    }

    private UIElement BuildHeader()
    {
        var header = new Border
        {
            CornerRadius = new CornerRadius(14),
            Padding = new Thickness(12, 10, 12, 10),
            Margin = new Thickness(0, 0, 0, 10),
            Background = UiTheme.Brush(0, 122, 255, 0.08),
            BorderBrush = UiTheme.Brush(0, 122, 255, 0.13),
            BorderThickness = new Thickness(1)
        };

        var layout = new Grid();
        layout.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        layout.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var titleStack = new StackPanel
        {
            Orientation = WpfOrientation.Vertical
        };
        titleStack.Children.Add(new TextBlock
        {
            Text = "SnipKey",
            FontSize = 14,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextPrimaryBrush
        });
        titleStack.Children.Add(new TextBlock
        {
            Text = "Matches",
            FontSize = 12,
            Margin = new Thickness(0, 2, 0, 0),
            Foreground = UiTheme.TextSecondaryBrush
        });
        layout.Children.Add(titleStack);

        countText.FontSize = 13;
        countText.FontWeight = FontWeights.SemiBold;
        countText.Foreground = UiTheme.AccentTextBrush;
        countText.VerticalAlignment = VerticalAlignment.Center;
        countText.Padding = new Thickness(10, 5, 10, 5);
        countText.Background = UiTheme.Brush(0, 122, 255, 0.12);
        Grid.SetColumn(countText, 1);
        layout.Children.Add(countText);

        header.Child = layout;
        DockPanel.SetDock(header, Dock.Top);
        return header;
    }

    private static DataTemplate BuildItemTemplate()
    {
        var stack = new FrameworkElementFactory(typeof(StackPanel));
        stack.SetValue(StackPanel.MarginProperty, new Thickness(0));

        var triggerPill = new FrameworkElementFactory(typeof(Border));
        triggerPill.SetValue(Border.CornerRadiusProperty, new CornerRadius(12));
        triggerPill.SetValue(Border.BackgroundProperty, UiTheme.Brush(0, 122, 255, 0.11));
        triggerPill.SetValue(Border.PaddingProperty, new Thickness(9, 5, 9, 5));
        triggerPill.SetValue(FrameworkElement.HorizontalAlignmentProperty, WpfHorizontalAlignment.Left);

        var trigger = new FrameworkElementFactory(typeof(TextBlock));
        trigger.SetBinding(TextBlock.TextProperty, new WpfBinding(nameof(CompletionItem.TriggerText)));
        trigger.SetValue(TextBlock.FontFamilyProperty, new WpfFontFamily("Consolas"));
        trigger.SetValue(TextBlock.FontWeightProperty, FontWeights.SemiBold);
        trigger.SetValue(TextBlock.ForegroundProperty, UiTheme.AccentTextBrush);
        triggerPill.AppendChild(trigger);
        stack.AppendChild(triggerPill);

        var preview = new FrameworkElementFactory(typeof(TextBlock));
        preview.SetBinding(TextBlock.TextProperty, new WpfBinding(nameof(CompletionItem.PreviewText)));
        preview.SetValue(TextBlock.TextWrappingProperty, TextWrapping.Wrap);
        preview.SetValue(TextBlock.TextTrimmingProperty, TextTrimming.CharacterEllipsis);
        preview.SetValue(TextBlock.MaxHeightProperty, 42.0);
        preview.SetValue(TextBlock.FontSizeProperty, 13.0);
        preview.SetValue(TextBlock.MarginProperty, new Thickness(0, 9, 0, 0));
        preview.SetValue(TextBlock.ForegroundProperty, UiTheme.TextSecondaryBrush);
        stack.AppendChild(preview);

        return new DataTemplate
        {
            VisualTree = stack
        };
    }

    private void SelectItemUnderPointer(object sender, WpfMouseEventArgs eventArgs)
    {
        if (ItemUnderPointer(eventArgs.OriginalSource) is { } item)
        {
            listBox.SelectedItem = item.DataContext;
        }
    }

    private void ConfirmItemUnderPointer(object sender, MouseButtonEventArgs eventArgs)
    {
        if (ItemUnderPointer(eventArgs.OriginalSource)?.DataContext is CompletionItem item)
        {
            listBox.SelectedItem = item;
            SnippetConfirmed?.Invoke(item.Snippet);
            eventArgs.Handled = true;
        }
    }

    private ListBoxItem? ItemUnderPointer(object originalSource)
    {
        return originalSource is DependencyObject source
            ? ItemsControl.ContainerFromElement(listBox, source) as ListBoxItem
            : null;
    }

    private void ConfirmSelected()
    {
        if (SelectedSnippet is { } snippet)
        {
            SnippetConfirmed?.Invoke(snippet);
        }
    }
}

internal sealed class CompletionItem
{
    public CompletionItem(Snippet snippet)
    {
        Snippet = snippet;
    }

    public Snippet Snippet { get; }

    public string TriggerText => "#" + Snippet.Trigger;

    public string PreviewText
    {
        get
        {
            var flattened = Snippet.Replacement
                .Replace("\r", " ", StringComparison.Ordinal)
                .Replace("\n", " ", StringComparison.Ordinal)
                .Replace("\t", " ", StringComparison.Ordinal)
                .Trim();
            return flattened.Length > 96 ? flattened[..96] + "..." : flattened;
        }
    }
}
