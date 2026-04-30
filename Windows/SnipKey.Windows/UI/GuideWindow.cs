using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Button = System.Windows.Controls.Button;
using FontFamily = System.Windows.Media.FontFamily;
using HorizontalAlignment = System.Windows.HorizontalAlignment;
using Orientation = System.Windows.Controls.Orientation;

namespace SnipKey.WinApp.UI;

internal sealed class GuideWindow : Window
{
    private readonly AppLanguageStore languageStore;
    private readonly TextBlock stepTitleText = new();
    private readonly TextBlock stepBodyText = new();
    private readonly TextBlock stepCounterText = new();
    private readonly Button previousButton = new();
    private readonly Button nextButton = new();
    private int currentStepIndex;

    public GuideWindow(AppLanguageStore languageStore)
    {
        this.languageStore = languageStore;

        Title = languageStore.Text(L10nKey.GuideTitle);
        Width = 520;
        Height = 360;
        MinWidth = 460;
        MinHeight = 320;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        Background = UiTheme.WindowBackgroundBrush;
        FontFamily = new FontFamily("Segoe UI Variable, Segoe UI");
        UseLayoutRounding = true;
        SnapsToDevicePixels = true;
        AppIcon.ApplyTo(this);
        Content = BuildLayout();

        languageStore.Changed += OnLanguageChanged;
        UpdateStep();
    }

    protected override void OnClosed(EventArgs eventArgs)
    {
        languageStore.Changed -= OnLanguageChanged;
        base.OnClosed(eventArgs);
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
            Text = languageStore.Text(L10nKey.GuideTitle),
            FontSize = 24,
            FontWeight = FontWeights.SemiBold,
            Foreground = UiTheme.TextPrimaryBrush
        });
        stepCounterText.FontSize = 12;
        stepCounterText.Margin = new Thickness(1, 4, 0, 0);
        stepCounterText.Foreground = UiTheme.TextSecondaryBrush;
        header.Children.Add(stepCounterText);
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
        var content = new StackPanel();
        stepTitleText.FontSize = 20;
        stepTitleText.FontWeight = FontWeights.SemiBold;
        stepTitleText.Foreground = UiTheme.TextPrimaryBrush;
        content.Children.Add(stepTitleText);

        stepBodyText.FontSize = 14;
        stepBodyText.LineHeight = 22;
        stepBodyText.TextWrapping = TextWrapping.Wrap;
        stepBodyText.Margin = new Thickness(0, 12, 0, 0);
        stepBodyText.Foreground = UiTheme.TextSecondaryBrush;
        content.Children.Add(stepBodyText);
        card.Child = content;
        Grid.SetRow(card, 1);
        root.Children.Add(card);

        var buttons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Margin = new Thickness(0, 18, 0, 0)
        };
        ConfigureButton(previousButton, languageStore.Text(L10nKey.CommonBack), PreviousStep, ButtonTone.Secondary, new Thickness(0, 0, 8, 0));
        ConfigureButton(nextButton, languageStore.Text(L10nKey.CommonNext), NextStep, ButtonTone.Primary, new Thickness(0));
        buttons.Children.Add(previousButton);
        buttons.Children.Add(nextButton);
        Grid.SetRow(buttons, 2);
        root.Children.Add(buttons);

        return root;
    }

    private void PreviousStep()
    {
        currentStepIndex = Math.Max(0, currentStepIndex - 1);
        UpdateStep();
    }

    private void NextStep()
    {
        if (currentStepIndex >= Steps().Count - 1)
        {
            Close();
            return;
        }

        currentStepIndex += 1;
        UpdateStep();
    }

    private void UpdateStep()
    {
        var steps = Steps();
        var step = steps[currentStepIndex];
        Title = languageStore.Text(L10nKey.GuideTitle);
        stepTitleText.Text = languageStore.Text(step.TitleKey);
        stepBodyText.Text = languageStore.Text(step.MessageKey);
        stepCounterText.Text = (currentStepIndex + 1).ToString(languageStore.Language.Culture()) + " / " + steps.Count.ToString(languageStore.Language.Culture());
        previousButton.Content = languageStore.Text(L10nKey.CommonBack);
        previousButton.IsEnabled = currentStepIndex > 0;
        nextButton.Content = currentStepIndex >= steps.Count - 1
            ? languageStore.Text(L10nKey.CommonDone)
            : languageStore.Text(L10nKey.CommonNext);
    }

    private void OnLanguageChanged(object? sender, EventArgs eventArgs)
    {
        UpdateStep();
    }

    private static IReadOnlyList<GuideStep> Steps()
    {
        return [
            new GuideStep(L10nKey.GuideStepCreateTitle, L10nKey.GuideStepCreateMessage),
            new GuideStep(L10nKey.GuideStepTriggerTitle, L10nKey.GuideStepTriggerMessage),
            new GuideStep(L10nKey.GuideStepReplacementTitle, L10nKey.GuideStepReplacementMessage),
            new GuideStep(L10nKey.GuideStepGroupTitle, L10nKey.GuideStepGroupMessage)
        ];
    }

    private static void ConfigureButton(Button button, string text, Action action, ButtonTone tone, Thickness margin)
    {
        button.Content = text;
        button.MinWidth = 76;
        button.Height = 32;
        button.Margin = margin;
        button.Padding = new Thickness(12, 0, 12, 0);
        button.Style = UiTheme.ButtonStyle(tone);
        button.Click += (_, _) => action();
    }

    private readonly record struct GuideStep(L10nKey TitleKey, L10nKey MessageKey);
}