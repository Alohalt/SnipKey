import AppKit
import SwiftUI

struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let developerDisplayName = "AlohaT"
    private let githubRepositoryDisplayName = "Alohalt/SnipKey"
    private let githubRepositoryURL = URL(string: "https://github.com/Alohalt/SnipKey")!
    private let githubIssuesURL = URL(string: "https://github.com/Alohalt/SnipKey/issues")!

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summaryCard
                    detailsCard
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .frame(minWidth: 520, minHeight: 360)
        .background(sheetBackground)
    }

    private var sheetBackground: Color {
        Color(.sRGB, red: 0.955, green: 0.959, blue: 0.966, opacity: 1)
    }

    private var appIconImage: NSImage {
        NSApplication.shared.applicationIconImage
    }

    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, buildVersion) {
        case let (shortVersion?, buildVersion?) where !buildVersion.isEmpty && buildVersion != shortVersion:
            return "v\(shortVersion) (\(buildVersion))"
        case let (shortVersion?, _):
            return "v\(shortVersion)"
        case let (_, buildVersion?) where !buildVersion.isEmpty:
            return "v\(buildVersion)"
        default:
            return "未知版本"
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("关于 SnipKey")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))

                Text("查看开发者信息、GitHub 仓库地址和反馈入口。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 16)

            Button("关闭") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var summaryCard: some View {
        AboutCard {
            HStack(alignment: .center, spacing: 14) {
                Image(nsImage: appIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("SnipKey")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))

                    Text("面向 macOS 的菜单栏文本扩展工具，支持 Key 管理、补全面板和剪贴板建议。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var detailsCard: some View {
        AboutCard {
            VStack(alignment: .leading, spacing: 12) {
                aboutMetadataRow(title: "开发者", value: developerDisplayName)
                aboutMetadataRow(title: "GitHub", value: githubRepositoryDisplayName)
                aboutMetadataRow(title: "仓库地址", value: githubRepositoryURL.absoluteString)
                aboutMetadataRow(title: "版本", value: appVersionText)

                HStack(spacing: 10) {
                    aboutActionLink(
                        title: "仓库主页",
                        systemImage: "link",
                        destination: githubRepositoryURL
                    )

                    aboutActionLink(
                        title: "反馈问题",
                        systemImage: "bubble.left.and.exclamationmark.bubble.right",
                        destination: githubIssuesURL
                    )
                }
            }
        }
    }

    private func aboutMetadataRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func aboutActionLink(title: String, systemImage: String, destination: URL) -> some View {
        Link(destination: destination) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct AboutCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.18), lineWidth: 1)
                    )
            )
    }
}