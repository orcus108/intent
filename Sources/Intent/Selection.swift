import AppKit
import ApplicationServices

struct SelectionGuard {
    let text: String
    let range: NSRange
    let document: String?

    func matches(text: String?, range: NSRange?, document: String?) -> Bool {
        guard text == self.text, range == self.range else { return false }
        return self.document == nil || self.document == document
    }

    func replacing(with replacement: String) -> String? {
        guard let document else { return nil }
        let value = document as NSString
        guard range.location != NSNotFound, range.location >= 0, range.length > 0,
              range.location <= value.length, range.length <= value.length - range.location,
              value.substring(with: range) == text else { return nil }
        return value.replacingCharacters(in: range, with: replacement)
    }
}

@MainActor
struct SelectedText {
    let target: InsertionTarget
    let snapshot: SelectionGuard
    private let window: AXUIElement?

    static func capture() -> SelectedText? {
        guard let target = InsertionTarget.capture(), let text = string(target.element, kAXSelectedTextAttribute),
              !text.isEmpty, let range = selectedRange(target.element), range.length > 0 else { return nil }
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(target.element, kAXWindowAttribute as CFString, &value)
        let window = value.flatMap { CFGetTypeID($0) == AXUIElementGetTypeID() ? ($0 as! AXUIElement) : nil }
        return SelectedText(target: target, snapshot: SelectionGuard(text: text, range: range,
                            document: string(target.element, kAXValueAttribute)), window: window)
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func selectedRange(_ element: AXUIElement) -> NSRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let ax = value as! AXValue
        guard AXValueGetType(ax) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(ax, .cfRange, &range), range.location >= 0, range.length > 0 else { return nil }
        return NSRange(location: range.location, length: range.length)
    }

    private func restoreApp() async -> Bool {
        guard let app = NSRunningApplication(processIdentifier: target.pid), !app.isTerminated else { return false }
        app.activate(options: [])
        if let window { AXUIElementPerformAction(window, kAXRaiseAction as CFString) }
        // Let the original app resume focus, without changing its text selection.
        for _ in 0..<10 {
            if target.isStillFocused() { return true }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return false
    }

    func apply(_ replacement: String) async throws -> AppliedEdit {
        guard await restoreApp(), snapshot.matches(text: Self.string(target.element, kAXSelectedTextAttribute),
                 range: Self.selectedRange(target.element), document: Self.string(target.element, kAXValueAttribute)) else {
            throw SelectionError.changed
        }
        // Use the editor's selection API. No unverified paste fallback for destructive replacement.
        guard AXUIElementSetAttributeValue(target.element, kAXSelectedTextAttribute as CFString, replacement as CFString) == .success else {
            throw SelectionError.unsupported
        }
        let expected = snapshot.replacing(with: replacement)
        if let expected, !(await confirmDocument(expected)) { throw SelectionError.unconfirmed }
        return AppliedEdit(selection: self, replacement: replacement, expectedDocument: expected)
    }

    func undo(_ edit: AppliedEdit) async throws {
        guard let expected = edit.expectedDocument, await restoreApp(),
              Self.string(target.element, kAXValueAttribute) == expected else { throw SelectionError.changed }
        var range = CFRange(location: snapshot.range.location, length: (edit.replacement as NSString).length)
        guard let value = AXValueCreate(.cfRange, &range),
              AXUIElementSetAttributeValue(target.element, kAXSelectedTextRangeAttribute as CFString, value) == .success,
              Self.string(target.element, kAXSelectedTextAttribute) == edit.replacement,
              AXUIElementSetAttributeValue(target.element, kAXSelectedTextAttribute as CFString, snapshot.text as CFString) == .success else {
            throw SelectionError.unsupported
        }
        if let original = snapshot.document, !(await confirmDocument(original)) { throw SelectionError.unconfirmed }
    }

    private func confirmDocument(_ expected: String) async -> Bool {
        for _ in 0..<10 {
            if Self.string(target.element, kAXValueAttribute) == expected { return true }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return false
    }
}

@MainActor
struct AppliedEdit {
    let selection: SelectedText
    let replacement: String
    let expectedDocument: String?
}

enum SelectionError: LocalizedError {
    case changed, unsupported, unconfirmed
    var errorDescription: String? {
        switch self {
        case .changed: return "The original field or selection has changed. Nothing was replaced. Copy the preview, or select the text again and start a new edit."
        case .unsupported: return "This editor does not support direct selection replacement. The preview and original are available to copy."
        case .unconfirmed: return "The editor accepted the change, but its resulting text could not be verified. Review it in your app. Your original is preserved here."
        }
    }
}
