import XCTest
@testable import IntelliTextCore

final class TextContextTests: XCTestCase {
    func testCurrentSentenceUsesCursorBoundary() {
        let context = TextContext(text: "First sentence. Second sentence", selectedRange: NSRange(location: 22, length: 0))
        XCTAssertEqual(context.currentSentence, " Second sentence")
        XCTAssertEqual(context.currentSentenceRange, NSRange(location: 15, length: 16))
    }

    func testSentenceRangeIncludesTerminalPunctuation() {
        let context = TextContext(text: "Fix this typo! Keep this.", selectedRange: NSRange(location: 8, length: 0))
        XCTAssertEqual(context.currentSentence, "Fix this typo!")
    }

    func testMockProviderOnlyChangesKnownTypo() async throws {
        let provider = MockInferenceProvider()
        let response = try await provider.correct(CorrectionRequest(sentence: "while inputing"))
        XCTAssertEqual(response.replacement, "While inputting")
        XCTAssertGreaterThan(response.confidence, 0.9)
    }

    func testBusinessStyleExpandsContractionAndKeepsRange() async throws {
        let result = try await CorrectionEngine().suggest(for: TextContext(text: "don't recieve this", selectedRange: NSRange(location: 5, length: 0)), style: .businessEmail)
        XCTAssertEqual(result?.1.range, NSRange(location: 0, length: 18))
        XCTAssertEqual(result?.0.replacement, "do not receive this")
    }
}
