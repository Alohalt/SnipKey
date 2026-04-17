import Foundation
#if canImport(AppKit)
import AppKit
#endif

public struct ResolvedText: Equatable {
    public let text: String
    public let cursorOffset: Int?

    public init(text: String, cursorOffset: Int? = nil) {
        self.text = text
        self.cursorOffset = cursorOffset
    }
}

public class VariableResolver {
    private let clipboardProvider: () -> String
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter

    public init(clipboardProvider: @escaping () -> String = VariableResolver.systemClipboard) {
        self.clipboardProvider = clipboardProvider

        dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
    }

    public func resolve(_ template: String) -> ResolvedText {
        var result = template
        var cursorOffset: Int? = nil

        // Replace {date}
        result = result.replacingOccurrences(of: "{date}", with: dateFormatter.string(from: Date()))

        // Replace {time}
        result = result.replacingOccurrences(of: "{time}", with: timeFormatter.string(from: Date()))

        // Replace {clipboard}
        if result.contains("{clipboard}") {
            result = result.replacingOccurrences(of: "{clipboard}", with: clipboardProvider())
        }

        // Handle {cursor} - find position then remove
        if let range = result.range(of: "{cursor}") {
            cursorOffset = result.distance(from: result.startIndex, to: range.lowerBound)
            result = result.replacingOccurrences(of: "{cursor}", with: "")
        }

        return ResolvedText(text: result, cursorOffset: cursorOffset)
    }

    public static func systemClipboard() -> String {
        #if canImport(AppKit)
        return NSPasteboard.general.string(forType: .string) ?? ""
        #else
        return ""
        #endif
    }
}
