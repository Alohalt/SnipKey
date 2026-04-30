using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace SnipKey.WinApp;

internal sealed class AppLanguageStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true
    };

    private readonly string filePath;
    private AppPreferences preferences = new();

    public AppLanguageStore(string? filePath = null)
    {
        this.filePath = filePath ?? DefaultFilePath();
        Load();
    }

    public event EventHandler? Changed;

    public AppLanguage Language => AppLanguageExtensions.FromCode(preferences.AppLanguage);

    public bool HasShownOnboardingGuide => preferences.HasShownOnboardingGuide;

    public string Text(L10nKey key)
    {
        return L10n.Text(key, Language);
    }

    public string Format(L10nKey key, params object[] arguments)
    {
        return L10n.Format(key, Language, arguments);
    }

    public void SetLanguage(AppLanguage language)
    {
        if (Language == language)
        {
            return;
        }

        preferences.AppLanguage = language.Code();
        Save();
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public void MarkOnboardingGuideShown()
    {
        if (preferences.HasShownOnboardingGuide)
        {
            return;
        }

        preferences.HasShownOnboardingGuide = true;
        Save();
        Changed?.Invoke(this, EventArgs.Empty);
    }

    private void Load()
    {
        if (!File.Exists(filePath))
        {
            preferences = new AppPreferences();
            Save();
            return;
        }

        try
        {
            var json = File.ReadAllText(filePath);
            preferences = JsonSerializer.Deserialize<AppPreferences>(json, JsonOptions) ?? new AppPreferences();
        }
        catch
        {
            preferences = new AppPreferences();
        }

        preferences.AppLanguage = AppLanguageExtensions.FromCode(preferences.AppLanguage).Code();
    }

    private void Save()
    {
        var directory = Path.GetDirectoryName(filePath);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        File.WriteAllText(filePath, JsonSerializer.Serialize(preferences, JsonOptions));
    }

    private static string DefaultFilePath()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var directory = Path.Combine(appData, "SnipKey");
        Directory.CreateDirectory(directory);
        return Path.Combine(directory, "app-settings.json");
    }
}

internal sealed class AppPreferences
{
    [JsonPropertyName("appLanguage")]
    public string AppLanguage { get; set; } = AppLanguageExtensions.Default.Code();

    [JsonPropertyName("hasShownOnboardingGuide")]
    public bool HasShownOnboardingGuide { get; set; }
}