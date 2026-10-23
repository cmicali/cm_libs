"""The move's message filter's own tests: each case is a commit message and
what scripts/plan/filter-messages.py must make of it.

Usage: python3 -I scripts/checks/filter-messages-test.py   (from the repo root)
"""
import os
import runpy
import sys

rewrite = runpy.run_path(os.path.join("scripts", "plan", "filter-messages.py"))["rewrite"]

CASES = [
    ("a plain message is kept",
     b"audio: Fade the voice out\n\nThe fade is linear.\n",
     b"audio: Fade the voice out\n\nThe fade is linear.\n"),
    ("each spelling of Co-Authored-By goes",
     b"audio: Fade\n\nBody.\n\nCo-Authored-By: A Tool <noreply@example.com>\n"
     b"Co-authored-by: Another <noreply@example.com>\nco-authored-by: x <y>\n",
     b"audio: Fade\n\nBody.\n"),
    ("a session link goes",
     b"audio: Fade\n\nClaude-Session: https://claude.ai/code/session_0\n",
     b"audio: Fade\n"),
    ("a Generated with footer goes",
     b"audio: Fade\n\n\xf0\x9f\xa4\x96 Generated with [A Tool](https://example.com/tool)\n",
     b"audio: Fade\n"),
    ("prose that says generated stays",
     b"audio: Fade\n\nThe table is generated with the script.\n",
     b"audio: Fade\n\nThe table is generated with the script.\n"),
    ("Closes #45 names Vibe",
     b"fix: Stop\n\nCloses #45.\n",
     b"fix: Stop\n\nCloses Vibe #45.\n"),
    ("every keyword in every tense and case names Vibe",
     b"close #1 closes #2 closed #3 fix #4 fixes #5 FIXED #6 resolve #7 Resolves #8 resolved #9\n",
     b"close Vibe #1 closes Vibe #2 closed Vibe #3 fix Vibe #4 fixes Vibe #5 FIXED Vibe #6 "
     b"resolve Vibe #7 Resolves Vibe #8 resolved Vibe #9\n"),
    ("a colon after the keyword names Vibe",
     b"Fixes: #12\n",
     b"Fixes: Vibe #12\n"),
    ("a number with no keyword stays",
     b"audio: Fade (#45)\n\nSee #46. Since Vibe #47.\n",
     b"audio: Fade (#45)\n\nSee #46. Since Vibe #47.\n"),
    ("a keyword inside a word stays",
     b"Prefix #3, suffixes #4, and unresolved #5.\n",
     b"Prefix #3, suffixes #4, and unresolved #5.\n"),
    ("a message already filtered is unchanged",
     b"fix: Stop\n\nCloses Vibe #45.\n",
     b"fix: Stop\n\nCloses Vibe #45.\n"),
]

failed = 0
for name, message, expected in CASES:
    got = rewrite(message)
    if got != expected:
        failed += 1
        print(f"FAIL {name}\n  got:      {got!r}\n  expected: {expected!r}")
print(f"filter-messages: {len(CASES) - failed} of {len(CASES)} cases pass")
sys.exit(1 if failed else 0)
