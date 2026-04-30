using System.IO;
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

    public SnippetGroup AddGroup(string name)
    {
        var group = new SnippetGroup
        {
            Name = NormalizedGroupName(name, groups.Select(existingGroup => existingGroup.Name))
        };
        groups.Add(group);
        Save();
        return group.Clone();
    }

    public bool RenameGroup(Guid id, string name)
    {
        var group = groups.FirstOrDefault(existingGroup => existingGroup.Id == id);
        if (group is null)
        {
            return false;
        }

        group.Name = NormalizedGroupName(name, groups.Where(existingGroup => existingGroup.Id != id).Select(existingGroup => existingGroup.Name));
        Save();
        return true;
    }

    public void DeleteGroup(Guid id)
    {
        groups.RemoveAll(group => group.Id == id);
        foreach (var snippet in snippets.Where(snippet => snippet.GroupId == id))
        {
            snippet.GroupId = null;
        }

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

    public string NextAvailableGroupName(string baseName = "New Group")
    {
        return NormalizedGroupName(baseName, groups.Select(group => group.Name));
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
        groups = NormalizeGroups(decoded.Groups ?? []);
        var didCleanGroupReferences = CleanInvalidGroupReferences();

        if (normalized.DidChange || didCleanGroupReferences)
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
            Groups = groups.Select(group => group.Clone()).ToList()
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
            Groups = groups.Select(group => group.Clone()).ToList()
        };
        File.WriteAllText(exportPath, JsonSerializer.Serialize(data, JsonOptions));
    }

    public void ImportData(string importPath)
    {
        var json = File.ReadAllText(importPath);
        var decoded = JsonSerializer.Deserialize<SnippetData>(json, JsonOptions) ?? new SnippetData();
        snippets = NormalizeSnippets(decoded.Snippets).Snippets;
        groups = NormalizeGroups(decoded.Groups ?? []);
        CleanInvalidGroupReferences();
        Save();
    }

    private static List<SnippetGroup> NormalizeGroups(IEnumerable<SnippetGroup> rawGroups)
    {
        var normalizedNames = new List<string>();
        var normalizedGroups = new List<SnippetGroup>();

        foreach (var rawGroup in rawGroups)
        {
            var group = rawGroup.Clone();
            if (group.Id == Guid.Empty)
            {
                group.Id = Guid.NewGuid();
            }

            group.Name = NormalizedGroupName(group.Name, normalizedNames);
            normalizedNames.Add(group.Name);
            normalizedGroups.Add(group);
        }

        return normalizedGroups;
    }

    private bool CleanInvalidGroupReferences()
    {
        var validGroupIds = groups.Select(group => group.Id).ToHashSet();
        var didChange = false;
        foreach (var snippet in snippets)
        {
            if (snippet.GroupId is not null && !validGroupIds.Contains(snippet.GroupId.Value))
            {
                snippet.GroupId = null;
                didChange = true;
            }
        }

        return didChange;
    }

    private static string NormalizedGroupName(string name, IEnumerable<string> existingNames)
    {
        var baseName = string.IsNullOrWhiteSpace(name) ? "New Group" : name.Trim();
        var normalizedExisting = existingNames.Select(existingName => existingName.ToLowerInvariant()).ToHashSet();
        if (!normalizedExisting.Contains(baseName.ToLowerInvariant()))
        {
            return baseName;
        }

        var suffix = 2;
        while (true)
        {
            var candidate = baseName + " " + suffix.ToString(System.Globalization.CultureInfo.InvariantCulture);
            if (!normalizedExisting.Contains(candidate.ToLowerInvariant()))
            {
                return candidate;
            }

            suffix += 1;
        }
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
