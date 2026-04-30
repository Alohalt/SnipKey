using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Effects;
using WpfButton = System.Windows.Controls.Button;
using WpfBrushes = System.Windows.Media.Brushes;
using WpfColor = System.Windows.Media.Color;
using WpfComboBox = System.Windows.Controls.ComboBox;
using WpfComboBoxItem = System.Windows.Controls.ComboBoxItem;
using WpfControl = System.Windows.Controls.Control;
using WpfCursors = System.Windows.Input.Cursors;
using WpfHorizontalAlignment = System.Windows.HorizontalAlignment;
using WpfPath = System.Windows.Shapes.Path;
using WpfPlacementMode = System.Windows.Controls.Primitives.PlacementMode;
using WpfPoint = System.Windows.Point;
using WpfPopup = System.Windows.Controls.Primitives.Popup;
using WpfTextBox = System.Windows.Controls.TextBox;
using WpfToggleButton = System.Windows.Controls.Primitives.ToggleButton;
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

    public static Style ComboBoxStyle()
    {
        var style = new Style(typeof(WpfComboBox));
        style.Setters.Add(new Setter(WpfControl.BackgroundProperty, SurfaceBrush));
        style.Setters.Add(new Setter(WpfControl.BorderBrushProperty, HairlineBrush));
        style.Setters.Add(new Setter(WpfControl.BorderThicknessProperty, new Thickness(1)));
        style.Setters.Add(new Setter(WpfControl.ForegroundProperty, TextPrimaryBrush));
        style.Setters.Add(new Setter(WpfControl.FontSizeProperty, 13.0));
        style.Setters.Add(new Setter(WpfControl.PaddingProperty, new Thickness(12, 0, 10, 0)));
        style.Setters.Add(new Setter(WpfControl.FocusVisualStyleProperty, null));
        style.Setters.Add(new Setter(WpfComboBox.MaxDropDownHeightProperty, 260.0));
        style.Setters.Add(new Setter(WpfComboBox.ItemContainerStyleProperty, ComboBoxItemStyle()));

        var grid = new FrameworkElementFactory(typeof(Grid));
        grid.SetValue(FrameworkElement.SnapsToDevicePixelsProperty, true);

        var chrome = new FrameworkElementFactory(typeof(Border));
        chrome.Name = "Chrome";
        chrome.SetValue(Border.CornerRadiusProperty, new CornerRadius(9));
        chrome.SetBinding(Border.BackgroundProperty, new System.Windows.Data.Binding("Background") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        chrome.SetBinding(Border.BorderBrushProperty, new System.Windows.Data.Binding("BorderBrush") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        chrome.SetBinding(Border.BorderThicknessProperty, new System.Windows.Data.Binding("BorderThickness") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        grid.AppendChild(chrome);

        var toggleChrome = new FrameworkElementFactory(typeof(Border));
        toggleChrome.SetValue(Border.BackgroundProperty, WpfBrushes.Transparent);
        var toggleTemplate = new ControlTemplate(typeof(WpfToggleButton))
        {
            VisualTree = toggleChrome
        };
        var toggleButton = new FrameworkElementFactory(typeof(WpfToggleButton));
        toggleButton.Name = "ToggleButton";
        toggleButton.SetValue(WpfControl.FocusVisualStyleProperty, null);
        toggleButton.SetValue(WpfControl.FocusableProperty, false);
        toggleButton.SetValue(WpfControl.BackgroundProperty, WpfBrushes.Transparent);
        toggleButton.SetValue(WpfControl.BorderThicknessProperty, new Thickness(0));
        toggleButton.SetValue(WpfControl.TemplateProperty, toggleTemplate);
        toggleButton.SetBinding(WpfToggleButton.IsCheckedProperty, new System.Windows.Data.Binding("IsDropDownOpen")
        {
            RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent,
            Mode = System.Windows.Data.BindingMode.TwoWay
        });
        grid.AppendChild(toggleButton);

        var contentSite = new FrameworkElementFactory(typeof(ContentPresenter));
        contentSite.Name = "ContentSite";
        contentSite.SetValue(UIElement.IsHitTestVisibleProperty, false);
        contentSite.SetValue(ContentPresenter.VerticalAlignmentProperty, WpfVerticalAlignment.Center);
        contentSite.SetValue(ContentPresenter.HorizontalAlignmentProperty, WpfHorizontalAlignment.Left);
        contentSite.SetBinding(ContentPresenter.ContentProperty, new System.Windows.Data.Binding("SelectionBoxItem") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        contentSite.SetBinding(ContentPresenter.ContentTemplateProperty, new System.Windows.Data.Binding("SelectionBoxItemTemplate") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        contentSite.SetBinding(ContentPresenter.ContentStringFormatProperty, new System.Windows.Data.Binding("SelectionBoxItemStringFormat") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        contentSite.SetBinding(FrameworkElement.MarginProperty, new System.Windows.Data.Binding("Padding") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        grid.AppendChild(contentSite);

        var arrow = new FrameworkElementFactory(typeof(WpfPath));
        arrow.SetValue(UIElement.IsHitTestVisibleProperty, false);
        arrow.SetValue(WpfPath.DataProperty, Geometry.Parse("M 0 0 L 4 4 L 8 0"));
        arrow.SetValue(WpfPath.StrokeProperty, TextSecondaryBrush);
        arrow.SetValue(WpfPath.StrokeThicknessProperty, 1.8);
        arrow.SetValue(WpfPath.StrokeStartLineCapProperty, PenLineCap.Round);
        arrow.SetValue(WpfPath.StrokeEndLineCapProperty, PenLineCap.Round);
        arrow.SetValue(FrameworkElement.WidthProperty, 8.0);
        arrow.SetValue(FrameworkElement.HeightProperty, 5.0);
        arrow.SetValue(FrameworkElement.HorizontalAlignmentProperty, WpfHorizontalAlignment.Right);
        arrow.SetValue(FrameworkElement.VerticalAlignmentProperty, WpfVerticalAlignment.Center);
        arrow.SetValue(FrameworkElement.MarginProperty, new Thickness(0, 0, 12, 0));
        grid.AppendChild(arrow);

        var popup = new FrameworkElementFactory(typeof(WpfPopup));
        popup.Name = "PART_Popup";
        popup.SetValue(WpfPopup.AllowsTransparencyProperty, true);
        popup.SetValue(WpfPopup.FocusableProperty, false);
        popup.SetValue(WpfPopup.PlacementProperty, WpfPlacementMode.Bottom);
        popup.SetBinding(WpfPopup.IsOpenProperty, new System.Windows.Data.Binding("IsDropDownOpen") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        popup.SetBinding(WpfPopup.PlacementTargetProperty, new System.Windows.Data.Binding { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });

        var dropDownBorder = new FrameworkElementFactory(typeof(Border));
        dropDownBorder.Name = "DropDownBorder";
        dropDownBorder.SetValue(Border.CornerRadiusProperty, new CornerRadius(9));
        dropDownBorder.SetValue(Border.BackgroundProperty, Brush(255, 255, 255));
        dropDownBorder.SetValue(Border.BorderBrushProperty, Brush(190, 197, 209));
        dropDownBorder.SetValue(Border.BorderThicknessProperty, new Thickness(1));
        dropDownBorder.SetValue(Border.PaddingProperty, new Thickness(4));
        dropDownBorder.SetValue(FrameworkElement.MarginProperty, new Thickness(0, 4, 0, 0));
        dropDownBorder.SetBinding(FrameworkElement.MinWidthProperty, new System.Windows.Data.Binding("ActualWidth") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        dropDownBorder.SetValue(UIElement.EffectProperty, Shadow(16, 4, 0.12));

        var scrollViewer = new FrameworkElementFactory(typeof(ScrollViewer));
        scrollViewer.SetValue(ScrollViewer.CanContentScrollProperty, true);
        scrollViewer.SetValue(ScrollViewer.VerticalScrollBarVisibilityProperty, ScrollBarVisibility.Auto);
        scrollViewer.SetValue(ScrollViewer.HorizontalScrollBarVisibilityProperty, ScrollBarVisibility.Disabled);
        scrollViewer.SetValue(FrameworkElement.MaxHeightProperty, 260.0);
        scrollViewer.AppendChild(new FrameworkElementFactory(typeof(ItemsPresenter)));
        dropDownBorder.AppendChild(scrollViewer);
        popup.AppendChild(dropDownBorder);
        grid.AppendChild(popup);

        var template = new ControlTemplate(typeof(WpfComboBox))
        {
            VisualTree = grid
        };

        var hoverTrigger = new Trigger { Property = UIElement.IsMouseOverProperty, Value = true };
        hoverTrigger.Setters.Add(new Setter(WpfControl.BorderBrushProperty, Brush(190, 197, 209)));
        template.Triggers.Add(hoverTrigger);

        var focusTrigger = new Trigger { Property = WpfComboBox.IsKeyboardFocusWithinProperty, Value = true };
        focusTrigger.Setters.Add(new Setter(WpfControl.BorderBrushProperty, AccentBrush));
        focusTrigger.Setters.Add(new Setter(WpfControl.BackgroundProperty, Brush(255, 255, 255)));
        template.Triggers.Add(focusTrigger);

        var disabledTrigger = new Trigger { Property = UIElement.IsEnabledProperty, Value = false };
        disabledTrigger.Setters.Add(new Setter(UIElement.OpacityProperty, 0.55));
        template.Triggers.Add(disabledTrigger);

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

    private static Style ComboBoxItemStyle()
    {
        var style = new Style(typeof(WpfComboBoxItem));
        style.Setters.Add(new Setter(WpfControl.FocusVisualStyleProperty, null));
        style.Setters.Add(new Setter(WpfControl.HorizontalContentAlignmentProperty, WpfHorizontalAlignment.Stretch));
        style.Setters.Add(new Setter(WpfControl.PaddingProperty, new Thickness(10, 7, 10, 7)));

        var chrome = new FrameworkElementFactory(typeof(Border));
        chrome.Name = "Chrome";
        chrome.SetValue(Border.CornerRadiusProperty, new CornerRadius(7));
        chrome.SetValue(Border.BackgroundProperty, WpfBrushes.Transparent);

        var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
        presenter.SetValue(ContentPresenter.HorizontalAlignmentProperty, WpfHorizontalAlignment.Stretch);
        presenter.SetValue(ContentPresenter.VerticalAlignmentProperty, WpfVerticalAlignment.Center);
        presenter.SetBinding(FrameworkElement.MarginProperty, new System.Windows.Data.Binding("Padding") { RelativeSource = System.Windows.Data.RelativeSource.TemplatedParent });
        chrome.AppendChild(presenter);

        var template = new ControlTemplate(typeof(WpfComboBoxItem))
        {
            VisualTree = chrome
        };

        var hoverTrigger = new Trigger { Property = UIElement.IsMouseOverProperty, Value = true };
        hoverTrigger.Setters.Add(new Setter(Border.BackgroundProperty, HoverBrush, "Chrome"));
        template.Triggers.Add(hoverTrigger);

        var selectedTrigger = new Trigger { Property = WpfComboBoxItem.IsSelectedProperty, Value = true };
        selectedTrigger.Setters.Add(new Setter(Border.BackgroundProperty, SelectedBrush, "Chrome"));
        selectedTrigger.Setters.Add(new Setter(WpfControl.ForegroundProperty, AccentTextBrush));
        template.Triggers.Add(selectedTrigger);

        style.Setters.Add(new Setter(WpfControl.TemplateProperty, template));
        return style;
    }
}
