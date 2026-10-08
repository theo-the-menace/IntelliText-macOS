import XCTest
@testable import IntelliTextCore

final class LocalLLMIntegrationTests: XCTestCase {
    func testLocalQwenCorrection() async throws {
        guard ProcessInfo.processInfo.environment["INTELLITEXT_LLM_INTEGRATION"] == "1" else {
            throw XCTSkip("Set INTELLITEXT_LLM_INTEGRATION=1 to exercise the installed local model server.")
        }
        let response = try await LocalLLMInferenceProvider().correct(
            CorrectionRequest(sentence: "She go to the office yesterday.", style: .professional)
        )
        XCTAssertEqual(response.replacement, "She went to the office yesterday.")
        XCTAssertGreaterThanOrEqual(response.confidence, 0.9)
    }
}
