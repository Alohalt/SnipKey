# SnipKey Windows 与 macOS 功能对齐计划

日期：2026-04-30

## 目标

把当前 Windows MVP 从“可用闭环”推进到尽量接近仓库中现有 macOS 版本的已交付能力，后续开发按这个顺序逐阶段落地。

本计划以当前仓库里的 macOS 已实现功能为对齐目标，不把云同步、富文本片段、按应用启用规则等尚未交付到主产品的未来项纳入本轮范围。

## 成功标准

Windows 版完成本计划后，应满足以下结果：

1. 设置窗口支持与 macOS 版相近的信息架构：分组浏览、Key 列表、详情编辑、工具入口、首次引导。
2. 剪贴板历史、重复复制建议建 Key、从剪贴板创建 Key 的默认 trigger 生成逻辑与 macOS 行为一致。
3. Windows 版所有用户可见文案支持英文和简体中文，语言偏好独立持久化，默认语言与 macOS 保持一致。
4. 托盘菜单、设置页入口、候选弹窗交互尽量与 macOS 版一致，至少补齐 clipboard history、guide/about、首次引导和点击外部取消补全等关键体验。
5. 针对 Windows 特有的 IME、剪贴板监听、打包分发约束，形成单独实现与验证路径，不再停留在 MVP 假设。

## 仓库证据

当前差距不是抽象猜测，而是可以直接从仓库看到：

- macOS 端已接入 `ClipboardHistoryStore`、`ClipboardMonitor`、`AppLanguageStore`、首次 onboarding、外部点击取消补全和 clipboard history 菜单入口。证据见 `Sources/SnipKeyApp/AppDelegate.swift`。
- macOS 菜单栏已经有 Enable、Permissions、Settings、Clipboard History、Quit 等入口。证据见 `Sources/SnipKeyApp/MenuBarController.swift`。
- macOS 设置页已经有分组、工具区、guide、about、语言切换、clipboard history sheet 和 onboarding。证据见 `Sources/SnipKeyApp/SettingsView.swift`、`Sources/SnipKeyApp/ClipboardHistorySheet.swift`、`Sources/SnipKeyApp/AboutSheet.swift`。
- macOS 本地化已经由 `AppLanguage`、`AppLanguageStore` 和 `L10n` 统一管理。证据见 `Sources/SnipKeyApp/AppLanguage.swift`、`Sources/SnipKeyApp/AppLanguageStore.swift`、`Sources/SnipKeyApp/L10n.swift`。
- macOS 输入链路已经使用 `TriggerContextAnalyzer` 做触发词完成判断，剪贴板建 Key 使用 `SnippetTriggerSuggester`。证据见 `Sources/SnipKeyApp/KeyboardMonitor.swift`、`Sources/SnipKeyApp/ClipboardSnippetFactory.swift`、`Sources/SnipKeyCore/TriggerContextAnalyzer.swift`、`Sources/SnipKeyCore/SnippetTriggerSuggester.swift`。
- Windows 当前代码树只有 `AppController`、MVP 版 `SettingsWindow`、`CompletionWindow`、基础 Core 和 Platform 文件，尚无 clipboard history、语言、about、guide、onboarding 等对应实现。证据见 `Windows/SnipKey.Windows/**/*.cs` 当前文件集合。
- Windows Core 已经保留了 `groups` 和 `groupId` 数据结构，但 Settings UI 还没有暴露分组管理和分组筛选。证据见 `Windows/SnipKey.Windows/Core/SnippetStore.cs`、`Windows/SnipKey.Windows/Core/Snippet.cs` 和 `Windows/SnipKey.Windows/UI/SettingsWindow.cs`。

## 当前差距清单

| 领域 | macOS 已有能力 | Windows 当前状态 | 结论 |
| --- | --- | --- | --- |
| 分组与设置信息架构 | 三栏设置、分组、工具区、group assignment、inline helper text | 只有 Key 列表和详情编辑，分组仅存在于数据层 | 需要补完整设置架构，而不是继续在现有单窗口上堆按钮 |
| 剪贴板历史与建议建 Key | `ClipboardHistoryStore`、`ClipboardMonitor`、`ClipboardHistorySheet`、suggestion prompt | 无对应 Core、Platform、UI 文件 | 是最大功能缺口之一 |
| 语言与文案 | `AppLanguage`、`AppLanguageStore`、`L10n`，默认简体中文 | 全部文案硬编码英文 | 需要先补基础设施再扩 UI |
| 首次引导 / guide / about | 首次启动自动打开设置并展示 guide，可手动重开，有 About sheet | 无 onboarding、guide、about 入口 | 需要在设置页和托盘侧一起补 |
| 菜单/托盘入口 | Enable、Permissions、Settings、Clipboard History、Quit | Enabled、Settings、Reload、Quit | 需要按 Windows 语义重做入口集合 |
| 补全面板会话控制 | 支持点击外部一次取消 | Windows 代码里没有对应的全局鼠标取消逻辑 | 需要补齐 |
| 输入上下文鲁棒性 | `TriggerContextAnalyzer` 已接入输入完成判断 | Windows 仍是低级 hook 缓冲逻辑，未移植 analyzer，也未做 IME 对齐 | 需要单独阶段处理 |
| 交付与运行时工程化 | macOS 已有签名/开发运行/打包文档与流程 | Windows 仍是裸 `dotnet run` / `dotnet build` | 功能对齐后还要补交付对齐 |

## 实施原则

1. 不重写现有 Windows 技术栈。继续使用 code-only WPF + Win32 集成，不为了“像 macOS”而切到 XAML 或其他 UI 框架。
2. 优先复用现有数据结构。`SnippetStore` 已支持 `groups`，不要再设计第二套模型。
3. 先补基础设施，再补表层 UI。多语言、共享状态、clipboard history Core 不先到位，后续 UI 改动都会返工。
4. 每个阶段都要有最便宜的可验证闭环，避免先铺大量 UI 再发现底层不成立。
5. IME 和剪贴板监听属于高风险边界，必须单列阶段，不和普通 UI 打磨混在一起。

## 分阶段计划

### 阶段 1：补齐应用状态与多语言基础设施

目标：先把 Windows 端的共享状态和文案系统建立起来，避免后续继续硬编码英文字符串。

范围：

- 新增 Windows 版 `AppLanguage`、`AppLanguageStore`、`L10n` 对应实现。
- 用统一文案替换 `AppController.cs`、`SettingsWindow.cs`、`CompletionWindow.cs` 中的硬编码字符串。
- 把语言偏好独立持久化，默认语言与 macOS 保持为简体中文。
- 视需要新增 Windows 版设置协调器，承接“打开设置并聚焦某个对象”“打开 clipboard history”“重新展示 guide”等跨界面请求。

建议新增/修改文件：

- `Windows/SnipKey.Windows/AppLanguage.cs`
- `Windows/SnipKey.Windows/AppLanguageStore.cs`
- `Windows/SnipKey.Windows/L10n.cs`
- `Windows/SnipKey.Windows/AppController.cs`
- `Windows/SnipKey.Windows/UI/SettingsWindow.cs`
- `Windows/SnipKey.Windows/UI/CompletionWindow.cs`

依赖关系：无，应最先做。

最便宜验证：

1. 运行 `dotnet build .\Windows\SnipKey.Windows\SnipKey.Windows.csproj`
2. 启动应用，切换语言，确认设置页、候选弹窗、托盘菜单文案同步变化
3. 重启应用，确认语言偏好保留

阶段验收：所有用户可见文案都不再写死在窗口代码里。

### 阶段 2：补齐设置窗口的信息架构与分组管理

目标：把 Windows 设置页从“Key CRUD 面板”升级成和 macOS 接近的工作台。

范围：

- 基于现有 `groups` 数据模型增加分组 sidebar、All Keys、group filter、group CRUD。
- 在详情区增加 group assignment，而不是只保留 trigger/replacement。
- 把当前 status bar 式 trigger 校验，补成更接近 macOS 的 inline helper text。
- 增加工具区入口：Clipboard History、Guide、About、Language。
- 保持现有导入/导出 JSON 兼容，不改 schema。

建议新增/修改文件：

- `Windows/SnipKey.Windows/UI/SettingsWindow.cs`
- `Windows/SnipKey.Windows/Core/SnippetStore.cs`
- `Windows/SnipKey.Windows/UI/UiTheme.cs`
- 视实现复杂度新增 `Windows/SnipKey.Windows/UI/AboutWindow.cs`

依赖关系：依赖阶段 1 的多语言与共享状态。

最便宜验证：

1. 新建分组、重命名分组、删除分组
2. 把 Key 分配到不同分组，确认筛选和保存生效
3. 导出 JSON 后重新导入，确认 `groups` 与 `groupId` 没丢

阶段验收：Windows 设置页在信息架构上不再明显落后于 macOS 主设置页。

### 阶段 3：移植 clipboard history、suggestion 与剪贴板建 Key 流程

目标：补齐当前 Windows 最大的功能缺口，让 clipboard history 和重复复制建议行为与 macOS 对齐。

范围：

- 把 `ClipboardHistoryStore` 移植到 Windows Core。
- 把 `SnippetTriggerSuggester` 移植到 Windows Core，保证从剪贴板内容创建 Key 时的默认 trigger 逻辑一致。
- 评估并实现 Windows 剪贴板监听策略，优先考虑 `AddClipboardFormatListener` 或稳定的序列号轮询方案。
- 补齐“忽略应用自身粘贴写入”的逻辑，避免 SnipKey 的替换结果反向污染 clipboard history。
- 增加 clipboard history 窗口或 sheet，支持 monitoring toggle、suggestion threshold、recent copies、create snippet、clear history。
- 增加重复复制建议提示，支持一键创建 Key。

建议新增/修改文件：

- `Windows/SnipKey.Windows/Core/ClipboardHistoryStore.cs`
- `Windows/SnipKey.Windows/Core/SnippetTriggerSuggester.cs`
- `Windows/SnipKey.Windows/AppController.cs`
- `Windows/SnipKey.Windows/Platform/ClipboardMonitor.cs`
- `Windows/SnipKey.Windows/UI/ClipboardHistoryWindow.cs`
- 视需要新增 `Windows/SnipKey.Windows/UI/ClipboardSnippetFactory.cs`

依赖关系：依赖阶段 1 的多语言和阶段 2 的设置工具入口。

最便宜验证：

1. 连续复制同一段文本达到阈值，出现 suggestion prompt
2. 通过 suggestion 创建 Key，确认默认 trigger 与 macOS 规则一致
3. 打开 clipboard history，确认 recent records、清空记录、开关监控、阈值调整都生效

阶段验收：Windows 不再需要把 clipboard history 标为 deferred；README 和设计文档里的 MVP 限制可同步收窄。

### 阶段 4：补齐托盘入口、首次引导、Guide 和 About

目标：把 Windows 应用层入口和首次使用路径补齐到接近 macOS。

范围：

- 托盘菜单新增 clipboard history 入口。
- 把 macOS 的“Grant Permissions”概念转换成适合 Windows 的诊断/帮助入口，而不是机械照抄 Accessibility 文案。
- 首次启动自动打开设置，并只展示一次 onboarding/guide。
- 设置页支持用户手动重新打开 guide。
- 增加 About 窗口，至少覆盖版本、项目链接、核心说明。

建议新增/修改文件：

- `Windows/SnipKey.Windows/AppController.cs`
- `Windows/SnipKey.Windows/UI/SettingsWindow.cs`
- `Windows/SnipKey.Windows/UI/AboutWindow.cs`
- 视实现需要新增 `Windows/SnipKey.Windows/SettingsCoordinator.cs`

依赖关系：依赖阶段 1 和阶段 2。

最便宜验证：

1. 在干净用户配置下首次启动应用，确认自动打开设置并展示 guide
2. 托盘菜单可打开设置、clipboard history、help/about
3. Guide 关闭后可从设置页再次手动打开

阶段验收：Windows 首次使用体验不再只是“启动后自己找入口”。

### 阶段 5：补齐候选弹窗会话控制与输入上下文鲁棒性

目标：补上当前最容易导致行为偏差的输入链路缺口。

范围：

- 给 Windows 候选弹窗增加“点击外部一次即取消当前补全会话”的能力。
- 评估是否移植 `TriggerContextAnalyzer`，或者引入更适合 Windows 的 text-before-cursor 读取策略。
- 针对 IME、终端、浏览器输入框做最小可行兼容方案，不要求一步做到完美，但要把行为边界写清楚。
- 复查候选弹窗选中、确认、取消和 replacement target capture 的一致性。

建议新增/修改文件：

- `Windows/SnipKey.Windows/Core/TriggerContextAnalyzer.cs`
- `Windows/SnipKey.Windows/AppController.cs`
- `Windows/SnipKey.Windows/Platform/KeyboardMonitor.cs`
- `Windows/SnipKey.Windows/UI/CompletionWindow.cs`

依赖关系：可与阶段 4 并行一部分，但建议在 clipboard history 之后集中做。

最便宜验证：

1. 在 Notepad 输入 `#account` 后弹出候选，点击外部一次，候选立即消失且不会误替换
2. 在至少一个中文 IME 场景下验证 trigger 完成判断不会明显错删或误触发
3. 在浏览器文本框与终端中验证基础替换行为仍可用，并记录不支持场景

阶段验收：Windows 候选交互和输入完成语义不再只停留在 MVP 假设。

### 阶段 6：补齐 Windows 交付与运行时工程化

目标：在功能对齐之后，把 Windows 的开发和发布流程补到可长期维护的水平。

范围：

- 选择并固化 Windows 分发形式：MSIX、MSI/NSIS 或其他方案，避免一直停留在裸 `dotnet run`。
- 增加 Windows 开发签名/打包/安装文档，形成与 macOS `development-signing` 类似的开发路径。
- 评估是否加入开机自启、升级、卸载等运行时能力。
- 补 CI 或至少补脚本，让 Windows 构建不只依赖手工命令。

建议新增/修改文件：

- `Windows/README.md`
- `Makefile`
- 新的 Windows 分发文档，例如 `docs/windows-packaging.md`
- 视选型新增打包脚本或 installer 配置

依赖关系：建议在前五个阶段基本完成后再做。

最便宜验证：

1. 在干净 Windows 机器上完成安装、启动、卸载一轮
2. 构建产物能稳定启动，不依赖仓库源码目录
3. 发布文档足够让另一台机器复现

阶段验收：Windows 版不再只是开发机上的 MVP，而是有可维护交付路径的产品分支。

## 建议实施顺序

推荐严格按下面顺序推进，而不是并行大面积铺开：

1. 阶段 1：多语言与共享状态基础设施
2. 阶段 2：设置窗口与分组管理
3. 阶段 3：clipboard history 与 suggestion
4. 阶段 4：托盘入口、guide、about、首次引导
5. 阶段 5：外部点击取消补全与 IME / 输入鲁棒性
6. 阶段 6：打包、签名、开机自启、发布工程化

原因：阶段 1 和阶段 2 会决定后续 UI 和状态流的骨架；阶段 3 依赖这些骨架；阶段 5 风险最高，应放在核心功能对齐之后集中处理；阶段 6 不应阻塞功能对齐。

## 风险、弱项与待决策点

有希望的部分：

- Windows Core 已经保留了 `groups`/`groupId`，这说明分组能力不是从零开始。
- Windows 当前 UI 仍是 code-only WPF，结构相对集中，适合逐阶段追加工具区、clipboard history 和 onboarding，而不用先重构框架。
- macOS 侧核心算法已经存在，`ClipboardHistoryStore`、`SnippetTriggerSuggester`、`TriggerContextAnalyzer` 都可以按语义移植，而不是重新发明规则。

薄弱和高风险部分：

- Windows 剪贴板监听的稳定性取决于具体 API 选型和 UI 线程整合。
- IME / TSF / 浏览器安全输入框的行为明显比 macOS MVP 更复杂，不能乐观假设低级键盘 hook 足够。
- 如果太早做 installer / auto-start / update，容易把精力从功能对齐上拉走。

当前仍缺的关键证据：

- Windows 上哪种 clipboard monitoring 方案在 WPF + tray app 里最稳。
- 哪些 IME / 终端 / 高权限窗口场景必须支持，哪些可以明确写为限制。
- Windows 发布形式最终选 MSIX 还是传统 installer，更适合这个项目的 tray app 形态。

最便宜的有用验证：

在每一阶段都保持“先 `dotnet build`，再用 Windows 实机做一条最小手工链路验证”，不要等到所有阶段都写完再统一试跑。

## 建议的阶段验收矩阵

后续每阶段结束至少跑下面这些最小检查：

| 检查项 | 目的 |
| --- | --- |
| `dotnet build .\Windows\SnipKey.Windows\SnipKey.Windows.csproj` | 保证 Windows 主工程持续可编译 |
| Settings 基础 CRUD | 防止 UI 重构破坏原 MVP 闭环 |
| `#trigger` 在 Notepad 中替换 | 保证核心输入路径未回退 |
| 导入/导出与重启后数据保留 | 保证 schema 和持久化没被破坏 |
| 新增阶段特有手工用例 | 例如语言切换、clipboard history、guide、外部点击取消等 |

## 结论

Windows 版当前离 macOS 版的主要差距，不是“还差一点 UI 打磨”，而是还缺一整层应用功能：clipboard history、suggestion、group workflow、multi-language、guide/about、tray parity 和输入鲁棒性。

最合理的推进方式不是继续零散补点，而是按本计划逐阶段收口：先补基础设施，再补设置和 clipboard history，再补应用入口与高风险输入边界，最后补分发工程化。
