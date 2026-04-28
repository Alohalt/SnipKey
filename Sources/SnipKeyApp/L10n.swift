import Foundation

enum L10n {
    enum Key: Hashable {
        case menuEnable
        case menuGrantPermissionsEllipsis
        case menuSettingsEllipsis
        case menuClipboardHistoryEllipsis
        case menuQuitSnipKey
        case menuEdit
        case menuUndo
        case menuRedo
        case menuCut
        case menuCopy
        case menuPaste
        case menuSelectAll
        case languageTitle
        case settingsOnboardingPreviewReplacement
        case settingsUnsavedReplacementTitle
        case settingsSaveAndContinue
        case settingsDiscardChanges
        case commonCancel
        case commonDelete
        case commonRestore
        case commonSave
        case commonApply
        case commonClose
        case commonImport
        case commonExport
        case commonNone
        case settingsUnsavedReplacementMessage
        case settingsSidebarSubtitle
        case settingsMetricGroups
        case settingsTools
        case settingsNewGroup
        case settingsClipboardHistory
        case settingsGuide
        case settingsAbout
        case settingsBrowse
        case settingsAllKeys
        case settingsGroups
        case settingsNoGroups
        case settingsRenameGroup
        case settingsDeleteGroup
        case settingsDeleteGroupTitle
        case settingsDeleteGroupMessage
        case settingsNewKey
        case settingsNewKeyHelp
        case settingsSearchPlaceholder
        case settingsNoKeyEmptyTitle
        case settingsNoSearchResultTitle
        case settingsNoKeyEmptySubtitle
        case settingsNoSearchResultSubtitle
        case settingsDeleteKey
        case settingsDeleteKeyTitle
        case settingsDeleteKeyMessage
        case settingsSelectKeyTitle
        case settingsSelectKeySubtitle
        case settingsUnsavedBadge
        case settingsOnboardingStepCreateTitle
        case settingsOnboardingStepCreateMessage
        case settingsOnboardingStepCreateFootnote
        case settingsOnboardingStepTriggerTitle
        case settingsOnboardingStepTriggerMessage
        case settingsOnboardingStepTriggerFootnote
        case settingsOnboardingStepReplacementTitle
        case settingsOnboardingStepReplacementMessage
        case settingsOnboardingStepReplacementFootnote
        case settingsOnboardingStepGroupTitle
        case settingsOnboardingStepGroupMessage
        case settingsOnboardingStepGroupFootnote
        case settingsResultCountFormat
        case settingsSearchPartFormat
        case settingsCurrentGroup
        case settingsAllTextExpansions
        case settingsKeyDetails
        case settingsDetailEmptySubtitle
        case settingsUngrouped
        case settingsAcceptedTimesFormat
        case settingsClipboardStatusEnabledFormat
        case settingsClipboardStatusDisabled
        case settingsTriggerEmpty
        case settingsTriggerInvalid
        case settingsTriggerDuplicate
        case settingsTriggerHelp
        case settingsTriggerTitle
        case settingsTriggerPlaceholder
        case settingsReplacementTitle
        case settingsReplacementSubtitle
        case settingsEditInWindow
        case settingsGroupTitle
        case settingsVariablesTitle
        case settingsVariablesSubtitle
        case settingsVariableCurrentDate
        case settingsVariableCurrentTime
        case settingsVariableClipboardText
        case settingsVariableCursorPosition
        case settingsRenameGroupTitle
        case settingsRenameGroupMessage
        case settingsGroupNamePlaceholder
        case settingsDefaultReplacement
        case settingsDefaultGroupName
        case settingsExportPanelTitle
        case settingsImportPanelTitle
        case settingsImportPanelMessage
        case settingsOnboardingGuideTitle
        case settingsLocatingControl
        case settingsWatchLater
        case settingsPrevious
        case settingsFinish
        case settingsNext
        case replacementEditorTitle
        case replacementEditorEditingFormat
        case replacementUnsavedTitle
        case replacementApplyChanges
        case replacementDiscardChanges
        case replacementContinueEditing
        case replacementUnsavedMessage
        case clipboardTitle
        case clipboardClearRecords
        case clipboardRecordMetric
        case clipboardStatusMetric
        case clipboardThresholdMetric
        case clipboardStatusOn
        case clipboardStatusOff
        case clipboardTimesFormat
        case clipboardSuggestionSettingsTitle
        case clipboardSuggestionSettingsSubtitle
        case clipboardMonitoringToggleTitle
        case clipboardMonitoringToggleSubtitle
        case clipboardThresholdTitle
        case clipboardThresholdDescriptionFormat
        case clipboardRecentCopiesTitle
        case clipboardEmptyTitle
        case clipboardEmptySubtitle
        case clipboardHeaderEnabledFormat
        case clipboardHeaderPaused
        case clipboardHistoryEmptySubtitle
        case clipboardHistoryCountSubtitleFormat
        case clipboardCreatedKey
        case clipboardCopiedTimesFormat
        case clipboardDeleteRecord
        case clipboardNewKey
        case clipboardTodayFormat
        case clipboardYesterdayFormat
        case aboutUnknownVersion
        case aboutTitle
        case aboutSubtitle
        case aboutSummary
        case aboutDeveloper
        case aboutRepositoryAddress
        case aboutVersion
        case aboutRepositoryHome
        case aboutReportIssue
        case clipboardSuggestionTitleFormat
        case clipboardSuggestionMessageFormat
        case clipboardSuggestionCreateKey
        case clipboardSuggestionLater
        case accessibilityPermissionTitle
        case accessibilityPermissionMessage
        case accessibilityOpenSettings
        case accessibilityLater
        case completionNoMatches
        case completionHeaderTitle
        case completionHeaderInstruction
        case completionCandidateAccessibilityCountFormat
        case completionRowAccessibilityHint
        case completionRowAccessibilityLabelFormat
    }

    static func text(_ key: Key, language: AppLanguage) -> String {
        let strings = language == .english ? english : simplifiedChinese
        return strings[key] ?? simplifiedChinese[key] ?? String(describing: key)
    }

    static func formatted(_ key: Key, language: AppLanguage, _ arguments: [CVarArg]) -> String {
        String(format: text(key, language: language), locale: language.locale, arguments: arguments)
    }

    private static let simplifiedChinese: [Key: String] = [
        .menuEnable: "启用",
        .menuGrantPermissionsEllipsis: "授予权限…",
        .menuSettingsEllipsis: "设置…",
        .menuClipboardHistoryEllipsis: "剪贴板记录…",
        .menuQuitSnipKey: "退出 SnipKey",
        .menuEdit: "编辑",
        .menuUndo: "撤销",
        .menuRedo: "重做",
        .menuCut: "剪切",
        .menuCopy: "复制",
        .menuPaste: "粘贴",
        .menuSelectAll: "全选",
        .languageTitle: "语言",
        .settingsOnboardingPreviewReplacement: "这是我的第一条 Key。\n你可以把常用回复、地址、签名或模板放在这里。",
        .settingsUnsavedReplacementTitle: "替换内容尚未保存",
        .settingsSaveAndContinue: "保存并继续",
        .settingsDiscardChanges: "放弃更改",
        .commonCancel: "取消",
        .commonDelete: "删除",
        .commonRestore: "还原",
        .commonSave: "保存",
        .commonApply: "应用",
        .commonClose: "关闭",
        .commonImport: "导入",
        .commonExport: "导出",
        .commonNone: "无",
        .settingsUnsavedReplacementMessage: "替换内容有未保存的修改。继续操作前，请先保存或放弃这些更改。",
        .settingsSidebarSubtitle: "像系统设置一样管理你的 Key、分组和常用文本。",
        .settingsMetricGroups: "分组",
        .settingsTools: "工具",
        .settingsNewGroup: "新建分组",
        .settingsClipboardHistory: "剪贴板记录",
        .settingsGuide: "使用指引",
        .settingsAbout: "关于 SnipKey",
        .settingsBrowse: "浏览",
        .settingsAllKeys: "全部Key",
        .settingsGroups: "分组",
        .settingsNoGroups: "还没有分组",
        .settingsRenameGroup: "重命名分组",
        .settingsDeleteGroup: "删除分组",
        .settingsDeleteGroupTitle: "删除分组？",
        .settingsDeleteGroupMessage: "删除后，这个分组中的Key会保留为未分组状态，此操作无法撤销。",
        .settingsNewKey: "新建Key",
        .settingsNewKeyHelp: "新建Key (⌘N)",
        .settingsSearchPlaceholder: "搜索触发词或替换内容",
        .settingsNoKeyEmptyTitle: "这里还没有 Key",
        .settingsNoSearchResultTitle: "没有匹配的 Key",
        .settingsNoKeyEmptySubtitle: "点击右上角“新建Key”开始添加。",
        .settingsNoSearchResultSubtitle: "试试其他关键词，或清空搜索。",
        .settingsDeleteKey: "删除Key",
        .settingsDeleteKeyTitle: "删除Key？",
        .settingsDeleteKeyMessage: "这个Key将被永久删除。",
        .settingsSelectKeyTitle: "请选择一个 Key 进行编辑",
        .settingsSelectKeySubtitle: "左侧可以按分组浏览，中间可以搜索和选择。",
        .settingsUnsavedBadge: "未保存",
        .settingsOnboardingStepCreateTitle: "先从这里创建 Key",
        .settingsOnboardingStepCreateMessage: "每一条常用文本都从左上角的“新建Key”开始。看完这套指引后，第一步就是先点它。",
        .settingsOnboardingStepCreateFootnote: "你可以直接点击高亮的“新建Key”，系统会自动进入下一步；如果暂时不想建，也可以先看后面的说明。",
        .settingsOnboardingStepTriggerTitle: "这里填写触发词",
        .settingsOnboardingStepTriggerMessage: "触发词只填关键词本身，不需要带 #。真正使用时，在别的应用里输入 #email_key 这样的形式即可。",
        .settingsOnboardingStepTriggerFootnote: "触发词只支持字母、数字和下划线，并且不能和现有 Key 重复。",
        .settingsOnboardingStepReplacementTitle: "这里写最终展开的内容",
        .settingsOnboardingStepReplacementMessage: "可以写多行文本、签名、地址、模板回复。内容较长时，点右上角“在窗口中编辑”会更舒服。",
        .settingsOnboardingStepReplacementFootnote: "修改替换内容后会显示“未保存”，按 ⌘S 或底部“保存”即可生效。",
        .settingsOnboardingStepGroupTitle: "用分组整理你的 Key",
        .settingsOnboardingStepGroupMessage: "把同类 Key 放进同一分组，左侧列表就能按分组筛选。Key 变多以后，这里会很有用。",
        .settingsOnboardingStepGroupFootnote: "看完后就可以回到左上角，创建并保存你的第一条 Key。",
        .settingsResultCountFormat: "%d 个结果",
        .settingsSearchPartFormat: "搜索“%@”",
        .settingsCurrentGroup: "当前分组",
        .settingsAllTextExpansions: "所有可用的文本展开",
        .settingsKeyDetails: "Key 详情",
        .settingsDetailEmptySubtitle: "配置触发词、替换内容和分组。",
        .settingsUngrouped: "未分组",
        .settingsAcceptedTimesFormat: "已接受 %d 次",
        .settingsClipboardStatusEnabledFormat: "剪贴板记录 %d 条 · 阈值 %d 次",
        .settingsClipboardStatusDisabled: "剪贴板记录已关闭",
        .settingsTriggerEmpty: "触发词不能为空。",
        .settingsTriggerInvalid: "只允许字母、数字和下划线。",
        .settingsTriggerDuplicate: "这个触发词已经存在，请换一个。",
        .settingsTriggerHelp: "只允许字母、数字和下划线，且必须唯一。",
        .settingsTriggerTitle: "触发词",
        .settingsTriggerPlaceholder: "例如：email_key",
        .settingsReplacementTitle: "替换内容",
        .settingsReplacementSubtitle: "接受 Key 后会插入这里的文本。",
        .settingsEditInWindow: "在窗口中编辑",
        .settingsGroupTitle: "分组",
        .settingsVariablesTitle: "变量",
        .settingsVariablesSubtitle: "可以在替换内容中使用的动态变量。",
        .settingsVariableCurrentDate: "当前日期",
        .settingsVariableCurrentTime: "当前时间",
        .settingsVariableClipboardText: "剪贴板文本",
        .settingsVariableCursorPosition: "光标位置",
        .settingsRenameGroupTitle: "重命名分组",
        .settingsRenameGroupMessage: "请输入新的分组名称。",
        .settingsGroupNamePlaceholder: "分组名称",
        .settingsDefaultReplacement: "替换文本",
        .settingsDefaultGroupName: "新分组",
        .settingsExportPanelTitle: "导出Key",
        .settingsImportPanelTitle: "导入Key",
        .settingsImportPanelMessage: "请选择要导入的 SnipKey Key文件。",
        .settingsOnboardingGuideTitle: "使用指引",
        .settingsLocatingControl: "正在定位当前控件…",
        .settingsWatchLater: "稍后再看",
        .settingsPrevious: "上一步",
        .settingsFinish: "完成",
        .settingsNext: "下一步",
        .replacementEditorTitle: "编辑替换内容",
        .replacementEditorEditingFormat: "正在编辑 #%@",
        .replacementUnsavedTitle: "替换内容尚未应用",
        .replacementApplyChanges: "应用更改",
        .replacementDiscardChanges: "放弃更改",
        .replacementContinueEditing: "继续编辑",
        .replacementUnsavedMessage: "你修改了替换内容。关闭窗口前，是否要应用这些更改？",
        .clipboardTitle: "剪贴板记录",
        .clipboardClearRecords: "清空记录",
        .clipboardRecordMetric: "记录",
        .clipboardStatusMetric: "状态",
        .clipboardThresholdMetric: "阈值",
        .clipboardStatusOn: "已开启",
        .clipboardStatusOff: "已关闭",
        .clipboardTimesFormat: "%d 次",
        .clipboardSuggestionSettingsTitle: "建议设置",
        .clipboardSuggestionSettingsSubtitle: "达到阈值时会提示你把重复复制的内容保存为 Key。",
        .clipboardMonitoringToggleTitle: "记录剪贴板文本",
        .clipboardMonitoringToggleSubtitle: "关闭后不会新增历史记录，也不会弹出创建 Key 的建议。",
        .clipboardThresholdTitle: "提示阈值",
        .clipboardThresholdDescriptionFormat: "同一段文本复制到 %d 次时，询问是否创建新的 Key。",
        .clipboardRecentCopiesTitle: "最近复制",
        .clipboardEmptyTitle: "还没有记录到可用的文本复制",
        .clipboardEmptySubtitle: "复制几段常用文本后，这里会按最近时间显示历史记录，并支持一键新建 Key。",
        .clipboardHeaderEnabledFormat: "按最近复制时间排序，最多保留最近 %d 条记录，达到设定次数后会提示创建 Key。",
        .clipboardHeaderPaused: "当前已暂停记录剪贴板文本。",
        .clipboardHistoryEmptySubtitle: "还没有可用的复制记录。",
        .clipboardHistoryCountSubtitleFormat: "共 %d 条记录，最近复制的内容会排在最前面，超出后会自动滚动清理旧记录。",
        .clipboardCreatedKey: "已建Key",
        .clipboardCopiedTimesFormat: "已复制 %d 次",
        .clipboardDeleteRecord: "删除记录",
        .clipboardNewKey: "新建Key",
        .clipboardTodayFormat: "今天 %@",
        .clipboardYesterdayFormat: "昨天 %@",
        .aboutUnknownVersion: "未知版本",
        .aboutTitle: "关于 SnipKey",
        .aboutSubtitle: "查看开发者信息、GitHub 仓库地址和反馈入口。",
        .aboutSummary: "面向 macOS 的菜单栏文本扩展工具，支持 Key 管理、补全面板和剪贴板建议。",
        .aboutDeveloper: "开发者",
        .aboutRepositoryAddress: "仓库地址",
        .aboutVersion: "版本",
        .aboutRepositoryHome: "仓库主页",
        .aboutReportIssue: "反馈问题",
        .clipboardSuggestionTitleFormat: "这段内容已经复制 %d 次，要新建成 Key 吗？",
        .clipboardSuggestionMessageFormat: "重复复制的内容很适合做成 Key，后续可以直接展开使用。\n\n%@",
        .clipboardSuggestionCreateKey: "新建Key",
        .clipboardSuggestionLater: "稍后",
        .accessibilityPermissionTitle: "需要键盘访问权限",
        .accessibilityPermissionMessage: """
            SnipKey 需要键盘相关权限，才能监听触发词并展开Key。

            1. 打开“系统设置” → “隐私与安全性” → “辅助功能”
            2. 勾选“SnipKey”（或你当前启动它的应用，例如 Xcode / Terminal）
            3. 如果“输入监控”里也出现 SnipKey，请一并启用
            4. 尽量从同一个应用路径启动 SnipKey，便于 macOS 稳定保留授权
            """,
        .accessibilityOpenSettings: "打开系统设置",
        .accessibilityLater: "稍后",
        .completionNoMatches: "无匹配结果",
        .completionHeaderTitle: "候选片段",
        .completionHeaderInstruction: "点击或回车插入",
        .completionCandidateAccessibilityCountFormat: "共 %d 条候选",
        .completionRowAccessibilityHint: "点击即可插入这个片段",
        .completionRowAccessibilityLabelFormat: "触发词 #%@，内容 %@"
    ]

    private static let english: [Key: String] = [
        .menuEnable: "Enable",
        .menuGrantPermissionsEllipsis: "Grant Permissions…",
        .menuSettingsEllipsis: "Settings…",
        .menuClipboardHistoryEllipsis: "Clipboard History…",
        .menuQuitSnipKey: "Quit SnipKey",
        .menuEdit: "Edit",
        .menuUndo: "Undo",
        .menuRedo: "Redo",
        .menuCut: "Cut",
        .menuCopy: "Copy",
        .menuPaste: "Paste",
        .menuSelectAll: "Select All",
        .languageTitle: "Language",
        .settingsOnboardingPreviewReplacement: "This is my first Key.\nUse it for frequent replies, addresses, signatures, or templates.",
        .settingsUnsavedReplacementTitle: "Replacement Not Saved",
        .settingsSaveAndContinue: "Save and Continue",
        .settingsDiscardChanges: "Discard Changes",
        .commonCancel: "Cancel",
        .commonDelete: "Delete",
        .commonRestore: "Restore",
        .commonSave: "Save",
        .commonApply: "Apply",
        .commonClose: "Close",
        .commonImport: "Import",
        .commonExport: "Export",
        .commonNone: "None",
        .settingsUnsavedReplacementMessage: "The replacement text has unsaved changes. Save or discard them before continuing.",
        .settingsSidebarSubtitle: "Manage Keys, groups, and reusable text like a system setting.",
        .settingsMetricGroups: "Groups",
        .settingsTools: "Tools",
        .settingsNewGroup: "New Group",
        .settingsClipboardHistory: "Clipboard History",
        .settingsGuide: "Guide",
        .settingsAbout: "About SnipKey",
        .settingsBrowse: "Browse",
        .settingsAllKeys: "All Keys",
        .settingsGroups: "Groups",
        .settingsNoGroups: "No groups yet",
        .settingsRenameGroup: "Rename Group",
        .settingsDeleteGroup: "Delete Group",
        .settingsDeleteGroupTitle: "Delete Group?",
        .settingsDeleteGroupMessage: "Keys in this group will be kept as ungrouped. This cannot be undone.",
        .settingsNewKey: "New Key",
        .settingsNewKeyHelp: "New Key (⌘N)",
        .settingsSearchPlaceholder: "Search triggers or replacement text",
        .settingsNoKeyEmptyTitle: "No Keys yet",
        .settingsNoSearchResultTitle: "No matching Keys",
        .settingsNoKeyEmptySubtitle: "Click “New Key” in the upper-right to add one.",
        .settingsNoSearchResultSubtitle: "Try another keyword, or clear the search.",
        .settingsDeleteKey: "Delete Key",
        .settingsDeleteKeyTitle: "Delete Key?",
        .settingsDeleteKeyMessage: "This Key will be permanently deleted.",
        .settingsSelectKeyTitle: "Select a Key to edit",
        .settingsSelectKeySubtitle: "Browse by group on the left, then search or select in the middle.",
        .settingsUnsavedBadge: "Unsaved",
        .settingsOnboardingStepCreateTitle: "Create a Key here",
        .settingsOnboardingStepCreateMessage: "Every reusable text item starts from “New Key” in the upper-left. After this guide, that is your first step.",
        .settingsOnboardingStepCreateFootnote: "You can click the highlighted “New Key” button to move to the next step, or keep reading first.",
        .settingsOnboardingStepTriggerTitle: "Add the trigger here",
        .settingsOnboardingStepTriggerMessage: "Enter only the keyword, without #. When using it in another app, type something like #email_key.",
        .settingsOnboardingStepTriggerFootnote: "Triggers can contain only letters, numbers, and underscores, and must be unique.",
        .settingsOnboardingStepReplacementTitle: "Write the expanded text here",
        .settingsOnboardingStepReplacementMessage: "Use multiple lines for replies, signatures, addresses, or templates. For longer text, “Edit in Window” is more comfortable.",
        .settingsOnboardingStepReplacementFootnote: "After changing replacement text, SnipKey shows “Unsaved”. Press ⌘S or the Save button to apply it.",
        .settingsOnboardingStepGroupTitle: "Organize Keys with groups",
        .settingsOnboardingStepGroupMessage: "Put related Keys in the same group, then filter by group from the left sidebar. This helps once your library grows.",
        .settingsOnboardingStepGroupFootnote: "When you finish, return to the upper-left and create your first saved Key.",
        .settingsResultCountFormat: "%d results",
        .settingsSearchPartFormat: "Search “%@”",
        .settingsCurrentGroup: "Current group",
        .settingsAllTextExpansions: "All available text expansions",
        .settingsKeyDetails: "Key Details",
        .settingsDetailEmptySubtitle: "Configure the trigger, replacement text, and group.",
        .settingsUngrouped: "Ungrouped",
        .settingsAcceptedTimesFormat: "Accepted %d times",
        .settingsClipboardStatusEnabledFormat: "Clipboard history %d records · threshold %d",
        .settingsClipboardStatusDisabled: "Clipboard history is off",
        .settingsTriggerEmpty: "Trigger cannot be empty.",
        .settingsTriggerInvalid: "Only letters, numbers, and underscores are allowed.",
        .settingsTriggerDuplicate: "This trigger already exists. Choose another one.",
        .settingsTriggerHelp: "Use letters, numbers, and underscores only. Must be unique.",
        .settingsTriggerTitle: "Trigger",
        .settingsTriggerPlaceholder: "Example: email_key",
        .settingsReplacementTitle: "Replacement Text",
        .settingsReplacementSubtitle: "This text is inserted after accepting a Key.",
        .settingsEditInWindow: "Edit in Window",
        .settingsGroupTitle: "Group",
        .settingsVariablesTitle: "Variables",
        .settingsVariablesSubtitle: "Dynamic variables available in replacement text.",
        .settingsVariableCurrentDate: "Current date",
        .settingsVariableCurrentTime: "Current time",
        .settingsVariableClipboardText: "Clipboard text",
        .settingsVariableCursorPosition: "Cursor position",
        .settingsRenameGroupTitle: "Rename Group",
        .settingsRenameGroupMessage: "Enter a new group name.",
        .settingsGroupNamePlaceholder: "Group name",
        .settingsDefaultReplacement: "Replacement text",
        .settingsDefaultGroupName: "New Group",
        .settingsExportPanelTitle: "Export Keys",
        .settingsImportPanelTitle: "Import Keys",
        .settingsImportPanelMessage: "Choose the SnipKey Keys file to import.",
        .settingsOnboardingGuideTitle: "Guide",
        .settingsLocatingControl: "Locating the current control…",
        .settingsWatchLater: "Later",
        .settingsPrevious: "Previous",
        .settingsFinish: "Done",
        .settingsNext: "Next",
        .replacementEditorTitle: "Edit Replacement Text",
        .replacementEditorEditingFormat: "Editing #%@",
        .replacementUnsavedTitle: "Replacement Not Applied",
        .replacementApplyChanges: "Apply Changes",
        .replacementDiscardChanges: "Discard Changes",
        .replacementContinueEditing: "Keep Editing",
        .replacementUnsavedMessage: "You changed the replacement text. Apply those changes before closing the window?",
        .clipboardTitle: "Clipboard History",
        .clipboardClearRecords: "Clear Records",
        .clipboardRecordMetric: "Records",
        .clipboardStatusMetric: "Status",
        .clipboardThresholdMetric: "Threshold",
        .clipboardStatusOn: "On",
        .clipboardStatusOff: "Off",
        .clipboardTimesFormat: "%d times",
        .clipboardSuggestionSettingsTitle: "Suggestion Settings",
        .clipboardSuggestionSettingsSubtitle: "When copied text reaches the threshold, SnipKey can suggest saving it as a Key.",
        .clipboardMonitoringToggleTitle: "Record clipboard text",
        .clipboardMonitoringToggleSubtitle: "When off, SnipKey stops adding history and stops suggesting new Keys.",
        .clipboardThresholdTitle: "Suggestion threshold",
        .clipboardThresholdDescriptionFormat: "Ask to create a new Key after the same text is copied %d times.",
        .clipboardRecentCopiesTitle: "Recent Copies",
        .clipboardEmptyTitle: "No text copies recorded yet",
        .clipboardEmptySubtitle: "After you copy reusable text, recent history appears here and can become a Key in one click.",
        .clipboardHeaderEnabledFormat: "Sorted by most recent copy. Keeps the latest %d records and suggests Keys after the threshold is reached.",
        .clipboardHeaderPaused: "Clipboard text recording is currently paused.",
        .clipboardHistoryEmptySubtitle: "No usable copy records yet.",
        .clipboardHistoryCountSubtitleFormat: "%d records. Most recent copies stay at the top; older records are trimmed automatically.",
        .clipboardCreatedKey: "Key Created",
        .clipboardCopiedTimesFormat: "Copied %d times",
        .clipboardDeleteRecord: "Delete Record",
        .clipboardNewKey: "New Key",
        .clipboardTodayFormat: "Today %@",
        .clipboardYesterdayFormat: "Yesterday %@",
        .aboutUnknownVersion: "Unknown version",
        .aboutTitle: "About SnipKey",
        .aboutSubtitle: "View developer info, the GitHub repository, and feedback links.",
        .aboutSummary: "A macOS menu bar text expansion tool with Key management, completion, and clipboard suggestions.",
        .aboutDeveloper: "Developer",
        .aboutRepositoryAddress: "Repository URL",
        .aboutVersion: "Version",
        .aboutRepositoryHome: "Repository",
        .aboutReportIssue: "Report Issue",
        .clipboardSuggestionTitleFormat: "This content has been copied %d times. Create a Key?",
        .clipboardSuggestionMessageFormat: "Repeatedly copied content is a good fit for a Key, so you can expand it directly later.\n\n%@",
        .clipboardSuggestionCreateKey: "New Key",
        .clipboardSuggestionLater: "Later",
        .accessibilityPermissionTitle: "Keyboard Access Required",
        .accessibilityPermissionMessage: """
            SnipKey needs keyboard-related permissions to monitor triggers and expand Keys.

            1. Open System Settings → Privacy & Security → Accessibility
            2. Enable SnipKey, or the app currently launching it, such as Xcode or Terminal
            3. If SnipKey also appears under Input Monitoring, enable it there too
            4. Launch SnipKey from the same app path when possible so macOS keeps the permission stable
            """,
        .accessibilityOpenSettings: "Open System Settings",
        .accessibilityLater: "Later",
        .completionNoMatches: "No Matches",
        .completionHeaderTitle: "Candidate Snippets",
        .completionHeaderInstruction: "Click or press Return to insert",
        .completionCandidateAccessibilityCountFormat: "%d candidates",
        .completionRowAccessibilityHint: "Click to insert this snippet",
        .completionRowAccessibilityLabelFormat: "Trigger #%@, content %@"
    ]
}