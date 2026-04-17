import Combine
import Foundation

struct FocusSnippetRequest: Equatable {
    let snippetId: UUID
    let requestId: UUID = UUID()
}

final class SettingsCoordinator: ObservableObject {
    @Published private(set) var focusRequest: FocusSnippetRequest?
    @Published private(set) var clipboardHistoryRequestId: UUID?

    func focusSnippet(_ snippetId: UUID) {
        focusRequest = FocusSnippetRequest(snippetId: snippetId)
    }

    func consumeFocusRequest(_ request: FocusSnippetRequest) {
        guard focusRequest == request else { return }
        focusRequest = nil
    }

    func showClipboardHistory() {
        clipboardHistoryRequestId = UUID()
    }

    func consumeClipboardHistoryRequest(_ requestId: UUID) {
        guard clipboardHistoryRequestId == requestId else { return }
        clipboardHistoryRequestId = nil
    }
}