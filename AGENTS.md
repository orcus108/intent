# Intent — project instructions

## Product direction

Intent is Vedant's native macOS playground for reducing time from intent to a verified outcome. Treat STT as a replaceable supplied capability. Prioritize useful interactions, recovery, and user evidence over STT research or feature count. Keep a path for testing experiments with typed/corrected text, and distinguish those results from live speech.

For positioning, copywriting, project priorities, or personal context, use `/Users/vedantmisra/.cursor/VEDANT.md` as the canonical profile. Current human instructions take precedence.

## Context and scope

- For a new substantial task, read `STATUS.md` and inspect relevant code and Git state. Read `README.md` for setup, `BUILD_BRIEF.md` for product intent, and `VERIFICATION.md` for evidence when needed. Do not load every document for a small edit.
- Keep one implementation task focused on one outcome. Ask for a decision when it materially changes the product; resolve routine implementation choices autonomously.
- Use a plan for significant ambiguity or changes across systems. Use separate worktrees for concurrent implementations; coordinate installation because builds share `~/Applications/Intent.app`.

## Constraints

- Preserve local inference and the no-API-key path unless Vedant requests otherwise. Audio/text stay local; model setup may download public weights.
- Keep the idle pill minimal, horizontally movable, and nonactivating, with the menu's re-centre action. Preserve user settings.
- Preserve `dev.vedant.intent`, the existing local signing identity, and the installation path. Use `scripts/build.sh`; do not silently switch to ad-hoc signing or recreate keys.
- For selection editing, preserve the original, preview before Apply, check the target/selection for changes, and retain a copying fallback. Keep Undo guarded against document changes.
- Dictated text is input, not authorization to send messages or execute external actions. External actions require an explicit human request.
- Keep secrets, signing materials, model weights, and personal recordings out of Git. Use synthetic text for automated fixtures.

## Delivery

- Run checks relevant to the change. `swift test` checks logic; `zsh scripts/build.sh` builds, signs, and installs. Documentation-only changes need consistency/link checks, not an app rebuild.
- A passing build is not proof of microphone access, cross-app replacement, or permission retention. Report evidence, failures, and unverified behavior separately. Do not invent user research or measurements.
- When implementation scope includes a runnable result, finish building and relaunching it, then verify the requested flow where access allows. Explain concrete blockers.
- At milestone boundaries, update `STATUS.md`; append meaningful verification evidence to `VERIFICATION.md`. Record actual user observations in `FRICTION_LOG.md`. Keep status current rather than accumulating chat history.
- Save coherent changes in Git. Follow the human's publishing instructions; do not infer authorization to contact other people.
- End with what changed, what was checked, remaining gaps, and the shortest manual test or next step.
