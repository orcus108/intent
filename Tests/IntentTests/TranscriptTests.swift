import XCTest
@testable import Intent

final class TranscriptTests: XCTestCase {
    func testClipboardContentsRemainLiteral() {
        let copied = "$1 \\ notes 👋\nsecond line"
        XCTAssertEqual(Transcript.expandClipboard(in: "Compare clip clip with CLIP CLIP.", clipboard: copied), "Compare \(copied) with \(copied).")
    }
    func testNoAccidentalPartialMatch() {
        XCTAssertEqual(Transcript.expandClipboard(in: "paperclip clip clips", clipboard: "secret"), "paperclip clip clips")
    }
    func testMissingClipboardPreservesIntent() {
        XCTAssertEqual(Transcript.expandClipboard(in: "Explain clip clip", clipboard: nil), "Explain clip clip")
    }
    func testNoRewriteOfMixedLanguage() {
        XCTAssertEqual(Transcript.normalize("  Kal 4 baje, actually 5 baje milte hain.  "), "Kal 4 baje, actually 5 baje milte hain.")
    }
}
