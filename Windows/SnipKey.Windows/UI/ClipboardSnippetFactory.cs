using SnipKey.WinApp.Core;

namespace SnipKey.WinApp.UI;

internal static class ClipboardSnippetFactory
{
    public static Snippet MakeSnippet(string content, IEnumerable<Snippet> existingSnippets)
    {
        return new Snippet
        {
            Trigger = SnippetTriggerSuggester.SuggestTrigger(content, existingSnippets.Select(snippet => snippet.Trigger)),
            Replacement = content
        };
    }
}