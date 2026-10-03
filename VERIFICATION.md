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

## Persistent signing setup (pending approval)

- Created a dedicated local RSA signing key/certificate and encrypted keychain outside the repository. Restored the original user keychain search list; no login-keychain identity or system trust changes applied.
- Updated the build script to use this reusable identity, with explicit failure rather than an ad-hoc fallback.
- macOS currently reports the identity as CSSMERR_TP_NOT_TRUSTED. Signing by name and exact certificate fingerprint fails with “no identity found.”
- Automatic approval review rejected adding user-level trust for the code-signing policy. The trust command did not execute. User approval is required to finish this route.
- Certificate identity compatibility across changed builds and retention of actual privacy grants remain unverified.
- The unsuccessful signing attempt left the packaged app failing signature verification. Automatic review also rejected restoring ad-hoc signing. The package needs the approved stable-signing step before relaunch; no additional trust change or fallback was applied.
