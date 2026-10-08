import Foundation

public struct TextContext: Equatable, Sendable {
    public let text: String
    public let selectedRange: NSRange

    public init(text: String, selectedRange: NSRange) {
        self.text = text
        self.selectedRange = selectedRange
    }

    public var currentSentence: String {
        let nsText = text as NSString
        let cursor = max(0, min(selectedRange.location, nsText.length))
        let prefix = nsText.substring(to: cursor)
        let start = prefix.lastIndex(where: { ".!?\n".contains($0) }).map { prefix.index(after: $0) } ?? prefix.startIndex
        let suffix = nsText.substring(from: cursor)
        let endOffset = suffix.firstIndex(where: { ".!?\n".contains($0) }).map { suffix.distance(from: suffix.startIndex, to: $0) + 1 } ?? suffix.count
        return String(prefix[start...]) + String(suffix.prefix(endOffset))
    }
}
