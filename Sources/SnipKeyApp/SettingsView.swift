import AppKit
import SwiftUI
import SnipKeyCore

struct SettingsView: View {
    private enum SidebarSelection: Hashable {
        case all
        case group(UUID)

        var groupId: UUID? {
            if case let .group(id) = self {
                return id
            }
            return nil
        }
    }

    private enum PendingSettingsAction {
        case selectSnippet(UUID?, sidebar: SidebarSelection?)
        case selectSidebar(SidebarSelection)
        case createSnippet
    }

    private let headerCardHeight: CGFloat = 44
    private let replacementPreviewHeight: CGFloat = 68
    private let onboardingExampleTrigger = "first_key"
    private let onboardingPreviewReplacement = "这是我的第一条 Key。\n你可以把常用回复、地址、签名或模板放在这里。"

    @ObservedObject var store: SnippetStore
    @ObservedObject var clipboardHistoryStore: ClipboardHistoryStore
    @ObservedObject var coordinator: SettingsCoordinator
    @State private var selectedSidebarSelection: SidebarSelection? = .all
    @State private var selectedSnippetId: UUID? = nil
    @State private var editingTrigger: String = ""
    @State private var editingReplacement: String = ""
    @State private var editingGroupId: UUID? = nil
    @State private var showDeleteSnippetConfirm = false
    @State private var showDeleteGroupConfirm = false
    @State private var showUnsavedReplacementPrompt = false
    @State private var showOnboardingGuide: Bool
    @State private var onboardingStepIndex = 0
    @State private var showReplacementEditor = false
    @State private var replacementEditorDraft: String = ""
    @State private var snippetToDelete: UUID? = nil
    @State private var groupToDelete: UUID? = nil
    @State private var pendingSettingsAction: PendingSettingsAction? = nil
    @State private var showClipboardHistorySheet = false
    @State private var showAboutSheet = false
    @State private var snippetSearchText: String = ""

    init(
        store: SnippetStore,
        clipboardHistoryStore: ClipboardHistoryStore,
        coordinator: SettingsCoordinator,
        initiallyShowsOnboarding: Bool = false
    ) {
        self.store = store
        self.clipboardHistoryStore = clipboardHistoryStore
        self.coordinator = coordinator
        _showOnboardingGuide = State(initialValue: initiallyShowsOnboarding)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebarColumn
                .frame(width: 306)

            snippetBrowserColumn
                .frame(width: 272)

            detailColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 920, minHeight: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlayPreferenceValue(SettingsOnboardingFramePreferenceKey.self) { anchors in
            if showOnboardingGuide {
                SettingsOnboardingOverlay(
                    step: currentOnboardingStep,
                    stepIndex: onboardingStepIndex,
                    stepCount: onboardingSteps.count,
                    targetAnchor: anchors[currentOnboardingStep.target],
                    onClose: dismissOnboardingGuide,
                    onPrevious: previousOnboardingStep,
                    onNext: nextOnboardingStep
                )
                .zIndex(10)
            }
        }
        .sheet(isPresented: $showReplacementEditor) {
            ReplacementEditorSheet(
                trigger: editingTrigger,
                originalText: editingReplacement,
                text: $replacementEditorDraft,
                onCancel: { showReplacementEditor = false },
                onApply: applyReplacementEditorChanges
            )
        }
        .sheet(isPresented: $showClipboardHistorySheet) {
            ClipboardHistorySheet(
                historyStore: clipboardHistoryStore,
                onCreateSnippet: createSnippetFromClipboardRecord
            )
        }
        .sheet(isPresented: $showAboutSheet) {
            AboutSheet()
        }
        .confirmationDialog(
            "替换内容尚未保存",
            isPresented: $showUnsavedReplacementPrompt,
            titleVisibility: .visible
        ) {
            Button("保存并继续") {
                saveEditing()
                applyPendingSettingsAction()
            }

            Button("放弃更改", role: .destructive) {
                discardUnsavedReplacementChanges()
                applyPendingSettingsAction()
            }

            Button("取消", role: .cancel) {
                pendingSettingsAction = nil
            }
        } message: {
            Text("替换内容有未保存的修改。继续操作前，请先保存或放弃这些更改。")
        }
        .onChange(of: selectedSnippetId) { newValue in
            if let id = newValue, let snippet = store.snippets.first(where: { $0.id == id }) {
                editingTrigger = snippet.trigger
                editingReplacement = snippet.replacement
                editingGroupId = snippet.groupId
            }
        }
        .onChange(of: editingTrigger) { newValue in
            autoSaveTrigger(newValue)
        }
        .onChange(of: editingGroupId) { newValue in
            autoSaveGroup(newValue)
        }
        .onChange(of: selectedSidebarSelection) { _ in
            syncSnippetSelectionToCurrentFilter()
        }
        .onAppear {
            if showOnboardingGuide {
                beginOnboardingGuide()
            }
        }
        .onChange(of: showOnboardingGuide) { newValue in
            if newValue {
                beginOnboardingGuide()
            }
        }
        .onReceive(coordinator.$focusRequest.compactMap { $0 }) { request in
            focusSnippet(request.snippetId)
            coordinator.consumeFocusRequest(request)
        }
        .onReceive(coordinator.$clipboardHistoryRequestId.compactMap { $0 }) { requestId in
            showClipboardHistorySheet = true
            coordinator.consumeClipboardHistoryRequest(requestId)
        }
        .onChange(of: onboardingStepIndex) { _ in
            prepareOnboardingPreviewIfNeeded()
        }
    }

    // MARK: - Sidebar (Groups)

    private var sidebarColumn: some View {
        VStack(spacing: 0) {
            sidebarHeader
            sidebar
            sidebarTools
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SnipKey")
                .font(.system(size: 25, weight: .bold, design: .rounded))

            Text("像系统设置一样管理你的 Key、分组和常用文本。")
                .font(.caption)
                .foregroundColor(.secondary)

            sidebarOverviewPanel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var sidebarOverviewPanel: some View {
        HStack(spacing: 10) {
            overviewMetricCard(title: "Key", value: "\(store.snippets.count)", systemImage: "number.square")
            overviewMetricCard(title: "分组", value: "\(store.groups.count)", systemImage: "folder")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.03), radius: 12, y: 3)
        )
    }

    private var sidebarTools: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("工具")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: addGroup) {
                Label("新建分组", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)

            Button {
                showClipboardHistorySheet = true
            } label: {
                Label("剪贴板记录", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)

            Button {
                showOnboardingGuide = true
            } label: {
                Label("使用指引", systemImage: "questionmark.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)

            Button {
                showAboutSheet = true
            } label: {
                Label("关于 SnipKey", systemImage: "info.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("浏览")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    sidebarNavigationButton(
                        title: "全部Key",
                        systemImage: "tray.full",
                        count: store.snippets.count,
                        selection: .all
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("分组")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if store.groups.isEmpty {
                        Text("还没有分组")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(store.groups) { group in
                            sidebarNavigationButton(
                                title: group.name,
                                systemImage: "folder",
                                count: store.snippets(forGroup: group.id).count,
                                selection: .group(group.id)
                            )
                            .contextMenu {
                                Button {
                                    renameGroup(group)
                                } label: {
                                    Label("重命名分组", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    groupToDelete = group.id
                                    showDeleteGroupConfirm = true
                                } label: {
                                    Label("删除分组", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .confirmationDialog(
            "删除分组？",
            isPresented: $showDeleteGroupConfirm,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let id = groupToDelete {
                    store.deleteGroup(id: id)
                    if selectedSidebarSelection == .group(id) {
                        selectedSidebarSelection = .all
                    }
                    syncSnippetSelectionToCurrentFilter()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后，这个分组中的Key会保留为未分组状态，此操作无法撤销。")
        }
    }

    // MARK: - Snippet List

    private var snippetBrowserColumn: some View {
        VStack(spacing: 0) {
            snippetBrowserHeader
            snippetList
        }
        .background(browserColumnBackground)
    }

    private var snippetBrowserHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentScopeTitle)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))

                    Text(currentScopeSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 16)

                Button(action: addSnippet) {
                    Label("新建Key", systemImage: "plus")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .help("新建Key (⌘N)")
                .keyboardShortcut("n", modifiers: .command)
                .onboardingTarget(.createKeyButton)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("搜索触发词或替换内容", text: $snippetSearchText)
                    .textFieldStyle(.plain)

                if !snippetSearchText.isEmpty {
                    Button {
                        snippetSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
            )

            HStack(spacing: 10) {
                Button(action: importSnippets) {
                    Label("导入", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)

                Button(action: exportSnippets) {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
                .disabled(store.snippets.isEmpty && store.groups.isEmpty)

                Spacer()

                Text(clipboardStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(18)
        .background(browserColumnBackground)
    }

    private var snippetList: some View {
        Group {
            if filteredSnippets.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: snippetSearchText.isEmpty ? "tray" : "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text(snippetSearchText.isEmpty ? "这里还没有 Key" : "没有匹配的 Key")
                        .font(.headline)
                    Text(snippetSearchText.isEmpty ? "点击右上角“新建Key”开始添加。" : "试试其他关键词，或清空搜索。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(browserColumnBackground)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredSnippets) { snippet in
                            Button {
                                requestActionOrPrompt(.selectSnippet(snippet.id, sidebar: nil))
                            } label: {
                                snippetRow(snippet)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contextMenu {
                                Button(role: .destructive) {
                                    snippetToDelete = snippet.id
                                    showDeleteSnippetConfirm = true
                                } label: {
                                    Label("删除Key", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
                .scrollContentBackground(.hidden)
                    .background(browserColumnBackground)
                .confirmationDialog(
                    "删除Key？",
                    isPresented: $showDeleteSnippetConfirm,
                    titleVisibility: .visible
                ) {
                    Button("删除", role: .destructive) {
                        if let id = snippetToDelete {
                            if let snippet = store.snippets.first(where: { $0.id == id }) {
                                clipboardHistoryStore.clearCreatedSnippetAssociation(
                                    for: id,
                                    matchingContent: snippet.replacement
                                )
                            }
                            store.deleteSnippet(id: id)
                            if selectedSnippetId == id {
                                selectedSnippetId = nil
                            }
                        }
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("这个Key将被永久删除。")
                }
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailColumn: some View {
        if selectedSnippet != nil || isShowingOnboardingPreview {
            VStack(spacing: 0) {
                detailHeader
                snippetDetailBody
            }
            .background(Color(nsColor: .windowBackgroundColor))
        } else {
            VStack(spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                Text("请选择一个 Key 进行编辑")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text("左侧可以按分组浏览，中间可以搜索和选择。")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detailTitle)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))

                    Text(detailSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 16)

                if hasUnsavedReplacementChanges {
                    Text("未保存")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.orange.opacity(0.14))
                        )
                }
            }

            HStack(spacing: 10) {
                Button("还原") {
                    restoreSelectedSnippet()
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button("保存") {
                    saveEditing()
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!hasUnsavedReplacementChanges)

                Spacer()

                Button(role: .destructive) {
                    snippetToDelete = selectedSnippetId
                    showDeleteSnippetConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("删除")
                            .foregroundColor(.red)
                    }
                }
                .buttonStyle(DangerGhostButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var snippetDetailBody: some View {
        if selectedSnippet != nil || isShowingOnboardingPreview {
            ScrollViewReader { proxy in
                ScrollView {
                    Color.clear
                        .frame(height: 0)
                        .id(SettingsOnboardingCoordinateSpace.detailTopID)

                    VStack(alignment: .leading, spacing: 6) {
                        basicInfoSection
                        replacementSection
                        variablesSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    scrollDetailToTop(proxy)
                }
                .onChange(of: showOnboardingGuide) { newValue in
                    if newValue {
                        scrollDetailToTop(proxy)
                    }
                }
                .onChange(of: onboardingStepIndex) { _ in
                    if showOnboardingGuide {
                        scrollDetailToTop(proxy)
                    }
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    // MARK: - Helpers

    private var filteredSnippets: [Snippet] {
        let source: [Snippet]
        if let groupId = currentSidebarSelection.groupId {
            source = store.snippets(forGroup: groupId)
        } else {
            source = store.snippets
        }

        let query = snippetSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return source }

        return source.filter {
            $0.trigger.localizedCaseInsensitiveContains(query)
                || $0.replacement.localizedCaseInsensitiveContains(query)
        }
    }

    private var onboardingSteps: [SettingsOnboardingStep] {
        [
            SettingsOnboardingStep(
                target: .createKeyButton,
                title: "先从这里创建 Key",
                message: "每一条常用文本都从左上角的“新建Key”开始。看完这套指引后，第一步就是先点它。",
                footnote: "你可以直接点击高亮的“新建Key”，系统会自动进入下一步；如果暂时不想建，也可以先看后面的说明。",
                requiresDetailPreview: false
            ),
            SettingsOnboardingStep(
                target: .triggerSection,
                title: "这里填写触发词",
                message: "触发词只填关键词本身，不需要带 #。真正使用时，在别的应用里输入 #email_key 这样的形式即可。",
                footnote: "触发词只支持字母、数字和下划线，并且不能和现有 Key 重复。",
                requiresDetailPreview: true
            ),
            SettingsOnboardingStep(
                target: .replacementSection,
                title: "这里写最终展开的内容",
                message: "可以写多行文本、签名、地址、模板回复。内容较长时，点右上角“在窗口中编辑”会更舒服。",
                footnote: "修改替换内容后会显示“未保存”，按 ⌘S 或底部“保存”即可生效。",
                requiresDetailPreview: true
            ),
            SettingsOnboardingStep(
                target: .groupSection,
                title: "用分组整理你的 Key",
                message: "把同类 Key 放进同一分组，左侧列表就能按分组筛选。Key 变多以后，这里会很有用。",
                footnote: "看完后就可以回到左上角，创建并保存你的第一条 Key。",
                requiresDetailPreview: true
            )
        ]
    }

    private var currentOnboardingStep: SettingsOnboardingStep {
        onboardingSteps[min(onboardingStepIndex, onboardingSteps.count - 1)]
    }

    private var isShowingOnboardingPreview: Bool {
        showOnboardingGuide && selectedSnippet == nil && currentOnboardingStep.requiresDetailPreview
    }

    private var selectedSnippet: Snippet? {
        guard let selectedSnippetId else { return nil }
        return store.snippets.first(where: { $0.id == selectedSnippetId })
    }

    private var selectedExistingGroup: SnippetGroup? {
        guard let groupId = currentSidebarSelection.groupId else { return nil }
        return store.groups.first(where: { $0.id == groupId })
    }

    private var currentScopeTitle: String {
        selectedExistingGroup?.name ?? "全部Key"
    }

    private var currentScopeSubtitle: String {
        var parts = ["\(filteredSnippets.count) 个结果"]
        if !snippetSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("搜索“\(snippetSearchText)”")
        } else if selectedExistingGroup != nil {
            parts.append("当前分组")
        } else {
            parts.append("所有可用的文本展开")
        }

        return parts.joined(separator: " · ")
    }

    private var detailTitle: String {
        if let selectedSnippet {
            return "#\(selectedSnippet.trigger)"
        }
        return "Key 详情"
    }

    private var detailSubtitle: String {
        guard let selectedSnippet else {
            return "配置触发词、替换内容和分组。"
        }

        var parts: [String] = []
        if let groupName = groupName(for: selectedSnippet.groupId) {
            parts.append(groupName)
        } else {
            parts.append("未分组")
        }
        parts.append("已接受 \(selectedSnippet.acceptanceCount) 次")
        return parts.joined(separator: " · ")
    }

    private var clipboardStatusText: String {
        if clipboardHistoryStore.settings.isMonitoringEnabled {
            return "剪贴板记录 \(clipboardHistoryStore.records.count) 条 · 阈值 \(clipboardHistoryStore.settings.suggestionThreshold) 次"
        }
        return "剪贴板记录已关闭"
    }

    private var hasUnsavedReplacementChanges: Bool {
        guard let selectedSnippet else { return false }
        return editingReplacement != selectedSnippet.replacement
    }

    private var triggerValidationError: SnippetTriggerRules.ValidationError? {
        guard selectedSnippetId != nil else { return nil }
        return store.validationError(for: editingTrigger, excluding: selectedSnippetId)
    }

    private var triggerHelperText: String {
        switch triggerValidationError {
        case .empty:
            return "触发词不能为空。"
        case .invalidCharacters:
            return "只允许字母、数字和下划线。"
        case .duplicate:
            return "这个触发词已经存在，请换一个。"
        case nil:
            return "只允许字母、数字和下划线，且必须唯一。"
        }
    }

    private var triggerHelperColor: Color {
        triggerValidationError == nil ? .secondary : .red
    }

    private var currentSidebarSelection: SidebarSelection {
        selectedSidebarSelection ?? .all
    }

    private var sidebarSelectionBinding: Binding<SidebarSelection?> {
        Binding(
            get: { selectedSidebarSelection },
            set: { newValue in
                let resolvedSelection = newValue ?? .all
                guard resolvedSelection != currentSidebarSelection else { return }
                requestActionOrPrompt(.selectSidebar(resolvedSelection))
            }
        )
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.22), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.12), lineWidth: 1)
            )
    }

    private var browserColumnBackground: Color {
        Color(.sRGB, red: 0.955, green: 0.959, blue: 0.966, opacity: 1)
    }

    private func overviewMetricCard(title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.accentColor.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(.primary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        )
    }

    private func sidebarNavigationButton(
        title: String,
        systemImage: String,
        count: Int,
        selection: SidebarSelection
    ) -> some View {
        let isSelected = currentSidebarSelection == selection

        return Button {
            requestActionOrPrompt(.selectSidebar(selection))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 20)

                Text(title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(isSelected ? .white : .primary)

                Spacer(minLength: 12)

                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? Color.white : Color(nsColor: .controlBackgroundColor))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.32) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func snippetRow(_ snippet: Snippet) -> some View {
        let isSelected = selectedSnippetId == snippet.id

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("#\(snippet.trigger)")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .accentColor : .primary)

                    if let groupName = groupName(for: snippet.groupId) {
                        Text(groupName)
                            .font(.caption2)
                            .foregroundColor(isSelected ? .accentColor : .secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor))
                            )
                    }
                }

                Text(snippetPreview(snippet))
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .primary.opacity(0.82) : .secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 6) {
                if snippet.acceptanceCount > 0 {
                    Text("\(snippet.acceptanceCount) 次")
                        .font(.caption2)
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }

                if selectedSnippetId == snippet.id {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.accentColor.opacity(0.9))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, lineWidth: 1)
        )
    }

    private func snippetPreview(_ snippet: Snippet) -> String {
        let flattened = snippet.replacement.replacingOccurrences(of: "\n", with: " ")
        let preview = String(flattened.prefix(86))
        return flattened.count > preview.count ? preview + "…" : preview
    }

    private func groupName(for groupId: UUID?) -> String? {
        guard let groupId else { return nil }
        return store.groups.first(where: { $0.id == groupId })?.name
    }

    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("触发词")
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Text("#")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentColor)

                TextField("例如：email_key", text: $editingTrigger)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .textFieldStyle(.plain)
            }
            .frame(maxWidth: .infinity, minHeight: headerCardHeight + 2, alignment: .leading)
            .padding(.horizontal, 9)
            .background(fieldBackground)
            .onboardingTarget(.triggerSection)

            Text(triggerHelperText)
                .font(.caption2)
                .foregroundColor(triggerHelperColor)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var basicInfoSection: some View {
        HStack(alignment: .top, spacing: 8) {
            triggerSection
            groupSection
                .frame(width: 154)
        }
        .padding(12)
        .background(sectionBackground)
    }

    private var replacementSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailSectionHeader(
                title: "替换内容",
                subtitle: "接受 Key 后会插入这里的文本。"
            ) {
                Button {
                    openReplacementEditor()
                } label: {
                    Label("在窗口中编辑", systemImage: "square.and.pencil")
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            TextEditor(text: $editingReplacement)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(height: replacementPreviewHeight + 28)
                .padding(9)
                .background(fieldBackground)
        }
        .padding(12)
        .background(sectionBackground)
        .onboardingTarget(.replacementSection)
    }

    private var groupSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("分组")
                .font(.caption2)
                .foregroundColor(.secondary)

            Menu {
                Button {
                    editingGroupId = nil
                } label: {
                    if editingGroupId == nil {
                        Label("无", systemImage: "checkmark")
                    } else {
                        Text("无")
                    }
                }

                if !store.groups.isEmpty {
                    Divider()
                    ForEach(store.groups) { group in
                        Button {
                            editingGroupId = group.id
                        } label: {
                            if editingGroupId == group.id {
                                Label(group.name, systemImage: "checkmark")
                            } else {
                                Text(group.name)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(groupName(for: editingGroupId) ?? "无")
                        .foregroundColor(.primary)

                    Spacer(minLength: 10)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: headerCardHeight + 2, alignment: .leading)
                .padding(.horizontal, 10)
                .background(fieldBackground)
            }
            .buttonStyle(.plain)
            .onboardingTarget(.groupSection)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var variablesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailSectionHeader(
                title: "变量",
                subtitle: "可以在替换内容中使用的动态变量。"
            ) {
                EmptyView()
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 6, alignment: .leading)],
                alignment: .leading,
                spacing: 6
            ) {
                variableTag("{date}", description: "当前日期")
                variableTag("{time}", description: "当前时间")
                variableTag("{clipboard}", description: "剪贴板文本")
                variableTag("{cursor}", description: "光标位置")
            }
        }
        .padding(12)
        .background(sectionBackground)
    }

    private var detailActionBar: some View {
        HStack {
            Button(role: .destructive) {
                snippetToDelete = selectedSnippetId
                showDeleteSnippetConfirm = true
            } label: {
                Label("删除", systemImage: "trash")
            }

            Spacer()

            Button("还原") {
                restoreSelectedSnippet()
            }

            Button("保存") { saveEditing() }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(!hasUnsavedReplacementChanges)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func variableTag(_ variable: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(variable)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(fieldBackground)
    }

    private func detailSectionHeader<Trailing: View>(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 12)

            trailing()
        }
    }

    private func restoreSelectedSnippet() {
        guard let snippet = selectedSnippet else { return }
        editingTrigger = snippet.trigger
        editingReplacement = snippet.replacement
        editingGroupId = snippet.groupId
    }

    private func openReplacementEditor() {
        replacementEditorDraft = editingReplacement
        showReplacementEditor = true
    }

    private func applyReplacementEditorChanges() {
        editingReplacement = replacementEditorDraft
        showReplacementEditor = false
    }

    private func renameGroup(_ group: SnippetGroup) {
        let alert = NSAlert()
        alert.messageText = "重命名分组"
        alert.informativeText = "请输入新的分组名称。"

        let textField = NSTextField(string: group.name)
        textField.placeholderString = "分组名称"
        textField.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = textField
        alert.addButton(withTitle: "重命名")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let trimmedName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName != group.name else { return }

        var updatedGroup = group
        updatedGroup.name = trimmedName
        store.updateGroup(updatedGroup)
    }

    private func syncSnippetSelectionToCurrentFilter() {
        guard let selectedSnippetId else { return }
        guard filteredSnippets.contains(where: { $0.id == selectedSnippetId }) else {
            self.selectedSnippetId = nil
            return
        }
    }

    private func requestActionOrPrompt(_ action: PendingSettingsAction) {
        guard hasUnsavedReplacementChanges else {
            performSettingsAction(action)
            return
        }

        pendingSettingsAction = action
        showUnsavedReplacementPrompt = true
    }

    private func performSettingsAction(_ action: PendingSettingsAction) {
        switch action {
        case .selectSnippet(let snippetId, let sidebarSelection):
            if let sidebarSelection {
                selectedSidebarSelection = sidebarSelection
            }
            selectedSnippetId = snippetId
        case .selectSidebar(let selection):
            selectedSidebarSelection = selection
            syncSnippetSelectionToCurrentFilter()
        case .createSnippet:
            let snippet = Snippet(
                trigger: store.nextAvailableTrigger(),
                replacement: "替换文本",
                groupId: currentSidebarSelection.groupId
            )
            guard store.addSnippet(snippet) else { return }
            selectedSnippetId = snippet.id
            if showOnboardingGuide && currentOnboardingStep.target == .createKeyButton {
                nextOnboardingStep()
            }
        }
    }

    private func applyPendingSettingsAction() {
        guard let pendingSettingsAction else { return }
        self.pendingSettingsAction = nil
        performSettingsAction(pendingSettingsAction)
    }

    private func discardUnsavedReplacementChanges() {
        guard let selectedSnippet else { return }
        editingReplacement = selectedSnippet.replacement
    }

    private func beginOnboardingGuide() {
        onboardingStepIndex = 0
        prepareOnboardingPreviewIfNeeded()
    }

    private func focusSnippet(_ id: UUID) {
        guard let snippet = store.snippets.first(where: { $0.id == id }) else { return }
        let sidebarSelection = snippet.groupId.map(SidebarSelection.group) ?? .all
        requestActionOrPrompt(.selectSnippet(id, sidebar: sidebarSelection))
    }

    private func createSnippetFromClipboardRecord(_ record: ClipboardRecord) {
        if let existingSnippet = store.snippets.first(where: { $0.replacement == record.content }) {
            clipboardHistoryStore.markCreatedSnippet(for: record.id, snippetID: existingSnippet.id)
            showClipboardHistorySheet = false
            focusSnippet(existingSnippet.id)
            return
        }

        let snippet = ClipboardSnippetFactory.makeSnippet(from: record.content, existingSnippets: store.snippets)
        store.addSnippet(snippet)
        clipboardHistoryStore.markCreatedSnippet(for: record.id, snippetID: snippet.id)
        showClipboardHistorySheet = false
        focusSnippet(snippet.id)
    }

    private func nextOnboardingStep() {
        if onboardingStepIndex < onboardingSteps.count - 1 {
            onboardingStepIndex += 1
        } else {
            dismissOnboardingGuide()
        }
    }

    private func previousOnboardingStep() {
        onboardingStepIndex = max(onboardingStepIndex - 1, 0)
    }

    private func dismissOnboardingGuide() {
        showOnboardingGuide = false
    }

    private func prepareOnboardingPreviewIfNeeded() {
        guard showOnboardingGuide,
              selectedSnippet == nil,
              currentOnboardingStep.requiresDetailPreview else { return }

        editingTrigger = onboardingExampleTrigger
        editingReplacement = onboardingPreviewReplacement
        editingGroupId = nil
    }

    private func scrollDetailToTop(_ proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(SettingsOnboardingCoordinateSpace.detailTopID, anchor: .top)
        }
    }

    private func autoSaveTrigger(_ newTrigger: String) {
        let sanitizedTrigger = SnippetTriggerRules.sanitize(newTrigger)

        if sanitizedTrigger != newTrigger {
            if editingTrigger != sanitizedTrigger {
                editingTrigger = sanitizedTrigger
            }
            return
        }

        guard let id = selectedSnippetId,
              let existingSnippet = store.snippets.first(where: { $0.id == id }),
              existingSnippet.trigger != sanitizedTrigger,
              store.validationError(for: sanitizedTrigger, excluding: id) == nil else { return }

        var snippet = existingSnippet
        snippet.trigger = sanitizedTrigger
        _ = store.updateSnippet(snippet)
    }

    private func autoSaveGroup(_ newGroupId: UUID?) {
        guard let id = selectedSnippetId,
              var snippet = store.snippets.first(where: { $0.id == id }),
              snippet.groupId != newGroupId else { return }

        snippet.groupId = newGroupId
        store.updateSnippet(snippet)

        if !hasUnsavedReplacementChanges {
            syncSnippetSelectionToCurrentFilter()
        }
    }

    // MARK: - Actions

    private func addSnippet() {
        requestActionOrPrompt(.createSnippet)
    }

    private func addGroup() {
        let group = SnippetGroup(name: "新分组")
        store.addGroup(group)
    }

    private func saveEditing() {
        guard let id = selectedSnippetId,
              var snippet = store.snippets.first(where: { $0.id == id }) else { return }
        snippet.replacement = editingReplacement
        snippet.groupId = editingGroupId
        _ = store.updateSnippet(snippet)
        syncSnippetSelectionToCurrentFilter()
    }

    private func exportSnippets() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "snipkey-snippets.json"
        panel.title = "导出Key"
        panel.prompt = "导出"
        if panel.runModal() == .OK, let url = panel.url {
            try? store.exportData(to: url)
        }
    }

    private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.title = "导入Key"
        panel.prompt = "导入"
        panel.message = "请选择要导入的 SnipKey Key文件。"
        if panel.runModal() == .OK, let url = panel.url {
            try? store.importData(from: url)
        }
    }
}

private enum SettingsOnboardingTarget: Hashable {
    case createKeyButton
    case triggerSection
    case replacementSection
    case groupSection
}

private struct SettingsOnboardingStep {
    let target: SettingsOnboardingTarget
    let title: String
    let message: String
    let footnote: String
    let requiresDetailPreview: Bool
}

private enum SettingsOnboardingCoordinateSpace {
    static let detailTopID = "settings-detail-top"
}

private struct SettingsOnboardingFramePreferenceKey: PreferenceKey {
    static var defaultValue: [SettingsOnboardingTarget: Anchor<CGRect>] = [:]

    static func reduce(value: inout [SettingsOnboardingTarget: Anchor<CGRect>], nextValue: () -> [SettingsOnboardingTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct SettingsOnboardingTargetModifier: ViewModifier {
    let target: SettingsOnboardingTarget

    func body(content: Content) -> some View {
        content.anchorPreference(key: SettingsOnboardingFramePreferenceKey.self, value: .bounds) { anchor in
            [target: anchor]
        }
    }
}

private extension View {
    func onboardingTarget(_ target: SettingsOnboardingTarget) -> some View {
        modifier(SettingsOnboardingTargetModifier(target: target))
    }
}

private struct SettingsOnboardingOverlay: View {
    let step: SettingsOnboardingStep
    let stepIndex: Int
    let stepCount: Int
    let targetAnchor: Anchor<CGRect>?
    let onClose: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let focusRect = focusRect(in: proxy)
            let coachLayout = coachLayout(in: proxy.size, focusRect: focusRect)

            ZStack(alignment: .topLeading) {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: proxy.size))
                    if let focusRect {
                        path.addRoundedRect(in: focusRect, cornerSize: CGSize(width: 18, height: 18))
                    }
                }
                .fill(Color.black.opacity(0.42), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

                if let focusRect {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.96), lineWidth: 2)
                        )
                        .frame(width: focusRect.width, height: focusRect.height, alignment: .topLeading)
                        .offset(x: focusRect.minX, y: focusRect.minY)
                        .allowsHitTesting(false)
                }

                SettingsOnboardingHitMaskView(passThroughRect: focusRect)

                coachMarkCard(layout: coachLayout)
                    .offset(x: coachLayout.origin.x, y: coachLayout.origin.y)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .transition(.opacity)
    }

    private func coachMarkCard(layout: SettingsOnboardingCoachLayout) -> some View {
        VStack(spacing: 0) {
            if layout.arrowDirection == .up {
                arrowRow(layout: layout)
            }

            coachMarkCardBody

            if layout.arrowDirection == .down {
                arrowRow(layout: layout)
            }
        }
        .frame(width: layout.width, alignment: .leading)
        .shadow(color: .black.opacity(0.16), radius: 24, y: 10)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: stepIndex)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: targetAnchor == nil)
    }

    private var coachMarkCardBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("使用指引")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(step.title)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(step.message)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            Text(step.footnote)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index == stepIndex ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.45))
                        .frame(width: index == stepIndex ? 22 : 8, height: 8)
                }
            }

            if targetAnchor == nil {
                Text("正在定位当前控件…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 10) {
                Button("稍后再看", action: onClose)
                    .buttonStyle(.borderless)

                Spacer()

                Button("上一步", action: onPrevious)
                    .buttonStyle(.bordered)
                    .disabled(stepIndex == 0)

                Button(stepIndex == stepCount - 1 ? "完成" : "下一步", action: onNext)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(maxWidth: 420, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.32), lineWidth: 1)
        )
    }

    private func arrowRow(layout: SettingsOnboardingCoachLayout) -> some View {
        ZStack(alignment: .leading) {
            SettingsOnboardingArrow(direction: layout.arrowDirection)
                .fill(Color(nsColor: .windowBackgroundColor))
                .frame(width: 22, height: 12)
                .offset(x: layout.arrowOffset - 11)
        }
        .frame(height: 12)
    }

    private func focusRect(in proxy: GeometryProxy) -> CGRect? {
        guard let targetAnchor else { return nil }

        let localFrame = proxy[targetAnchor]
        let adjustedExpanded = localFrame.insetBy(dx: -8, dy: -8)
        let container = CGRect(origin: .zero, size: proxy.size)
        let intersection = adjustedExpanded.intersection(container)
        return intersection.isNull ? nil : intersection
    }

    private func coachLayout(in size: CGSize, focusRect: CGRect?) -> SettingsOnboardingCoachLayout {
        let horizontalInset: CGFloat = 24
        let bubbleWidth = min(360, max(300, size.width - horizontalInset * 2))
        let estimatedHeight: CGFloat = step.target == .replacementSection ? 230 : 206

        guard let focusRect else {
            return SettingsOnboardingCoachLayout(
                origin: CGPoint(x: max(horizontalInset, (size.width - bubbleWidth) / 2), y: max(horizontalInset, size.height - estimatedHeight - 24)),
                width: bubbleWidth,
                arrowOffset: bubbleWidth / 2,
                arrowDirection: .up
            )
        }

        let x = clamped(focusRect.midX - bubbleWidth / 2, min: horizontalInset, max: max(horizontalInset, size.width - bubbleWidth - horizontalInset))
        let spaceBelow = size.height - focusRect.maxY - horizontalInset
        let placeBelow = spaceBelow >= estimatedHeight + 18 || focusRect.minY < estimatedHeight + 36
        let y = placeBelow
            ? clamped(focusRect.maxY + 16, min: horizontalInset, max: max(horizontalInset, size.height - estimatedHeight - 24))
            : clamped(focusRect.minY - estimatedHeight - 16, min: horizontalInset, max: max(horizontalInset, size.height - estimatedHeight - 24))
        let arrowOffset = clamped(focusRect.midX - x, min: 32, max: bubbleWidth - 32)

        return SettingsOnboardingCoachLayout(
            origin: CGPoint(x: x, y: y),
            width: bubbleWidth,
            arrowOffset: arrowOffset,
            arrowDirection: placeBelow ? .up : .down
        )
    }

    private func clamped(_ value: CGFloat, min lowerBound: CGFloat, max upperBound: CGFloat) -> CGFloat {
        Swift.max(lowerBound, Swift.min(value, upperBound))
    }
}

private enum SettingsOnboardingArrowDirection {
    case up
    case down
}

private struct SettingsOnboardingCoachLayout {
    let origin: CGPoint
    let width: CGFloat
    let arrowOffset: CGFloat
    let arrowDirection: SettingsOnboardingArrowDirection
}

private struct SettingsOnboardingArrow: Shape {
    let direction: SettingsOnboardingArrowDirection

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch direction {
        case .up:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .down:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

private struct SettingsOnboardingHitMaskView: NSViewRepresentable {
    let passThroughRect: CGRect?

    func makeNSView(context: Context) -> SettingsOnboardingHitMaskNSView {
        SettingsOnboardingHitMaskNSView()
    }

    func updateNSView(_ nsView: SettingsOnboardingHitMaskNSView, context: Context) {
        nsView.passThroughRect = passThroughRect
    }
}

private final class SettingsOnboardingHitMaskNSView: NSView {
    var passThroughRect: CGRect?

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let passThroughRect, passThroughRect.contains(point) {
            return nil
        }
        return self
    }
}

private struct ReplacementEditorSheet: View {
    let trigger: String
    let originalText: String
    @Binding var text: String
    let onCancel: () -> Void
    let onApply: () -> Void

    @State private var showCancelConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("编辑替换内容")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("正在编辑 #\(trigger.isEmpty ? "Key" : trigger)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("取消", action: handleCancel)
                    .buttonStyle(SecondaryActionButtonStyle())

                Button("应用", action: onApply)
                    .buttonStyle(PrimaryActionButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(20)
                .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minWidth: 760, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .confirmationDialog(
            "替换内容尚未应用",
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("应用更改") {
                onApply()
            }

            Button("放弃更改", role: .destructive) {
                onCancel()
            }

            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("你修改了替换内容。关闭窗口前，是否要应用这些更改？")
        }
    }

    private var hasUnsavedChanges: Bool {
        text != originalText
    }

    private func handleCancel() {
        if hasUnsavedChanges {
            showCancelConfirmation = true
        } else {
            onCancel()
        }
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    private let fillColor = Color(.sRGB, red: 0.09, green: 0.48, blue: 0.96, opacity: 1)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default).weight(.semibold))
            .foregroundColor(isEnabled ? .white : fillColor.opacity(0.9))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isEnabled ? fillColor.opacity(configuration.isPressed ? 0.84 : 1) : fillColor.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isEnabled ? fillColor.opacity(0.18) : fillColor.opacity(0.22), lineWidth: 1)
            )
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default).weight(.semibold))
            .foregroundColor(isEnabled ? .primary : .secondary.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(configuration.isPressed ? 0.92 : 0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.14), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.75)
    }
}

private struct DangerGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default).weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.10 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.red.opacity(0.10), lineWidth: 1)
            )
    }
}
