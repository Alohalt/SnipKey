using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace SnipKey.WinApp.Core;

public sealed class ClipboardRecord
{
    private int copyCount = 1;
    private int lastPromptedCopyCount;

    [JsonPropertyName("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [JsonPropertyName("content")]
    public string Content { get; set; } = string.Empty;

    [JsonPropertyName("copyCount")]
    public int CopyCount
    {
        get => copyCount;
        set => copyCount = Math.Max(1, value);
    }

    [JsonPropertyName("lastCopiedAt")]
    public DateTimeOffset LastCopiedAt { get; set; } = DateTimeOffset.Now;

    [JsonPropertyName("lastPromptedCopyCount")]
    public int LastPromptedCopyCount
    {
        get => lastPromptedCopyCount;
        set => lastPromptedCopyCount = Math.Max(0, value);
    }

    [JsonPropertyName("snippetCreatedAt")]
    public DateTimeOffset? SnippetCreatedAt { get; set; }

    [JsonPropertyName("createdSnippetID")]
    public Guid? CreatedSnippetId { get; set; }

    public ClipboardRecord Clone()
    {
        return new ClipboardRecord
        {
            Id = Id,
            Content = Content,
            CopyCount = CopyCount,
            LastCopiedAt = LastCopiedAt,
            LastPromptedCopyCount = LastPromptedCopyCount,
            SnippetCreatedAt = SnippetCreatedAt,
            CreatedSnippetId = CreatedSnippetId
        };
    }
}

public sealed class ClipboardSettings
{
    private int suggestionThreshold = 3;

    [JsonPropertyName("isMonitoringEnabled")]
    public bool IsMonitoringEnabled { get; set; } = true;

    [JsonPropertyName("suggestionThreshold")]
    public int SuggestionThreshold
    {
        get => suggestionThreshold;
        set => suggestionThreshold = Math.Max(2, value);
    }

    public ClipboardSettings Clone()
    {
        return new ClipboardSettings
        {
            IsMonitoringEnabled = IsMonitoringEnabled,
            SuggestionThreshold = SuggestionThreshold
        };
    }
}

public sealed class ClipboardSuggestionStat
{
    private int copyCount = 1;
    private int lastPromptedCopyCount;

    [JsonPropertyName("contentHash")]
    public string ContentHash { get; set; } = string.Empty;

    [JsonPropertyName("copyCount")]
    public int CopyCount
    {
        get => copyCount;
        set => copyCount = Math.Max(1, value);
    }

    [JsonPropertyName("lastCopiedAt")]
    public DateTimeOffset LastCopiedAt { get; set; } = DateTimeOffset.Now;

    [JsonPropertyName("lastPromptedCopyCount")]
    public int LastPromptedCopyCount
    {
        get => lastPromptedCopyCount;
        set => lastPromptedCopyCount = Math.Max(0, value);
    }

    [JsonPropertyName("snippetCreatedAt")]
    public DateTimeOffset? SnippetCreatedAt { get; set; }

    [JsonPropertyName("createdSnippetID")]
    public Guid? CreatedSnippetId { get; set; }

    public ClipboardSuggestionStat Clone()
    {
        return new ClipboardSuggestionStat
        {
            ContentHash = ContentHash,
            CopyCount = CopyCount,
            LastCopiedAt = LastCopiedAt,
            LastPromptedCopyCount = LastPromptedCopyCount,
            SnippetCreatedAt = SnippetCreatedAt,
            CreatedSnippetId = CreatedSnippetId
        };
    }
}

public sealed class ClipboardHistoryData
{
    [JsonPropertyName("records")]
    public List<ClipboardRecord> Records { get; set; } = [];

    [JsonPropertyName("settings")]
    public ClipboardSettings Settings { get; set; } = new();

    [JsonPropertyName("suggestionStats")]
    public List<ClipboardSuggestionStat> SuggestionStats { get; set; } = [];
}

public sealed class ClipboardHistoryStore
{
    public const int DefaultMaxRecordCount = 50;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true
    };

    private readonly string filePath;
    private readonly int maxRecordCount;
    private readonly Func<DateTimeOffset> now;
    private List<ClipboardRecord> records = [];
    private ClipboardSettings settings = new();
    private List<ClipboardSuggestionStat> suggestionStats = [];

    public ClipboardHistoryStore(string? filePath = null, int maxRecordCount = DefaultMaxRecordCount, Func<DateTimeOffset>? now = null)
    {
        this.filePath = filePath ?? DefaultFilePath();
        this.maxRecordCount = Math.Max(1, maxRecordCount);
        this.now = now ?? (() => DateTimeOffset.Now);
        Load();
    }

    public event EventHandler? Changed;

    public IReadOnlyList<ClipboardRecord> Records => records;

    public ClipboardSettings Settings => settings;

    public string FilePath => filePath;

    public ClipboardRecord? RecordCopy(string content)
    {
        if (string.IsNullOrWhiteSpace(content))
        {
            return null;
        }

        var timestamp = now();
        var existingRecord = records.FirstOrDefault(record => record.Content == content);
        var suggestionStat = RegisterCopy(content, timestamp, existingRecord);

        if (existingRecord is not null)
        {
            records.Remove(existingRecord);
            var record = SynchronizedRecord(existingRecord, suggestionStat);
            records.Insert(0, record);
            TrimRecordsIfNeeded();
            Save();
            return record.Clone();
        }

        var newRecord = MakeRecord(content, suggestionStat);
        records.Insert(0, newRecord);
        TrimRecordsIfNeeded();
        Save();
        return newRecord.Clone();
    }

    public bool ShouldSuggestKey(ClipboardRecord record)
    {
        if (!settings.IsMonitoringEnabled)
        {
            return false;
        }

        var suggestionStat = SuggestionStat(record.Content);
        var snippetCreatedAt = suggestionStat?.SnippetCreatedAt ?? record.SnippetCreatedAt;
        var copyCount = suggestionStat?.CopyCount ?? record.CopyCount;
        var lastPromptedCopyCount = suggestionStat?.LastPromptedCopyCount ?? record.LastPromptedCopyCount;

        return snippetCreatedAt is null && copyCount - lastPromptedCopyCount >= settings.SuggestionThreshold;
    }

    public void MarkPrompted(Guid id)
    {
        var record = records.FirstOrDefault(record => record.Id == id);
        if (record is null)
        {
            return;
        }

        var updatedStat = UpdateSuggestionStat(record.Content, record, stat => stat.LastPromptedCopyCount = stat.CopyCount);
        ApplySuggestionStat(updatedStat, record.Content);
        Save();
    }

    public void MarkCreatedSnippet(Guid id, Guid snippetId)
    {
        var record = records.FirstOrDefault(record => record.Id == id);
        if (record is null)
        {
            return;
        }

        var timestamp = now();
        var updatedStat = UpdateSuggestionStat(record.Content, record, stat =>
        {
            stat.SnippetCreatedAt = timestamp;
            stat.CreatedSnippetId = snippetId;
            stat.LastPromptedCopyCount = stat.CopyCount;
        });
        ApplySuggestionStat(updatedStat, record.Content);
        Save();
    }

    public void ClearCreatedSnippetAssociation(Guid snippetId, string? matchingContent = null)
    {
        var didChange = false;
        var legacyContentHash = matchingContent is null ? null : ClipboardContentHash(matchingContent);

        foreach (var stat in suggestionStats)
        {
            var matchesLinkedSnippet = stat.CreatedSnippetId == snippetId;
            var matchesLegacyContent = legacyContentHash is not null
                && stat.ContentHash == legacyContentHash
                && stat.SnippetCreatedAt is not null;
            if (!matchesLinkedSnippet && !matchesLegacyContent)
            {
                continue;
            }

            stat.SnippetCreatedAt = null;
            stat.CreatedSnippetId = null;
            didChange = true;
        }

        foreach (var record in records)
        {
            var matchesLinkedSnippet = record.CreatedSnippetId == snippetId;
            var matchesLegacyContent = matchingContent is not null
                && record.Content == matchingContent
                && record.SnippetCreatedAt is not null;
            if (!matchesLinkedSnippet && !matchesLegacyContent)
            {
                continue;
            }

            record.SnippetCreatedAt = null;
            record.CreatedSnippetId = null;
            didChange = true;
        }

        if (didChange)
        {
            Save();
        }
    }

    public void DeleteRecord(Guid id)
    {
        records.RemoveAll(record => record.Id == id);
        Save();
    }

    public void ClearHistory()
    {
        records.Clear();
        suggestionStats.Clear();
        Save();
    }

    public void UpdateSettings(ClipboardSettings newSettings)
    {
        settings = new ClipboardSettings
        {
            IsMonitoringEnabled = newSettings.IsMonitoringEnabled,
            SuggestionThreshold = newSettings.SuggestionThreshold
        };
        Save();
    }

    public void Load()
    {
        if (!File.Exists(filePath))
        {
            return;
        }

        try
        {
            var json = File.ReadAllText(filePath);
            var decoded = JsonSerializer.Deserialize<ClipboardHistoryData>(json, JsonOptions) ?? new ClipboardHistoryData();
            records = decoded.Records.OrderByDescending(record => record.LastCopiedAt).ToList();
            settings = decoded.Settings ?? new ClipboardSettings();
            suggestionStats = decoded.SuggestionStats.Count > 0
                ? decoded.SuggestionStats
                : MakeSuggestionStats(records);

            var didRecoverStats = RecoverMissingSuggestionStatsIfNeeded();
            var didSynchronizeRecords = SynchronizeRecordsWithSuggestionStats();
            var didTrimRecords = TrimRecordsIfNeeded();
            if (didRecoverStats || didSynchronizeRecords || didTrimRecords)
            {
                Save();
            }
        }
        catch
        {
            records = [];
            settings = new ClipboardSettings();
            suggestionStats = [];
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

        var data = new ClipboardHistoryData
        {
            Records = records.Select(record => record.Clone()).ToList(),
            Settings = settings.Clone(),
            SuggestionStats = suggestionStats.Select(stat => stat.Clone()).ToList()
        };
        File.WriteAllText(filePath, JsonSerializer.Serialize(data, JsonOptions));
        Changed?.Invoke(this, EventArgs.Empty);
    }

    private ClipboardSuggestionStat RegisterCopy(string content, DateTimeOffset timestamp, ClipboardRecord? fallbackRecord)
    {
        var contentHash = ClipboardContentHash(content);
        var existingStat = suggestionStats.FirstOrDefault(stat => stat.ContentHash == contentHash);
        if (existingStat is not null)
        {
            existingStat.CopyCount += 1;
            existingStat.LastCopiedAt = timestamp;
            return existingStat.Clone();
        }

        var suggestionStat = fallbackRecord is null
            ? new ClipboardSuggestionStat { ContentHash = contentHash, CopyCount = 1, LastCopiedAt = timestamp }
            : MakeSuggestionStat(fallbackRecord, contentHash);

        if (fallbackRecord is not null)
        {
            suggestionStat.CopyCount += 1;
            suggestionStat.LastCopiedAt = timestamp;
        }

        suggestionStats.Add(suggestionStat);
        return suggestionStat.Clone();
    }

    private ClipboardSuggestionStat? SuggestionStat(string content)
    {
        var contentHash = ClipboardContentHash(content);
        return suggestionStats.FirstOrDefault(stat => stat.ContentHash == contentHash);
    }

    private ClipboardSuggestionStat UpdateSuggestionStat(string content, ClipboardRecord fallbackRecord, Action<ClipboardSuggestionStat> transform)
    {
        var contentHash = ClipboardContentHash(content);
        var existingStat = suggestionStats.FirstOrDefault(stat => stat.ContentHash == contentHash);
        if (existingStat is not null)
        {
            transform(existingStat);
            return existingStat.Clone();
        }

        var newStat = MakeSuggestionStat(fallbackRecord, contentHash);
        transform(newStat);
        suggestionStats.Add(newStat);
        return newStat.Clone();
    }

    private void ApplySuggestionStat(ClipboardSuggestionStat suggestionStat, string content)
    {
        for (var index = 0; index < records.Count; index += 1)
        {
            if (records[index].Content == content)
            {
                records[index] = SynchronizedRecord(records[index], suggestionStat);
            }
        }

        records = records.OrderByDescending(record => record.LastCopiedAt).ToList();
    }

    private bool RecoverMissingSuggestionStatsIfNeeded()
    {
        var didChange = false;
        foreach (var record in records)
        {
            if (SuggestionStat(record.Content) is not null)
            {
                continue;
            }

            suggestionStats.Add(MakeSuggestionStat(record));
            didChange = true;
        }

        return didChange;
    }

    private bool SynchronizeRecordsWithSuggestionStats()
    {
        var didChange = false;
        for (var index = 0; index < records.Count; index += 1)
        {
            var suggestionStat = SuggestionStat(records[index].Content);
            if (suggestionStat is null)
            {
                continue;
            }

            var synchronized = SynchronizedRecord(records[index], suggestionStat);
            if (RecordsEqual(records[index], synchronized))
            {
                continue;
            }

            records[index] = synchronized;
            didChange = true;
        }

        if (didChange)
        {
            records = records.OrderByDescending(record => record.LastCopiedAt).ToList();
        }

        return didChange;
    }

    private static ClipboardRecord SynchronizedRecord(ClipboardRecord record, ClipboardSuggestionStat suggestionStat)
    {
        var synchronized = record.Clone();
        synchronized.CopyCount = suggestionStat.CopyCount;
        synchronized.LastCopiedAt = suggestionStat.LastCopiedAt;
        synchronized.LastPromptedCopyCount = suggestionStat.LastPromptedCopyCount;
        synchronized.SnippetCreatedAt = suggestionStat.SnippetCreatedAt;
        synchronized.CreatedSnippetId = suggestionStat.CreatedSnippetId;
        return synchronized;
    }

    private static ClipboardRecord MakeRecord(string content, ClipboardSuggestionStat suggestionStat)
    {
        return new ClipboardRecord
        {
            Content = content,
            CopyCount = suggestionStat.CopyCount,
            LastCopiedAt = suggestionStat.LastCopiedAt,
            LastPromptedCopyCount = suggestionStat.LastPromptedCopyCount,
            SnippetCreatedAt = suggestionStat.SnippetCreatedAt,
            CreatedSnippetId = suggestionStat.CreatedSnippetId
        };
    }

    private static ClipboardSuggestionStat MakeSuggestionStat(ClipboardRecord record, string? contentHash = null)
    {
        return new ClipboardSuggestionStat
        {
            ContentHash = contentHash ?? ClipboardContentHash(record.Content),
            CopyCount = record.CopyCount,
            LastCopiedAt = record.LastCopiedAt,
            LastPromptedCopyCount = record.LastPromptedCopyCount,
            SnippetCreatedAt = record.SnippetCreatedAt,
            CreatedSnippetId = record.CreatedSnippetId
        };
    }

    private bool TrimRecordsIfNeeded()
    {
        if (records.Count <= maxRecordCount)
        {
            return false;
        }

        records.RemoveRange(maxRecordCount, records.Count - maxRecordCount);
        return true;
    }

    private static List<ClipboardSuggestionStat> MakeSuggestionStats(IEnumerable<ClipboardRecord> sourceRecords)
    {
        var statsByHash = new Dictionary<string, ClipboardSuggestionStat>();
        foreach (var record in sourceRecords)
        {
            var contentHash = ClipboardContentHash(record.Content);
            var candidate = MakeSuggestionStat(record, contentHash);
            if (statsByHash.TryGetValue(contentHash, out var existing))
            {
                statsByHash[contentHash] = MergeSuggestionStat(existing, candidate);
            }
            else
            {
                statsByHash[contentHash] = candidate;
            }
        }

        return statsByHash.Values.ToList();
    }

    private static ClipboardSuggestionStat MergeSuggestionStat(ClipboardSuggestionStat left, ClipboardSuggestionStat right)
    {
        var merged = left.LastCopiedAt >= right.LastCopiedAt ? left.Clone() : right.Clone();
        merged.CopyCount = Math.Max(left.CopyCount, right.CopyCount);
        merged.LastPromptedCopyCount = Math.Max(left.LastPromptedCopyCount, right.LastPromptedCopyCount);

        if (right.SnippetCreatedAt is not null && (left.SnippetCreatedAt is null || right.SnippetCreatedAt > left.SnippetCreatedAt))
        {
            merged.SnippetCreatedAt = right.SnippetCreatedAt;
            merged.CreatedSnippetId = right.CreatedSnippetId;
        }
        else if (left.SnippetCreatedAt is not null)
        {
            merged.SnippetCreatedAt = left.SnippetCreatedAt;
            merged.CreatedSnippetId = left.CreatedSnippetId;
        }

        return merged;
    }

    private static bool RecordsEqual(ClipboardRecord left, ClipboardRecord right)
    {
        return left.Id == right.Id
            && left.Content == right.Content
            && left.CopyCount == right.CopyCount
            && left.LastCopiedAt == right.LastCopiedAt
            && left.LastPromptedCopyCount == right.LastPromptedCopyCount
            && left.SnippetCreatedAt == right.SnippetCreatedAt
            && left.CreatedSnippetId == right.CreatedSnippetId;
    }

    private static string ClipboardContentHash(string content)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(content));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    private static string DefaultFilePath()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var directory = Path.Combine(appData, "SnipKey");
        Directory.CreateDirectory(directory);
        return Path.Combine(directory, "clipboard-history.json");
    }
}