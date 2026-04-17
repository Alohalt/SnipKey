import SwiftUI
import SnipKeyCore

struct CompletionView: View {
    private let cornerRadius: CGFloat = 12

    let snippets: [Snippet]
    let selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if snippets.isEmpty {
                Text("无匹配结果")
                    .foregroundColor(.secondary)
                    .padding(8)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(snippets.enumerated()), id: \.element.id) { index, snippet in
                                CompletionRow(
                                    snippet: snippet,
                                    isSelected: index == selectedIndex
                                )
                                .id(index)
                            }
                        }
                    }
                    .onChange(of: selectedIndex) { newValue in
                        withAnimation {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 320, height: min(CGFloat(snippets.count) * 44, 264))
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 18, y: 10)
    }
}

struct CompletionRow: View {
    let snippet: Snippet
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(snippet.trigger)")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                Text(snippet.replacement.prefix(60) + (snippet.replacement.count > 60 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        .contentShape(Rectangle())
    }
}
