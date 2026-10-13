import XCTest
@testable import IntelliTextCore

final class LocalLLMIntegrationTests: XCTestCase {
    func testLocalQwenCorrection() async throws {
        guard ProcessInfo.processInfo.environment["INTELLITEXT_LLM_INTEGRATION"] == "1" else {
            throw XCTSkip("Set INTELLITEXT_LLM_INTEGRATION=1 to exercise the installed local model server.")
        }
        let sentence = "This project aims to help those who doesn't have only a few experience at crypto and continue losing money and desiring build own skills systemly."
        let provider = LocalLLMInferenceProvider()
        for style in WritingStyle.allCases {
            let response = try await provider.correct(CorrectionRequest(sentence: sentence, style: style))
            XCTAssertGreaterThanOrEqual(response.confidence, 0.9, "Low confidence for \(style)")
            XCTAssertFalse(response.polishedVersion.isEmpty, "Missing polished version for \(style)")
            XCTAssertFalse(response.shortNote.isEmpty, "Missing teaching tip for \(style)")
        }
    }
}
