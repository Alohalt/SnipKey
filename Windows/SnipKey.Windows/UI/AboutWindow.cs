using System.Diagnostics;
using System.Reflection;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Button = System.Windows.Controls.Button;
using FontFamily = System.Windows.Media.FontFamily;
using HorizontalAlignment = System.Windows.HorizontalAlignment;
using Orientation = System.Windows.Controls.Orientation;

namespace SnipKey.WinApp.UI;

internal sealed class AboutWindow : Window
{
    private const string DeveloperDisplayName = "AlohaT";
    private const string RepositoryDisplayName = "Alohalt/SnipKey";
    private const string RepositoryUrl = "https://github.com/Alohalt/SnipKey";
    private const string IssuesUrl = "https://github.com/Alohalt/SnipKey/issues";

    private readonly AppLanguageStore languageStore;

    public AboutWindow(AppLanguageStore languageStore)
    {
        this.languageStore = languageStore;

        Title = languageStore.Text(L10nKey.AboutTitle);
        Width = 540;
        Height = 390;
        MinWidth = 500;
        MinHeight = 340;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = UiTheme.WindowBackgroundBrush;
        FontFamily = new FontFamily("Segoe UI Variable, Segoe UI");
        UseLayoutRounding = true;
        SnapsToDevicePixels = true;
        AppIcon.ApplyTo(this);
        Content = BuildLayout();
    }

    private UIElement BuildLayout()
    {
        var root = new Grid
        {
            Margin = new Thickness(22)
        };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var header = new StackPanel
        {
            Margin = new Thickness(0, 0, 0, 18)
        };
        header.Children.Add(new TextBlock
        {
            Text = languageStore.Text(L10nKey.AboutTitle),
            FontSize = 24,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextPrimaryBrush
        });
        header.Children.Add(new TextBlock
        {
            Text = languageStore.Text(L10nKey.AboutSubtitle),
            FontSize = 12,
            Margin = new Thickness(0, 4, 0, 0),
            Foreground = UiTheme.TextSecondaryBrush
        });
        root.Children.Add(header);

        var card = new Border
        {
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(18),
            Background = UiTheme.SurfaceBrush,
            BorderBrush = UiTheme.HairlineBrush,
            BorderThickness = new Thickness(1),
            Effect = UiTheme.Shadow(10, 2, 0.05)
        };
        var details = new StackPanel();
        details.Children.Add(new TextBlock
        {
            Text = "SnipKey",
            FontSize = 22,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextPrimaryBrush
        });
        details.Children.Add(new TextBlock
        {
            Text = languageStore.Text(L10nKey.AboutSummary),
            FontSize = 13,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 6, 0, 16),
            Foreground = UiTheme.TextSecondaryBrush
        });
        details.Children.Add(MetadataRow(languageStore.Text(L10nKey.AboutDeveloper), DeveloperDisplayName));
        details.Children.Add(MetadataRow("GitHub", RepositoryDisplayName));
        details.Children.Add(MetadataRow(languageStore.Text(L10nKey.AboutRepositoryAddress), RepositoryUrl));
        details.Children.Add(MetadataRow(languageStore.Text(L10nKey.AboutVersion), VersionText()));
        card.Child = details;
        Grid.SetRow(card, 1);
        root.Children.Add(card);

        var buttons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Margin = new Thickness(0, 18, 0, 0)
        };
        buttons.Children.Add(MakeButton(languageStore.Text(L10nKey.AboutRepositoryHome), () => OpenUrl(RepositoryUrl), ButtonTone.Secondary, new Thickness(0, 0, 8, 0)));
        buttons.Children.Add(MakeButton(languageStore.Text(L10nKey.AboutReportIssue), () => OpenUrl(IssuesUrl), ButtonTone.Secondary, new Thickness(0, 0, 8, 0)));
        buttons.Children.Add(MakeButton(languageStore.Text(L10nKey.CommonClose), Close, ButtonTone.Primary, new Thickness(0)));
        Grid.SetRow(buttons, 2);
        root.Children.Add(buttons);

        return root;
    }

    private UIElement MetadataRow(string title, string value)
    {
        var row = new StackPanel
        {
            Margin = new Thickness(0, 0, 0, 10)
        };
        row.Children.Add(new TextBlock
        {
            Text = title,
            FontSize = 11,
            Foreground = UiTheme.TextSecondaryBrush
        });
        row.Children.Add(new TextBlock
        {
            Text = value,
            FontSize = 13,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextPrimaryBrush
        });
        return row;
    }

    private string VersionText()
    {
        var version = Assembly.GetExecutingAssembly().GetName().Version;
        return version is null ? languageStore.Text(L10nKey.AboutUnknownVersion) : "v" + version.ToString();
    }

    private static Button MakeButton(string text, Action action, ButtonTone tone, Thickness margin)
    {
        var button = new Button
        {
            Content = text,
            MinWidth = 86,
            Height = 32,
            Margin = margin,
            Padding = new Thickness(12, 0, 12, 0),
            Style = UiTheme.ButtonStyle(tone)
        };
        button.Click += (_, _) => action();
        return button;
    }

    private static void OpenUrl(string url)
    {
        Process.Start(new ProcessStartInfo(url)
        {
            UseShellExecute = true
        });
    }
}