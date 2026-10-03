import AppKit
import AVFoundation
import SwiftUI

@MainActor
final class DictationModel: ObservableObject {
    enum Phase: String { case setup, loading, ready, recording, processing, failed }
    enum TakeMode { case dictation, editing }
    @Published var phase: Phase = .setup
    @Published var status = "Download the voice model to get started."
    @Published var progress: Double = 0
    @Published var level: Float = 0
    @Published var transcript = ""
    @Published var rawTranscript = ""
    @Published var elapsed = ""
    @Published var takeMode: TakeMode = .dictation
    @Published var editOriginal = ""
    @Published var editInstruction = ""
    @Published var editResult = ""
    @Published var editPresentation = 0
    @Published var editHasSelection = false
    @Published var editApplied = false
    @Published var isApplyingEdit = false
    @Published var isRewriting = false
    @Published var canUndoEdit = false
    @Published var editorStatus = "Local editing uses Llama 3.2 through Ollama."
    @Published var microphoneAllowed = false
    @Published var accessibilityAllowed = false
    @Published var shortcutAvailable = false
    @Published var shortcutStatus = "Checking shortcut…"
    @Published var showPill = UserDefaults.standard.object(forKey: "showPill") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showPill, forKey: "showPill") }
    }
    @Published var preview = UserDefaults.standard.object(forKey: "preview") as? Bool ?? false {
        didSet { UserDefaults.standard.set(preview, forKey: "preview") }
    }
    @Published var clipboardExperiment = false
    @Published var vocabulary = UserDefaults.standard.string(forKey: "vocabulary") ?? "" {
        didSet { UserDefaults.standard.set(vocabulary, forKey: "vocabulary") }
    }
    @Published var useControl = UserDefaults.standard.bool(forKey: "useControl") {
        didSet { UserDefaults.standard.set(useControl, forKey: "useControl"); hotkey.useControl = useControl }
    }
    let hotkey = Hotkey()
    var showWindow: (() -> Void)?
    private var engine: (any SpeechEngine)?
    private var recorder: AVAudioRecorder?
    private var meter: Timer?
    private var task: Task<Void, Never>?
    private var token = UUID()
    private var audioURL: URL?
    private var target: InsertionTarget?
    private var clipboardSnapshot: String?
    private var takePreview = false
    private var takeClipboard = false
    private var successful = false
    private let textEditor: any TextEditing = LocalTextEditor()
    private var editSelection: SelectedText?
    private var lastAppliedEdit: AppliedEdit?
    var busy: Bool { [.loading, .recording, .processing].contains(phase) || isApplyingEdit }
    var canApplyEdit: Bool { editHasSelection && !editApplied && !editResult.isEmpty && !busy }
    var hasAudio: Bool { audioURL != nil }
    var engineReady: Bool { engine != nil }
    var canRetry: Bool { audioURL != nil && engine != nil && !busy && !successful }
    var shortcut: String { useControl ? "⌃ Space" : "⌥ Space" }

    init() {
        refreshPermissions()
        hotkey.useControl = useControl
        hotkey.onStart = { [weak self] in self?.start() }
        hotkey.onStop = { [weak self] in self?.stop() }
        hotkey.onCancel = { [weak self] in self?.cancel() }
        hotkey.onStatus = { [weak self] available, message in
            self?.shortcutAvailable = available; self?.shortcutStatus = message
        }
        hotkey.install()
        // The first permission refresh may have installed the listener before
        // its status callback was connected. Re-publish the actual backend state.
        hotkey.reportStatus()
        let recovery = dataDirectory.appendingPathComponent("current-take.wav")
        if FileManager.default.fileExists(atPath: recovery.path) {
            audioURL = recovery
            status = "A previous recording is saved. Prepare the model, then retry or export it."
        }
    }

    private var dataDirectory: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Intent", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func refreshPermissions() {
        microphoneAllowed = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let granted = AXIsProcessTrusted()
        if granted && !accessibilityAllowed { hotkey.install() }
        accessibilityAllowed = granted
    }

    func requestMicrophone() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .denied {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            return
        }
        Task { microphoneAllowed = await AVCaptureDevice.requestAccess(for: .audio) }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func loadModel() {
        guard !busy else { return }
        phase = .loading; status = "Downloading / loading local model…"; progress = 0
        task = Task {
            do {
                engine = try await LocalSpeechEngine.prepare { [weak self] fraction in
                    Task { @MainActor in self?.progress = fraction }
                }
                phase = .ready; status = "Ready. Hold \(shortcut) in a text field."
            } catch { phase = .failed; status = "Model setup failed: \(error.localizedDescription). Try again." }
        }
    }

    func start(mode: TakeMode = .dictation) {
        guard !busy else { return }
        guard engine != nil else { status = "Prepare the local voice model in Setup first."; showWindow?(); return }
        refreshPermissions()
        guard microphoneAllowed else { status = "Allow microphone access in setup first."; showWindow?(); return }
        if mode == .editing {
            guard let selection = SelectedText.capture() else {
                status = accessibilityAllowed ? "Select text in an editable field in another app, then click the pill's pencil." : "Allow Accessibility in Setup to read the selected text."
                showWindow?(); return
            }
            guard selection.snapshot.text.count <= 8000 else { status = "Select a shorter passage (up to 8,000 characters)."; showWindow?(); return }
            editSelection = selection; editOriginal = selection.snapshot.text
            editInstruction = ""; editResult = ""; editHasSelection = true; editApplied = false
            lastAppliedEdit = nil; canUndoEdit = false; editPresentation += 1
        }
        takeMode = mode
        clearAudio()
        transcript = ""; rawTranscript = ""; elapsed = ""; successful = false
        target = InsertionTarget.capture()
        takePreview = preview; takeClipboard = clipboardExperiment
        clipboardSnapshot = takeClipboard ? NSPasteboard.general.string(forType: .string) : nil
        let url = dataDirectory.appendingPathComponent("current-take.wav")
        do {
            let recording = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false
            ])
            recording.isMeteringEnabled = true
            guard recording.record() else { throw NSError(domain: "Intent", code: 1, userInfo: [NSLocalizedDescriptionKey: "The microphone could not start recording."]) }
            recorder = recording; audioURL = url; phase = .recording
            status = mode == .editing ? "Say how to change the selection. Click stop when finished." : "Listening… Release to finish."
            meter = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let recorder = self.recorder else { return }
                    recorder.updateMeters(); self.level = max(0, min(1, (recorder.averagePower(forChannel: 0) + 55) / 55))
                    if recorder.currentTime >= 180 { self.stop() }
                }
            }
        } catch { phase = .failed; status = error.localizedDescription; showWindow?() }
    }

    func stop() {
        guard phase == .recording else { return }
        let duration = recorder?.currentTime ?? 0
        recorder?.stop(); recorder = nil; meter?.invalidate(); meter = nil; level = 0
        guard duration > 0.25 else { clearAudio(); phase = .ready; status = "Take was too short. Hold the shortcut and speak."; return }
        transcribe()
    }

    func retry() { guard canRetry else { return }; target = nil; takePreview = true; transcribe() }

    private func transcribe() {
        guard let engine, let audioURL else { return }
        phase = .processing; status = "Transcribing on your Mac…"
        let run = UUID(); token = run
        let started = Date()
        task = Task {
            defer {
                if token != run { phase = .ready; status = "Cancelled. Nothing inserted. Recording available for retry." }
            }
            do {
                let result = try await engine.transcribe(audio: audioURL, vocabulary: vocabulary)
                guard token == run, !Task.isCancelled else { return }
                rawTranscript = result
                if takeMode == .editing {
                    editInstruction = result
                    guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        phase = .ready; status = "No instruction detected. Retry the recording or type your instruction below."; showWindow?(); return
                    }
                    isRewriting = true; status = "Rewriting the selection locally…"
                    defer { isRewriting = false }
                    let revised = try await textEditor.rewrite(source: editOriginal, instruction: result)
                    guard token == run, !Task.isCancelled else { return }
                    editResult = revised; elapsed = String(format: "%.1fs", Date().timeIntervalSince(started))
                    phase = .ready; status = "Review the proposed edit. The original text is unchanged."
                    showWindow?(); return
                }
                transcript = takeClipboard ? Transcript.expandClipboard(in: rawTranscript, clipboard: clipboardSnapshot) : rawTranscript
                elapsed = String(format: "%.1fs", Date().timeIntervalSince(started))
                phase = .ready
                guard !transcript.isEmpty else { status = "No speech detected. Retry or clear this recording."; showWindow?(); return }
                if takePreview || takeClipboard { status = "Review your text, then copy it."; showWindow?() }
                else if let target, target.insert(transcript) { successful = true; status = "Text inserted. Review it in your app."; clearAudio() }
                else { status = "Text is ready. Focus changed or this field could not be reached; copy it below."; showWindow?() }
            } catch {
                guard token == run, !Task.isCancelled else { return }
                phase = .failed; status = "\(error.localizedDescription) Your recording is saved for retry."; showWindow?()
            }
        }
    }

    func cancel() {
        guard phase == .recording || phase == .processing else { return }
        token = UUID(); task?.cancel(); recorder?.stop(); recorder = nil
        meter?.invalidate(); meter = nil; level = 0
        // Keep audio on cancellation until explicitly cleared or a new take starts.
        if phase == .recording { phase = .ready }
        status = phase == .processing ? "Cancelling transcription… Nothing will be inserted." : "Cancelled. Nothing inserted. Recording available for retry."
    }

    func clearAudio() {
        if let audioURL { try? FileManager.default.removeItem(at: audioURL) }
        audioURL = nil
    }

    func clearTake() {
        guard !busy else { return }
        clearAudio(); transcript = ""; rawTranscript = ""; clipboardSnapshot = nil
        status = engine == nil ? "Download the voice model to get started." : "Ready. Hold \(shortcut) in a text field."
    }

    func copy() {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(transcript, forType: .string)
        successful = true; clearAudio(); status = "Copied. Paste it into your app."
    }

    func previewExperiment() {
        guard !busy else { return }
        rawTranscript = transcript
        clipboardSnapshot = NSPasteboard.general.string(forType: .string)
        if clipboardExperiment { transcript = Transcript.expandClipboard(in: transcript, clipboard: clipboardSnapshot) }
        status = "Corrected-transcript experiment. Review and copy the result."
    }

    func saveRecording() {
        guard let audioURL, !busy else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = "dictation.wav"
        if panel.runModal() == .OK, let destination = panel.url {
            do { let data = try Data(contentsOf: audioURL); try data.write(to: destination, options: .atomic) }
            catch { status = "Could not export recording: \(error.localizedDescription)" }
        }
    }

    func startEditing() { start(mode: .editing) }

    func checkEditor() {
        editorStatus = "Checking local editor…"
        Task {
            do { try await LocalTextEditor().checkModel(); editorStatus = "Local editor ready · Llama 3.2" }
            catch { editorStatus = "Start Ollama and install llama3.2 if needed. \(error.localizedDescription)" }
        }
    }

    func regenerateEdit() {
        guard !busy else { return }
        let source = editOriginal, instruction = editInstruction
        takeMode = .editing; isRewriting = true; phase = .processing; editResult = ""
        status = "Rewriting the selection locally…"
        let run = UUID(); token = run
        task = Task {
            defer { isRewriting = false; if token != run { phase = .ready; status = "Edit cancelled. Original unchanged." } }
            do {
                let result = try await textEditor.rewrite(source: source, instruction: instruction)
                guard token == run, !Task.isCancelled else { return }
                editResult = result; phase = .ready; status = "Review the proposed edit. Original unchanged."
            } catch {
                guard token == run, !Task.isCancelled else { return }
                phase = .ready; status = error.localizedDescription
            }
        }
    }

    func applyEdit() {
        guard canApplyEdit, let selection = editSelection else { return }
        let replacement = editResult
        isApplyingEdit = true
        Task {
            defer { isApplyingEdit = false }
            do {
                lastAppliedEdit = try await selection.apply(replacement)
                canUndoEdit = lastAppliedEdit?.expectedDocument != nil
                editApplied = true; clearAudio()
                status = "Edit applied. Original text preserved below."
            } catch { status = error.localizedDescription; showWindow?() }
        }
    }

    func undoEdit() {
        guard !busy, let edit = lastAppliedEdit, canUndoEdit else { return }
        isApplyingEdit = true
        Task {
            defer { isApplyingEdit = false }
            do {
                try await edit.selection.undo(edit)
                lastAppliedEdit = nil; canUndoEdit = false; editApplied = false
                status = "Original text restored."
            } catch { status = error.localizedDescription; showWindow?() }
        }
    }

    func cancelEditPreview() {
        guard !busy else { return }
        editSelection = nil; editHasSelection = false; editResult = ""; editInstruction = ""
        clearAudio(); status = editApplied ? "Preview dismissed. The applied edit remains; original preserved." : "Edit dismissed. Nothing replaced."
    }

    func copyEdit(_ original: Bool = false) {
        guard !busy else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(original ? editOriginal : editResult, forType: .string)
        status = original ? "Original text copied." : "Edited text copied."
    }
}
