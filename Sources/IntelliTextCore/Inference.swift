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

public struct LocalLLMInferenceProvider: InferenceProvider {
    public let endpoint: URL

    public init(endpoint: URL = URL(string: "http://127.0.0.1:11439/v1/chat/completions")!) {
        self.endpoint = endpoint
    }

    public func correct(_ request: CorrectionRequest) async throws -> CorrectionResponse {
        let styleInstruction: String
        switch request.style {
        case .casual: styleInstruction = "Use natural, friendly everyday English."
        case .businessEmail: styleInstruction = "Use polished, concise business-email English. Be courteous and professional."
        case .professional: styleInstruction = "Use clear, natural professional English."
        case .academic: styleInstruction = "Use precise, formal academic English without changing the author's claims."
        }

        let system = """
        /no_think You are an English editing engine. Correct grammar, spelling, punctuation, and awkward phrasing in exactly one sentence. \(styleInstruction) Preserve the author's meaning and facts. Do not translate non-English words; leave them in place. Return exactly one JSON object with keys replacement, confidence (0 to 1), and short_note. No markdown or explanation.
        """
        let payload = ChatCompletionPayload(
            model: "Qwen3-8B-Q4_K_M",
            messages: [.init(role: "system", content: system), .init(role: "user", content: request.sentence)],
            temperature: 0.15,
            max_tokens: 128,
            response_format: .init(type: "json_object")
        )
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 20
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw InferenceError.invalidServerResponse
        }
        let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = completion.choices.first?.message.content,
              let json = content.data(using: .utf8),
              let result = try? JSONDecoder().decode(ModelCorrection.self, from: json) else {
            throw InferenceError.invalidModelOutput
        }
        return CorrectionResponse(
            original: request.sentence,
            replacement: result.replacement.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: min(1, max(0, result.confidence)),
            shortNote: result.shortNote
        )
    }
}

private struct ChatCompletionPayload: Encodable {
    struct Message: Encodable { let role: String; let content: String }
    struct Format: Encodable { let type: String }
    let model: String
    let messages: [Message]
    let temperature: Double
    let max_tokens: Int
    let response_format: Format
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable { struct Message: Decodable { let content: String }; let message: Message }
    let choices: [Choice]
}

private struct ModelCorrection: Decodable {
    let replacement: String
    let confidence: Double
    let shortNote: String
    enum CodingKeys: String, CodingKey { case replacement, confidence; case shortNote = "short_note" }
}

public enum InferenceError: Error {
    case invalidServerResponse
    case invalidModelOutput
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

public struct HybridInferenceProvider: InferenceProvider {
    private let rules = RuleInferenceProvider()
    private let languageModel: InferenceProvider

    public init(languageModel: InferenceProvider = LocalLLMInferenceProvider()) {
        self.languageModel = languageModel
    }

    public func correct(_ request: CorrectionRequest) async throws -> CorrectionResponse {
        let deterministic = try await rules.correct(request)
        if deterministic.replacement != request.sentence {
            return deterministic
        }
        return try await languageModel.correct(request)
    }
}

public struct MockInferenceProvider: InferenceProvider {
    public init() {}

    public func correct(_ request: CorrectionRequest) async throws -> CorrectionResponse {
        return try await RuleInferenceProvider().correct(request)
    }
}
