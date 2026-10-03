import XCTest
@testable import Intent

final class EditingTests: XCTestCase {
    func testRejectsSelectionAndDocumentDrift() {
        let original = SelectionGuard(text: "review", range: NSRange(location: 4, length: 6), document: "The review tomorrow")
        XCTAssertTrue(original.matches(text: "review", range: original.range, document: original.document))
        XCTAssertFalse(original.matches(text: "review", range: NSRange(location: 0, length: 6), document: original.document))
        XCTAssertFalse(original.matches(text: "review", range: original.range, document: "The review today"))
        XCTAssertFalse(original.matches(text: "today", range: original.range, document: original.document))
        XCTAssertFalse(original.matches(text: "review", range: original.range, document: nil))
    }

    func testUTF16ReplacementPreservesSurroundingText() {
        let document = "👋 Before नमस्ते after."
        let range = (document as NSString).range(of: "नमस्ते")
        let selection = SelectionGuard(text: "नमस्ते", range: range, document: document)
        XCTAssertEqual(selection.replacing(with: "hello 🌏"), "👋 Before hello 🌏 after.")
        XCTAssertNil(SelectionGuard(text: "different", range: range, document: document).replacing(with: "hello"))
        XCTAssertNil(SelectionGuard(text: "नमस्ते", range: NSRange(location: Int.max, length: 5), document: document).replacing(with: "hello"))
    }

    func testMissingDocumentCannotProduceUndoSnapshot() {
        let selection = SelectionGuard(text: "hello", range: NSRange(location: 0, length: 5), document: nil)
        XCTAssertTrue(selection.matches(text: "hello", range: selection.range, document: nil))
        XCTAssertNil(selection.replacing(with: "hi"))
    }

    private func reply(_ text: String, done: Bool = true, reason: String = "stop") throws -> Data {
        let content = try JSONSerialization.data(withJSONObject: ["text": text])
        return try JSONSerialization.data(withJSONObject: ["message": ["content": String(decoding: content, as: UTF8.self)], "done": done, "done_reason": reason])
    }

    func testStructuredReplyPreservesFormattingAndUnicode() throws {
        let text = "• Kal 4 baje 👋\n• Budget: ₹2,000\n"
        XCTAssertEqual(try LocalTextEditor.decode(reply(text)), text)
    }

    func testRejectsIncompleteEmptyAndMalformedRewrites() throws {
        XCTAssertThrowsError(try LocalTextEditor.decode(reply("partial", done: false)))
        XCTAssertThrowsError(try LocalTextEditor.decode(reply("partial", reason: "length")))
        XCTAssertThrowsError(try LocalTextEditor.decode(reply("  \n")))
        XCTAssertThrowsError(try LocalTextEditor.decode(Data("not JSON".utf8)))
        let malformed = try JSONSerialization.data(withJSONObject: ["message": ["content": "Here is your edit"], "done": true])
        XCTAssertThrowsError(try LocalTextEditor.decode(malformed))
    }
}
