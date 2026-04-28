import AppKit
import SwiftUI
import SnipKeyCore

struct ClipboardHistorySheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var historyStore: ClipboardHistoryStore
    @ObservedObject var languageStore: AppLanguageStore
    let onCreateSnippet: (ClipboardRecord) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    settingsCard
                    historySection
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .frame(minWidth: 680, minHeight: 520)
        .background(sheetBackground)
    }

    private var monitoringEnabledBinding: Binding<Bool> {
        Binding(
            get: { historyStore.settings.isMonitoringEnabled },
            set: { newValue in
                historyStore.updateSettings(
                    ClipboardSettings(
                        isMonitoringEnabled: newValue,
                        suggestionThreshold: historyStore.settings.suggestionThreshold
                    )
                )
            }
        )
    }

    private var suggestionThresholdBinding: Binding<Int> {
        Binding(
            get: { historyStore.settings.suggestionThreshold },
            set: { newValue in
                historyStore.updateSettings(
                    ClipboardSettings(
                        isMonitoringEnabled: historyStore.settings.isMonitoringEnabled,
                        suggestionThreshold: newValue
                    )
                )
            }
        )
    }

    private var sheetBackground: Color {
        Color(.sRGB, red: 0.955, green: 0.959, blue: 0.966, opacity: 1)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(languageStore.text(.clipboardTitle))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))

                    Text(headerSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 16)

                HStack(spacing: 8) {
                    Button(languageStore.text(.clipboardClearRecords), role: .destructive) {
                        historyStore.clearHistory()
                    }
                    .buttonStyle(.bordered)
                    .disabled(historyStore.records.isEmpty)

                    Button(languageStore.text(.commonClose)) {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 2)

            statusStrip
                .padding(.trailing, statusStripTrailingInset)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var statusStripTrailingInset: CGFloat {
        guard NSScroller.preferredScrollerStyle == .legacy else {
            return 0
        }

        return NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    }

    private var statusStrip: some View {
        ClipboardSheetCard {
            HStack(spacing: 0) {
                statusItem(
                    icon: "doc.text",
                    title: languageStore.text(.clipboardRecordMetric),
                    value: "\(historyStore.records.count)",
                    tint: .primary
                )

                statusDivider

                statusItem(
                    icon: historyStore.settings.isMonitoringEnabled ? "checkmark.circle.fill" : "pause.circle.fill",
                    title: languageStore.text(.clipboardStatusMetric),
                    value: historyStore.settings.isMonitoringEnabled ? languageStore.text(.clipboardStatusOn) : languageStore.text(.clipboardStatusOff),
                    tint: historyStore.settings.isMonitoringEnabled ? .green : .secondary
                )

                statusDivider

                statusItem(
                    icon: "slider.horizontal.3",
                    title: languageStore.text(.clipboardThresholdMetric),
                    value: languageStore.formatted(.clipboardTimesFormat, historyStore.settings.suggestionThreshold),
                    tint: .accentColor
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var settingsCard: some View {
        ClipboardSheetCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(
                    title: languageStore.text(.clipboardSuggestionSettingsTitle),
                    subtitle: languageStore.text(.clipboardSuggestionSettingsSubtitle)
                ) {
                    EmptyView()
                }

                VStack(spacing: 8) {
                    ClipboardSheetField {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(languageStore.text(.clipboardMonitoringToggleTitle))
                                    .font(.body)
                                    .fontWeight(.medium)

                                Text(languageStore.text(.clipboardMonitoringToggleSubtitle))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer(minLength: 12)

                            Toggle("", isOn: monitoringEnabledBinding)
                                .labelsHidden()
                        }
                    }

                    ClipboardSheetField {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(languageStore.text(.clipboardThresholdTitle))
                                    .font(.body)
                                    .fontWeight(.medium)

                                Text(languageStore.formatted(.clipboardThresholdDescriptionFormat, historyStore.settings.suggestionThreshold))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer(minLength: 12)

                            Text(languageStore.formatted(.clipboardTimesFormat, historyStore.settings.suggestionThreshold))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()

                            Stepper("", value: suggestionThresholdBinding, in: 2...10)
                                .labelsHidden()
                        }
                    }
                }
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: languageStore.text(.clipboardRecentCopiesTitle),
                subtitle: historySectionSubtitle
            ) {
                EmptyView()
            }

            if historyStore.records.isEmpty {
                ClipboardSheetCard {
                    VStack(alignment: .center, spacing: 10) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 26))
                            .foregroundColor(.secondary)

                        Text(languageStore.text(.clipboardEmptyTitle))
                            .font(.headline)

                        Text(languageStore.text(.clipboardEmptySubtitle))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(historyStore.records) { record in
                        ClipboardHistoryRow(
                            record: record,
                            languageStore: languageStore,
                            onCreateSnippet: {
                                onCreateSnippet(record)
                                dismiss()
                            },
                            onDelete: {
                                historyStore.deleteRecord(id: record.id)
                            }
                        )
                    }
                }
            }
        }
    }

    private var headerSubtitle: String {
        if historyStore.settings.isMonitoringEnabled {
            return languageStore.formatted(.clipboardHeaderEnabledFormat, ClipboardHistoryStore.defaultMaxRecordCount)
        }

        return languageStore.text(.clipboardHeaderPaused)
    }

    private var historySectionSubtitle: String {
        if historyStore.records.isEmpty {
            return languageStore.text(.clipboardHistoryEmptySubtitle)
        }

        return languageStore.formatted(.clipboardHistoryCountSubtitleFormat, historyStore.records.count)
    }

    private var statusDivider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.18))
            .frame(width: 1, height: 30)
            .padding(.horizontal, 4)
    }

    private func statusItem(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.system(.body, design: .default).weight(.semibold))
                    .foregroundColor(.primary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private func sectionHeader<Trailing: View>(
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
}

private struct ClipboardHistoryRow: View {
    let record: ClipboardRecord
    @ObservedObject var languageStore: AppLanguageStore
    let onCreateSnippet: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ClipboardSheetCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.headline)
                            .lineLimit(1)

                        Text(lastCopiedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 12)

                    if record.snippetCreatedAt != nil {
                        badge(
                            title: languageStore.text(.clipboardCreatedKey),
                            systemImage: "checkmark.circle.fill",
                            tint: .green,
                            fill: Color.green.opacity(0.12)
                        )
                    } else {
                        badge(
                            title: languageStore.formatted(.clipboardCopiedTimesFormat, record.copyCount),
                            systemImage: nil,
                            tint: .accentColor,
                            fill: Color.accentColor.opacity(0.10)
                        )
                    }
                }

                ClipboardSheetField {
                    Text(bodyPreview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(4)
                }

                HStack(spacing: 10) {
                    Button(languageStore.text(.clipboardDeleteRecord), role: .destructive, action: onDelete)
                        .buttonStyle(.borderless)

                    Spacer()

                    Button(action: onCreateSnippet) {
                        Label(record.snippetCreatedAt != nil ? languageStore.text(.clipboardCreatedKey) : languageStore.text(.clipboardNewKey), systemImage: record.snippetCreatedAt != nil ? "checkmark.circle.fill" : "plus")
                    }
                    .buttonStyle(ClipboardPrimaryButtonStyle())
                    .disabled(record.snippetCreatedAt != nil)
                }
            }
        }
    }

    private func badge(title: String, systemImage: String?, tint: Color, fill: Color) -> some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
            }

            Text(title)
        }
        .font(.caption2)
        .fontWeight(.medium)
        .foregroundColor(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(fill)
        )
    }

    private var title: String {
        let trimmed = record.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? trimmed
        let preview = String(firstLine.prefix(36))
        return firstLine.count > preview.count ? preview + "…" : preview
    }

    private var bodyPreview: String {
        let flattened = record.content.replacingOccurrences(of: "\n", with: " ")
        let preview = String(flattened.prefix(180))
        return flattened.count > preview.count ? preview + "…" : preview
    }

    private var lastCopiedDescription: String {
        let calendar = Calendar.current
        let time = record.lastCopiedAt.formatted(.dateTime.locale(languageStore.language.locale).hour().minute())

        if calendar.isDateInToday(record.lastCopiedAt) {
            return languageStore.formatted(.clipboardTodayFormat, time)
        }

        if calendar.isDateInYesterday(record.lastCopiedAt) {
            return languageStore.formatted(.clipboardYesterdayFormat, time)
        }

        return record.lastCopiedAt.formatted(.dateTime.locale(languageStore.language.locale).month(.abbreviated).day().hour().minute())
    }
}

private struct ClipboardSheetCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)
            )
    }
}

private struct ClipboardSheetField<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.12), lineWidth: 1)
                    )
            )
    }
}

private struct ClipboardPrimaryButtonStyle: ButtonStyle {
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