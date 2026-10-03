# Intent

A native macOS voice playground for exploring what happens after speech recognition. Free local Whisper transcription, with an interchangeable engine boundary. No account, API key, or subscription.

## Run

Open `~/Applications/Intent.app` after building (`dist/Intent.app` links there). On first use:

1. In Setup, allow Microphone and Accessibility. macOS may require reopening the app after granting Accessibility.
2. Click **Download & prepare** if the local model has not already been installed. Initial setup needs internet and downloads the multilingual Whisper model and tokenizer. Subsequent launches use the installed model locally.
3. Put the cursor in an editable field, hold **Option + Space**, speak, and release. Escape cancels. Control + Space is available in Setup if the default conflicts with another app.

Shortcut registration uses macOS global hotkeys and does not require Accessibility. The window footer reports registration failures rather than assuming the shortcut is available. Accessibility is still required for insertion into other apps. Grant permissions once for the new stable signing identity; actual retention across the next rebuild remains to be checked.

The app stays in the menu bar and shows a tiny 36 × 6 point dark bar above the Dock even when idle. Hover to reveal microphone and pencil buttons. Click the microphone for dictation or the pencil to edit selected text. Click stop to finish or × to cancel. The pill does not take keyboard focus away from your editor. You can hide the idle pill in Setup; recording feedback still appears while active.

Drag the pill left or right to reposition it. Its height stays fixed, it stays within the screen edges, and its horizontal position is remembered across launches and recording-state changes. A drag is distinct from a click to record.

Choose **Re-centre pill** from Intent's menu bar popup to move it back to the centre and reset the saved horizontal position.

Open the main window from the menu bar to copy or edit the latest result, retry a failed take, export audio, or clear it. Recording is limited to three minutes per take. The microphone follows the Mac's system input setting.

## Clipboard experiment

In Experiments, enable **Clipboard reference**. Copy text, then include “clip clip” in your dictation. The text clipboard is captured at the beginning of the take and substituted literally at the cue. All clipboard takes open a preview for manual copying. This experiment does not send messages or execute commands.

You can also type a corrected transcript in Experiments and run substitution without recording. Keep those results separate from live voice tests.

## Voice editing

Select text in an editable field in another app, hover over the pill and click its pencil (or choose **Edit selected text** in the menu bar). Say an instruction such as “Make this shorter, keeping the dates,” then click stop. Review the original, instruction and proposed edit in **Voice edit**. You can correct the instruction and Rewrite, adjust the result, Apply, dismiss, or copy either version.

Rewrites use the existing local Ollama service at `127.0.0.1:11434` and `llama3.2:latest`. Keep Ollama running; install the model with `ollama pull llama3.2` if needed. Setup includes **Check editor**. No API key is required. Requests reject redirects and do not use a configured web proxy.

Apply restores the original app and checks the focused field, selected text, selection range and full document when available. It uses direct Accessibility selection replacement; unsupported fields offer copying. Undo is available only when a full document snapshot is available and the document still matches the applied edit. Original text remains in the preview for manual recovery. Previews are kept in memory, not persisted across quitting. Model output can still change meaning; review before applying.

To explore the application layer without recording, paste sample text into **Voice edit**, type an instruction and click **Rewrite**. This mode offers copying rather than applying to another app. Selections are limited to 8,000 characters; instructions to 1,000.

## Build and checks

Requires Apple Silicon, macOS 14+, and Xcode's Swift tools. This prototype has been built on macOS 26.5.1.

```sh
zsh scripts/build.sh
swift test
```

The build script signs in a temporary directory and installs in `~/Applications/Intent.app`, outside iCloud Documents to avoid Finder metadata disrupting signing. `dist/Intent.app` is a link to that installation. It uses a reusable local signing identity and refuses ad-hoc fallback. Keep the bundle identifier and signing key consistent. This is a local development build, not a notarized distribution.

### Signing setup

`scripts/setup_signing.py` creates the **Intent Local Development** certificate and its private key in a dedicated keychain under `~/Library/Application Support/IntentSigning/`, outside this repository and iCloud Documents. It restores the original keychain search list and permits codesign to use the key. It does not add certificate trust.

The identity and code-signing-only trust have been enabled on this Mac with explicit user approval. Its public certificate is also in the login keychain so validation can find it normally; the private key stays in the dedicated keychain. The signing script temporarily adds that keychain to the search list and restores the original list afterward. No website trust, system trust roots, or privacy database entries are changed.

Different debug and release executables were signed and verified against each other's designated requirement. Grant Microphone and Accessibility once for this identity, then check that the next rebuild keeps them. Actual permission persistence has not yet been verified. On a new Mac, run `scripts/setup_signing.py` and explicitly approve adding this public certificate's code-signing-only trust before building.

To test the same speech engine on an existing audio file without microphone access:

```sh
.build/release/Intent --transcribe /absolute/path/to/audio.wav
```

To test the same local editor with UTF-8 text files:

```sh
.build/release/Intent --rewrite /absolute/path/to/source.txt /absolute/path/to/instruction.txt
```

## Implementation and limits

- `SpeechEngine.swift`: replaceable speech interface, local model download/cache and transcription. SDK pinned in Package.resolved.
- `Model.swift`: recording, state, cancellation, recovery and experiment orchestration.
- `Insertion.swift`: configurable global shortcut, focused-element checks, Accessibility insertion with paste fallback. A focus mismatch opens recovery instead of pasting elsewhere. Password fields are excluded.
- `Selection.swift`: selection snapshots, drift protection, direct replacement and guarded undo.
- `TextEditor.swift`: local Ollama editing client and structured result validation.
- `Interface.swift`: setup, dictation, voice editing, experiments and nonactivating recording indicator.

Whisper supplies transcription and punctuation. This build does **not** yet reproduce Wispr's advanced cleanup, spoken self-correction, list formatting, automatic learning, or app-specific styles. Vocabulary entries are recognition hints, not guaranteed corrections. Hinglish quality and daily-use latency remain to be evaluated with Vedant.

Some editors do not support Accessibility text writes, so the fallback synthesizes a normal paste. Paste dispatch is not proof the editor accepted it; review the result. Clipboard data is restored shortly afterward unless another application changed it in the meantime. Cross-app reliability must be checked with Accessibility enabled in the actual target fields.

## Data

Model files and the most recent unfinished audio take live in `~/Library/Application Support/Intent/`. Initial setup contacts Hugging Face for public files. Audio and text inference stay on this Mac. Preferences and vocabulary use macOS UserDefaults. No analytics or continuous recording.

The current take survives an app restart for recovery. It is removed on successful insertion/copy, Clear, or when a new take replaces it. There is no transcript history database. Quit during model download may leave partial cached files; setup can be retried.

See BUILD_BRIEF.md for the milestone and FRICTION_LOG.md for research notes.

## Continuing development

Start with [STATUS.md](STATUS.md) for the current milestone and handoff. [AGENTS.md](AGENTS.md) contains concise instructions for coding agents. [WORKFLOW.md](WORKFLOW.md) includes reusable prompts, chat boundaries, and the next manual verification checklist. [VERIFICATION.md](VERIFICATION.md) records evidence and unverified behavior; it is not a claim that all acceptance criteria passed.
