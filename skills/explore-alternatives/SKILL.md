---
name: explore-alternatives
description: When and how to split a Flare-On solve into parallel subagent lanes that explore different directions. Use after ~10 minutes without a correct flag, when the harness nudges you, after a wrong submission, or whenever you notice you are looping on one idea. Covers picking orthogonal lanes, briefing subagents, and merging their results.
---

# Split into alternative directions

## When
- 10 min without a flag (the harness nudges you at 10 and 30 min), a wrong `ilio submit`, or two attempts at the same idea with no new facts.
- At 30 min: re-split. Drop lanes that produced no new facts, and start lanes that make *different* assumptions.

## Pick 2-3 lanes that are genuinely different (not the same idea twice)
- **Dynamic**: run or emulate the target and capture the decrypted or computed value (`$windows-dynamic`, unicorn, speakeasy). This often skips the reversing entirely.
- **Static deep-dive**: fully reverse the one routine that matters (the checker, key schedule, or VM) into a clean Python model.
- **Format / forensics**: look again at everything in `src/`: embedded resources, appended overlays, second files, metadata, pcaps, images.
- **Math / crypto**: treat the check as equations (z3, sympy, linear algebra), identify the primitive from its constants, and look for known weaknesses.
- **Re-read the prompt**: the title and description puns, earlier flags in `/solves.md`, and what the handout author expects you to notice.
- **Tooling**: when a tool is the blocker (Kuna failure, wrong Python version, missing emulator), one lane fixes or replaces it while the others continue.

## Brief each subagent
- One bounded question plus the exact files and addresses to use.
- Paste in what is already ruled out (from `notes.md`), so it does not repeat dead ends.
- Give it its own dir, `/work/lanes/<name>/`. It writes `report.md` there: findings, evidence (addresses, commands) and candidate flags.
- Tell it: "Do not run `ilio submit`; return candidate flags to me."
- Use `fork_turns: "none"` with a self-contained brief for fresh eyes, or `"all"` only when the lane needs your full context.

## Run the lanes
- Keep your own lane moving while they run. Check their reports and wait with a timeout rather than blocking forever.
- Merge the facts into `notes.md` as they arrive. Close lanes that are finished or dead. Only you submit.
- Once a lane produces a candidate flag, verify it cheaply, then submit it.
