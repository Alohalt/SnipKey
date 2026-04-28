using System.Text.Json.Serialization;

namespace SnipKey.WinApp.Core;

public sealed class Snippet
{
    private int acceptanceCount;

    [JsonPropertyName("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [JsonPropertyName("trigger")]
    public string Trigger { get; set; } = string.Empty;

    [JsonPropertyName("replacement")]
    public string Replacement { get; set; } = string.Empty;

    [JsonPropertyName("groupId")]
    public Guid? GroupId { get; set; }

    [JsonPropertyName("acceptanceCount")]
    public int AcceptanceCount
    {
        get => acceptanceCount;
        set => acceptanceCount = Math.Max(0, value);
    }

    public Snippet Clone()
    {
        return new Snippet
        {
            Id = Id,
            Trigger = Trigger,
            Replacement = Replacement,
            GroupId = GroupId,
            AcceptanceCount = AcceptanceCount
        };
    }

    public override string ToString()
    {
        return "#" + Trigger;
    }
}

public sealed class SnippetGroup
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;
}

public sealed class SnippetData
{
    [JsonPropertyName("snippets")]
    public List<Snippet> Snippets { get; set; } = [];

    [JsonPropertyName("groups")]
    public List<SnippetGroup> Groups { get; set; } = [];
}
