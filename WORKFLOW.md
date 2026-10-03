# Working on Intent with Codex

These are project workflow recommendations and reusable prompts. They do not change Codex settings or start tasks automatically.

## Chat boundaries

Use one implementation chat per meaningful outcome, keeping its bug fixes in that chat. Start a fresh project chat after a milestone with a saved handoff. Continue/compact when the objective is still the same; fork for an alternative direction with shared history; use a side chat for an explanation when available. Check the app's command menu for supported commands.

Run one implementation at a time by default. Independent research or review can run separately. Concurrent implementations need separate worktrees and explicit integration; this project's build script installs to one shared app path, so coordinate builds/relaunches even with worktrees.

## Decide → build → verify → observe

Before a substantial feature, define the user problem, intended interaction, constraints, and evidence of success. During implementation, correct direction with concrete examples. Afterward, review the diff and try the actual product flow. Use observed friction to choose the next change.

Keep standing rules in `AGENTS.md`, the current milestone in `STATUS.md`, setup in `README.md`, technical evidence in `VERIFICATION.md`, and user observations in `FRICTION_LOG.md`. The original `BUILD_BRIEF.md` records product intent; some desired behavior is not implemented. Do not treat its acceptance criteria as passed results.

## Prompts to reuse

**Explore before implementation**

> Don't code yet. Here is the user problem: [observation]. Challenge the assumptions, propose three approaches and their tradeoffs, then recommend the smallest experiment that would teach us something. Separate observed evidence from hypotheses.

**Implement a selected approach**

> Implement [specific interaction] for [user/task]. Preserve [constraints]. Done means [observable flow and checks]. Resolve routine choices yourself and finish the runnable result. Keep changes focused. Report verified behavior and gaps separately. [State whether to commit/push.]

**Report a bug**

> In [app/version], I did [exact steps]. Expected [behavior]. Observed [behavior]. It happens [frequency/context]. Here is a screenshot or recording. Reproduce and fix the cause, then check the failing flow.

**Review a change**

> Review [commit/diff] against [acceptance criteria]. Look for incorrect behavior, lost data, wrong destinations, cancellation issues, and regressions. Give concrete findings with evidence. Don't modify code during this review.

**Finish and hand off**

> Check Git state and update STATUS.md from the actual code and evidence. Record the current objective, durable decisions, failures, unverified behavior, and next step. Update setup/verification docs only where needed. Give me a short prompt for a fresh project chat; keep the handoff concise.

**Turn interviews into an experiment**

> Analyze these anonymized user notes. Separate observations, interpretations, and assumptions. Identify recurring friction, conflicting evidence, and missing information. Recommend one small experiment and how we would assess its benefit. Don't invent quotes or turn a single anecdote into a general finding.

## Next milestone: manual voice-editing verification

Use a new disposable TextEdit document in plain-text mode, not a personal document. Keep unrelated prefix/suffix text around the selected paragraph. Use synthetic details:

> Hi Ananya, are you available for our design review on 8 October at 4 PM? We need to discuss the pill interaction and editing preview. The prototype budget is ₹2,000. Please let me know if that time works.

Spoken instruction: “Make this shorter. Keep the name, date, time, agenda, and budget.”

| Check | Procedure | Required observation |
| --- | --- | --- |
| Prerequisites | Inspect Setup; allow mic/Accessibility if needed; Check editor; check Ready and shortcut status. Enable the pill if it is hidden for this test. | Actual permission/service state recorded. Restore any temporarily changed visibility setting afterward. |
| Typed experiment | Paste sample into Voice edit without an external selection, type an instruction, Rewrite. | Result appears; original unchanged; Copy available; Apply disabled. |
| Capture and recording | Select only the paragraph in TextEdit; hover/click pencil; speak; stop. | Selection captured without stealing focus before capture; instruction and result appear in preview. |
| Apply | Review facts, apply, then inspect TextEdit. | Only selected paragraph replaced once; surrounding text intact; original retained in Intent. |
| Undo | Return to Intent and Undo without modifying TextEdit. | Exact original restored when document snapshot support makes Undo available. |
| Selection drift | Generate a new preview, select another range in the original field before Apply. | Replacement refused; preview/original recoverable. |
| Document drift | Generate a new preview; edit another part of the document before Apply. | Replacement refused when full document text is exposed. |
| Undo drift | Apply, then type something else in TextEdit; attempt Undo. | No overwrite of the changed document; recovery message/original available. |
| Cancellation | Cancel during recording and during processing in separate takes. | No replacement, including after delayed model completion; recoverable state. |
| Unsupported destination | Try a target that lacks direct selection-write support. | Clear refusal/recovery with copying; no blind destructive paste. Mark not exercised if no such target is available. |
| Rebuild grants | Observe both grants and successful recording/capture; close Intent; build/install; reopen same path; inspect grants and repeat a take. | Grants remain available with no renewed request, or a precise failure is recorded. Signature compatibility alone is insufficient. |

Repeat the successful capture/Apply/Undo flow three times before broader compatibility testing. Record app, steps, expected/observed behavior, and pass/fail/not-run in `VERIFICATION.md`. The original brief's ten-take checks in target apps and three-day use are later acceptance checks, not a requirement for every small change.

## User evidence after reliability

Collect actual tasks and switching-back occasions. Compare time to a verified result, corrections, checking effort, and voluntary reuse against the person's existing workflow. Record the context and sample size. Distinguish a functioning demo from evidence of value; use the observations to revise the next experiment.
