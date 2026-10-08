import Foundation

public enum WritingStyle: String, CaseIterable, Sendable {
    case casual
    case businessEmail = "business_email"
    case professional
    case academic
}

public struct CorrectionRequest: Sendable {
    public let sentence: String
    public let style: WritingStyle
    public let assist: Bool

    public init(sentence: String, style: WritingStyle = .professional, assist: Bool = false) {
        self.sentence = sentence
        self.style = style
        self.assist = assist
    }
}

public struct CorrectionResponse: Equatable, Sendable {
    public let original: String
    public let replacement: String
    public let confidence: Double
    public let shortNote: String

    public init(original: String, replacement: String, confidence: Double, shortNote: String) {
        self.original = original
        self.replacement = replacement
        self.confidence = confidence
        self.shortNote = shortNote
    }
}

public protocol InferenceProvider: Sendable {
    func correct(_ request: CorrectionRequest) async throws -> CorrectionResponse
}

public struct RuleInferenceProvider: InferenceProvider {
    public init() {}

    public func correct(_ request: CorrectionRequest) async throws -> CorrectionResponse {
        var result = request.sentence
        var notes: [String] = []
        for (wrong, right) in [("inputing", "inputting"), ("teh", "the"), ("recieve", "receive"), ("grammer", "grammar"), ("alot", "a lot")] where result.range(of: wrong, options: .caseInsensitive) != nil {
            result = result.replacingOccurrences(of: wrong, with: right, options: .caseInsensitive)
            notes.append("spelling")
        }
        let collapsed = result.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
        if collapsed != result { result = collapsed; notes.append("spacing") }
        if let first = result.first, first.isLowercase { result = first.uppercased() + result.dropFirst(); notes.append("capitalization") }
        if request.style == .businessEmail {
            result = result.replacingOccurrences(of: "can't", with: "cannot", options: .caseInsensitive)
            result = result.replacingOccurrences(of: "don't", with: "do not", options: .caseInsensitive)
        }
        return CorrectionResponse(original: request.sentence, replacement: result, confidence: result == request.sentence ? 0.0 : 0.995, shortNote: notes.isEmpty ? "No rule-based change" : notes.joined(separator: ", "))
    }
}

public struct MockInferenceProvider: InferenceProvider {
    public init() {}

    public func correct(_ request: CorrectionRequest) async throws -> CorrectionResponse {
        return try await RuleInferenceProvider().correct(request)
    }
}
