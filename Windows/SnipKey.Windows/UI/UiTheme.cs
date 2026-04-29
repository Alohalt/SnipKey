using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Effects;
using WpfButton = System.Windows.Controls.Button;
using WpfBrushes = System.Windows.Media.Brushes;
using WpfColor = System.Windows.Media.Color;
using WpfControl = System.Windows.Controls.Control;
using WpfCursors = System.Windows.Input.Cursors;
using WpfHorizontalAlignment = System.Windows.HorizontalAlignment;
using WpfPoint = System.Windows.Point;
using WpfTextBox = System.Windows.Controls.TextBox;
using WpfVerticalAlignment = System.Windows.VerticalAlignment;

namespace SnipKey.WinApp.UI;

internal enum ButtonTone
{
    Primary,
    Secondary,
    Danger
}

internal static class UiTheme
{
    private static readonly CornerRadius ButtonRadius = new(9);

    public static SolidColorBrush AccentBrush => Brush(0, 122, 255);

    public static SolidColorBrush AccentTextBrush => Brush(0, 96, 210);

    public static SolidColorBrush TextPrimaryBrush => Brush(28, 32, 38);

    public static SolidColorBrush TextSecondaryBrush => Brush(92, 99, 112);

    public static SolidColorBrush WindowBackgroundBrush => Brush(245, 245, 247);

    public static SolidColorBrush SurfaceBrush => Brush(255, 255, 255, 0.94);

    public static SolidColorBrush SidebarBrush => Brush(250, 250, 252, 0.96);

    public static SolidColorBrush HairlineBrush => Brush(210, 214, 222, 0.82);

    public static SolidColorBrush HoverBrush => Brush(237, 244, 255, 0.88);

    public static SolidColorBrush SelectedBrush => Brush(225, 239, 255, 0.96);

    public static SolidColorBrush DangerBrush => Brush(211, 47, 47);

    public static SolidColorBrush Brush(byte red, byte green, byte blue, double opacity = 1)
    {
        var alpha = (byte)Math.Round(Math.Clamp(opacity, 0, 1) * 255);
        var brush = new SolidColorBrush(WpfColor.FromArgb(alpha, red, green, blue));
        brush.Freeze();
        return brush;
    }

    public static LinearGradientBrush PanelBrush()
    {
        var brush = new LinearGradientBrush
        {
            StartPoint = new WpfPoint(0, 0),
            EndPoint = new WpfPoint(1, 1)
        };
        brush.GradientStops.Add(new GradientStop(WpfColor.FromArgb(248, 255, 255, 255), 0));
        brush.GradientStops.Add(new GradientStop(WpfColor.FromArgb(238, 243, 247, 252), 1));
        brush.Freeze();
        return brush;
    }

    public static DropShadowEffect Shadow(double blurRadius, double depth, double opacity)
    {
        return new DropShadowEffect
        {
            BlurRadius = blurRadius,
            Direction = 270,
            ShadowDepth = depth,
            Opacity = opacity,
            Color = Colors.Black
        };
    }

    public static Style ButtonStyle(ButtonTone tone)
    {
        var style = new Style(typeof(WpfButton));
        style.Setters.Add(new Setter(WpfControl.ForegroundProperty, ButtonForeground(tone)));
        style.Setters.Add(new Setter(WpfControl.BackgroundProperty, ButtonBackground(tone)));
        style.Setters.Add(new Setter(WpfControl.BorderBrushProperty, ButtonBorder(tone)));
        style.Setters.Add(new Setter(WpfControl.BorderThicknessProperty, new Thickness(1)));
        style.Setters.Add(new Setter(WpfControl.FontSizeProperty, 13.0));
        style.Setters.Add(new Setter(WpfControl.FontWeightProperty, FontWeights.SemiBold));
        style.Setters.Add(new Setter(WpfControl.CursorProperty, WpfCursors.Hand));
        style.Setters.Add(new Setter(WpfControl.FocusVisualStyleProperty, null));

        var chrome = new FrameworkElementFactory(typeof(Border));
        chrome.Name = "Chrome";
        chrome.SetValue(Border.CornerRadiusProperty, ButtonRadius);
        chrome.SetBinding(Border.BackgroundProperty, new System.Windows.Data.Binding("Background") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        chrome.SetBinding(Border.BorderBrushProperty, new System.Windows.Data.Binding("BorderBrush") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        chrome.SetBinding(Border.BorderThicknessProperty, new System.Windows.Data.Binding("BorderThickness") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });

        var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
        presenter.SetValue(ContentPresenter.HorizontalAlignmentProperty, WpfHorizontalAlignment.Center);
        presenter.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
        presenter.SetValue(ContentPresenter.RecognizesAccessKeyProperty, true);
        presenter.SetBinding(FrameworkElement.MarginProperty, new System.Windows.Data.Binding("Padding") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        chrome.AppendChild(presenter);

        var template = new ControlTemplate(typeof(WpfButton))
        {
            VisualTree = chrome
        };

        var hoverTrigger = new Trigger { Property = UIElement.IsMouseOverProperty, Value = true };
        hoverTrigger.Setters.Add(new Setter(WpfControl.BackgroundProperty, ButtonHoverBackground(tone)));
        hoverTrigger.Setters.Add(new Setter(WpfControl.BorderBrushProperty, ButtonHoverBorder(tone)));
        template.Triggers.Add(hoverTrigger);

        var pressedTrigger = new Trigger { Property = WpfButton.IsPressedProperty, Value = true };
        pressedTrigger.Setters.Add(new Setter(WpfControl.BackgroundProperty, ButtonPressedBackground(tone)));
        template.Triggers.Add(pressedTrigger);

        var disabledTrigger = new Trigger { Property = UIElement.IsEnabledProperty, Value = false };
        disabledTrigger.Setters.Add(new Setter(UIElement.OpacityProperty, 0.5));
        template.Triggers.Add(disabledTrigger);

        style.Setters.Add(new Setter(WpfControl.TemplateProperty, template));
        return style;
    }

    public static Style TextBoxStyle(double cornerRadius = 10, Thickness? padding = null)
    {
        var style = new Style(typeof(WpfTextBox));
        style.Setters.Add(new Setter(WpfControl.BackgroundProperty, SurfaceBrush));
        style.Setters.Add(new Setter(WpfControl.BorderBrushProperty, HairlineBrush));
        style.Setters.Add(new Setter(WpfControl.BorderThicknessProperty, new Thickness(1)));
        style.Setters.Add(new Setter(WpfControl.ForegroundProperty, TextPrimaryBrush));
        style.Setters.Add(new Setter(WpfTextBox.CaretBrushProperty, AccentBrush));
        style.Setters.Add(new Setter(WpfControl.FontSizeProperty, 13.0));
        style.Setters.Add(new Setter(WpfControl.PaddingProperty, padding ?? new Thickness(12, 5, 12, 5)));
        style.Setters.Add(new Setter(WpfControl.FocusVisualStyleProperty, null));

        var chrome = new FrameworkElementFactory(typeof(Border));
        chrome.Name = "Chrome";
        chrome.SetValue(Border.CornerRadiusProperty, new CornerRadius(cornerRadius));
        chrome.SetBinding(Border.BackgroundProperty, new System.Windows.Data.Binding("Background") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        chrome.SetBinding(Border.BorderBrushProperty, new System.Windows.Data.Binding("BorderBrush") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        chrome.SetBinding(Border.BorderThicknessProperty, new System.Windows.Data.Binding("BorderThickness") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });

        var contentHost = new FrameworkElementFactory(typeof(ScrollViewer));
        contentHost.Name = "PART_ContentHost";
        contentHost.SetBinding(FrameworkElement.MarginProperty, new System.Windows.Data.Binding("Padding") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        chrome.AppendChild(contentHost);

        var template = new ControlTemplate(typeof(WpfTextBox))
        {
            VisualTree = chrome
        };

        var focusTrigger = new Trigger { Property = UIElement.IsKeyboardFocusedProperty, Value = true };
        focusTrigger.Setters.Add(new Setter(Border.BorderBrushProperty, AccentBrush, "Chrome"));
        focusTrigger.Setters.Add(new Setter(Border.BackgroundProperty, Brush(255, 255, 255), "Chrome"));
        template.Triggers.Add(focusTrigger);

        style.Setters.Add(new Setter(WpfControl.TemplateProperty, template));
        return style;
    }

    public static Style SettingsListItemStyle()
    {
        var style = new Style(typeof(ListBoxItem));
        style.Setters.Add(new Setter(WpfControl.FocusVisualStyleProperty, null));
        style.Setters.Add(new Setter(WpfControl.HorizontalContentAlignmentProperty, WpfHorizontalAlignment.Stretch));
        style.Setters.Add(new Setter(WpfControl.MarginProperty, new Thickness(0, 3, 0, 3)));

        var chrome = new FrameworkElementFactory(typeof(Border));
        chrome.Name = "Chrome";
        chrome.SetValue(Border.CornerRadiusProperty, new CornerRadius(10));
        chrome.SetValue(Border.BackgroundProperty, WpfBrushes.Transparent);
        chrome.SetValue(Border.BorderBrushProperty, WpfBrushes.Transparent);
        chrome.SetValue(Border.BorderThicknessProperty, new Thickness(1));

        var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
        presenter.SetValue(ContentPresenter.HorizontalAlignmentProperty, WpfHorizontalAlignment.Stretch);
        presenter.SetValue(FrameworkElement.MarginProperty, new Thickness(12, 10, 12, 10));
        chrome.AppendChild(presenter);

        var template = new ControlTemplate(typeof(ListBoxItem))
        {
            VisualTree = chrome
        };

        var hoverTrigger = new Trigger { Property = UIElement.IsMouseOverProperty, Value = true };
        hoverTrigger.Setters.Add(new Setter(Border.BackgroundProperty, HoverBrush, "Chrome"));
        hoverTrigger.Setters.Add(new Setter(Border.BorderBrushProperty, Brush(188, 213, 245), "Chrome"));
        template.Triggers.Add(hoverTrigger);

        var selectedTrigger = new Trigger { Property = ListBoxItem.IsSelectedProperty, Value = true };
        selectedTrigger.Setters.Add(new Setter(Border.BackgroundProperty, SelectedBrush, "Chrome"));
        selectedTrigger.Setters.Add(new Setter(Border.BorderBrushProperty, Brush(142, 190, 244), "Chrome"));
        template.Triggers.Add(selectedTrigger);

        style.Setters.Add(new Setter(WpfControl.TemplateProperty, template));
        return style;
    }

    public static Style CompletionListItemStyle()
    {
        var style = new Style(typeof(ListBoxItem));
        style.Setters.Add(new Setter(WpfControl.FocusVisualStyleProperty, null));
        style.Setters.Add(new Setter(WpfControl.HorizontalContentAlignmentProperty, WpfHorizontalAlignment.Stretch));
        style.Setters.Add(new Setter(WpfControl.MarginProperty, new Thickness(0, 4, 0, 4)));

        var grid = new FrameworkElementFactory(typeof(Grid));

        var chrome = new FrameworkElementFactory(typeof(Border));
        chrome.Name = "Chrome";
        chrome.SetValue(Border.CornerRadiusProperty, new CornerRadius(16));
        chrome.SetValue(Border.BackgroundProperty, Brush(255, 255, 255, 0.72));
        chrome.SetValue(Border.BorderBrushProperty, Brush(213, 219, 228, 0.48));
        chrome.SetValue(Border.BorderThicknessProperty, new Thickness(1));

        var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
        presenter.SetValue(ContentPresenter.HorizontalAlignmentProperty, WpfHorizontalAlignment.Stretch);
        presenter.SetValue(FrameworkElement.MarginProperty, new Thickness(14, 12, 14, 12));
        chrome.AppendChild(presenter);
        grid.AppendChild(chrome);

        var accent = new FrameworkElementFactory(typeof(Border));
        accent.Name = "Accent";
        accent.SetValue(FrameworkElement.WidthProperty, 4.0);
        accent.SetValue(Border.CornerRadiusProperty, new CornerRadius(2));
        accent.SetValue(Border.BackgroundProperty, WpfBrushes.Transparent);
        accent.SetValue(FrameworkElement.HorizontalAlignmentProperty, WpfHorizontalAlignment.Left);
        accent.SetValue(FrameworkElement.VerticalAlignmentProperty, WpfVerticalAlignment.Stretch);
        accent.SetValue(FrameworkElement.MarginProperty, new Thickness(6, 12, 0, 12));
        grid.AppendChild(accent);

        var template = new ControlTemplate(typeof(ListBoxItem))
        {
            VisualTree = grid
        };

        var hoverTrigger = new Trigger { Property = UIElement.IsMouseOverProperty, Value = true };
        hoverTrigger.Setters.Add(new Setter(Border.BackgroundProperty, Brush(248, 251, 255, 0.94), "Chrome"));
        hoverTrigger.Setters.Add(new Setter(Border.BorderBrushProperty, Brush(178, 210, 246, 0.72), "Chrome"));
        template.Triggers.Add(hoverTrigger);

        var selectedTrigger = new Trigger { Property = ListBoxItem.IsSelectedProperty, Value = true };
        selectedTrigger.Setters.Add(new Setter(Border.BackgroundProperty, Brush(235, 245, 255, 0.96), "Chrome"));
        selectedTrigger.Setters.Add(new Setter(Border.BorderBrushProperty, Brush(155, 202, 255, 0.84), "Chrome"));
        selectedTrigger.Setters.Add(new Setter(Border.BackgroundProperty, AccentBrush, "Accent"));
        template.Triggers.Add(selectedTrigger);

        style.Setters.Add(new Setter(WpfControl.TemplateProperty, template));
        return style;
    }

    private static SolidColorBrush ButtonForeground(ButtonTone tone)
    {
        return tone switch
        {
            ButtonTone.Primary => Brush(255, 255, 255),
            ButtonTone.Danger => DangerBrush,
            _ => TextPrimaryBrush
        };
    }

    private static SolidColorBrush ButtonBackground(ButtonTone tone)
    {
        return tone switch
        {
            ButtonTone.Primary => AccentBrush,
            ButtonTone.Danger => Brush(255, 255, 255, 0.92),
            _ => Brush(255, 255, 255, 0.92)
        };
    }

    private static SolidColorBrush ButtonBorder(ButtonTone tone)
    {
        return tone switch
        {
            ButtonTone.Primary => Brush(0, 102, 220),
            ButtonTone.Danger => Brush(236, 191, 191),
            _ => HairlineBrush
        };
    }

    private static SolidColorBrush ButtonHoverBackground(ButtonTone tone)
    {
        return tone switch
        {
            ButtonTone.Primary => Brush(0, 112, 235),
            ButtonTone.Danger => Brush(255, 246, 246),
            _ => Brush(247, 249, 252)
        };
    }

    private static SolidColorBrush ButtonHoverBorder(ButtonTone tone)
    {
        return tone switch
        {
            ButtonTone.Primary => Brush(0, 89, 196),
            ButtonTone.Danger => Brush(226, 160, 160),
            _ => Brush(190, 197, 209)
        };
    }

    private static SolidColorBrush ButtonPressedBackground(ButtonTone tone)
    {
        return tone switch
        {
            ButtonTone.Primary => Brush(0, 92, 204),
            ButtonTone.Danger => Brush(255, 236, 236),
            _ => Brush(235, 239, 246)
        };
    }
}
