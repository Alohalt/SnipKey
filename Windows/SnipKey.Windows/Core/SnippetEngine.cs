namespace SnipKey.WinApp.Core;

public sealed class SnippetEngine
{
    private List<Snippet> snippets = [];

    public void UpdateSnippets(IEnumerable<Snippet> newSnippets)
    {
        snippets = newSnippets.Select(snippet => snippet.Clone()).ToList();
    }

    public IReadOnlyList<Snippet> Match(string query)
    {
        var candidates = string.IsNullOrEmpty(query)
            ? snippets
            : snippets.Where(snippet => snippet.Trigger.StartsWith(query, StringComparison.OrdinalIgnoreCase));

        return SortSnippets(candidates, query).ToList();
    }

    public Snippet? FindExact(string trigger)
    {
        return SortSnippets(
                snippets.Where(snippet => string.Equals(snippet.Trigger, trigger, StringComparison.OrdinalIgnoreCase)),
                trigger)
            .FirstOrDefault();
    }

    private static IOrderedEnumerable<Snippet> SortSnippets(IEnumerable<Snippet> candidates, string? exactMatchQuery)
    {
        return candidates
            .OrderByDescending(snippet => exactMatchQuery is not null && string.Equals(snippet.Trigger, exactMatchQuery, StringComparison.OrdinalIgnoreCase))
            .ThenByDescending(snippet => snippet.AcceptanceCount)
            .ThenBy(snippet => snippet.Trigger, StringComparer.CurrentCultureIgnoreCase)
            .ThenBy(snippet => snippet.Id);
    }
}
