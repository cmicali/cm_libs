# cm_libs: the plan

**Status: planned 2026-10-17, not started.** This replaces the plan of 2026-10-09, written when the repo was called PlaybackKit.

cm_libs is a toolbox of small libraries for macOS and iOS apps. An app takes only the pieces it wants. The first pieces come from [Vibe](https://github.com/cmicali/vibe): the audio engine, FX, analysis, waveform data, waveform drawing, the caches, and the third-party code Vibe vendors. Non-audio pieces join later. Candidates from Vibe are its stall sampler, its sandbox folder-grant manager, and its debug command channel.

Its users are Vibe and another app. Both add it as a git submodule.

## Decided

- **The name is cm_libs, and the prefix for new code is `CMM`.** `CM` alone is CoreMedia's.
- **Code moved from Vibe keeps its names.** A move is `git mv` and nothing else. The `Vibe` C prefix stays.
- **One repo of many pieces.** An app picks pieces, not the whole repo.
- **Apps compile the pieces' sources in their own targets**, through templates in a shared XcodeGen spec. No static libraries and no Swift package for the apps, for now.
- **Third-party code is a piece of its own**, one per library.
- **Vibe's waveform engine (PR #294) merges in Vibe before the waveform data moves.**

Still open: the license. Apache 2.0, like Vibe, lets code move between the repos freely.

### What changed from the 2026-10-09 plan

| Was | Now | Why |
| --- | --- | --- |
| PlaybackKit, prefix `PBK` | cm_libs, prefix `CMM` for new code | The repo is a toolbox, not only playback. |
| Rename every class and C symbol on the move | No rename | A rename touches 441 names in 678 files of Vibe and 88 of #294's 111 files. Folded into the move, it would turn every moved file into a content change and break the performance proof. |
| Static framework targets in the shared spec | Templates the app compiles in | Same run time, and the app's test targets can still build the engine with their own flags (below). |
| A prefix header per product | Explicit imports of one macros header | A target has one prefix header, so a piece cannot bring its own. |
| Vendored code inside the engine product | Each library a piece of its own | An app can take TagLib or dr_flac without the engine. |

## The pieces

```
cm_libs/
  AGENTS.md  README.md  LICENSE  docs/plan.md
  cm_libs.yml        the shared spec: settingGroups, and one targetTemplate per piece
  project.yml        this repo's own project: the spec, plus one test bundle per piece
  Makefile  .github/workflows/ci.yml  scripts/checks/check-pieces.sh
  Common/            CMMMacros.h (log, realtime, signposts), HelperMacros.h, the platform aliases, the work tally
  Audio/             the engine, with Loading/ inside it
  WaveformData/      AudioWaveform, its codable form, and WaveformCore/
  Analysis/          the BPM and key analyzers, MusicalKey.h, the analysis framer
  FX/                AudioVarispeed, then AudioFX and FadeMath.h
  WaveformUI/        WaveformTheme, Renderers/, Mac/, iOS/, Controls/
  ThirdParty/        taglib/, dr_mp3/, dr_flac/, dr_wav/, r8brain/, PINCache/ (with PINOperation), ogg/, vorbis/
  Tests/             mirrors the pieces
```

| Piece | Imports from | Third-party |
| --- | --- | --- |
| Common | nothing | none |
| ThirdParty/* | nothing | itself |
| Analysis | nothing outside itself | none |
| FX | Common | none |
| WaveformData | Common | none |
| Audio | Common, FX, Analysis, WaveformData | taglib, dr_*, r8brain, PINCache, ogg, vorbis |
| WaveformUI | Common, WaveformData | none |

**What each split buys:**

- **Audio without WaveformUI.** A command-line tool, a background analyzer, or an app with its own interface links no view code.
- **WaveformUI without Audio.** An app on AVFoundation can draw these waveforms from its own samples, with no TagLib, no r8brain, and no player. The waveform views reach into the engine only through `AudioWaveform.h`, so this split follows a line Vibe's code already draws.
- **FX without anything.** Any render callback can host the varispeed: an `AVAudioSourceNode`, an Audio Unit, or someone else's player.
- **Analysis without anything.** BPM and key from a buffer of PCM.
- **A vendored library alone.** TagLib for tags, dr_flac for decoding, PINCache for a disk cache.

**Two groupings are forced by today's code.**

- **`Loading/` sits inside `Audio/`.** The file handle imports the materializer and the network read-ahead, and the coordinator's open imports the file handle. They are one piece.
- **The waveform loader and cache stay in Audio.** They open files through the file handle and file through the cache helper. Only the waveform type and its archive are WaveformData, which is what keeps WaveformUI free of the engine.

**One cycle stays inside Audio.** `AudioTrack` carries its tags, and the metadata code imports `AudioTrack` and the file handle. Splitting them means two track types: a core track (URL, cue window, keys) and an app's row model (tags, art, detected BPM and key, display names). Do that when someone needs the player without TagLib, not before.

**Artwork is the one place the engine hands out UI types.** `AudioTrack` and the metadata code return `NSImage` or `UIImage`. AppKit and UIKit are always present, so that is tolerable. A UI-free engine would return a `CGImage`. Leave it until someone asks.

**Caching is not a piece of its own.** It is the PINCache piece, plus the cache helper and the cache key in Audio. Both of Audio's disk caches take a root path, so an app can place its caches, or share one directory with another app through an app group.

## How an app uses a piece

**A git submodule, compiled in tree.**

- The app's repo has this repo as a submodule at `cm_libs/`, pinned to a commit. The app's `make project` runs `git submodule update --init --recursive` before it generates, so a fresh clone or a worktree works.
- The app's `project.yml` has `include: [cm_libs/cm_libs.yml]`. Each app target lists the pieces it wants under `templates:`. It sets `templateAttributes: {excludedPlatform: iOS}` on macOS, or `Mac` on iOS.
- The pieces' files compile as the app's own sources. Each vendored library keeps its own compiler flags in its template.
- The spec reads one project setting, the verbose-logging switch. Vibe maps it from its beta switch, and test targets set it to 1.
- The log subsystem is the main bundle's identifier, so each app logs under its own name.

### Why compile in, and not link

The constraint is no performance change in either app. Compiling in meets it by construction.

| Shape | Run time | What it costs |
| --- | --- | --- |
| Templates, compiled in | identical: the same files, flags, and objects as today | nothing |
| Static library targets in the shared spec | identical, given `-ObjC` on every app | A library is built once per project. Vibe's audio tests build four render files at `-O2` and turn verbose logging on, and its unit tests link a stand-in metadata class. One shared build cannot serve both. |
| A Swift package, linked | slower in Debug | Xcode builds a package with its own settings, unoptimized in Debug. `-O3` for the decoders exists only as `unsafeFlags`, which a package fetched by URL may not use. There is no prefix header and no per-file flag. |

Vibe has no link-time optimization today, so files inline across each other only through headers. A library boundary would not change that. The difference is entirely in the flags and the test builds.

**The proof, for the pilot and every move**, run in Vibe with its `vibe-perf` skill:

1. `perf.py compare main main` records the no-op band of retired instructions.
2. `perf.py compare <before the move> <after the move>` keeps every benchmark inside that band.
3. `make test-audio` wall time before and after stays within noise. This catches a lost Debug optimization, which Release benchmarks would not show.

### When to switch shapes

- **To static library targets**, when the test targets no longer compile production sources and two consumer targets in one project make the double compile cost real time. The template becomes `type: library.static`, apps change `templates:` to `dependencies:`, and every app and test target gets `OTHER_LDFLAGS: -ObjC`. **TRAP: without `-ObjC`, a static library silently drops category-only objects**, such as `NSURL+Hash` and every debug seam.
- **To a Swift package**, only for outside users. Measure the decoders without `-O3` first. Add whole-file `#if TARGET_OS_OSX` guards to the platform halves, since a package compiles every file on every platform. Keep C++ out of public headers. Tag `0.x` until the API settles. WaveformCore keeps its own `Package.swift` throughout, since it is pure C++ and already standalone.

## The boundary check

This repo's `project.yml` has one test bundle per piece. Each sets `USE_HEADERMAP: NO`, `ALWAYS_SEARCH_USER_PATHS: NO`, and `GCC_PREFIX_HEADER: ""`, with header search paths for only its piece and the pieces it declares. An import outside them fails to compile here. Each piece also builds for iOS, so an AppKit leak fails here too.

`scripts/checks/check-pieces.sh` checks the rest:

- every top-level piece has a template, a test bundle, and an `AGENTS.md`
- every template's paths stay inside its piece
- every import between pieces is in the dependency table
- the platform rule: only `Mac/` and `iOS/` are platform-specific
- no `#if DEBUG` in a shipping header
- the classes with no prefix, listed
- the other app's name appears nowhere

CI runs `make check-pieces`, `make test`, `make build-ios`, and `make analyze CONFIG=Release`. GitHub Actions is free for a public repo, macOS runners included.

## The work, in order

**Decoupling happens in Vibe first**, under Vibe's gates, with no piece moved. Then each move is mechanical. Each move is a pull request here, plus one in Vibe that bumps the submodule and deletes the moved directory.

### Phase 0: setup and experiments

Choose the license. Then answer eight questions with throwaway specs and branches, and record each answer here:

1. Paths in an included spec resolve relative to the included file, so the submodule can sit anywhere.
2. A template can list other templates, and `${excludedPlatform}` substitutes from `templateAttributes`.
3. A template's header search paths join the target's, rather than replace them.
4. A test bundle with the headermap off fails on a stray import of an app header.
5. `xcodegen dump` keeps an included spec's templates. Vibe's `perf.py` builds its benchmark tool from that dump.
6. The pilot passes the performance proof.
7. A package dependency by path accepts `unsafeFlags`, and one by URL refuses them.
8. `actions/checkout` with `submodules: recursive` reaches every CI job in Vibe.

### Phase 1: the cuts in Vibe

Twelve small pull requests in Vibe remove every reach from the moving code into Vibe's own. When they are done, this returns nothing in Vibe:

```
grep -rln 'AppSettings\|AppTheme\|VibeStrings.h\|FolderAccessManager\|PlaylistFile.h\|DebugWireFormat' \
  Vibe/Audio Vibe/Loading Vibe/WaveformUI Vibe/Controls | grep -v Loading/iOS/Dropbox
```

1. A debug seam stops importing the debug channel's parser.
2. The playlist extension tests move below both readers, so loading stops importing the playlist code.
3. The metadata cache takes a root path, as the waveform cache already does.
4. Folder art stops reading the settings and the mac's folder grants. The app installs both as providers.
5. `AudioTrack`'s two strings: one key is retired, and the app pushes the cue-row title format at launch.
6. One header in Vibe turns every error code and style identifier into its localized text. The engine reports codes only.
7. Duration, file-info, and accessibility formatting move out of the engine and the views.
8. The waveform style and theme identifiers move from Vibe's settings into the registry and the theme.
9. The mapping from Vibe's settings onto a waveform theme becomes a category in Vibe.
10. The app pushes the mac waveform view its settings, instead of the view reading them.
11. The app pushes the iOS scrubber its settings, instead of the view reading them.
12. The log, realtime, and signpost macros move out of Vibe's prefix header into `CMMMacros.h`. The prefix header imports it.

### Phase 2: the pilot, FX with the varispeed

The smallest real piece goes first. `AudioVarispeed` is Vibe's own windowed-sinc converter for the pitch fader. Its distortion sits near −150 dB, against −83 to −135 dB for Apple's Varispeed unit. It is flat to 20 kHz and a bit-perfect pass-through at zero pitch. It costs about 0.2% of one core at 48 kHz.

It is already a library in all but location. Its API is plain C. It imports only system headers and the realtime macros. It has one caller in Vibe. Its tests and its benchmark stand alone.

The pilot proves every step the big moves will take: `git filter-repo`, the template, this repo's CI, the submodule in Vibe, `make project`, worktrees, Vibe's CI checkout, and `perf.py`. **Done when** Vibe's checks pass with the varispeed coming from here, the `pitch` benchmark shows no change, and this repo's CI runs `AudioVarispeedTests`.

`AudioFX`, the DJ chain, follows into FX once its hosting rules are written as its contract. Connect it with the output stopped. Dispose of it only after the render leaves.

### Phase 3: the vendored pieces

TagLib, dr_mp3, dr_flac, dr_wav, r8brain, PINCache, ogg, and vorbis move, each with its flags and its notes on Vibe's fixes. They depend on nothing, and Vibe's binary is unchanged after. The third-party notices split. This repo lists its pieces' licenses, and Vibe lists Sparkle and points here.

### Phase 4: Analysis and Common

The analyzers with `MusicalKey.h`, and the macros, helpers, and platform aliases. **Done when** `perf.py --analyze` proves Vibe's tempo and key results exact.

### Phase 5: WaveformData

This waits for #294 to merge in Vibe. Then `AudioWaveform.h`, its codable form, and `Packages/WaveformCore` move whole, with WaveformCore's `Package.swift` and its tests.

### Phase 6: Audio

The engine with `Loading/` inside it, the metadata and artwork, the caches, and the engine's debug seams and simulators. The seams stay DEBUG-only as they are. The engine's tests move with it, including the render-pump suite and its fixtures. **Done when** Vibe's checks pass against this repo, this repo's CI passes on its own, and the performance proof holds.

### Phase 7: WaveformUI

The renderers, the morph engine, the theme, the loading and equalizer controls, and both views. **Done when** Vibe's waveform benchmark pictures are byte-identical and screenshots on both platforms match.

### Phase 8: docs

Each directory's `AGENTS.md` moves with it. The engine's own guarantees move to this repo's `AGENTS.md`: the handle-open ceiling, the meter's place in the render, and the waveform theme's precedence. Vibe keeps the guarantees that span app and engine, each naming its side here. Vibe's audio-quality measurements and its component performance charts move too.

## TRAPs

- **A checkout without the submodule compiles nothing from here and fails late.** Every consumer's `make project`, benchmark worktrees, and CI checkouts must update it.
- **YAML anchors do not cross `include:` files.** A consumer's own flag anchors cannot reach a template's entries. Every flag lives in its template.
- **The headermap hides a crossed boundary.** In any project holding two pieces, an import by basename resolves across them. Only this repo's headermap-off bundles make the compiler refuse.
- **`xcodegen dump` leaves templates unresolved.** A tool that rebuilds a consumer's target from the dump must copy `templates` and `templateAttributes`. Otherwise it builds without the pieces.
- **Keep `/ThirdParty/` in every vendored path.** Otherwise the analyzer gate fails on third-party findings.

## Costs

- **Most engine changes also change app code.** Since 2026-04-01, 232 commits changed Vibe's engine, and 167 of them (72%) also changed Vibe's app code. After a move, each is a commit here, then a submodule bump. One editing session covers both through the submodule.
- **Many changes span pieces.** 90 of those commits (39%) changed more than one piece. That is why this is one repo and not one per piece.
- **Agent docs split across two repos.** An agent in an app must read this repo's `AGENTS.md` before changing a piece. Each app's root doc says so.
- **The engine's tooling lives here after the move.** That covers its tests, its parts of the stress and performance harness, and its audio-quality checks. Apps keep their app-level stress runs.
- **Vibe's two test source lists stay until each piece's tests move here.** Vibe's tests build production sources with their own flags, which is the reason compiling in was chosen.

## Later: the HTTP road

Streaming over HTTP into the engine is planned in Vibe ([share links](https://github.com/cmicali/vibe/blob/main/docs/future/share-links.md) Phase 2, and [streaming from any source](https://github.com/cmicali/vibe/blob/main/docs/future/streaming-any-source.md) Phase 1). Once the engine lives here, that work lands here.
