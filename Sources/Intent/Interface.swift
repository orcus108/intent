import SwiftUI
import AppKit

struct MainView: View {
    @ObservedObject var model: DictationModel
    @State private var tab = 0
    private let accent = Color(red: 0.22, green: 0.42, blue: 0.34)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("intent").font(.system(size: 32, weight: .semibold, design: .rounded))
                    Text("Speak it. Keep moving.").foregroundStyle(.secondary)
                }
                Spacer()
                Label("On your Mac", systemImage: "desktopcomputer")
                    .font(.caption).padding(9).background(accent.opacity(0.09), in: Capsule())
            }
            HStack(spacing: 12) {
                Image(systemName: model.phase == .recording ? "waveform" : "mic.fill")
                    .font(.title2).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.phase == .recording ? "Listening" : model.phase == .processing ? "Working on your words" : model.phase == .loading ? "Preparing your voice engine" : "Your voice, wherever you write")
                        .font(.headline)
                    Text(model.status).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Spacer(minLength: 0)
                Text(model.shortcut).font(.system(.callout, design: .monospaced))
                    .padding(10).background(.background, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(18).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            if model.phase == .loading { ProgressView(value: model.progress).tint(accent) }
            Picker("View", selection: $tab) {
                Text("Dictation").tag(0); Text("Voice edit").tag(3); Text("Setup").tag(1); Text("Experiments").tag(2)
            }.pickerStyle(.segmented)
            Group {
                if tab == 0 { dictation }
                else if tab == 1 { setup }
                else if tab == 3 { editing }
                else { experiments }
            }
            Spacer(minLength: 0)
            HStack {
                Circle().fill(model.shortcutAvailable ? accent : .orange).frame(width: 6, height: 6)
                Text(model.shortcutStatus)
                Spacer()
                if !model.elapsed.isEmpty { Text("Last transcription: \(model.elapsed)") }
            }.font(.caption).foregroundStyle(.secondary)
        }
        .padding(28).frame(minWidth: 620, minHeight: 620)
        .tint(accent)
        .onAppear { if model.phase == .setup { tab = 1 } }
        .onChange(of: model.editPresentation) { _, _ in tab = 3 }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in model.refreshPermissions() }
    }

    private var dictation: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Latest take").font(.headline)
                Spacer()
                if model.phase == .recording { Button("Finish") { model.stop() } }
                else { Button("Record here") { model.start() }.disabled(model.busy || !model.engineReady) }
            }
            TextEditor(text: $model.transcript)
                .font(.system(size: 15)).scrollContentBackground(.hidden)
                .padding(10).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
                .frame(minHeight: 175).disabled(model.busy)
            HStack {
                Button("Copy text", systemImage: "doc.on.doc") { model.copy() }
                    .buttonStyle(.borderedProminent).disabled(model.transcript.isEmpty || model.busy)
                if model.canRetry { Button("Retry recording") { model.retry() } }
                if model.hasAudio { Button("Save audio…") { model.saveRecording() }.disabled(model.busy) }
                Spacer()
                if model.phase == .recording || model.phase == .processing { Button("Cancel") { model.cancel() } }
                else { Button("Clear") { model.clearTake() } }
            }
            Toggle("Preview every take before copying", isOn: $model.preview).disabled(model.busy)
            Text("To change existing text, select it in your app, then click the pencil on the floating pill.")
                .font(.caption).foregroundStyle(.secondary)
            if !model.rawTranscript.isEmpty && model.rawTranscript != model.transcript {
                DisclosureGroup("Original transcript") { Text(model.rawTranscript).font(.callout).textSelection(.enabled) }
            }
        }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 18) {
            permission("Microphone", detail: "Record only when you start a take.", granted: model.microphoneAllowed, action: model.requestMicrophone)
            permission("Accessibility", detail: "Insert text into your active app.", granted: model.accessibilityAllowed, action: model.requestAccessibility)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local voice model").font(.headline)
                    Text("Whisper multilingual · about 626 MB of weights, plus supporting files").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.phase == .setup || model.phase == .failed ? "Download & prepare" : "Reload model") { model.loadModel() }.disabled(model.busy)
            }
            Text("Initial setup downloads public model files from Hugging Face. Audio and transcripts are processed locally. The current recording remains on this Mac until copied, inserted, cleared, or replaced by a new take.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local text editor").font(.headline)
                    Text(model.editorStatus).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Check editor") { model.checkEditor() }.disabled(model.busy)
            }
            Text("Keep Ollama running with llama3.2 installed. Rewrites run on this Mac; no API key needed.").font(.caption).foregroundStyle(.secondary)
            Divider()
            Toggle("Show floating pill", isOn: $model.showPill)
            Picker("Shortcut", selection: $model.useControl) {
                Text("Option + Space").tag(false); Text("Control + Space").tag(true)
            }.disabled(model.busy)
            HStack { Text("Microphone"); Spacer(); Text("System default").foregroundStyle(.secondary) }
            Text("Names & vocabulary").font(.headline)
            TextField("Vedant, Sarvam, Kivi, IIT Madras…", text: $model.vocabulary, axis: .vertical).textFieldStyle(.roundedBorder)
            Text("Hints for recognition, not guaranteed spelling corrections. Nothing leaves your Mac.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func permission(_ title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle").foregroundStyle(granted ? accent : .secondary)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(.secondary) }
            Spacer()
            if !granted { Button("Allow", action: action) }
        }
    }

    private var editing: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Select a passage in your app → pencil on the pill → say what to change → stop.")
                    .font(.callout).foregroundStyle(.secondary)
                Text("Original").font(.headline)
                if model.editHasSelection || model.editApplied {
                    Text(model.editOriginal).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                } else {
                    TextEditor(text: $model.editOriginal).font(.system(size: 15)).frame(minHeight: 80)
                        .padding(8).overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary)).disabled(model.busy)
                    Text("Or paste sample text here and type an instruction to explore editing without recording. Copy the result when ready.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Instruction").font(.headline)
                TextField("Make this shorter, keeping the dates…", text: $model.editInstruction, axis: .vertical)
                    .textFieldStyle(.roundedBorder).disabled(model.busy)
                Text("Proposed edit").font(.headline)
                TextEditor(text: $model.editResult).font(.system(size: 15))
                    .frame(minHeight: 130).padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))
                    .disabled(model.busy || model.editApplied)
                HStack {
                    Button("Apply to selection") { model.applyEdit() }
                        .buttonStyle(.borderedProminent).disabled(!model.canApplyEdit)
                    Button("Rewrite") { model.regenerateEdit() }
                        .disabled(model.busy || model.editOriginal.isEmpty || model.editInstruction.isEmpty || model.editApplied)
                    if model.canUndoEdit { Button("Undo edit") { model.undoEdit() }.disabled(model.busy) }
                    Spacer()
                    if model.phase == .recording { Button("Finish") { model.stop() } }
                    else if model.phase == .processing { Button("Cancel") { model.cancel() } }
                    else { Button("Dismiss") { model.cancelEditPreview() }.disabled(model.busy) }
                }
                HStack {
                    Button("Copy edit") { model.copyEdit() }.disabled(model.editResult.isEmpty || model.busy)
                    Button("Copy original") { model.copyEdit(true) }.disabled(model.editOriginal.isEmpty || model.busy)
                    if model.canRetry { Button("Retry recording") { model.retry() } }
                }
                Text("Apply checks that the original field and selection still match. Undo is available when the app exposes its text and it has not changed since applying.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var experiments: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bring context into your words.").font(.title2.weight(.semibold))
            Toggle("Clipboard reference: “clip clip”", isOn: $model.clipboardExperiment).disabled(model.busy)
            Text("Copy a passage, then say “Explain this simply: clip clip.” The copied text is inserted at that phrase. Clipboard takes always open a preview; nothing is sent or executed.")
                .foregroundStyle(.secondary)
            Divider()
            Text("Test with a corrected transcript").font(.headline)
            Text("Use this to explore what accurate STT could unlock. These are text experiments, separate from live voice results.").font(.callout).foregroundStyle(.secondary)
            TextEditor(text: $model.transcript).font(.system(size: 15)).frame(minHeight: 120)
                .padding(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary)).disabled(model.busy)
            HStack {
                Button("Run clipboard experiment") { model.previewExperiment() }.disabled(model.busy || !model.clipboardExperiment || model.transcript.isEmpty)
                Button("Copy result") { model.copy() }.disabled(model.busy || model.transcript.isEmpty)
            }
        }
    }
}

struct RecordingView: View {
    @ObservedObject var model: DictationModel
    var onDrag: () -> Void = {}
    var onDragEnd: () -> Void = {}
    @State private var hovering = false
    private var recording: Bool { model.phase == .recording }
    private var processing: Bool { model.phase == .processing }
    private var loading: Bool { model.phase == .loading }

    var body: some View {
        Group {
            if !recording && !processing {
                if hovering && model.engineReady && !loading {
                    HStack(spacing: 0) {
                        Button { model.start() } label: {
                            Image(systemName: "mic.fill").frame(width: 26, height: 22)
                        }.accessibilityLabel("Start dictation").help("Dictate · \(model.shortcut)")
                        Button { model.startEditing() } label: {
                            Image(systemName: "pencil").frame(width: 26, height: 22)
                        }.accessibilityLabel("Edit selected text").help("Select text in your app, then click to speak an edit")
                    }.font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
                        .buttonStyle(.plain).background(.black.opacity(0.85), in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                Button {
                    if model.engineReady && !loading { model.start() } else { model.showWindow?() }
                } label: {
                    ZStack {
                        Capsule().fill(.black.opacity(hovering ? 0.85 : 0.60))
                        if hovering {
                            Image(systemName: loading ? "ellipsis" : "mic.fill")
                                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .frame(width: hovering ? 52 : 36, height: hovering ? 22 : 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel("Start dictation")
                .help(loading ? "Preparing local voice model" : "Click to dictate · \(model.shortcut)")
                }
            } else {
                activePill
            }
        }.onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: hovering)
            .highPriorityGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { _ in onDrag() }
                    .onEnded { _ in onDragEnd() }
            )
    }

    private var activePill: some View {
        HStack(spacing: 6) {
            if processing {
                ProgressView().controlSize(.small).tint(.white)
                Text(model.isRewriting ? "Rewriting" : "Transcribing").font(.system(size: 11, weight: .medium))
                cancelButton
            } else if recording {
                HStack(spacing: 3) {
                    ForEach(0..<7) { i in
                        Capsule().fill(.white.opacity(0.9)).frame(width: 2, height: CGFloat(4 + model.level * Float(8 + (i % 3) * 3)))
                    }
                }.frame(width: 32, height: 20)
                Text(model.takeMode == .editing ? "Edit" : "Listening").font(.system(size: 11, weight: .medium))
                Button { model.stop() } label: {
                    Image(systemName: "stop.fill").font(.system(size: 9)).frame(width: 22, height: 22)
                        .background(.white.opacity(0.15), in: Circle())
                }.buttonStyle(.plain).accessibilityLabel("Finish dictation").help("Finish and transcribe")
                cancelButton
            }
        }.foregroundStyle(.white).padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.12, green: 0.18, blue: 0.15).opacity(hovering ? 1 : 0.95), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(hovering ? 0.25 : 0.12), lineWidth: 1))
    }

    private var cancelButton: some View {
        Button { model.cancel() } label: {
            Image(systemName: "xmark").font(.system(size: 9, weight: .medium)).frame(width: 20, height: 22)
        }.buttonStyle(.plain).accessibilityLabel("Cancel dictation").help("Cancel · Escape")
    }
}
