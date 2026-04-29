# SnipKey Windows 版设计与首版实现

日期：2026-04-28

## 成功标准

首版 Windows 实现要先形成可手工验证的最小闭环：

1. 应用能以 Windows 托盘程序运行，并能打开 Key 管理窗口。
2. 用户能创建、编辑、删除、导入、导出 Key，数据写入 `%APPDATA%\SnipKey\snippets.json`。
3. 在其他应用中输入 `#trigger` 后能看到候选，支持上下选择、`Tab`/`Enter` 确认和鼠标确认。
4. 确认后删除已输入触发文本，并通过剪贴板粘贴替换内容。
5. `{date}`、`{time}`、`{clipboard}`、`{cursor}` 与 macOS 版语义保持一致。

## 关键假设

- Windows 版不复用 SwiftUI/AppKit UI。Swift 源码中的 `SnipKeyCore` 行为按规则移植到 C#，平台集成用 Win32/WPF 实现。
- 首版以 Windows 10 19041+ / Windows 11 和 .NET 8 SDK 为基线。
- 触发词仍然只支持 ASCII 字母、数字和下划线；这是 macOS 当前实现的稳定性约束，也降低了 Windows IME 组合输入的不确定性。
- JSON 数据结构保持字段名兼容，但 macOS 默认路径和 Windows 默认路径不同，跨平台迁移通过导入导出完成。

## 现有仓库证据

- Core 行为来自 `Sources/SnipKeyCore`：`SnippetEngine`、`SnippetTriggerRules`、`SnippetStore`、`VariableResolver`。
- macOS 平台绑定来自 `Sources/SnipKeyApp`：`KeyboardMonitor` 使用 CGEvent tap，`TextReplacer` 使用 AppKit pasteboard 和模拟按键，`CompletionPanel` 使用 AppKit/SwiftUI 浮窗。
- 这些平台绑定都不能直接搬到 Windows，因此 Windows 版放在 `Windows/SnipKey.Windows`，减少对现有 macOS 包的扰动。

## 模块设计

```text
Windows/SnipKey.Windows/
├── Core/                 # C# 行为移植：模型、触发规则、匹配、存储、变量解析
├── Platform/             # Windows 专属能力：键盘 hook、光标定位、SendInput、剪贴板粘贴
├── UI/                   # WPF 候选弹窗和设置窗口
├── AppController.cs      # 托盘、Core、Platform、UI 的协调层
└── Program.cs            # 单实例 WPF 入口
```

### Core

Core 层保持与 macOS 版一致的产品规则：

- `Snippet`、`SnippetGroup`、`SnippetData` 使用 `id`、`trigger`、`replacement`、`groupId`、`acceptanceCount`、`groups`、`snippets` JSON 字段。
- `SnippetTriggerRules` 保持触发词字符约束、大小写不敏感唯一性和冲突后缀规则。
- `SnippetEngine` 保持精确命中优先、接受次数优先、trigger 字典序兜底的排序策略。
- `VariableResolver` 支持日期、时间、剪贴板和光标变量。

### Platform

Windows 平台层对应 macOS 实现中的系统 API 边界：

- `GlobalKeyboardHook` 用 `WH_KEYBOARD_LL` 监听全局按键。
- `KeyboardMonitor` 维护 `#` 捕获缓冲区，并发出 query 更新、完成、取消、选择移动和确认事件。
- `CaretPositionProvider` 优先通过 `GetGUIThreadInfo` 定位 caret，失败时回退到鼠标位置。
- `TextReplacer` 用 `SendInput` 删除触发文本，再临时写入剪贴板并发送 `Ctrl+V`，最后恢复剪贴板。

### UI

- `CompletionWindow` 是不抢焦点的置顶 WPF 弹窗，用于候选展示、上下选择和鼠标确认。
- `SettingsWindow` 是首版 Key 管理界面，覆盖创建、编辑、删除、导入和导出。
- 托盘菜单提供启用开关、打开设置、重载 Key 和退出。

#### 2026-04-29 UI 质感优化

本轮优化只调整 Windows UI 表现层，不改变 Core、平台 hook、数据结构或替换语义。目标是让 Windows 版在 MVP 基础上更接近 macOS 版的视觉层次和直接交互：

- `UiTheme` 集中管理 WPF 色彩、圆角、阴影、按钮、输入框和列表项样式，避免设置窗与候选窗各自散落硬编码视觉参数。
- `CompletionWindow` 对齐 macOS 候选面板的轻量材质感：圆角面板、柔和阴影、header 计数、trigger 胶囊、候选行 hover/selected 状态和左侧选中强调条。
- `SettingsWindow` 改为更清晰的 sidebar + detail 布局：左侧品牌/统计/搜索/Key 列表，右侧 trigger 与 replacement 编辑区，底部状态栏保留导入、导出、保存等反馈。
- 鼠标悬停选择、单击确认、键盘上下移动和确认仍沿用 MVP 的既有事件流，避免引入新的替换风险。

## 首版不做的内容

- 剪贴板历史和重复复制建议：需要移植 `ClipboardHistoryStore`、剪贴板监听与提示策略，行为面较大，放到第二阶段。
- 完整多语言：当前 Windows MVP 使用英文 UI 文案；后续应移植 `L10n` 对应结构。
- IME/辅助功能读回：首版依赖低级键盘 hook 的 ASCII trigger 缓冲。若要和 macOS 的 post-terminator reconciliation 对齐，需要引入 UI Automation 或 Text Services Framework 评估。
- 安装包、签名、开机自启、自动更新：这些属于分发阶段，不阻塞功能闭环验证。

## 验证计划

最便宜的有用验证：

1. 在 Windows 机器上运行 `dotnet build .\Windows\SnipKey.Windows\SnipKey.Windows.csproj`。
2. 运行应用，确认托盘图标出现，设置窗口可打开。
3. 新建 `account -> hello`，到 Notepad 输入 `#account` 后按空格，确认替换成 `hello`。
4. 新建包含 `{cursor}` 的 Key，确认替换后光标回退到预期位置。
5. 导出 JSON 后导入 macOS 版，确认字段兼容；反向也做一次。

## 风险

- `WH_KEYBOARD_LL` 可能受安全软件、管理员权限边界或远程桌面环境影响。若 hook 启动失败，托盘会提示，但仍需要 Windows 实机验证。
- 不同应用对模拟 backspace 和 `Ctrl+V` 的接受程度不同，尤其是高权限窗口、终端和浏览器安全输入框。
- `GetGUIThreadInfo` 不能覆盖所有现代 UI 框架，候选弹窗可能回退到鼠标附近。
- 当前没有 Windows CI，本机 macOS 也未安装 .NET SDK，因此首版 C# 工程仍需要在 Windows 上完成构建验证。
