using System.Globalization;

namespace SnipKey.WinApp;

internal enum AppLanguage
{
    English,
    SimplifiedChinese
}

internal static class AppLanguageExtensions
{
    public const string EnglishCode = "en";
    public const string SimplifiedChineseCode = "zh-Hans";

    public static AppLanguage Default => AppLanguage.SimplifiedChinese;

    public static string Code(this AppLanguage language)
    {
        return language switch
        {
            AppLanguage.English => EnglishCode,
            AppLanguage.SimplifiedChinese => SimplifiedChineseCode,
            _ => SimplifiedChineseCode
        };
    }

    public static string PickerTitle(this AppLanguage language)
    {
        return language switch
        {
            AppLanguage.English => "English",
            AppLanguage.SimplifiedChinese => "简体中文",
            _ => "简体中文"
        };
    }

    public static CultureInfo Culture(this AppLanguage language)
    {
        return CultureInfo.GetCultureInfo(language == AppLanguage.English ? "en-US" : "zh-CN");
    }

    public static AppLanguage FromCode(string? code)
    {
        return code switch
        {
            EnglishCode => AppLanguage.English,
            SimplifiedChineseCode => AppLanguage.SimplifiedChinese,
            _ => Default
        };
    }
}