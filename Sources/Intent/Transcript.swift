import Foundation

enum Transcript {
    static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: #"\[BLANK_AUDIO\]|\[NO_SPEECH\]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Explicit, opt-in substitution. Clipboard text is never treated as instructions.
    static func expandClipboard(in text: String, clipboard: String?) -> String {
        guard let clipboard, !clipboard.isEmpty else { return text }
        let pattern = #"(?i)\bclip clip\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            if let range = Range(match.range, in: result) { result.replaceSubrange(range, with: clipboard) }
        }
        return result
    }
}
