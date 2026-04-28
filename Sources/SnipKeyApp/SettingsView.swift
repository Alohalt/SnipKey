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

    @ObservedObject var store: SnippetStore
    @ObservedObject var clipboardHistoryStore: ClipboardHistoryStore
    @ObservedObject var languageStore: AppLanguageStore
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
        languageStore: AppLanguageStore,
        coordinator: SettingsCoordinator,
        initiallyShowsOnboarding: Bool = false
    ) {
        self.store = store
        self.clipboardHistoryStore = clipboardHistoryStore
        self.languageStore = languageStore
        self.coordinator = coordinator
        _showOnboardingGuide = State(initialValue: initiallyShowsOnboarding)
    }

    private func text(_ key: L10n.Key) -> String {
        languageStore.text(key)
    }

    private func formatted(_ key: L10n.Key, _ arguments: CVarArg...) -> String {
        L10n.formatted(key, language: languageStore.language, arguments)
    }

    private var onboardingPreviewReplacement: String {
        text(.settingsOnboardingPreviewReplacement)
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
                    languageStore: languageStore,
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
                languageStore: languageStore,
                onCancel: { showReplacementEditor = false },
                onApply: applyReplacementEditorChanges
            )
        }
        .sheet(isPresented: $showClipboardHistorySheet) {
            ClipboardHistorySheet(
                historyStore: clipboardHistoryStore,
                languageStore: languageStore,
                onCreateSnippet: createSnippetFromClipboardRecord
            )
        }
        .sheet(isPresented: $showAboutSheet) {
            AboutSheet(languageStore: languageStore)
        }
        .confirmationDialog(
            text(.settingsUnsavedReplacementTitle),
            isPresented: $showUnsavedReplacementPrompt,
            titleVisibility: .visible
        ) {
            Button(text(.settingsSaveAndContinue)) {
                saveEditing()
                applyPendingSettingsAction()
            }

            Button(text(.settingsDiscardChanges), role: .destructive) {
                discardUnsavedReplacementChanges()
                applyPendingSettingsAction()
            }

            Button(text(.commonCancel), role: .cancel) {
                pendingSettingsAction = nil
            }
        } message: {
            Text(text(.settingsUnsavedReplacementMessage))
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

            Text(text(.settingsSidebarSubtitle))
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
            overviewMetricCard(title: text(.settingsMetricGroups), value: "\(store.groups.count)", systemImage: "folder")
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
            Text(text(.settingsTools))
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: addGroup) {
                Label(text(.settingsNewGroup), systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)

            Button {
                showClipboardHistorySheet = true
            } label: {
                Label(text(.settingsClipboardHistory), systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)

            Button {
                showOnboardingGuide = true
            } label: {
                Label(text(.settingsGuide), systemImage: "questionmark.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)

            Button {
                showAboutSheet = true
            } label: {
                Label(text(.settingsAbout), systemImage: "info.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 6) {
                Text(text(.languageTitle))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Picker(text(.languageTitle), selection: $languageStore.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.pickerTitle).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(text(.settingsBrowse))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    sidebarNavigationButton(
                        title: text(.settingsAllKeys),
                        systemImage: "tray.full",
                        count: store.snippets.count,
                        selection: .all
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(text(.settingsGroups))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if store.groups.isEmpty {
                        Text(text(.settingsNoGroups))
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
                                    Label(text(.settingsRenameGroup), systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    groupToDelete = group.id
                                    showDeleteGroupConfirm = true
                                } label: {
                                    Label(text(.settingsDeleteGroup), systemImage: "trash")
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
            text(.settingsDeleteGroupTitle),
            isPresented: $showDeleteGroupConfirm,
            titleVisibility: .visible
        ) {
            Button(text(.commonDelete), role: .destructive) {
                if let id = groupToDelete {
                    store.deleteGroup(id: id)
                    if selectedSidebarSelection == .group(id) {
                        selectedSidebarSelection = .all
                    }
                    syncSnippetSelectionToCurrentFilter()
                }
            }
            Button(text(.commonCancel), role: .cancel) {}
        } message: {
            Text(text(.settingsDeleteGroupMessage))
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
                    Label(text(.settingsNewKey), systemImage: "plus")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .help(text(.settingsNewKeyHelp))
                .keyboardShortcut("n", modifiers: .command)
                .onboardingTarget(.createKeyButton)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField(text(.settingsSearchPlaceholder), text: $snippetSearchText)
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
                    Label(text(.commonImport), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)

                Button(action: exportSnippets) {
                    Label(text(.commonExport), systemImage: "square.and.arrow.up")
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
                    Text(snippetSearchText.isEmpty ? text(.settingsNoKeyEmptyTitle) : text(.settingsNoSearchResultTitle))
                        .font(.headline)
                    Text(snippetSearchText.isEmpty ? text(.settingsNoKeyEmptySubtitle) : text(.settingsNoSearchResultSubtitle))
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
                                    Label(text(.settingsDeleteKey), systemImage: "trash")
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
                    text(.settingsDeleteKeyTitle),
                    isPresented: $showDeleteSnippetConfirm,
                    titleVisibility: .visible
                ) {
                    Button(text(.commonDelete), role: .destructive) {
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
                    Button(text(.commonCancel), role: .cancel) {}
                } message: {
                    Text(text(.settingsDeleteKeyMessage))
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
                Text(text(.settingsSelectKeyTitle))
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text(text(.settingsSelectKeySubtitle))
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
                    Text(text(.settingsUnsavedBadge))
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
                Button(text(.commonRestore)) {
                    restoreSelectedSnippet()
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button(text(.commonSave)) {
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
                        Text(text(.commonDelete))
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
                title: text(.settingsOnboardingStepCreateTitle),
                message: text(.settingsOnboardingStepCreateMessage),
                footnote: text(.settingsOnboardingStepCreateFootnote),
                requiresDetailPreview: false
            ),
            SettingsOnboardingStep(
                target: .triggerSection,
                title: text(.settingsOnboardingStepTriggerTitle),
                message: text(.settingsOnboardingStepTriggerMessage),
                footnote: text(.settingsOnboardingStepTriggerFootnote),
                requiresDetailPreview: true
            ),
            SettingsOnboardingStep(
                target: .replacementSection,
                title: text(.settingsOnboardingStepReplacementTitle),
                message: text(.settingsOnboardingStepReplacementMessage),
                footnote: text(.settingsOnboardingStepReplacementFootnote),
                requiresDetailPreview: true
            ),
            SettingsOnboardingStep(
                target: .groupSection,
                title: text(.settingsOnboardingStepGroupTitle),
                message: text(.settingsOnboardingStepGroupMessage),
                footnote: text(.settingsOnboardingStepGroupFootnote),
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
        selectedExistingGroup?.name ?? text(.settingsAllKeys)
    }

    private var currentScopeSubtitle: String {
        var parts = [formatted(.settingsResultCountFormat, filteredSnippets.count)]
        if !snippetSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(formatted(.settingsSearchPartFormat, snippetSearchText))
        } else if selectedExistingGroup != nil {
            parts.append(text(.settingsCurrentGroup))
        } else {
            parts.append(text(.settingsAllTextExpansions))
        }

        return parts.joined(separator: " · ")
    }

    private var detailTitle: String {
        if let selectedSnippet {
            return "#\(selectedSnippet.trigger)"
        }
        return text(.settingsKeyDetails)
    }

    private var detailSubtitle: String {
        guard let selectedSnippet else {
            return text(.settingsDetailEmptySubtitle)
        }

        var parts: [String] = []
        if let groupName = groupName(for: selectedSnippet.groupId) {
            parts.append(groupName)
        } else {
            parts.append(text(.settingsUngrouped))
        }
        parts.append(formatted(.settingsAcceptedTimesFormat, selectedSnippet.acceptanceCount))
        return parts.joined(separator: " · ")
    }

    private var clipboardStatusText: String {
        if clipboardHistoryStore.settings.isMonitoringEnabled {
            return formatted(.settingsClipboardStatusEnabledFormat, clipboardHistoryStore.records.count, clipboardHistoryStore.settings.suggestionThreshold)
        }
        return text(.settingsClipboardStatusDisabled)
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
            return text(.settingsTriggerEmpty)
        case .invalidCharacters:
            return text(.settingsTriggerInvalid)
        case .duplicate:
            return text(.settingsTriggerDuplicate)
        case nil:
            return text(.settingsTriggerHelp)
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
                    Text(formatted(.clipboardTimesFormat, snippet.acceptanceCount))
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
            Text(text(.settingsTriggerTitle))
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Text("#")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentColor)

                TextField(text(.settingsTriggerPlaceholder), text: $editingTrigger)
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
                title: text(.settingsReplacementTitle),
                subtitle: text(.settingsReplacementSubtitle)
            ) {
                Button {
                    openReplacementEditor()
                } label: {
                    Label(text(.settingsEditInWindow), systemImage: "square.and.pencil")
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
            Text(text(.settingsGroupTitle))
                .font(.caption2)
                .foregroundColor(.secondary)

            Menu {
                Button {
                    editingGroupId = nil
                } label: {
                    if editingGroupId == nil {
                        Label(text(.commonNone), systemImage: "checkmark")
                    } else {
                        Text(text(.commonNone))
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
                    Text(groupName(for: editingGroupId) ?? text(.commonNone))
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
                title: text(.settingsVariablesTitle),
                subtitle: text(.settingsVariablesSubtitle)
            ) {
                EmptyView()
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 6, alignment: .leading)],
                alignment: .leading,
                spacing: 6
            ) {
                variableTag("{date}", description: text(.settingsVariableCurrentDate))
                variableTag("{time}", description: text(.settingsVariableCurrentTime))
                variableTag("{clipboard}", description: text(.settingsVariableClipboardText))
                variableTag("{cursor}", description: text(.settingsVariableCursorPosition))
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
                Label(text(.commonDelete), systemImage: "trash")
            }

            Spacer()

            Button(text(.commonRestore)) {
                restoreSelectedSnippet()
            }

            Button(text(.commonSave)) { saveEditing() }
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
        alert.messageText = text(.settingsRenameGroupTitle)
        alert.informativeText = text(.settingsRenameGroupMessage)

        let textField = NSTextField(string: group.name)
        textField.placeholderString = text(.settingsGroupNamePlaceholder)
        textField.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = textField
        alert.addButton(withTitle: text(.settingsRenameGroup))
        alert.addButton(withTitle: text(.commonCancel))

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
                replacement: text(.settingsDefaultReplacement),
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
        let group = SnippetGroup(name: text(.settingsDefaultGroupName))
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
        panel.title = text(.settingsExportPanelTitle)
        panel.prompt = text(.commonExport)
        if panel.runModal() == .OK, let url = panel.url {
            try? store.exportData(to: url)
        }
    }

    private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.title = text(.settingsImportPanelTitle)
        panel.prompt = text(.commonImport)
        panel.message = text(.settingsImportPanelMessage)
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

private struct SettingsOnboardingCoachCardSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let nextSize = nextValue()
        if nextSize != .zero {
            value = nextSize
        }
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
    @ObservedObject var languageStore: AppLanguageStore
    let onClose: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    @State private var coachCardSize: CGSize = .zero

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
                    .background(
                        GeometryReader { cardProxy in
                            Color.clear.preference(
                                key: SettingsOnboardingCoachCardSizePreferenceKey.self,
                                value: cardProxy.size
                            )
                        }
                    )
                    .offset(x: coachLayout.origin.x, y: coachLayout.origin.y)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onPreferenceChange(SettingsOnboardingCoachCardSizePreferenceKey.self) { newSize in
            guard newSize != .zero, newSize != coachCardSize else { return }
            coachCardSize = newSize
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
                    Text(languageStore.text(.settingsOnboardingGuideTitle))
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
                Text(languageStore.text(.settingsLocatingControl))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 10) {
                Button(languageStore.text(.settingsWatchLater), action: onClose)
                    .buttonStyle(.borderless)

                Spacer()

                Button(languageStore.text(.settingsPrevious), action: onPrevious)
                    .buttonStyle(.bordered)
                    .disabled(stepIndex == 0)

                Button(stepIndex == stepCount - 1 ? languageStore.text(.settingsFinish) : languageStore.text(.settingsNext), action: onNext)
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
        let verticalInset: CGFloat = 24
        let targetGap: CGFloat = 16
        let bubbleWidth = min(360, max(300, size.width - horizontalInset * 2))
        let fallbackHeight: CGFloat = step.target == .replacementSection ? 304 : 236
        let cardHeight = coachCardSize.height > 0 ? coachCardSize.height : fallbackHeight
        let maxY = max(verticalInset, size.height - cardHeight - verticalInset)

        guard let focusRect else {
            return SettingsOnboardingCoachLayout(
                origin: CGPoint(
                    x: max(horizontalInset, (size.width - bubbleWidth) / 2),
                    y: clamped(size.height - cardHeight - verticalInset, min: verticalInset, max: maxY)
                ),
                width: bubbleWidth,
                arrowOffset: bubbleWidth / 2,
                arrowDirection: .up
            )
        }

        let verticalLayout = verticalCoachLayout(
            size: size,
            focusRect: focusRect,
            bubbleWidth: bubbleWidth,
            cardHeight: cardHeight,
            horizontalInset: horizontalInset,
            verticalInset: verticalInset,
            targetGap: targetGap,
            maxY: maxY
        )

        if let verticalLayout {
            return verticalLayout
        }

        let sideLayout = sideCoachLayout(
            size: size,
            focusRect: focusRect,
            bubbleWidth: bubbleWidth,
            cardHeight: cardHeight,
            horizontalInset: horizontalInset,
            verticalInset: verticalInset,
            targetGap: targetGap,
            maxY: maxY
        )

        if let sideLayout {
            return sideLayout
        }

        let x = clamped(focusRect.midX - bubbleWidth / 2, min: horizontalInset, max: max(horizontalInset, size.width - bubbleWidth - horizontalInset))
        let availableBelow = size.height - focusRect.maxY - verticalInset
        let availableAbove = focusRect.minY - verticalInset
        let placeBelow = availableBelow >= availableAbove
        let y = placeBelow
            ? clamped(focusRect.maxY + targetGap, min: verticalInset, max: maxY)
            : clamped(focusRect.minY - cardHeight - targetGap, min: verticalInset, max: maxY)
        let arrowOffset = clamped(focusRect.midX - x, min: 32, max: bubbleWidth - 32)

        return SettingsOnboardingCoachLayout(
            origin: CGPoint(x: x, y: y),
            width: bubbleWidth,
            arrowOffset: arrowOffset,
            arrowDirection: placeBelow ? .up : .down
        )
    }

    private func verticalCoachLayout(
        size: CGSize,
        focusRect: CGRect,
        bubbleWidth: CGFloat,
        cardHeight: CGFloat,
        horizontalInset: CGFloat,
        verticalInset: CGFloat,
        targetGap: CGFloat,
        maxY: CGFloat
    ) -> SettingsOnboardingCoachLayout? {
        let x = clamped(focusRect.midX - bubbleWidth / 2, min: horizontalInset, max: max(horizontalInset, size.width - bubbleWidth - horizontalInset))
        let arrowOffset = clamped(focusRect.midX - x, min: 32, max: bubbleWidth - 32)
        let availableBelow = size.height - focusRect.maxY - verticalInset
        let availableAbove = focusRect.minY - verticalInset

        if availableBelow >= cardHeight + targetGap {
            return SettingsOnboardingCoachLayout(
                origin: CGPoint(x: x, y: focusRect.maxY + targetGap),
                width: bubbleWidth,
                arrowOffset: arrowOffset,
                arrowDirection: .up
            )
        }

        if availableAbove >= cardHeight + targetGap {
            return SettingsOnboardingCoachLayout(
                origin: CGPoint(x: x, y: clamped(focusRect.minY - cardHeight - targetGap, min: verticalInset, max: maxY)),
                width: bubbleWidth,
                arrowOffset: arrowOffset,
                arrowDirection: .down
            )
        }

        return nil
    }

    private func sideCoachLayout(
        size: CGSize,
        focusRect: CGRect,
        bubbleWidth: CGFloat,
        cardHeight: CGFloat,
        horizontalInset: CGFloat,
        verticalInset: CGFloat,
        targetGap: CGFloat,
        maxY: CGFloat
    ) -> SettingsOnboardingCoachLayout? {
        let availableLeading = focusRect.minX - horizontalInset
        let availableTrailing = size.width - focusRect.maxX - horizontalInset
        let y = clamped(focusRect.midY - cardHeight / 2, min: verticalInset, max: maxY)

        if availableLeading >= bubbleWidth + targetGap {
            return SettingsOnboardingCoachLayout(
                origin: CGPoint(x: focusRect.minX - bubbleWidth - targetGap, y: y),
                width: bubbleWidth,
                arrowOffset: bubbleWidth / 2,
                arrowDirection: .none
            )
        }

        if availableTrailing >= bubbleWidth + targetGap {
            return SettingsOnboardingCoachLayout(
                origin: CGPoint(x: focusRect.maxX + targetGap, y: y),
                width: bubbleWidth,
                arrowOffset: bubbleWidth / 2,
                arrowDirection: .none
            )
        }

        return nil
    }

    private func clamped(_ value: CGFloat, min lowerBound: CGFloat, max upperBound: CGFloat) -> CGFloat {
        Swift.max(lowerBound, Swift.min(value, upperBound))
    }
}

private enum SettingsOnboardingArrowDirection {
    case up
    case down
    case none
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
        case .none:
            return path
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
    @ObservedObject var languageStore: AppLanguageStore
    let onCancel: () -> Void
    let onApply: () -> Void

    @State private var showCancelConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(languageStore.text(.replacementEditorTitle))
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(languageStore.formatted(.replacementEditorEditingFormat, trigger.isEmpty ? "Key" : trigger))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(languageStore.text(.commonCancel), action: handleCancel)
                    .buttonStyle(SecondaryActionButtonStyle())

                Button(languageStore.text(.commonApply), action: onApply)
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
            languageStore.text(.replacementUnsavedTitle),
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button(languageStore.text(.replacementApplyChanges)) {
                onApply()
            }

            Button(languageStore.text(.replacementDiscardChanges), role: .destructive) {
                onCancel()
            }

            Button(languageStore.text(.replacementContinueEditing), role: .cancel) {}
        } message: {
            Text(languageStore.text(.replacementUnsavedMessage))
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
