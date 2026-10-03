# Intent

A native macOS voice playground for exploring what happens after speech recognition. Free local Whisper transcription, with an interchangeable engine boundary. No account, API key, or subscription.

## Run

Open `dist/Intent.app` after building. On first use:

1. In Setup, allow Microphone and Accessibility. macOS may require reopening the app after granting Accessibility.
2. Click **Download & prepare** if the local model has not already been installed. Initial setup needs internet and downloads the multilingual Whisper model and tokenizer. Subsequent launches use the installed model locally.
3. Put the cursor in an editable field, hold **Option + Space**, speak, and release. Escape cancels. Control + Space is available in Setup if the default conflicts with another app.

Shortcut registration uses macOS global hotkeys and does not require Accessibility. The window footer reports registration failures rather than assuming the shortcut is available. Accessibility is still required for insertion into other apps. The original ad-hoc development builds invalidated grants; the signing setup below is being introduced to prevent that.

The app stays in the menu bar and shows a tiny 36 × 6 point dark bar above the Dock even when idle. Hover to reveal the microphone, then click to start hands-free dictation. Click stop to finish or × to cancel. The pill does not take keyboard focus away from your editor. You can hide the idle pill in Setup; recording feedback still appears while active.

Drag the pill left or right to reposition it. Its height stays fixed, it stays within the screen edges, and its horizontal position is remembered across launches and recording-state changes. A drag is distinct from a click to record.

Choose **Re-centre pill** from Intent's menu bar popup to move it back to the centre and reset the saved horizontal position.

Open the main window from the menu bar to copy or edit the latest result, retry a failed take, export audio, or clear it. Recording is limited to three minutes per take. The microphone follows the Mac's system input setting.

## Clipboard experiment

In Experiments, enable **Clipboard reference**. Copy text, then include “clip clip” in your dictation. The text clipboard is captured at the beginning of the take and substituted literally at the cue. All clipboard takes open a preview for manual copying. This experiment does not send messages or execute commands.

You can also type a corrected transcript in Experiments and run substitution without recording. Keep those results separate from live voice tests.

## Build and checks

Requires Apple Silicon, macOS 14+, and Xcode's Swift tools. This prototype has been built on macOS 26.5.1.

```sh
zsh scripts/build.sh
swift test
```

The build script packages the app in `dist/Intent.app` and uses a reusable local signing identity. It refuses to fall back to ad-hoc signing, since that invalidates permissions. Keep the bundle identifier and signing key consistent. This is a local development build, not a notarized distribution.

### Signing setup (trust approval pending)

`scripts/setup_signing.py` creates the **Intent Local Development** certificate and its private key in a dedicated keychain under `~/Library/Application Support/IntentSigning/`, outside this repository and iCloud Documents. It restores the original keychain search list and permits codesign to use the key. It does not add certificate trust.

The identity has been created. macOS marks it untrusted for signing; approval for user-level trust constrained to the code-signing policy is pending. `scripts/sign_app.py` therefore fails clearly until that approval and trust step are complete. No system trust roots, website trust, or privacy database entries have been changed.

Once trusted, sign two different builds and verify that each satisfies the other's designated requirement. Then grant Microphone and Accessibility once for the new signed identity and check that the next rebuild keeps them. Permission persistence has not yet been verified.

To test the same speech engine on an existing audio file without microphone access:

```sh
.build/release/Intent --transcribe /absolute/path/to/audio.wav
```

## Implementation and limits

- `SpeechEngine.swift`: replaceable speech interface, local model download/cache and transcription. SDK pinned in Package.resolved.
- `Model.swift`: recording, state, cancellation, recovery and experiment orchestration.
- `Insertion.swift`: configurable global shortcut, focused-element checks, Accessibility insertion with paste fallback. A focus mismatch opens recovery instead of pasting elsewhere. Password fields are excluded.
- `Interface.swift`: setup, dictation, experiments and nonactivating recording indicator.

Whisper supplies transcription and punctuation. This build does **not** yet reproduce Wispr's advanced cleanup, spoken self-correction, list formatting, automatic learning, or app-specific styles. Vocabulary entries are recognition hints, not guaranteed corrections. Hinglish quality and daily-use latency remain to be evaluated with Vedant.

Some editors do not support Accessibility text writes, so the fallback synthesizes a normal paste. Paste dispatch is not proof the editor accepted it; review the result. Clipboard data is restored shortly afterward unless another application changed it in the meantime. Cross-app reliability must be checked with Accessibility enabled in the actual target fields.

## Data

Model files and the most recent unfinished audio take live in `~/Library/Application Support/Intent/`. Initial setup contacts Hugging Face for public files. Audio and text inference stay on this Mac. Preferences and vocabulary use macOS UserDefaults. No analytics or continuous recording.

The current take survives an app restart for recovery. It is removed on successful insertion/copy, Clear, or when a new take replaces it. There is no transcript history database. Quit during model download may leave partial cached files; setup can be retried.

See BUILD_BRIEF.md for the milestone and FRICTION_LOG.md for research notes.
