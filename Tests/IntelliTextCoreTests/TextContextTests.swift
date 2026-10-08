import XCTest
@testable import IntelliTextCore

final class TextContextTests: XCTestCase {
    func testCurrentSentenceUsesCursorBoundary() {
        let context = TextContext(text: "First sentence. Second sentence", selectedRange: NSRange(location: 22, length: 0))
        XCTAssertEqual(context.currentSentence, " Second sentence")
    }

    func testMockProviderOnlyChangesKnownTypo() async throws {
        let provider = MockInferenceProvider()
        let response = try await provider.correct(CorrectionRequest(sentence: "while inputing"))
        XCTAssertEqual(response.replacement, "while inputting")
        XCTAssertGreaterThan(response.confidence, 0.9)
    }
}
