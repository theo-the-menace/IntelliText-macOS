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
        XCTAssertEqual(response.polishedVersion, "While inputting")
        XCTAssertGreaterThan(response.confidence, 0.9)
    }

    func testBusinessStyleExpandsContractionAndKeepsRange() async throws {
        let result = try await CorrectionEngine().suggest(for: TextContext(text: "don't recieve this", selectedRange: NSRange(location: 5, length: 0)), style: .businessEmail)
        XCTAssertEqual(result?.1.range, NSRange(location: 0, length: 18))
        XCTAssertEqual(result?.0.polishedVersion, "do not receive this")
    }

    func testHybridModelCorrectsTenseEvenWhenRuleProviderCapitalizes() async throws {
        let provider = HybridInferenceProvider(languageModel: FixedInferenceProvider(polishedVersion: "We went to school yesterday."))
        let result = try await provider.correct(CorrectionRequest(sentence: "we go to school yesterday."))
        XCTAssertEqual(result.original, "we go to school yesterday.")
        XCTAssertEqual(result.polishedVersion, "We went to school yesterday.")
    }

    func testDailyConversationIsDefaultStyle() {
        XCTAssertEqual(CorrectionRequest(sentence: "Hello").style, .casual)
        XCTAssertEqual(WritingStyle.allCases.first, .casual)
    }

    func testHybridReturnsOnePolishedVersion() async throws {
        let provider = HybridInferenceProvider(languageModel: FixedInferenceProvider(
            polishedVersion: "This project is designed to help people who are new to crypto, have been losing money, and want to develop their skills in a structured way."
        ))
        let result = try await provider.correct(CorrectionRequest(sentence: "This project aims to help those who doesn't have only a few experience at crypto and continue losing money and desiring build own skills systemly."))
        XCTAssertTrue(result.polishedVersion.contains("new to crypto"))
    }
}

private struct FixedInferenceProvider: InferenceProvider {
    let polishedVersion: String

    func correct(_ request: CorrectionRequest) async throws -> CorrectionResponse {
        CorrectionResponse(original: request.sentence, polishedVersion: polishedVersion, confidence: 0.99, shortNote: "Native speakers use this structure because it is clearer and more natural in context.")
    }
}
