# Verification — 3 October 2026

## Passed

- Debug and release builds on Apple Silicon / macOS 26.5.1, with Swift 6.3.3.
- Four tests: literal clipboard substitution including Unicode/newlines and replacement metacharacters; partial-word exclusion; missing clipboard; preservation of mixed-language text.
- Download and initialization of the multilingual Whisper model, without credentials.
- Synthetic speech transcription through the same replaceable engine used by the app. Initial measured inference: 1.40 seconds; subsequent release inference with all network access blocked: 0.82 seconds. These exclude model loading and do not establish everyday latency.
- Offline model/tokenizer loading and transcription under a process sandbox denying network access.
- Native app launch and visible ready state. Setup and dictation interface inspected through Accessibility and a screenshot.

Sample speech: “Hello Vedant. This is a local transcription test. Please move the design review to four tomorrow.” Output preserved the sentence but recognised “four” as “for.”

## Needs user permissions and real-world evaluation

- Live microphone recording, global shortcut, and cross-app insertion in Codex/ChatGPT, WhatsApp Web and Google Docs. Microphone and Accessibility have not been granted on the user's behalf.
- The brief's consecutive-take checks, focus-change and failure recovery scenarios in actual editors, and daily use over three days.
- English/Hinglish accuracy, vocabulary effectiveness, quiet speech, and recognition on natural spoken clipboard cues.
- User value of the clipboard experiment compared with normal copy/paste.

Advanced cleanup, spoken correction and formatting parity with Wispr are not implemented. This is the working transcription and experimentation foundation.

## Floating pill update

- Release build passes with an always-visible idle pill, nonactivating click-to-record panel, recording stop/cancel controls, processing feedback, and an idle visibility setting.
- Rebuilt app relaunched and reached Ready. The UI automation tool rejected further interaction with the rebuilt bundle as changed, so idle appearance and click/focus behavior have not been visually verified.
- The rebuilt app reports Accessibility as unavailable; the previous development-build grant needs re-enabling before global shortcut and insertion checks.

## Shortcut fix

- Replaced permission-dependent shortcut listening as the primary backend with macOS global hotkey registration; retained Accessibility event-tap fallback and Escape/modifier monitoring.
- Configured Control + Space registered successfully in the rebuilt app while Accessibility reported false. Confirmed through the app-bundle executable's `--check-hotkey` diagnostic.
- Settings changes unregister the previous shortcut before registering the new one. The UI now reports actual shortcut registration status independently of insertion permissions.
- Physical-key recording and cross-app insertion still need live verification after restoring Accessibility for this rebuilt app.

## Stable signing and voice editing update

- User explicitly approved code-signing-only certificate trust. The public certificate is visible through the login keychain; its private key remains in the dedicated encrypted keychain. No system roots or website trust changed.
- Signing temporarily includes the dedicated keychain in the search list and restores the list afterward. The build stages outside iCloud Documents and installs in `~/Applications/Intent.app`, linked from `dist/Intent.app`, avoiding file-provider metadata races.
- Final release build and deep strict signature verification passed. Different debug/release executables signed with this key satisfy each other's designated requirement (bundle identifier plus certificate leaf hash).
- Nine tests passed: the existing four transcript tests plus selection/document drift rejection, UTF-16 replacement boundaries, unavailable undo snapshots, Unicode/format preservation, and incomplete/empty/malformed rewrite rejection.
- Real local rewrite through the production client and installed Llama 3.2 completed in 1.94 seconds on synthetic text. It shortened a scheduling paragraph and retained the name, date, time, two agenda items and budget. This is a single sample, not a quality benchmark.
- Updated app reached Ready with the registered Control + Space shortcut. Voice edit controls and disabled Apply in text-only mode were inspected through Accessibility. Further UI automation timed out, so the final typed UI submission and live recording/apply/undo were not verified.
- Microphone and Accessibility were unavailable for the new identity during inspection. Grant them once, then verify retention through a rebuild. Existing user reports confirmed the earlier shortcut worked; they do not establish grants for the new certificate.
- Remaining live checks: selected text capture without focus stealing; Apply/Undo in a supported editor; refusing selection/document drift; unsupported-editor copying; microphone instruction transcription; actual permission persistence.
