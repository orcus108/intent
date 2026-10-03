# Intent — current handoff

Updated: 3 October 2026 (Asia/Kolkata). Implementation checkpoint: `92a273c` on `main`, pushed to `https://github.com/orcus108/intent.git`. Later documentation commits may follow this checkpoint. Confirm current Git state before starting work.

## Current objective

Verify the existing voice-editing flow in TextEdit and permission retention across rebuilding. Fix failures found in that flow before expanding feature scope. This is the next recommended milestone, not a claim that live verification has been completed.

## What exists

- Native Swift/AppKit/SwiftUI menu bar app, Apple Silicon, macOS 14+. WhisperKit pinned to 1.1.0; free local multilingual transcription behind `SpeechEngine`.
- Hold-to-talk with configurable Option/Control + Space, plus click-to-record. Vedant selected Control + Space and confirmed the earlier shortcut fix worked.
- Tiny idle pill, hover microphone/pencil controls, horizontal dragging with remembered position, re-centre menu action, and a visibility setting.
- Dictation insertion with focus checks and recovery/copying. Preview, current-take audio recovery/export, vocabulary hints, and literal clipboard-cue experiment.
- Selection editing: capture selected text → record instruction → local rewrite → preview → Apply. Original retained, editable instruction/result, guarded Undo, copying fallback. Typed sample text can exercise rewriting without STT.
- Ollama client uses `127.0.0.1:11434`, `llama3.2:latest`, structured results, and rejects redirects. Ollama and this model were already installed on this Mac; runtime availability must be checked.

## Run and identity

- Workspace: `/Users/vedantmisra/Documents/ChatGPT/kivi`.
- Build/install: `zsh scripts/build.sh`; launch `open "$HOME/Applications/Intent.app"`.
- Installed app: `~/Applications/Intent.app`; `dist/Intent.app` is a link there. Packaging stages outside iCloud Documents to avoid Finder metadata disrupting signing.
- Bundle ID: `dev.vedant.intent`. Certificate: **Intent Local Development**. Private key is in the dedicated encrypted keychain under `~/Library/Application Support/IntentSigning/`, outside Git. Code-signing-only public certificate trust was explicitly authorized by Vedant and enabled. No need to repeat that approval for ordinary signing with this identity.
- Models/audio: `~/Library/Application Support/Intent/`. Settings use UserDefaults. Do not reset permissions or preferences to get a clean test without an explicit reason and authorization.

## Evidence and remaining uncertainty

- Last implementation check: nine unit tests passed; release build and installed app's deep strict signature validation passed.
- Different debug/release executables satisfied each other's designated signing requirement. This verifies identity compatibility, not retention of actual privacy grants.
- Real local synthetic rewrite completed in 1.94 seconds and retained the sample's name, date, time, agenda, and budget. One sample does not establish general rewrite quality.
- App reached Ready; Control + Space registration and voice-edit controls were observed. Further UI automation timed out.
- Microphone and Accessibility were unavailable for the new signed identity at the last inspection. Vedant was asked to grant them once. Do not assume their current status either way.
- Live capture, focus preservation, Apply/Undo, changed-selection refusal, unsupported editors, final typed UI submission, and permission retention remain unverified. Use the checklist in `WORKFLOW.md`.
- Edit previews/selection snapshots are in memory. Audio can survive quitting, but the current recovery code does not restore the editing session/mode; inspect the recovery behavior before retrying an interrupted edit instruction.
- Whisper-only advanced cleanup, spoken self-correction, automatic personalization, and Wispr parity are not established. No general agentic execution is implemented.

## Next sequence

1. Inspect current permissions, installed app, model/service availability, and Git state.
2. Execute the TextEdit checklist using disposable synthetic text; record evidence and repair confirmed failures in scope.
3. Check grants before/after a rebuild using the same identity and location.
4. Once dependable, gather real friction examples and choose the next experiment from evidence. `FRICTION_LOG.md` currently has a blank template, not validated research results.

## Starter for a fresh chat

> Read AGENTS.md and STATUS.md, then inspect relevant code and Git state. Verify Intent's existing voice-editing flow in TextEdit using WORKFLOW.md's checklist, including Apply, Undo, changed-selection/document refusal, and permission retention across rebuilding. Fix confirmed failures in this flow. Keep the current local models and signing identity. Report what you observed, what you changed, and what remains unverified. Don't add new features. If an OS permission needs human action, explain exactly what is needed and continue independent checks.
