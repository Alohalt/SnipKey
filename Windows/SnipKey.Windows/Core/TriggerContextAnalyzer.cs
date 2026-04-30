namespace SnipKey.WinApp.Core;

public static class TriggerContextAnalyzer
{
    public readonly record struct CompletedTrigger(string Trigger, int DeletionCount);

    public static string? ActiveQuery(string textBeforeCursor, char triggerPrefix = '#')
    {
        if (string.IsNullOrEmpty(textBeforeCursor))
        {
            return null;
        }

        if (textBeforeCursor[^1] == triggerPrefix)
        {
            return string.Empty;
        }

        var endIndex = textBeforeCursor.Length - 1;
        if (!SnippetTriggerRules.IsAllowedCharacter(textBeforeCursor[endIndex]))
        {
            return null;
        }

        var startIndex = endIndex;
        while (startIndex > 0 && SnippetTriggerRules.IsAllowedCharacter(textBeforeCursor[startIndex - 1]))
        {
            startIndex -= 1;
        }

        if (startIndex == 0 || textBeforeCursor[startIndex - 1] != triggerPrefix)
        {
            return null;
        }

        return textBeforeCursor[startIndex..(endIndex + 1)];
    }

    public static CompletedTrigger? CompletedTriggerIn(string textBeforeCursor, char triggerPrefix = '#')
    {
        if (string.IsNullOrEmpty(textBeforeCursor))
        {
            return null;
        }

        var trailingCharacter = textBeforeCursor[^1];
        if (!IsTriggerTerminator(trailingCharacter, triggerPrefix))
        {
            return null;
        }

        var committedText = textBeforeCursor[..^1];
        var query = ActiveQuery(committedText, triggerPrefix);
        if (string.IsNullOrEmpty(query))
        {
            return null;
        }

        return new CompletedTrigger(query, query.Length + 2);
    }

    private static bool IsTriggerTerminator(char character, char triggerPrefix)
    {
        return !SnippetTriggerRules.IsAllowedCharacter(character) && character != triggerPrefix;
    }
}