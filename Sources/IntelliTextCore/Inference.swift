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

public struct MockInferenceProvider: InferenceProvider {
    public init() {}

    public func correct(_ request: CorrectionRequest) async throws -> CorrectionResponse {
        let replacement = request.sentence.replacingOccurrences(of: "inputing", with: "inputting")
        return CorrectionResponse(
            original: request.sentence,
            replacement: replacement,
            confidence: replacement == request.sentence ? 0.0 : 0.99,
            shortNote: replacement == request.sentence ? "No high-confidence change" : "Corrected spelling"
        )
    }
}
