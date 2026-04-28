# SnipKey

[English](README.md) | 简体中文

SnipKey 是一个面向 macOS 的菜单栏文本扩展工具。用户在任意应用中输入 `#trigger`，即可通过补全面板选择或直接展开为预设文本。

当前分支新增了原生 Windows MVP，位于 `Windows/SnipKey.Windows`。它使用 .NET 8 WPF 实现托盘应用，并保持与 macOS 版一致的 `snippets.json` 数据结构。

项目主页：<https://alohalt.github.io/SnipKey/>（由 `site/` 目录通过 GitHub Actions 部署，仓库 Settings → Pages 中需选择 “GitHub Actions” 作为部署源）。

## 当前能力

- 全局监听键盘输入，在系统范围内捕获 `#` 前缀触发词。
- 浮动补全面板跟随光标显示匹配结果，支持上下选择、`Tab` 或 `Enter` 确认、`Esc` 取消，也支持鼠标悬停高亮与单击确认。
- 补全面板点击外部一次即取消当前补全会话，避免在焦点已切走时继续尝试替换到错误位置。
- 菜单栏常驻运行，可快速打开权限引导、设置窗口和剪贴板记录。
- 原生三栏设置界面，支持分组、搜索、创建、编辑、删除和 JSON 导入导出。
- 支持英文和简体中文界面语言切换，默认保留简体中文；切换只影响界面文案，不迁移已有 Key、分组或剪贴板内容。
- 触发词仅支持字母、数字和下划线，并在保存时执行唯一性校验。
- 支持动态变量：`{date}`、`{time}`、`{clipboard}`、`{cursor}`。
- 记录剪贴板历史，并在内容被重复复制时建议一键生成新的 Key，默认会本地生成简短 trigger；界面滚动保留最近 50 条记录，建议计数独立于可见历史。
- 使用接受次数对候选排序，常用 Key 会优先展示。

## 项目结构

```text
.
├── Sources/
│   ├── SnipKeyCore/      # 可测试的核心逻辑：数据模型、匹配、变量解析、持久化
│   └── SnipKeyApp/       # macOS 应用层：菜单栏、权限、键盘监听、设置界面、补全面板
├── Windows/
│   └── SnipKey.Windows/  # 原生 Windows MVP：托盘、全局键盘 hook、设置页、补全面板
├── Tests/
│   └── SnipKeyCoreTests/ # Core 层单元测试
├── Resources/            # Info.plist、entitlements、图标资源
├── Scripts/              # 辅助脚本
└── docs/                 # 设计、签名流程和需求记录
```

## 环境要求

- macOS 13+
- Swift 5.9+
- Xcode（建议，用于签名和权限稳定性）
- 辅助功能权限

Windows MVP 环境要求：

- Windows 10 19041+ 或 Windows 11
- .NET 8 SDK

## 快速开始

推荐使用已签名的开发包运行，而不是直接 `swift run`。这样 macOS 会把辅助功能权限绑定到稳定的应用身份上，避免每次重新构建后权限失效。

```bash
make signing-help
make bootstrap-personal-team
make run
```

如果本机已经有可用的 `Apple Development` 证书，通常直接执行下面两条就够了：

```bash
make test
make run
```

常用命令：

```bash
make build        # SwiftPM 构建
make test         # 运行单元测试
make run          # 安装并启动签名后的开发版应用
make run-swift    # 直接运行 Swift 可执行文件，不推荐用于权限调试
make windows-build # 在安装 .NET 8 SDK 的 Windows 机器上构建 Windows MVP
make windows-run  # 在 Windows 上运行 Windows MVP
make verify-dev   # 检查开发包签名信息
make package-dmg  # 生成可分发的 DMG
```

更完整的签名说明见 [docs/development-signing.md](docs/development-signing.md)。

## 使用方式

1. 启动应用后，从菜单栏打开“设置”。
2. 新建一个 Key，例如触发词 `account`，替换内容填入需要插入的文本。触发词仅支持字母、数字和下划线，且不能与现有 Key 重复。
3. 回到任意可输入文本的应用，输入 `#account`。
4. 使用 `Tab`、`Enter` 或鼠标单击候选项确认展开；点击提示栏外部会取消本次候选。

可在设置页左侧“工具”区域切换界面语言，当前支持 English 与简体中文。

展开时，SnipKey 会删除已输入的触发内容，再插入解析后的结果文本。

如果本地已有中文、非法字符或重复的 trigger，应用会在加载或导入时自动将它们归一化为合法且唯一的新 trigger。

## 数据存储

- Key 数据：`~/Library/Application Support/SnipKey/snippets.json`
- 剪贴板历史：`~/Library/Application Support/SnipKey/clipboard-history.json`（界面滚动保留最近 50 条；清空记录会同时重置建议计数）
- 界面语言偏好：`UserDefaults` 中的 `SnipKey.appLanguage`，不写入 Key 或剪贴板 JSON。

## 测试

当前仓库主要覆盖 `SnipKeyCore`：

- `SnippetStoreTests`
- `SnippetEngineTests`
- `VariableResolverTests`
- `ClipboardHistoryStoreTests`
- `ModelsTests`

AppKit 和系统权限相关行为目前以手工验证为主。

## 相关文档

- [docs/development-signing.md](docs/development-signing.md)
- [docs/plans/2026-04-15-snipkey-mac-design.md](docs/plans/2026-04-15-snipkey-mac-design.md)
- [docs/plans/2026-04-15-snipkey-implementation.md](docs/plans/2026-04-15-snipkey-implementation.md)
- [docs/requirements-change-log.md](docs/requirements-change-log.md)
