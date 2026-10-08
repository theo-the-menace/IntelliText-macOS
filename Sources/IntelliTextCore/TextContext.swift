import Foundation

public struct TextContext: Equatable, Sendable {
    public let text: String
    public let selectedRange: NSRange

    public init(text: String, selectedRange: NSRange) {
        self.text = text
        self.selectedRange = selectedRange
    }

    public var currentSentence: String {
        let range = currentSentenceRange
        return (text as NSString).substring(with: range)
    }

    /// Document-relative UTF-16 range, suitable for IMKTextInput replacementRange.
    public var currentSentenceRange: NSRange {
        let nsText = text as NSString
        let cursor = max(0, min(selectedRange.location, nsText.length))
        let delimiters = CharacterSet(charactersIn: ".!?\n")

        var start = cursor
        while start > 0 {
            let character = nsText.character(at: start - 1)
            if character <= UInt16.max, delimiters.contains(UnicodeScalar(character)!) { break }
            start -= 1
        }

        var end = cursor
        while end < nsText.length {
            let character = nsText.character(at: end)
            if character <= UInt16.max, delimiters.contains(UnicodeScalar(character)!) {
                end += 1
                break
            }
            end += 1
        }
        return NSRange(location: start, length: end - start)
    }
}

public struct ReplacementTransaction: Equatable, Sendable {
    public let range: NSRange
    public let original: String
    public let replacement: String

    public init(range: NSRange, original: String, replacement: String) {
        self.range = range
        self.original = original
        self.replacement = replacement
    }
}
