using System.Text.Json;

namespace SnipKey.WinApp.Core;

public sealed class SnippetStore
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true
    };

    private readonly string filePath;
    private List<Snippet> snippets = [];
    private List<SnippetGroup> groups = [];

    public event EventHandler? Changed;

    public SnippetStore(string? filePath = null)
    {
        if (filePath is not null)
        {
            this.filePath = filePath;
        }
        else
        {
            var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            var directory = Path.Combine(appData, "SnipKey");
            Directory.CreateDirectory(directory);
            this.filePath = Path.Combine(directory, "snippets.json");
        }

        Load();
    }

    public IReadOnlyList<Snippet> Snippets => snippets;

    public IReadOnlyList<SnippetGroup> Groups => groups;

    public string FilePath => filePath;

    public bool AddSnippet(Snippet snippet)
    {
        if (ValidationError(snippet.Trigger) is not null)
        {
            return false;
        }

        snippets.Add(snippet.Clone());
        Save();
        return true;
    }

    public bool UpdateSnippet(Snippet snippet)
    {
        if (ValidationError(snippet.Trigger, snippet.Id) is not null)
        {
            return false;
        }

        var index = snippets.FindIndex(existingSnippet => existingSnippet.Id == snippet.Id);
        if (index < 0)
        {
            return false;
        }

        snippets[index] = snippet.Clone();
        Save();
        return true;
    }

    public void DeleteSnippet(Guid id)
    {
        snippets.RemoveAll(snippet => snippet.Id == id);
        Save();
    }

    public void RecordAcceptance(Guid id)
    {
        var snippet = snippets.FirstOrDefault(existingSnippet => existingSnippet.Id == id);
        if (snippet is null)
        {
            return;
        }

        snippet.AcceptanceCount += 1;
        Save();
    }

    public SnippetTriggerRules.ValidationError? ValidationError(string trigger, Guid? excludingSnippetId = null)
    {
        var existingTriggers = snippets
            .Where(snippet => snippet.Id != excludingSnippetId)
            .Select(snippet => snippet.Trigger);

        return SnippetTriggerRules.Validate(trigger, existingTriggers);
    }

    public string NextAvailableTrigger(string baseTrigger = SnippetTriggerRules.DefaultBase)
    {
        return SnippetTriggerRules.NextAvailableTrigger(snippets.Select(snippet => snippet.Trigger), baseTrigger);
    }

    public void Load()
    {
        if (!File.Exists(filePath))
        {
            return;
        }

        var json = File.ReadAllText(filePath);
        var decoded = JsonSerializer.Deserialize<SnippetData>(json, JsonOptions) ?? new SnippetData();
        var normalized = NormalizeSnippets(decoded.Snippets);
        snippets = normalized.Snippets;
        groups = decoded.Groups ?? [];

        if (normalized.DidChange)
        {
            Save();
        }

        Changed?.Invoke(this, EventArgs.Empty);
    }

    public void Save()
    {
        var directory = Path.GetDirectoryName(filePath);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }

        var data = new SnippetData
        {
            Snippets = snippets.Select(snippet => snippet.Clone()).ToList(),
            Groups = groups
        };
        var json = JsonSerializer.Serialize(data, JsonOptions);
        File.WriteAllText(filePath, json);
        Changed?.Invoke(this, EventArgs.Empty);
    }

    public void ExportData(string exportPath)
    {
        var data = new SnippetData
        {
            Snippets = snippets.Select(snippet => snippet.Clone()).ToList(),
            Groups = groups
        };
        File.WriteAllText(exportPath, JsonSerializer.Serialize(data, JsonOptions));
    }

    public void ImportData(string importPath)
    {
        var json = File.ReadAllText(importPath);
        var decoded = JsonSerializer.Deserialize<SnippetData>(json, JsonOptions) ?? new SnippetData();
        snippets = NormalizeSnippets(decoded.Snippets).Snippets;
        groups = decoded.Groups ?? [];
        Save();
    }

    private static (List<Snippet> Snippets, bool DidChange) NormalizeSnippets(IEnumerable<Snippet> rawSnippets)
    {
        var normalizedTriggers = new List<string>();
        var normalizedSnippets = new List<Snippet>();
        var didChange = false;

        foreach (var rawSnippet in rawSnippets)
        {
            var snippet = rawSnippet.Clone();
            if (snippet.Id == Guid.Empty)
            {
                snippet.Id = Guid.NewGuid();
                didChange = true;
            }

            var normalizedTrigger = SnippetTriggerRules.NormalizedTrigger(snippet.Trigger, normalizedTriggers);
            if (snippet.Trigger != normalizedTrigger)
            {
                snippet.Trigger = normalizedTrigger;
                didChange = true;
            }

            normalizedTriggers.Add(snippet.Trigger);
            normalizedSnippets.Add(snippet);
        }

        return (normalizedSnippets, didChange);
    }
}
