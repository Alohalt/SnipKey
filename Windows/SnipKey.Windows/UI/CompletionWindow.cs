using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using SnipKey.WinApp.Core;
using SnipKey.WinApp.Platform;

namespace SnipKey.WinApp.UI;

internal sealed class CompletionWindow : Window
{
    private readonly ListBox listBox = new();

    public CompletionWindow()
    {
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        ShowActivated = false;
        Topmost = true;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        SizeToContent = SizeToContent.WidthAndHeight;

        listBox.Width = 380;
        listBox.MaxHeight = 320;
        listBox.BorderThickness = new Thickness(0);
        listBox.Background = Brushes.Transparent;
        listBox.ItemTemplate = BuildItemTemplate();
        listBox.ItemContainerStyle = BuildItemStyle();
        listBox.PreviewMouseMove += SelectItemUnderPointer;
        listBox.PreviewMouseLeftButtonUp += (_, _) => ConfirmSelected();

        Content = new Border
        {
            CornerRadius = new CornerRadius(8),
            Padding = new Thickness(10),
            Background = new SolidColorBrush(Color.FromRgb(250, 250, 250)),
            BorderBrush = new SolidColorBrush(Color.FromRgb(214, 219, 226)),
            BorderThickness = new Thickness(1),
            Effect = new System.Windows.Media.Effects.DropShadowEffect
            {
                BlurRadius = 18,
                ShadowDepth = 6,
                Opacity = 0.18
            },
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

    public void ShowSnippets(IReadOnlyList<Snippet> snippets, Point screenPoint)
    {
        if (snippets.Count == 0)
        {
            HidePopup();
            return;
        }

        listBox.ItemsSource = snippets.Select(snippet => new CompletionItem(snippet)).ToList();
        listBox.SelectedIndex = 0;

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

    private static TextBlock BuildHeader()
    {
        var header = new TextBlock
        {
            Text = "SnipKey",
            FontWeight = FontWeights.SemiBold,
            Foreground = new SolidColorBrush(Color.FromRgb(38, 44, 52)),
            Margin = new Thickness(6, 2, 6, 8)
        };
        DockPanel.SetDock(header, Dock.Top);
        return header;
    }

    private static DataTemplate BuildItemTemplate()
    {
        var stack = new FrameworkElementFactory(typeof(StackPanel));
        stack.SetValue(StackPanel.MarginProperty, new Thickness(2));

        var trigger = new FrameworkElementFactory(typeof(TextBlock));
        trigger.SetBinding(TextBlock.TextProperty, new Binding(nameof(CompletionItem.TriggerText)));
        trigger.SetValue(TextBlock.FontFamilyProperty, new FontFamily("Consolas"));
        trigger.SetValue(TextBlock.FontWeightProperty, FontWeights.SemiBold);
        trigger.SetValue(TextBlock.ForegroundProperty, new SolidColorBrush(Color.FromRgb(25, 94, 170)));
        stack.AppendChild(trigger);

        var preview = new FrameworkElementFactory(typeof(TextBlock));
        preview.SetBinding(TextBlock.TextProperty, new Binding(nameof(CompletionItem.PreviewText)));
        preview.SetValue(TextBlock.TextWrappingProperty, TextWrapping.Wrap);
        preview.SetValue(TextBlock.TextTrimmingProperty, TextTrimming.CharacterEllipsis);
        preview.SetValue(TextBlock.MaxHeightProperty, 42.0);
        preview.SetValue(TextBlock.MarginProperty, new Thickness(0, 4, 0, 0));
        preview.SetValue(TextBlock.ForegroundProperty, new SolidColorBrush(Color.FromRgb(91, 99, 112)));
        stack.AppendChild(preview);

        return new DataTemplate
        {
            VisualTree = stack
        };
    }

    private static Style BuildItemStyle()
    {
        var style = new Style(typeof(ListBoxItem));
        style.Setters.Add(new Setter(Control.PaddingProperty, new Thickness(10, 8, 10, 8)));
        style.Setters.Add(new Setter(Control.MarginProperty, new Thickness(0, 2, 0, 2)));
        style.Setters.Add(new Setter(Control.HorizontalContentAlignmentProperty, HorizontalAlignment.Stretch));
        return style;
    }

    private void SelectItemUnderPointer(object sender, MouseEventArgs eventArgs)
    {
        if (eventArgs.OriginalSource is not DependencyObject source)
        {
            return;
        }

        if (ItemsControl.ContainerFromElement(listBox, source) is ListBoxItem item)
        {
            listBox.SelectedItem = item.DataContext;
        }
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
