import Foundation

public struct CorrectionEngine: Sendable {
    private let provider: InferenceProvider

    public init(provider: InferenceProvider = MockInferenceProvider()) { self.provider = provider }

    public func suggest(for context: TextContext, style: WritingStyle = .professional) async throws -> (CorrectionResponse, ReplacementTransaction)? {
        let sentence = context.currentSentence
        guard !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let response = try await provider.correct(CorrectionRequest(sentence: sentence, style: style))
        guard response.confidence >= 0.9, response.replacement != response.original else { return nil }
        return (response, ReplacementTransaction(range: context.currentSentenceRange, original: response.original, replacement: response.replacement))
    }
}
