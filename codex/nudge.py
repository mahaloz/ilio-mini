#!/usr/bin/env python3
"""Codex PostToolUse hook: after 10 and 30 min without a flag, tell the ROOT agent to split into parallel lanes."""
import json, os, sys, time
ev, W = json.load(sys.stdin), "/work"
if os.path.exists(f"{W}/FLAG") or not os.path.exists(f"{W}/.start"): sys.exit(0)
root = open(f"{W}/.root").read().strip() if os.path.exists(f"{W}/.root") else ev.get("session_id")
if ev.get("session_id") != root: sys.exit(0)
m = int((time.time() - float(open(f"{W}/.start").read())) / 60)
for t in (30, 10):
    if m >= t and not os.path.exists(f"{W}/.nudge{t}"):
        for u in (10, 30):
            if u <= t: open(f"{W}/.nudge{u}", "w").close()
        msg = (f"HARNESS: {m} min and no correct flag yet. Split now with $explore-alternatives: update /work/notes.md, "
               "then spawn 2-3 subagents on genuinely different directions (each with one bounded question and its own "
               "/work/lanes/<name>/), keep your own lane moving, and merge their reports. Only you submit.")
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": msg}}))
        break
