import AppKit
import SwiftUI
import SnipKeyCore

struct ClipboardHistorySheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var historyStore: ClipboardHistoryStore
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
                    Text("剪贴板记录")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))

                    Text(headerSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 16)

                HStack(spacing: 8) {
                    Button("清空记录", role: .destructive) {
                        historyStore.clearHistory()
                    }
                    .buttonStyle(.bordered)
                    .disabled(historyStore.records.isEmpty)

                    Button("关闭") {
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
                    title: "记录",
                    value: "\(historyStore.records.count)",
                    tint: .primary
                )

                statusDivider

                statusItem(
                    icon: historyStore.settings.isMonitoringEnabled ? "checkmark.circle.fill" : "pause.circle.fill",
                    title: "状态",
                    value: historyStore.settings.isMonitoringEnabled ? "已开启" : "已关闭",
                    tint: historyStore.settings.isMonitoringEnabled ? .green : .secondary
                )

                statusDivider

                statusItem(
                    icon: "slider.horizontal.3",
                    title: "阈值",
                    value: "\(historyStore.settings.suggestionThreshold) 次",
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
                    title: "建议设置",
                    subtitle: "达到阈值时会提示你把重复复制的内容保存为 Key。"
                ) {
                    EmptyView()
                }

                VStack(spacing: 8) {
                    ClipboardSheetField {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("记录剪贴板文本")
                                    .font(.body)
                                    .fontWeight(.medium)

                                Text("关闭后不会新增历史记录，也不会弹出创建 Key 的建议。")
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
                                Text("提示阈值")
                                    .font(.body)
                                    .fontWeight(.medium)

                                Text("同一段文本复制到 \(historyStore.settings.suggestionThreshold) 次时，询问是否创建新的 Key。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer(minLength: 12)

                            Text("\(historyStore.settings.suggestionThreshold) 次")
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
                title: "最近复制",
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

                        Text("还没有记录到可用的文本复制")
                            .font(.headline)

                        Text("复制几段常用文本后，这里会按最近时间显示历史记录，并支持一键新建 Key。")
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
            return "按最近复制时间排序，达到设定次数后会提示创建 Key。"
        }

        return "当前已暂停记录剪贴板文本。"
    }

    private var historySectionSubtitle: String {
        if historyStore.records.isEmpty {
            return "还没有可用的复制记录。"
        }

        return "共 \(historyStore.records.count) 条记录，最近复制的内容会排在最前面。"
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
                            title: "已建Key",
                            systemImage: "checkmark.circle.fill",
                            tint: .green,
                            fill: Color.green.opacity(0.12)
                        )
                    } else {
                        badge(
                            title: "已复制 \(record.copyCount) 次",
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
                    Button("删除记录", role: .destructive, action: onDelete)
                        .buttonStyle(.borderless)

                    Spacer()

                    Button(action: onCreateSnippet) {
                        Label(record.snippetCreatedAt != nil ? "已建Key" : "新建Key", systemImage: record.snippetCreatedAt != nil ? "checkmark.circle.fill" : "plus")
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
        let time = record.lastCopiedAt.formatted(date: .omitted, time: .shortened)

        if calendar.isDateInToday(record.lastCopiedAt) {
            return "今天 \(time)"
        }

        if calendar.isDateInYesterday(record.lastCopiedAt) {
            return "昨天 \(time)"
        }

        return record.lastCopiedAt.formatted(date: .abbreviated, time: .shortened)
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