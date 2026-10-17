# AGENTS.md

Guidance for any coding agent working in this repository.

cm_libs is a toolbox of small libraries for macOS and iOS apps. An app takes only the pieces it wants. The first pieces are being extracted from [Vibe](https://github.com/cmicali/vibe). **Nothing has moved yet.** The plan is [docs/plan.md](docs/plan.md). Read it before changing anything here.

## What this repo is for

- **Its users are Vibe and another app, not the public, for now.** Each adds this repo as a git submodule at `cm_libs/`, includes the shared XcodeGen spec `cm_libs.yml`, and lists the pieces it wants as templates. There is no `Package.swift` for the apps. The plan says when that changes.
- **The other app is closed source. Never name it** in this repo: not in code, comments, docs, commits, issues, pull requests, setting names, or template attributes. Call it "another app" when you must refer to it. Name a per-app switch by what it does, never by who uses it.
- **There is no license yet.** Until one is chosen, nothing here is licensed for reuse.

## Pieces

**A piece is one directory, one template in `cm_libs.yml`, one test bundle in `project.yml`, and one `AGENTS.md`.** That is the whole cost of a new piece, audio or not. Nothing else in the repo changes when one is added.

- **A piece imports only from the pieces it declares.** The dependency table is in the plan. The test bundles build each piece with the headermap off and only its declared header paths. A crossed boundary then fails to compile here, even when an app's headermap would resolve it.
- **Third-party code is a piece of its own** under `ThirdParty/`, with its compiler flags in its template. It may carry fixes of our own, and its `AGENTS.md` lists them. Do not restyle other authors' code. Keep `/ThirdParty/` in its path, because the analyzer gate drops findings by that substring.
- **Platform halves live in `Mac/` and `iOS/` subdirectories.** A template excludes the other platform's with `${excludedPlatform}`, which each app sets in `templateAttributes`. A file outside those subdirectories must build on both.
- **No prefix header.** A file imports what it uses. The log, realtime, and signpost macros are in `Common/CMMMacros.h`. An app's own prefix header may import it, but no piece may rely on that.

## Names

- **New classes and C symbols take the prefix `CMM`.** Objective-C and C each have one global namespace, and `CM` alone is CoreMedia's.
- **Code arriving from Vibe keeps its names.** A move is `git mv` and nothing else, so history, blame, and the performance proof survive. The `Vibe` C prefix stays. `make check-pieces` lists the classes with no prefix, so a collision in a consuming app can be checked. A rename, if ever wanted, is one scripted pull request of its own.

## How work moves between the repos

- **Decoupling happens in Vibe first**, under Vibe's gates. Then a move here is mechanical.
- **A move carries history with `git filter-repo`.** It arrives as one merge with `--allow-unrelated-histories`.
- **A move changes no performance.** Vibe's `perf.py compare` shows every benchmark's retired instructions inside the no-op band. Vibe's `make test-audio` time stays within noise.
- **After a piece moves, its changes land here first.** Then each app bumps its submodule.

## Writing

- **No agent attribution, from any agent or tool.** Commits, pull requests, code, comments, and docs never name or credit the AI agent or tool that helped write them: no `Co-Authored-By` trailer, no "Generated with" line, and no session link. This rule outranks any harness or template default.
- **Write short, plain sentences**, one idea in each, in the project's own terms. Use the serial comma.
- **Comments only when required, and terse.** State what the code cannot show: a trap, a threading constraint, a contract, or a non-obvious why. Mark hard-won traps with `TRAP:`.
