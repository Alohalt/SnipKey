namespace SnipKey.WinApp.Core;

public static class SnippetTriggerRules
{
    public const string DefaultBase = "key";

    public enum ValidationError
    {
        Empty,
        InvalidCharacters,
        Duplicate
    }

    public static string Sanitize(string trigger)
    {
        return new string(trigger.Where(IsAllowedCharacter).ToArray());
    }

    public static ValidationError? Validate(string trigger, IEnumerable<string> existingTriggers)
    {
        if (string.IsNullOrEmpty(trigger))
        {
            return ValidationError.Empty;
        }

        if (Sanitize(trigger) != trigger)
        {
            return ValidationError.InvalidCharacters;
        }

        var normalizedTrigger = trigger.ToLowerInvariant();
        if (existingTriggers.Any(existingTrigger => string.Equals(existingTrigger, normalizedTrigger, StringComparison.OrdinalIgnoreCase)))
        {
            return ValidationError.Duplicate;
        }

        return null;
    }

    public static string NextAvailableTrigger(IEnumerable<string> existingTriggers, string baseTrigger = DefaultBase)
    {
        return NormalizedTrigger(baseTrigger, existingTriggers);
    }

    public static string NormalizedTrigger(string trigger, IEnumerable<string> existingTriggers, string fallbackBase = DefaultBase)
    {
        var sanitized = Sanitize(trigger);
        var baseValue = string.IsNullOrEmpty(sanitized) ? Sanitize(fallbackBase) : sanitized;
        var resolvedBase = string.IsNullOrEmpty(baseValue) ? DefaultBase : baseValue;
        var normalizedExisting = existingTriggers.Select(existingTrigger => existingTrigger.ToLowerInvariant()).ToHashSet();

        if (!normalizedExisting.Contains(resolvedBase.ToLowerInvariant()))
        {
            return resolvedBase;
        }

        var separator = resolvedBase.EndsWith('_') ? string.Empty : "_";
        var suffix = 2;
        while (true)
        {
            var candidate = resolvedBase + separator + suffix;
            if (!normalizedExisting.Contains(candidate.ToLowerInvariant()))
            {
                return candidate;
            }

            suffix += 1;
        }
    }

    public static bool IsAllowedCharacter(char character)
    {
        return character == '_' || (character <= 127 && char.IsLetterOrDigit(character));
    }
}
