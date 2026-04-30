using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace SnipKey.WinApp.Core;

public static partial class SnippetTriggerSuggester
{
    public const int DefaultPreferredLength = 4;

    private const string DefaultBase = "clip";
    private static readonly HashSet<string> GenericHostLabels = ["www", "m", "mobile", "app"];
    private static readonly HashSet<string> GenericSecondLevelDomains = ["ac", "co", "com", "edu", "gov", "net", "org"];

    public static string SuggestTrigger(string content, IEnumerable<string>? existingTriggers = null, int preferredLength = DefaultPreferredLength)
    {
        var resolvedPreferredLength = Math.Max(1, preferredLength);
        var normalizedExisting = (existingTriggers ?? [])
            .Select(trigger => trigger.ToLowerInvariant())
            .ToHashSet();

        foreach (var candidate in Candidates(content))
        {
            var sanitized = Sanitize(candidate.RawValue);
            if (string.IsNullOrEmpty(sanitized))
            {
                continue;
            }

            return MakeUnique(sanitized, candidate.Direction, normalizedExisting, resolvedPreferredLength);
        }

        return MakeUnique(DefaultBase, TriggerDirection.Prefix, normalizedExisting, resolvedPreferredLength);
    }

    private static List<TriggerCandidate> Candidates(string content)
    {
        var collapsed = CollapseWhitespace(content);
        if (string.IsNullOrEmpty(collapsed))
        {
            return [new TriggerCandidate(DefaultBase, TriggerDirection.Prefix)];
        }

        var candidates = new List<TriggerCandidate>();

        if (CodeCandidate(collapsed) is { } code)
        {
            candidates.Add(new TriggerCandidate(code, TriggerDirection.Suffix));
        }

        if (EmailCandidate(collapsed) is { } email)
        {
            candidates.Add(new TriggerCandidate(email, TriggerDirection.Prefix));
        }

        candidates.AddRange(UrlCandidates(collapsed).Select(candidate => new TriggerCandidate(candidate, TriggerDirection.Prefix)));

        if (PathCandidate(collapsed) is { } path)
        {
            candidates.Add(new TriggerCandidate(path, TriggerDirection.Prefix));
        }

        if (EnglishPhraseCandidate(collapsed) is { } englishPhrase)
        {
            candidates.Add(new TriggerCandidate(englishPhrase, TriggerDirection.Prefix));
        }

        if (IdentifierCandidate(collapsed) is { } identifier)
        {
            candidates.Add(new TriggerCandidate(identifier, TriggerDirection.Prefix));
        }

        candidates.Add(new TriggerCandidate(DefaultBase, TriggerDirection.Prefix));
        return Deduplicated(candidates);
    }

    private static string? CodeCandidate(string content)
    {
        if (content.Length < 6 || content.Any(character => character > 127 || !char.IsLetterOrDigit(character)))
        {
            return null;
        }

        var letters = content.Count(char.IsLetter);
        var digits = content.Count(char.IsDigit);
        var hasUppercaseLetter = content.Any(char.IsUpper);

        if (digits < 4 || (!hasUppercaseLetter && letters != 0 && digits < letters * 2))
        {
            return null;
        }

        return content.ToLowerInvariant();
    }

    private static string? EmailCandidate(string content)
    {
        if (!EmailRegex().IsMatch(content))
        {
            return null;
        }

        var localPart = content.Split('@', 2)[0];
        return IdentifierCandidate(localPart);
    }

    private static IEnumerable<string> UrlCandidates(string content)
    {
        if (!Uri.TryCreate(content, UriKind.Absolute, out var uri) || uri.Scheme.Equals("mailto", StringComparison.OrdinalIgnoreCase))
        {
            return [];
        }

        if (string.IsNullOrEmpty(uri.Host))
        {
            return [];
        }

        var hostTokens = uri.Host
            .ToLowerInvariant()
            .Split('.', StringSplitOptions.RemoveEmptyEntries)
            .Where(token => !GenericHostLabels.Contains(token))
            .ToList();
        var domain = PreferredDomainLabel(hostTokens);
        if (domain is null)
        {
            return [];
        }

        var candidates = new List<string> { domain };
        if (PreferredUrlPathToken(uri.AbsolutePath) is { } pathToken)
        {
            candidates.Insert(0, domain + pathToken);
        }

        return candidates.Select(IdentifierCandidate).Where(candidate => candidate is not null).Cast<string>();
    }

    private static string? PreferredDomainLabel(IReadOnlyList<string> hostTokens)
    {
        if (hostTokens.Count == 0)
        {
            return null;
        }

        if (hostTokens.Count == 1)
        {
            return hostTokens[0];
        }

        foreach (var label in hostTokens.Take(hostTokens.Count - 1).Reverse())
        {
            if (!GenericSecondLevelDomains.Contains(label))
            {
                return label;
            }
        }

        return hostTokens[^2];
    }

    private static string? PreferredUrlPathToken(string path)
    {
        var components = path.Split('/', StringSplitOptions.RemoveEmptyEntries);
        foreach (var component in components.Reverse())
        {
            var candidate = IdentifierCandidate(component);
            if (candidate is { Length: >= 3 })
            {
                return candidate;
            }
        }

        return null;
    }

    private static string? PathCandidate(string content)
    {
        if (!LooksLikePath(content))
        {
            return null;
        }

        var resolvedPath = content.StartsWith("file://", StringComparison.OrdinalIgnoreCase) && Uri.TryCreate(content, UriKind.Absolute, out var uri)
            ? uri.LocalPath
            : content;
        var fileName = Path.GetFileNameWithoutExtension(resolvedPath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
        return IdentifierCandidate(fileName);
    }

    private static bool LooksLikePath(string content)
    {
        if (content.StartsWith("/", StringComparison.Ordinal)
            || content.StartsWith("~/", StringComparison.Ordinal)
            || content.StartsWith("file://", StringComparison.OrdinalIgnoreCase)
            || Regex.IsMatch(content, "^[A-Za-z]:[\\\\/]"))
        {
            return true;
        }

        return content.Contains('/') && !content.Any(char.IsWhiteSpace) && !content.Contains("://", StringComparison.Ordinal);
    }

    private static string? EnglishPhraseCandidate(string content)
    {
        if (ContainsCjk(content) || !content.Any(char.IsWhiteSpace))
        {
            return null;
        }

        var tokens = WordTokens(TransliteratedAscii(content))
            .Where(token => token.Length > 0 && !token.All(char.IsDigit))
            .ToList();
        if (tokens.Count <= 1)
        {
            return null;
        }

        return new string(tokens.Select(token => token[0]).ToArray());
    }

    private static string? IdentifierCandidate(string content)
    {
        var normalized = new string(TransliteratedAscii(content).Where(char.IsLetterOrDigit).ToArray());
        return string.IsNullOrEmpty(normalized) ? null : normalized;
    }

    private static string CollapseWhitespace(string content)
    {
        return string.Join(' ', content.Replace("\n", " ", StringComparison.Ordinal)
            .Trim()
            .Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
    }

    private static string TransliteratedAscii(string content)
    {
        var normalized = content.Normalize(NormalizationForm.FormD);
        var builder = new StringBuilder(normalized.Length);
        foreach (var character in normalized)
        {
            var category = CharUnicodeInfo.GetUnicodeCategory(character);
            if (category == UnicodeCategory.NonSpacingMark)
            {
                continue;
            }

            if (character <= 127)
            {
                builder.Append(char.ToLowerInvariant(character));
            }
        }

        return builder.ToString();
    }

    private static IEnumerable<string> WordTokens(string content)
    {
        return Regex.Split(content, "[^A-Za-z0-9]+").Where(token => token.Length > 0);
    }

    private static string Sanitize(string candidate)
    {
        return new string(TransliteratedAscii(candidate).Where(char.IsLetterOrDigit).ToArray());
    }

    private static string MakeUnique(string baseValue, TriggerDirection direction, HashSet<string> existingTriggers, int preferredLength)
    {
        var resolvedLength = Math.Min(Math.Max(1, preferredLength), baseValue.Length);
        for (var length = resolvedLength; length <= baseValue.Length; length += 1)
        {
            var candidate = CandidateSlice(baseValue, direction, length);
            if (!existingTriggers.Contains(candidate.ToLowerInvariant()))
            {
                return candidate;
            }
        }

        return MakeNumericUnique(CandidateSlice(baseValue, direction, resolvedLength), existingTriggers);
    }

    private static string CandidateSlice(string baseValue, TriggerDirection direction, int length)
    {
        return direction == TriggerDirection.Prefix ? baseValue[..length] : baseValue[^length..];
    }

    private static string MakeNumericUnique(string baseValue, HashSet<string> existingTriggers)
    {
        var index = 2;
        while (true)
        {
            var candidate = baseValue + index.ToString(CultureInfo.InvariantCulture);
            if (!existingTriggers.Contains(candidate.ToLowerInvariant()))
            {
                return candidate;
            }

            index += 1;
        }
    }

    private static List<TriggerCandidate> Deduplicated(IEnumerable<TriggerCandidate> candidates)
    {
        var seen = new HashSet<string>();
        var result = new List<TriggerCandidate>();
        foreach (var candidate in candidates)
        {
            var key = candidate.Direction + ":" + candidate.RawValue.ToLowerInvariant();
            if (seen.Add(key))
            {
                result.Add(candidate);
            }
        }

        return result;
    }

    private static bool ContainsCjk(string content)
    {
        return content.Any(character => character is >= '\u3400' and <= '\u4DBF' or >= '\u4E00' and <= '\u9FFF' or >= '\uF900' and <= '\uFAFF');
    }

    [GeneratedRegex("^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex EmailRegex();

    private readonly record struct TriggerCandidate(string RawValue, TriggerDirection Direction);

    private enum TriggerDirection
    {
        Prefix,
        Suffix
    }
}