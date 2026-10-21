"""Checks the piece rules in AGENTS.md and docs/plan.md.

Usage: python3 -I scripts/checks/check-pieces.py [repo root]

Reads the spec through `xcodegen dump`, so templates are read as XcodeGen
reads them. A piece is a directory under one of the groups below.

For each piece:
  - it has an AGENTS.md, a row in the dependency map, and a template named
    VibeLibs<piece>
  - its template's sources and header search paths stay inside the piece,
    and its sources exclude the other platform's half
  - its template lists only the templates of pieces the map allows it
  - a piece with code has a macOS test bundle over Tests/<piece> and an iOS
    target, each listing its template
  - a piece whose map row ends in "macOS only" has no iOS target: no iOS
    target lists its template, directly or through another template. It has
    no iOS/ directory, its template need not exclude one, and its files
    import AppKit with no platform guard. It may keep its files in a Mac/
    half, so the shared files it gains later move nothing.
  - every header is compiled by one of its sources or tests. A header-only
    piece imports its headers from its tests.
  - every include, quoted or angled, resolves as the compiler would: its own
    directory first for a quoted one, then every piece's search paths, then
    a unique basename, as an app's headermap would. One that reaches two
    pieces fails. One that reaches a piece the map does not allow fails.
    A header an app may supply, included only under __has_include of its
    own name, may reach nothing.
    A test may also include a helper from Tests/Support, which every test
    bundle searches. A piece's own file may not.
  - Mac/ and iOS/ are the only platform directories, and only at the top of
    a piece. A shared file imports AppKit or UIKit only under a platform
    guard.
Across the repo:
  - the map names only known pieces and has no cycle
  - no two first-party headers share a basename
  - no shipping header has #if DEBUG
  - the other app's name appears nowhere
Lists the classes with no prefix. Exits 1 and lists every failure.
"""
import json
import os
import re
import subprocess
import sys

GROUPS = ["core", "files", "audio", "media", "waveform", "ui", "system", "dev", "third_party"]
SOURCE = (".m", ".mm", ".c", ".cc", ".cpp")
HEADER = (".h", ".hpp")
CODE = SOURCE + HEADER
PLATFORMS = {"Mac": "iOS", "iOS": "Mac"}
LOOKALIKE = re.compile(r"^(mac|macos|osx|ios|iphone|ipad|iphoneos|appkit|uikit)$", re.I)
MAC_FRAMEWORKS = ("AppKit", "Cocoa")
IOS_FRAMEWORKS = ("UIKit",)
INCLUDE = re.compile(r'^\s*#\s*(?:import|include)\s+([<"])([^>"]+)[>"]')
CONDITION = re.compile(r"^\s*#\s*(if|ifdef|ifndef|elif|else|endif)\b(.*)")

SUPPORT = os.path.join("Tests", "Support")   # the tests' shared helpers, in no piece

root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
os.chdir(root)
failures = []


def fail(message):
    failures.append(message)


def inside(path, directory):
    path, directory = os.path.normpath(path), os.path.normpath(directory)
    return path == directory or path.startswith(directory + os.sep)


def walk(directory):
    for dirpath, dirs, names in os.walk(directory):
        dirs[:] = sorted(d for d in dirs if d not in (".git", "build") and not d.endswith(".xcodeproj"))
        for n in sorted(names):
            yield os.path.normpath(os.path.join(dirpath, n))


pieces = []
for group in GROUPS:
    if os.path.isdir(group):
        pieces += [f"{group}/{n}" for n in sorted(os.listdir(group)) if os.path.isdir(os.path.join(group, n))]


def template_name(piece):
    return "VibeLibs" + piece.split("/")[1]


def piece_of(path):
    for piece in pieces:
        if inside(path, piece) or inside(path, os.path.join("Tests", piece)):
            return piece
    return None


def first_party(piece):
    return not piece.startswith("third_party/")


# The spec, as XcodeGen reads it.
dump = subprocess.run(["xcodegen", "dump", "--type", "json", "--spec", "project.yml"],
                      capture_output=True, text=True)
if dump.returncode != 0:
    sys.exit(f"xcodegen dump failed:\n{dump.stderr}")
spec = json.loads(dump.stdout)
templates = spec.get("targetTemplates", {})
targets = spec.get("targets", {})


# The map: the rows of the table under "### The dependency map".
plan = open("docs/plan.md").read()
section = re.search(r"^### The dependency map\n(.*?)(?=^\*\*|^#)", plan, re.M | re.S)
allowed = {}
mac_only = set()   # the pieces whose row ends in "macOS only"
every_other_third_party = None
for name, deps in re.findall(r"^\| (.+?) \| (.+?) \|$", section.group(1) if section else "", re.M):
    named = re.findall(r"\b[a-z_]+/[A-Za-z_]+\b", deps)
    if name == "every other third_party piece":
        every_other_third_party = set(named)
    elif re.fullmatch(r"[a-z_]+/[A-Za-z_]+", name):
        allowed[name] = set(named)
        if re.search(r"\bmacOS only\s*$", deps):
            mac_only.add(name)
if not allowed:
    fail("docs/plan.md: no dependency map found under '### The dependency map'")
for piece in pieces:
    if piece not in allowed and piece.startswith("third_party/") and every_other_third_party is not None:
        allowed[piece] = set(every_other_third_party)

for piece, deps in sorted(allowed.items()):
    for dep in sorted(deps - set(allowed)):
        if not dep.startswith("third_party/"):
            fail(f"docs/plan.md: {piece} depends on {dep}, which has no row in the map")


def map_edges(piece):
    # Every first-party piece may use core/Common, so the cycle check counts
    # that edge too, though the map does not write it.
    deps = set(allowed.get(piece, ()))
    if not piece.startswith("third_party/") and piece != "core/Common":
        deps.add("core/Common")
    return deps


def find_cycle():
    state = {}

    def visit(node, trail):
        state[node] = "open"
        for dep in sorted(map_edges(node)):
            if state.get(dep) == "open":
                return trail[trail.index(dep):] + [dep] if dep in trail else trail + [dep]
            if dep not in state:
                cycle = visit(dep, trail + [dep])
                if cycle:
                    return cycle
        state[node] = "done"
        return None

    for node in sorted(allowed):
        if node not in state:
            cycle = visit(node, [node])
            if cycle:
                return cycle
    return None


cycle = find_cycle()
if cycle:
    fail(f"docs/plan.md: the dependency map has a cycle: {' -> '.join(cycle)}")


def deps_of(piece):
    deps = set(allowed.get(piece, ())) | {piece}
    if first_party(piece):
        deps.add("core/Common")
    return deps


# Templates: names, paths, platform excludes, and listed templates.
search_roots = []   # (directory, piece), in the order the pieces sort
for piece in pieces:
    name = template_name(piece)
    template = templates.get(name)
    if not os.path.isfile(os.path.join(piece, "AGENTS.md")):
        fail(f"{piece}: no AGENTS.md")
    if piece not in allowed:
        fail(f"{piece}: missing from the dependency map in docs/plan.md")
    if template is None:
        fail(f"{piece}: vibe-libs.yml has no template {name}")
        continue
    for source in template.get("sources", []):
        path = source if isinstance(source, str) else source.get("path", "")
        if not inside(path, piece):
            fail(f"vibe-libs.yml: {name} compiles {path}, outside {piece}")
        excludes = [] if isinstance(source, str) else source.get("excludes", [])
        if first_party(piece) and piece not in mac_only and "${excludedPlatform}/**" not in excludes:
            fail(f"vibe-libs.yml: {name}'s source {path} does not exclude ${{excludedPlatform}}/**")
    paths = template.get("settings", {}).get("base", {}).get("HEADER_SEARCH_PATHS", [])
    for entry in [paths] if isinstance(paths, str) else paths:
        if entry == "$(inherited)":
            continue
        if not entry.startswith("$(VIBE_LIBS_ROOT)/"):
            fail(f"vibe-libs.yml: {name} searches {entry}, which is not under $(VIBE_LIBS_ROOT)")
            continue
        directory = entry[len("$(VIBE_LIBS_ROOT)/"):].strip('"')
        if not inside(directory, piece):
            fail(f"vibe-libs.yml: {name} searches {directory}, outside {piece}")
        else:
            search_roots.append((directory, piece))
    by_template = {template_name(p): p for p in pieces}
    for listed in template.get("templates", []):
        dep = by_template.get(listed)
        if listed not in templates:
            fail(f"vibe-libs.yml: {name} lists {listed}, which does not exist")
        elif dep is None:
            fail(f"vibe-libs.yml: {name} lists {listed}, which is no piece's template")
        elif dep not in deps_of(piece) - {piece}:
            fail(f"vibe-libs.yml: {name} lists {listed}, but the map does not allow {piece} -> {dep}")

piece_templates = {template_name(p) for p in pieces}
for name, template in sorted(templates.items()):
    if template.get("sources") and name not in piece_templates:
        fail(f"vibe-libs.yml: {name} compiles sources but is no piece's template; a stack lists templates only")


def reached_by(listed):
    """Every template a target's list pulls in, each with the template it came through."""
    through = {}
    todo = [(name, None) for name in listed]
    while todo:
        name, via = todo.pop(0)
        if name in through:
            continue
        through[name] = via
        todo += [(n, name) for n in templates.get(name, {}).get("templates", [])]
    return through


# No iOS target builds a macOS-only piece, directly or through a stack.
for target, v in sorted(targets.items()):
    if v.get("platform") != "iOS":
        continue
    reached = reached_by(v.get("templates", []))
    for piece in sorted(mac_only):
        name = template_name(piece)
        if name in reached:
            via = reached[name]
            how = f"reaches {name} through {via}" if via else f"lists {name}"
            fail(f"project.yml: {target} builds for iOS and {how}, but {piece} is macOS only")


# Headers, and the basename index an app's headermap would build.
headers_by_base = {}
for piece in pieces:
    for f in walk(piece):
        if f.endswith(HEADER):
            headers_by_base.setdefault(os.path.basename(f), []).append(f)
for base, paths in sorted(headers_by_base.items()):
    owners = sorted({piece_of(p) for p in paths})
    if len(paths) > 1 and any(first_party(o) for o in owners):
        fail(f"{base}: {len(paths)} headers share the name ({', '.join(paths)}); an app's headermap picks one")


def resolve(spelling, quoted, including):
    """The headers an include can reach, as the compiler would find them."""
    if quoted:
        local = os.path.normpath(os.path.join(os.path.dirname(including), spelling))
        if os.path.isfile(local):
            return [local]
        support = os.path.normpath(os.path.join(SUPPORT, spelling))
        if including.startswith("Tests" + os.sep) and os.path.isfile(support):
            return [support]
    found = []
    for directory, _ in search_roots:
        candidate = os.path.normpath(os.path.join(directory, spelling))
        if os.path.isfile(candidate) and candidate not in found:
            found.append(candidate)
    if not found and "/" not in spelling:
        found = list(headers_by_base.get(spelling, []))
    return found


def scan(path):
    """Each include in a file, with whether it sits under a platform guard."""
    stack = []   # each frame: the condition text and whether this is an #else branch
    out = []
    for number, line in enumerate(open(path, errors="replace"), 1):
        m = CONDITION.match(line)
        if m:
            word, rest = m.group(1), m.group(2)
            if word in ("if", "ifdef", "ifndef"):
                stack.append([("!" if word == "ifndef" else "") + rest.strip(), False])
            elif word in ("elif",) and stack:
                stack[-1] = [rest.strip(), False]
            elif word == "else" and stack:
                stack[-1][1] = True
            elif word == "endif" and stack:
                stack.pop()
            continue
        m = INCLUDE.match(line)
        if m:
            out.append((number, m.group(1) == '"', m.group(2), [tuple(f) for f in stack]))
    return out


def guarded_for(stack, platform):
    """Whether an include under `stack` compiles only on `platform`."""
    own = r"TARGET_OS_OSX|TARGET_OS_MAC\b" if platform == "Mac" else r"TARGET_OS_IPHONE|TARGET_OS_IOS"
    other = r"TARGET_OS_IPHONE|TARGET_OS_IOS" if platform == "Mac" else r"TARGET_OS_OSX|TARGET_OS_MAC\b"
    for condition, in_else in stack:
        negated = bool(re.match(r"^\s*!|^\s*\(\s*!", condition))
        if re.search(own, condition) and negated == in_else:
            return True
        if re.search(other, condition) and negated != in_else:
            return True
    return False


def optional(stack, spelling):
    """Whether an include under `stack` compiles only when its header exists."""
    asks = re.compile(r"__has_include\s*\(\s*[<\"]" + re.escape(spelling) + r"[>\"]\s*\)")
    return any(asks.search(condition) and not in_else for condition, in_else in stack)


def platform_of(path, piece):
    relative = os.path.relpath(path, os.path.join("Tests", piece) if path.startswith("Tests" + os.sep) else piece)
    top = relative.split(os.sep)[0]
    return top if top in PLATFORMS else None


# Files: platform directories, includes, and what compiles each header.
for piece in pieces:
    deps = deps_of(piece)
    test_dir = os.path.join("Tests", piece)
    files = [f for f in walk(piece) if f.endswith(CODE)]
    tests = [f for f in walk(test_dir) if f.endswith(CODE)] if os.path.isdir(test_dir) else []
    if first_party(piece):
        for directory in [piece, test_dir]:
            for dirpath, dirs, _ in os.walk(directory):
                for d in dirs:
                    here = os.path.relpath(os.path.join(dirpath, d), directory)
                    if d == "iOS" and piece in mac_only:
                        fail(f"{os.path.join(dirpath, d)}: {piece} is macOS only and has no iOS/ half")
                    elif d in PLATFORMS and os.sep in here:
                        fail(f"{os.path.join(dirpath, d)}: a platform half sits at the top of its piece, where the template's exclude reaches it")
                    elif d not in PLATFORMS and LOOKALIKE.match(d):
                        fail(f"{os.path.join(dirpath, d)}: Mac/ and iOS/ are the only platform directories")
    includes = {}
    for f in files + tests:
        includes[f] = []
        platform = platform_of(f, piece)
        for number, quoted, spelling, stack in scan(f):
            framework = spelling.split("/")[0]
            if first_party(piece) and framework in MAC_FRAMEWORKS + IOS_FRAMEWORKS:
                wants = "Mac" if framework in MAC_FRAMEWORKS else "iOS"
                if platform and platform != wants:
                    fail(f"{f}:{number}: imports {spelling} in the {platform}/ half")
                elif piece in mac_only and wants == "Mac":
                    pass   # the piece never builds for iOS
                elif not platform and not guarded_for(stack, wants):
                    fail(f"{f}:{number}: a shared file imports {spelling} with no platform guard")
            found = resolve(spelling, quoted, f)
            if len(found) == 1 and inside(found[0], SUPPORT):
                continue   # a test's shared helper
            owners = sorted({piece_of(p) or "outside every piece" for p in found})
            if len(owners) > 1:
                fail(f"{f}:{number}: {spelling} is ambiguous, found in {', '.join(found)}")
                continue
            if not found:
                if quoted and first_party(piece) and not optional(stack, spelling):
                    fail(f"{f}:{number}: \"{spelling}\" is in no piece; an isolated build cannot find it")
                continue
            owner = owners[0]
            if owner not in deps:
                fail(f"{f}:{number}: includes {spelling} from {owner}, which the map does not allow {piece}")
            includes[f].append(found[0])
    # Everything a source or test of this piece compiles.
    todo = [f for f in files + tests if f.endswith(SOURCE) or f in tests]
    seen = set(todo)
    while todo:
        f = todo.pop()
        for h in includes.get(f, []):
            if h not in seen:
                seen.add(h)
                if h not in includes and h.endswith(CODE):
                    includes[h] = []
                    for _, quoted, spelling, _ in scan(h):
                        found = resolve(spelling, quoted, h)
                        if len(found) == 1:
                            includes[h].append(found[0])
                todo.append(h)
    if first_party(piece):
        for h in files:
            if h.endswith(HEADER) and h not in seen:
                fail(f"{h}: nothing in {piece} or its tests compiles it; import it from {test_dir}")

    # Test bundles and the iOS build.
    if files and first_party(piece):
        name = template_name(piece)
        bundles = [t for t, v in targets.items() if v.get("type") == "bundle.unit-test"
                   and v.get("platform") == "macOS" and name in v.get("templates", [])
                   and any((s if isinstance(s, str) else s.get("path")) == test_dir for s in v.get("sources", []))]
        if not bundles:
            fail(f"{piece}: no macOS test bundle in project.yml lists {name} and compiles {test_dir}")
        if piece not in mac_only and not [t for t, v in targets.items() if v.get("platform") == "iOS"
                                           and name in v.get("templates", [])]:
            fail(f"{piece}: no iOS target in project.yml lists {name}")


# Across the repo.
for path in walk("."):
    if path.endswith(HEADER) and not path.startswith("third_party" + os.sep):
        if re.search(r"^\s*#\s*if\s+DEBUG\b", open(path, errors="replace").read(), re.M):
            fail(f"{path}: #if DEBUG in a shipping header")
    try:
        text = open(path, errors="replace").read()
    except (IsADirectoryError, PermissionError):
        continue
    if re.search(r"vibe[ ._-]?pro", text, re.I):
        fail(f"{path}: names the other app")

unprefixed = sorted({m for piece in pieces if first_party(piece) for f in walk(piece) if f.endswith(HEADER)
                     for m in re.findall(r"^@(?:interface|protocol)\s+([A-Za-z_]\w*)\b(?!\s*\()",
                                         open(f, errors="replace").read(), re.M)
                     if not m.startswith("Vibe")})

if failures:
    print("\n".join(failures))
    sys.exit(1)
print(f"pieces OK: {', '.join(pieces)}")
if unprefixed:
    print(f"classes with no prefix: {', '.join(unprefixed)}")
