import SwiftUI
import SnipKeyCore

private enum CompletionPanelMetrics {
    static let panelWidth: CGFloat = 380
    static let panelCornerRadius: CGFloat = 18
    static let panelPadding: CGFloat = 12
    static let listSpacing: CGFloat = 8
    static let maxListHeight: CGFloat = 288
    static let estimatedRowHeight: CGFloat = 82
    static let rowCornerRadius: CGFloat = 16
}

struct CompletionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let snippets: [Snippet]
    let selectedIndex: Int
    let shouldAutoScrollSelection: Bool
    let onHoverSelection: (Int) -> Void
    let onConfirmSelection: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CompletionHeader(snippetCount: snippets.count)

            if snippets.isEmpty {
                Text("无匹配结果")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: snippets.count > 4) {
                        VStack(alignment: .leading, spacing: CompletionPanelMetrics.listSpacing) {
                            ForEach(Array(snippets.enumerated()), id: \.element.id) { index, snippet in
                                CompletionRow(
                                    snippet: snippet,
                                    isSelected: index == selectedIndex,
                                    onHover: { isHovering in
                                        guard isHovering else { return }
                                        onHoverSelection(index)
                                    },
                                    onConfirm: {
                                        onConfirmSelection(index)
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: listHeight)
                    .onChange(of: selectedIndex) { newValue in
                        guard shouldAutoScrollSelection else { return }
                        guard snippets.indices.contains(newValue) else { return }
                        if reduceMotion {
                            proxy.scrollTo(newValue, anchor: .center)
                        } else {
                            withAnimation(.easeOut(duration: 0.18)) {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .padding(CompletionPanelMetrics.panelPadding)
        .frame(width: CompletionPanelMetrics.panelWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CompletionPanelMetrics.panelCornerRadius)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CompletionPanelMetrics.panelCornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.32), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: CompletionPanelMetrics.panelCornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.58), Color(nsColor: .separatorColor).opacity(0.20)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: CompletionPanelMetrics.panelCornerRadius))
        .shadow(color: .black.opacity(0.12), radius: 24, y: 14)
        .shadow(color: Color.accentColor.opacity(0.08), radius: 10, y: 4)
    }

    private var listHeight: CGFloat {
        let estimatedHeight = CGFloat(snippets.count) * CompletionPanelMetrics.estimatedRowHeight
        return min(estimatedHeight, CompletionPanelMetrics.maxListHeight)
    }
}

private struct CompletionHeader: View {
    let snippetCount: Int

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("候选片段")
                    .font(.headline)

                Label("点击或回车插入", systemImage: "cursorarrow.click.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(snippetCount.formatted())
                .font(.system(.subheadline, design: .rounded))
                .bold()
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.accentColor.opacity(0.12))
                )
                .accessibilityLabel("共 \(snippetCount) 条候选")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.accentColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.accentColor.opacity(0.14), lineWidth: 1)
                )
        )
    }
}

private struct CompletionRow: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    let snippet: Snippet
    let isSelected: Bool
    let onHover: (Bool) -> Void
    let onConfirm: () -> Void

    var body: some View {
        Button(action: onConfirm) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Text("#\(snippet.trigger)")
                        .font(.system(.callout, design: .monospaced))
                        .bold()
                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(
                                    isSelected
                                    ? Color.accentColor.opacity(0.14)
                                    : Color(nsColor: .controlBackgroundColor).opacity(0.82)
                                )
                        )

                    Spacer(minLength: 8)

                    if isSelected {
                        Image(systemName: differentiateWithoutColor ? "checkmark.circle.fill" : "cursorarrow.click.2")
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                    }
                }

                Text(replacementPreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CompletionPanelMetrics.rowCornerRadius)
                    .fill(
                        isSelected
                        ? Color.accentColor.opacity(0.10)
                        : Color(nsColor: .windowBackgroundColor).opacity(0.72)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CompletionPanelMetrics.rowCornerRadius)
                            .stroke(
                                isSelected
                                ? Color.accentColor.opacity(0.18)
                                : Color(nsColor: .separatorColor).opacity(0.10),
                                lineWidth: 1
                            )
                    )
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 4)
                        .padding(.vertical, 10)
                        .padding(.leading, 6)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: CompletionPanelMetrics.rowCornerRadius))
        .onHover(perform: onHover)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("点击即可插入这个片段")
    }

    private var replacementPreview: String {
        let flattened = snippet.replacement
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let preview = String(flattened.prefix(96))
        return flattened.count > preview.count ? preview + "…" : preview
    }

    private var accessibilityText: String {
        "触发词 #\(snippet.trigger)，内容 \(replacementPreview)"
    }
}
