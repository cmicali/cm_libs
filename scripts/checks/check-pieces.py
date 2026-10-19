"""Checks the piece rules in AGENTS.md and docs/plan.md.

Usage: python3 -I scripts/checks/check-pieces.py   (from the repo root)

A piece is a directory under one of the groups below. For each piece:
  - it has an AGENTS.md
  - vibe-libs.yml has its template, named CMM<piece>
  - a piece with source files has a test bundle in project.yml that lists
    its template
  - every quoted import that names a header in another piece names one the
    dependency map in docs/plan.md allows, or core/Common
Across the repo:
  - no shipping header has #if DEBUG
  - the other app's name appears nowhere
Exits 1 and lists every failure.
"""
import os
import re
import sys

GROUPS = ["core", "files", "audio", "media", "waveform", "ui", "system", "dev", "third_party"]
SOURCE = (".m", ".mm", ".c", ".cc", ".cpp")
HEADER = (".h", ".hpp")
failures = []


def fail(message):
    failures.append(message)


pieces = []
for group in GROUPS:
    if not os.path.isdir(group):
        continue
    for name in sorted(os.listdir(group)):
        if os.path.isdir(os.path.join(group, name)):
            pieces.append(f"{group}/{name}")

spec = open("vibe-libs.yml").read()
project = open("project.yml").read()
plan = open("docs/plan.md").read()


def files_of(piece):
    for dirpath, _, names in os.walk(piece):
        for n in names:
            yield os.path.join(dirpath, n)


# The map: "| piece | deps |" rows of the dependency map's table.
allowed = {}
for row in re.findall(r"^\| ([a-z_]+/[A-Za-z_]+) \| (.+?) \|$", plan, re.M):
    piece, deps = row
    allowed[piece] = set(re.findall(r"[a-z_]+/[A-Za-z_]+", deps))

header_owner = {}
for piece in pieces:
    for f in files_of(piece):
        if f.endswith(HEADER):
            header_owner.setdefault(os.path.basename(f), piece)

for piece in pieces:
    template = "CMM" + piece.split("/")[1]
    if not os.path.isfile(os.path.join(piece, "AGENTS.md")):
        fail(f"{piece}: no AGENTS.md")
    if not re.search(rf"^  {re.escape(template)}:\s*$", spec, re.M):
        fail(f"{piece}: vibe-libs.yml has no template {template}")
    has_source = any(f.endswith(SOURCE) for f in files_of(piece))
    if has_source and not re.search(rf"type: bundle\.unit-test(?:(?!\n  \S).)*templates: \[[^\]]*\b{re.escape(template)}\b", project, re.S):
        fail(f"{piece}: has source but no test bundle in project.yml lists {template}")
    if piece not in allowed:
        fail(f"{piece}: missing from the dependency map in docs/plan.md")
    deps = allowed.get(piece, set()) | {"core/Common", piece}
    for f in files_of(piece):
        if not f.endswith(SOURCE + HEADER):
            continue
        for spelling in re.findall(r'^\s*#\s*(?:import|include)\s+"([^"]+)"', open(f, errors="replace").read(), re.M):
            owner = header_owner.get(os.path.basename(spelling))
            if owner and owner not in deps:
                fail(f"{f}: imports {spelling} from {owner}, which the map does not allow {piece}")

for dirpath, dirs, names in os.walk("."):
    dirs[:] = [d for d in dirs if d not in (".git", "build")]
    for n in names:
        path = os.path.join(dirpath, n)
        if n.endswith(HEADER) and "/third_party/" not in path:
            if re.search(r"^\s*#if\s+DEBUG\b", open(path, errors="replace").read(), re.M):
                fail(f"{path}: #if DEBUG in a shipping header")
        try:
            text = open(path, errors="replace").read()
        except (IsADirectoryError, PermissionError):
            continue
        if re.search(r"vibe[ ._-]?pro", text, re.I):
            fail(f"{path}: names the other app")

if failures:
    print("\n".join(failures))
    sys.exit(1)
print(f"pieces OK: {', '.join(pieces)}")
