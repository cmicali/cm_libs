"""The piece checker's own tests: each case breaks one rule in a copy of the
repo and expects check-pieces.py to fail with that rule's message.

Usage: python3 -I scripts/checks/check-pieces-test.py   (from the repo root)
"""
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(".")
CHECKER = os.path.join("scripts", "checks", "check-pieces.py")


def copy_repo(into):
    listed = subprocess.run(["git", "ls-files", "-co", "--exclude-standard"], capture_output=True,
                            text=True, check=True).stdout.split("\n")
    for path in filter(None, listed):
        if os.path.isfile(path):
            os.makedirs(os.path.join(into, os.path.dirname(path)), exist_ok=True)
            shutil.copy2(path, os.path.join(into, path))


def write(root, path, text):
    os.makedirs(os.path.dirname(os.path.join(root, path)), exist_ok=True)
    with open(os.path.join(root, path), "w") as f:
        f.write(text)


def append(root, path, text):
    with open(os.path.join(root, path), "a") as f:
        f.write(text)


def replace(root, path, old, new):
    full = os.path.join(root, path)
    text = open(full).read()
    if old not in text:
        raise AssertionError(f"{path}: the mutation's text is gone: {old!r}")
    with open(full, "w") as f:
        f.write(text.replace(old, new, 1))


HEADER = "core/Common/CMMMacros.h"
SOURCE = "audio/DSP/AudioVarispeed.m"
OTHER_APP = "vibe" + " " + "pro"

# (name, mutation, text the failure must contain, or None for a pass)
CASES = [
    ("an angled include the map does not allow",
     lambda r: append(r, HEADER, "\n#import <AudioVarispeed.h>\n"),
     "which the map does not allow core/Common"),
    ("a quoted include the map does not allow",
     lambda r: append(r, HEADER, '\n#import "AudioVarispeed.h"\n'),
     "which the map does not allow core/Common"),
    ("a cycle in the map",
     lambda r: replace(r, "docs/plan.md", "| core/Common | nothing |", "| core/Common | audio/DSP |"),
     "has a cycle"),
    ("a map row naming an unknown piece",
     lambda r: replace(r, "docs/plan.md", "| audio/OutputDevices | nothing |", "| audio/OutputDevices | audio/Nowhere |"),
     "which has no row in the map"),
    ("two headers with one name",
     lambda r: write(r, "core/Common/AudioVarispeed.h", "#pragma once\n"),
     "headers share the name"),
    ("a template compiling outside its piece",
     lambda r: replace(r, "cm_libs.yml", "- path: audio/DSP", "- path: audio"),
     "compiles audio, outside audio/DSP"),
    ("a template searching outside its piece",
     lambda r: replace(r, "cm_libs.yml", '"$(CMM_ROOT)/audio/DSP"]', '"$(CMM_ROOT)/audio/DSP", "$(CMM_ROOT)/core/Common"]'),
     "searches core/Common, outside audio/DSP"),
    ("a template not excluding the other platform",
     lambda r: replace(r, "cm_libs.yml", 'path: audio/DSP\n        excludes: ["**/*.md", "${excludedPlatform}/**"]',
                       'path: audio/DSP\n        excludes: ["**/*.md"]'),
     "does not exclude ${excludedPlatform}/**"),
    ("a template listing a piece the map does not allow",
     lambda r: replace(r, "cm_libs.yml", "  CMMCommon:\n", "  CMMCommon:\n    templates: [CMMDSP]\n"),
     "the map does not allow core/Common -> audio/DSP"),
    ("a platform directory with another name",
     lambda r: write(r, "audio/DSP/macOS/Thing.m", "int CMMThing(void) { return 0; }\n"),
     "the only platform directories"),
    ("a platform half below the top of its piece",
     lambda r: write(r, "audio/DSP/Sub/Mac/Thing.m", "int CMMThing(void) { return 0; }\n"),
     "sits at the top of its piece"),
    ("a shared file importing AppKit with no guard",
     lambda r: append(r, SOURCE, "\n#import <AppKit/AppKit.h>\n"),
     "with no platform guard"),
    ("a shared file importing AppKit under a guard",
     lambda r: append(r, SOURCE, "\n#if TARGET_OS_OSX\n#import <AppKit/AppKit.h>\n#endif\n"),
     None),
    ("a shared file importing UIKit in the other branch of a mac guard",
     lambda r: append(r, SOURCE, "\n#if TARGET_OS_OSX\n#else\n#import <UIKit/UIKit.h>\n#endif\n"),
     None),
    ("the iOS half importing AppKit",
     lambda r: write(r, "audio/DSP/iOS/Thing.m", "#import <AppKit/AppKit.h>\n"),
     "in the iOS/ half"),
    ("a header nothing compiles",
     lambda r: write(r, "audio/DSP/Orphan.h", "#pragma once\n"),
     "nothing in audio/DSP or its tests compiles it"),
    ("a quoted include of an app header",
     lambda r: append(r, SOURCE, '\n#import "AppSettings.h"\n'),
     "is in no piece"),
    ("#if DEBUG in a shipping header",
     lambda r: append(r, HEADER, "\n#if DEBUG\n#endif\n"),
     "#if DEBUG in a shipping header"),
    ("the other app's name",
     lambda r: append(r, "README.md", f"\n{OTHER_APP}\n"),
     "names the other app"),
]


def run(root):
    result = subprocess.run([sys.executable, "-I", os.path.join(root, CHECKER), root], capture_output=True, text=True)
    return result.returncode, result.stdout + result.stderr


def main():
    problems = []
    base = tempfile.mkdtemp(prefix="check-pieces-")
    try:
        clean = os.path.join(base, "clean")
        copy_repo(clean)
        code, output = run(clean)
        if code != 0:
            problems.append(f"the unchanged repo fails:\n{output}")
        for i, (name, mutate, expected) in enumerate(CASES):
            root = os.path.join(base, str(i))
            shutil.copytree(clean, root)
            mutate(root)
            code, output = run(root)
            if expected is None and code != 0:
                problems.append(f"{name}: should pass, but failed:\n{output}")
            elif expected is not None and (code == 0 or expected not in output):
                problems.append(f"{name}: expected a failure containing {expected!r}, got exit {code}:\n{output}")
    finally:
        shutil.rmtree(base, ignore_errors=True)
    if problems:
        print("\n\n".join(problems))
        sys.exit(1)
    print(f"check-pieces tests OK: {len(CASES)} cases")


if __name__ == "__main__":
    main()
