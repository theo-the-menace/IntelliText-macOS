import XCTest
@testable import IntelliTextCore

final class LocalLLMIntegrationTests: XCTestCase {
    func testLocalQwenCorrection() async throws {
        guard ProcessInfo.processInfo.environment["INTELLITEXT_LLM_INTEGRATION"] == "1" else {
            throw XCTSkip("Set INTELLITEXT_LLM_INTEGRATION=1 to exercise the installed local model server.")
        }
        let provider = LocalLLMInferenceProvider()
        for sentence in ["we go to school yesterday.", "we go to schoole yesterday."] {
            let response = try await provider.correct(CorrectionRequest(sentence: sentence, style: .professional))
            XCTAssertEqual(response.replacement, "We went to school yesterday.")
            XCTAssertGreaterThanOrEqual(response.confidence, 0.9)
        }
    }
}
