# Voice dictation playground: first build

This is the original product brief and desired acceptance criteria, not a description of everything implemented or verified. For current scope and evidence, see STATUS.md and VERIFICATION.md. The immediate next milestone is checking the existing voice-editing flow before adding features.

## Purpose

Build a Mac app Vedant can use for everyday dictation, providing a dependable foundation for experiments that reduce the effort between intent and a correct outcome. Reproduce the core Wispr Flow interaction with an independent identity. The first milestone is usable dictation; the larger research question is which context and actions make it materially more useful.

## First user and workflow

Vedant is the first user. Start with English and his everyday Hinglish, using free local Whisper through WhisperKit on his Apple Silicon Mac. No API key or paid transcription service is required; initial setup downloads model weights. Start with the SDK's recommended multilingual model and measure its performance on this Mac. Treat STT as a supplied, replaceable capability while evaluating recognition errors as part of the complete experience. Do not turn this project into STT model development.

Keep the product experimentation layer independent of the STT engine. Include a development-only way to supply or correct a transcript before running an experiment, so recognition errors do not prevent testing what good STT could unlock. Report live voice results separately from corrected-transcript experiments.

Initial target fields: ChatGPT/Codex prompts, WhatsApp Web messages, and Google Docs paragraphs. Verify actual compatibility in each during development; handle unsupported fields with a recoverable result.

## Core interaction

1. Launch a menu bar app and complete microphone, Accessibility, and the initial local model download. Default shortcut: hold Option + Space; make it configurable.
2. Place the cursor in a text field. Hold the shortcut to record. Show a small listening indicator and audio activity; leave the target app focused.
3. Release to finish. Show processing feedback, transcribe, and apply restrained cleanup: punctuation, filler removal, explicit spoken self-corrections, and simple lists. Preserve meaning, names, casual phrasing, and language mixing. Do not translate unless requested.
4. Insert the completed text once into the intended field. If focus changes or insertion cannot be completed safely, retain the result for explicit copying instead of pasting into another destination.
5. Escape cancels recording or processing and prevents insertion. On failure, retain the current take for retry or recovery; never discard it silently.

Provide a small result/recovery window, basic settings for shortcut and microphone, and a manually editable vocabulary list. Preserve clipboard contents when insertion uses paste. Keep any recent-take recovery local, limited, and clearable; do not add cloud history sync. Explain which providers receive audio and text before first use.

## Acceptance criteria

- Complete ten consecutive takes in each target app without duplicate insertion, wrong-destination insertion, or an unrecoverable lost take. Include short replies, a paragraph, a list, and a spoken correction.
- Verify cancellation, microphone denial, an unavailable STT service, an empty recording, and a focus change during processing. Each must end in a clear, recoverable state without unintended insertion.
- Compare raw transcription and final text on representative English/Hinglish takes. Cleanup must preserve the user's intended meaning; record errors rather than hiding them behind polished prose.
- Measure release-to-result latency and the time spent correcting output on typical short takes. Initial responsiveness target: most takes finish within two seconds after release; report measured results and revise the target if needed.
- Vedant uses the app for ordinary work across three days and logs each occasion he switches back to Kivi/Wispr, including why. This determines whether the foundation is usable enough for experiments.

## Scope boundary

Build for macOS only. Defer billing, accounts, usage dashboards, mobile versions, full visual parity, continuous recording, automatic learning, and general computer control. Do not send messages or execute dictated requests in this milestone.

## First experiment after the baseline

Test an explicit spoken reference to the latest clipboard item inside dictation. Example: copy a passage, then dictate “Explain this in simple terms: [clipboard cue].” Substitute the copied text verbatim at the marked position, with a preview before insertion during the experiment. The cue is undecided; test discoverability and accidental activation before fixing it. Defer numbered clipboard history until users demonstrate a need.

Before choosing this experiment, collect five friction examples from Vedant and observe three people doing real dictation work, including one who stopped using it. Change the experiment if a stronger recurring problem emerges. Compare task completion time, manual corrections, checking effort, and voluntary reuse with the existing workflow.

## Product evidence to keep

Maintain a short friction log: intended outcome → existing workflow → observed problem → prototype change → result. The eventual internship case study should connect a specific user problem to a shipped interaction and the evidence that guided its revisions.
