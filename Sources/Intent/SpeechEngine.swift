import Foundation
import WhisperKit

protocol SpeechEngine {
    func transcribe(audio: URL, vocabulary: String) async throws -> String
}

final class LocalSpeechEngine: SpeechEngine {
    private let pipe: WhisperKit
    static let variant = "large-v3-v20240930_626MB"
    static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Intent/Models", isDirectory: true)
    }
    static var manifest: URL { root.appendingPathComponent("installed-model.txt") }
    static var isInstalled: Bool {
        guard let path = try? String(contentsOf: manifest, encoding: .utf8) else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    private init(pipe: WhisperKit) { self.pipe = pipe }

    static func prepare(progress: @escaping (Double) -> Void = { _ in }) async throws -> LocalSpeechEngine {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let folder: URL
        if isInstalled, let path = try? String(contentsOf: manifest, encoding: .utf8) {
            folder = URL(fileURLWithPath: path)
        } else {
            folder = try await WhisperKit.download(variant: variant, downloadBase: root) { progress($0.fractionCompleted) }
        }
        let pipe = try await WhisperKit(WhisperKitConfig(modelFolder: folder.path, tokenizerFolder: root,
                                                       verbose: false, prewarm: true, load: true, download: false))
        try folder.path.write(to: manifest, atomically: true, encoding: .utf8)
        return LocalSpeechEngine(pipe: pipe)
    }

    func transcribe(audio: URL, vocabulary: String) async throws -> String {
        var options = DecodingOptions(task: .transcribe)
        options.skipSpecialTokens = true
        let terms = vocabulary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !terms.isEmpty { options.promptTokens = pipe.tokenizer?.encode(text: "Names and terms: " + String(terms.prefix(1500))) }
        let results = try await pipe.transcribe(audioPath: audio.path, decodeOptions: options)
        return Transcript.normalize(results.map(\.text).joined(separator: " "))
    }
}
