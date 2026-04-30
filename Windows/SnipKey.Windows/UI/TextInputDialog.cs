using System.Windows;
using System.Windows.Controls;
using WpfTextBox = System.Windows.Controls.TextBox;
using Button = System.Windows.Controls.Button;
using HorizontalAlignment = System.Windows.HorizontalAlignment;
using Orientation = System.Windows.Controls.Orientation;

namespace SnipKey.WinApp.UI;

internal sealed class TextInputDialog : Window
{
    private readonly WpfTextBox inputBox = new();

    private TextInputDialog(string title, string message, string initialValue, AppLanguageStore languageStore)
    {
        Title = title;
        Width = 380;
        Height = 180;
        MinWidth = 340;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = UiTheme.WindowBackgroundBrush;
        FontFamily = new System.Windows.Media.FontFamily("Segoe UI Variable, Segoe UI");
        UseLayoutRounding = true;
        SnapsToDevicePixels = true;
        AppIcon.ApplyTo(this);

        var root = new Grid
        {
            Margin = new Thickness(18)
        };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        root.Children.Add(new TextBlock
        {
            Text = message,
            FontSize = 13,
            Foreground = UiTheme.TextSecondaryBrush,
            TextWrapping = TextWrapping.Wrap
        });

        inputBox.Text = initialValue;
        inputBox.Height = 36;
        inputBox.Margin = new Thickness(0, 12, 0, 0);
        inputBox.Style = UiTheme.TextBoxStyle();
        Grid.SetRow(inputBox, 1);
        root.Children.Add(inputBox);

        var buttons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Margin = new Thickness(0, 16, 0, 0)
        };
        buttons.Children.Add(MakeButton(languageStore.Text(L10nKey.CommonCancel), () =>
        {
            DialogResult = false;
            Close();
        }, ButtonTone.Secondary, new Thickness(0, 0, 8, 0)));
        buttons.Children.Add(MakeButton(languageStore.Text(L10nKey.CommonSave), () =>
        {
            DialogResult = true;
            Close();
        }, ButtonTone.Primary, new Thickness(0)));
        Grid.SetRow(buttons, 3);
        root.Children.Add(buttons);

        Content = root;
        Loaded += (_, _) =>
        {
            inputBox.Focus();
            inputBox.SelectAll();
        };
    }

    public string Value => inputBox.Text.Trim();

    public static string? Show(Window owner, string title, string message, string initialValue, AppLanguageStore languageStore)
    {
        var dialog = new TextInputDialog(title, message, initialValue, languageStore)
        {
            Owner = owner
        };
        return dialog.ShowDialog() == true ? dialog.Value : null;
    }

    private static Button MakeButton(string text, Action action, ButtonTone tone, Thickness margin)
    {
        var button = new Button
        {
            Content = text,
            MinWidth = 76,
            Height = 32,
            Margin = margin,
            Padding = new Thickness(12, 0, 12, 0),
            Style = UiTheme.ButtonStyle(tone)
        };
        button.Click += (_, _) => action();
        return button;
    }
}