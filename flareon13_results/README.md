# FLARE-On 13 — ilio agent results

Autonomous run of the ilio harness (Codex `gpt-5.6-sol`, reasoning `high`, service tier
`priority`) against the live FLARE-On 13 CTFd on 2026-09-26. `ilio auto` looped
download → triage → solve → submit → next, one challenge at a time. **All 9 real
challenges were solved on the first attempt** (0 resumes, 0 cyber-filter blocks, 0
wrong-flag retries).

## Contents
- `index.html` — the full report: per-challenge trace, tool usage (incl. kuna), and
  token cost. Standalone; open in a browser (loads Jost and Roboto Mono from Google
  Fonts, falls back to system fonts offline).
- `results.tsv` — per-challenge wall time, first-response time, and token count.
  The `tokens_blended` column is the harness's own metric, which sums every usage
  sub-field and so double-counts cached input + reasoning (see the note below).
- `report_data.json` — parsed metrics behind the report: per-challenge tool counts,
  clean token splits (input/cached/uncached/output), and aggregates.

## Summary
- **9 / 9 solved & accepted**, each in a single Codex turn.
- **~80.5 min** total agent wall time (42 s → 24 min per challenge).
- **494** shell commands across the 9 turns.
- **51** `kuna` invocations across 6 of 9 challenges (heaviest on the native
  problems: FlareCalc ×20, FlareOn13.doc ×10, Threat Invaders ×10). No `KUNA_NEED.md`
  gaps were logged.
- **64.9 M** billable tokens (input + output), **98% served from cache**
  (63.30 M cached input, 1.39 M uncached input, 0.20 M output). Illustrative cost
  ≈ $21 total (~$2.4/challenge) at representative frontier rates — recompute with the
  real gpt-5.6-sol priority rate from the token splits in `report_data.json`.

Challenge 10 "victory" is **not** a challenge: its CTFd body is a "Congratulations on
completing FLARE-On 13!" note with a prize-shipping form (0 solves, no flag). The
agent submitted six evidence-based candidates, all rejected, then concluded it is an
announcement sentinel that should be excluded from `ilio auto`.

The raw per-challenge working directories (handouts, `log.jsonl`, kuna exports, notes)
live under `chals/`, which is gitignored (~15 GB) and not committed here. Flags and
solve write-ups are intentionally not published.
