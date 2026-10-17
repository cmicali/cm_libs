# cm_libs: the plan

**Status: planned 2026-10-17, not started.** This replaces the plan of 2026-10-09, written when the repo was called PlaybackKit.

cm_libs is a toolbox of small libraries for macOS and iOS apps. An app takes only the pieces it wants. The first pieces come from [Vibe](https://github.com/cmicali/vibe). They are its audio engine, file loading, tags, playlists, waveform data and drawing, controls, app plumbing, and the third-party code it vendors. **Anything in Vibe that is general enough for another app to use belongs here.**

Its users are Vibe and another app. Both add it as a git submodule.

## Decided

- **The name is cm_libs, and the prefix for new code is `CMM`.** `CM` alone is CoreMedia's.
- **Code moved from Vibe keeps its names.** A move is `git mv` and nothing else. The `Vibe` C prefix stays.
- **One repo of many pieces, grouped by what they are about.** An app picks pieces, not the whole repo.
- **Apps compile the pieces' sources in their own targets**, through templates in a shared XcodeGen spec. No static libraries and no Swift package for the apps, for now.
- **Third-party code is a piece of its own**, one per library.
- **Vibe's waveform engine (PR #294) merges in Vibe before the waveform data moves.**

Still open: the license. Apache 2.0, like Vibe, lets code move between the repos freely.

### What changed from the 2026-10-09 plan

| Was | Now | Why |
| --- | --- | --- |
| PlaybackKit, prefix `PBK` | cm_libs, prefix `CMM` for new code | The repo is a toolbox, not only playback. |
| Four products cut along Vibe's directories | About thirty pieces, each with one job | Each piece should be usable without its neighbors. |
| Rename every class and C symbol on the move | No rename | A rename touches 441 names in 678 files of Vibe and 88 of #294's 111 files. Folded into the move, it would turn every moved file into a content change and break the performance proof. |
| Static framework targets in the shared spec | Templates the app compiles in | Same run time, and the app's test targets can still build the code with their own flags (below). |
| A prefix header per product | Explicit imports of one macros header | A target has one prefix header, so a piece cannot bring its own. |
| Vendored code inside the engine product | Each library a piece of its own | An app can take TagLib or dr_flac without the engine. |

## How the pieces are cut

1. **One job per piece, named for the job.** Ask whether someone would want it without its neighbors.
2. **Split when it saves a consumer a dependency. Merge when the parts only work together, or when splitting saves nothing.** Tempo and key detection are one piece, because they share their framing and depend on nothing. Tags and Metadata are two pieces, because a tag reader should not drag in the cache, the scan, and the decoders.
3. **Pieces meet through values and blocks, never through another piece's model class.** Vibe's playlist row, `AudioTrack`, is imported by nine of today's shared areas. It splits: the toolbox gets a small value naming a file and an optional frame window of it, and the row stays in Vibe.
4. **Optional work is injected, never imported.** Analyzers ride the waveform decode as observers. Folder art takes its switch and its access check as providers. The file loader takes the opener of the handle it serves.
5. **Portable is a property of a piece, not a group.** A portable piece (◆ below) is C or C++, has a `CMakeLists.txt` beside its template, and depends only on portable pieces. It may call Accelerate behind a fallback. A Darwin piece may wrap a portable one.
6. **Policy stays in apps.** That means which files count as playable, what plays next under which settings, every display string, and every setting.
7. **Fakes live with what they fake.** The manual render pump lives in Player, the fake cloud in FileLoading, and the fake HTTP host in HTTP.

## The pieces

◆ marks a portable piece. The arrow names what a piece depends on, besides `core/Common`, which every piece may use.

```
cm_libs/
├── AGENTS.md  README.md  LICENSE  docs/plan.md
├── cm_libs.yml          the shared spec: one targetTemplate per piece, plus stack templates
├── project.yml          this repo's own project: one headermap-off test bundle per piece
├── Makefile  .github/workflows/ci.yml  scripts/checks/check-pieces.sh
│
├── core/
│   ├── Common           log, realtime-check and signpost macros; stall sampler, work tally,
│   │                    load timing; path spelling and comparison, file identity and emptiness;
│   │                    fixed-slot work lanes; a weak proxy; a display-paced update timer;
│   │                    build provenance and the script that writes it
│   └── Graphics         image and color aliases, bounded image decode, hex, blend and OKLCH
│                        colors, dominant color, blur, dark-mode helpers
│
├── files/
│   ├── FileLoading      from a path to readable bytes: placeholder checks, downloads, reading
│   │                    a file while it downloads, read-ahead on network mounts, progress, the
│   │                    transfer registry, and one shared download and open per file
│   ├── RemoteFiles      a local placeholder for a file on a server, fetched by range        → FileLoading, HTTP
│   ├── HTTP             ranged HTTP transfers
│   ├── ShareLinks ◆     Dropbox, Google Drive and iCloud share links turned into direct URLs → HTTP
│   ├── SandboxAccess    security-scoped bookmarks and folder grants, with the grant panel
│   └── DiskCache        a bounded disk cache, and a cache key from a file's attributes      → PINCache
│
├── audio/
│   ├── DSP ◆            varispeed, resampler, fades, FX math, FFT band math, analysis framing → r8brain
│   ├── Analysis ◆       tempo and musical key from PCM                                       → DSP
│   ├── Decode           open a file or a frame window of it, and read PCM                     → FileLoading, dr_*, ogg, vorbis
│   ├── Meter            live band levels from inside a render, only while someone looks      → DSP
│   ├── FX               the DJ chain over Apple's audio units                                → DSP
│   ├── OutputDevices    where the sound goes: Mac/ output devices, rates, hog mode and
│   │                    bit-perfect formats; iOS/ the audio session and route recovery
│   └── Player           the transport, the voice bus, the master bus, the output unit,
│                        prefetch, gapless, crossfades, and open deadlines                     → Decode, DSP, Meter, FX,
│                                                                                               OutputDevices, FileLoading
├── media/
│   ├── Tags ◆           TagLib fields and embedded art bytes                                 → taglib
│   ├── Metadata         the tag record, the CoreAudio fallback, the cache, the background
│   │                    scan, embedded art and thumbnails, and covers beside the files       → Tags, Decode, DiskCache,
│   │                                                                                           FileLoading, Graphics
│   ├── Playlists ◆      CUE sheets, also embedded in FLAC, and M3U, read and written as records
│   ├── FolderScan       walk folders and links into files and CUE rows, and search file names → Playlists, FileLoading
│   └── PlayQueue        play order, shuffle, repeat, and what follows a track's end
│
├── waveform/
│   ├── Waveform ◆       the summary, its pyramid, deep zoom, the raster, and the archive
│   ├── WaveformStyles   each style's look: its columns, levels, and colors                   → Waveform
│   ├── WaveformLoading  a file decoded into a summary, with observers on the same pass, cached
│   │                    and shared                                                           → Waveform, Decode, DiskCache
│   └── WaveformView     the layer host, the morph engine, the macOS view, the iOS scrubber   → WaveformStyles, Controls
│
├── ui/
│   └── Controls         loading bar and pill, equalizer bars, and on the mac Mac/ symbol
│                        buttons, drawn controls, detent slider, pitch fader, image views     → Graphics
│
├── system/
│   ├── NowPlaying       Now Playing info and remote commands, fed a snapshot                 → Graphics
│   ├── AppOpening       on the mac, one open request from the batches Launch Services
│   │                    splits it into, delivered in order
│   └── Updates          Sparkle for a direct-download build, compiled out of an App Store build → Sparkle
│
├── dev/
│   ├── DebugChannel     drive and inspect a running debug build from a script
│   └── iOSDriver        taps, drags and pinches in the iOS simulator, for scripts
│
├── third_party/         taglib/  dr_mp3/  dr_flac/  dr_wav/  r8brain/  PINCache/  PINOperation/
│                        ogg/  vorbis/  Sparkle/
│
└── Tests/               one directory per piece, mirroring the tree
```

**A stack is a template that lists other templates.** `cm_libs.yml` offers a few, so an app's `project.yml` stays short. Examples are a Playback stack (Player and everything it needs) and a Library stack (Metadata, Playlists, FolderScan). An app may list pieces one by one instead.

**What a few consumers would take:**

| Consumer | Pieces |
| --- | --- |
| A waveform VST | Waveform, WaveformStyles, DSP, Analysis, all portable once WaveformStyles is |
| A tag editor | Tags, Metadata |
| An app that reads users' iCloud and network files | FileLoading, and nothing from audio |
| A DJ tool reading CUE sheets | Playlists |
| Vibe and the other app | Nearly everything, through the stacks |

### What some pieces mean, in plain words

- **FileLoading** turns a path into bytes you can read. The file may be local, an iCloud placeholder that must download first, a file still downloading, or a file on a slow network share. Every request for one file shares one download and one open, so a playlist scan and the play button never download the same file twice. The file the user is waiting on goes first, and background reads step aside.
- **Player** is everything between a decoded file and the speaker. The voice bus, the master bus and the output unit only work together, so they are one piece.
- **OutputDevices** is one job with a half per platform: on the mac, which device and format; on iOS, the audio session and its routes.
- **WaveformLoading** decodes a file into a waveform and caches it. Decoding without caching has no second user, so the two are one piece.

### Groupings forced by today's code

- **`Player` holds the master bus.** The master bus composes the varispeed, the FX, and the meter, so it lives with the piece that composes them.
- **The waveform loader and cache sit outside `Waveform`.** They open files through Decode and file through DiskCache. Only the data type and its archive are in `Waveform`, which keeps the drawing free of the engine.
- **Artwork is inside `Metadata`.** The art is found during the tag parse and cached beside the tags. Nothing uses one without the other.

**Artwork is the one place the engine hands out UI types.** `Metadata` returns `NSImage` or `UIImage`. AppKit and UIKit are always present, so that is tolerable. A UI-free version would return a `CGImage`. Leave it until someone asks.

## How an app uses a piece

**A git submodule, compiled in tree.**

- The app's repo has this repo as a submodule at `cm_libs/`, pinned to a commit. The app's `make project` runs `git submodule update --init --recursive` before it generates, so a fresh clone or a worktree works.
- The app's `project.yml` has `include: [cm_libs/cm_libs.yml]`. Each app target lists the pieces or stacks it wants under `templates:`. It sets `templateAttributes: {excludedPlatform: iOS}` on macOS, or `Mac` on iOS.
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

Vibe has no link-time optimization today, so files inline across each other only through headers. A library boundary would not change that. The difference is entirely in the flags and the test builds. The number of pieces does not matter either.

**The proof, for the pilot and every move**, run in Vibe with its `vibe-perf` skill:

1. `perf.py compare main main` records the no-op band of retired instructions.
2. `perf.py compare <before the move> <after the move>` keeps every benchmark inside that band.
3. `make test-audio` wall time before and after stays within noise. This catches a lost Debug optimization, which Release benchmarks would not show.

### When to switch shapes

- **To static library targets**, when the test targets no longer compile production sources and two consumer targets in one project make the double compile cost real time. The template becomes `type: library.static`, apps change `templates:` to `dependencies:`, and every app and test target gets `OTHER_LDFLAGS: -ObjC`. **TRAP: without `-ObjC`, a static library silently drops category-only objects**, such as the cache-key category and every debug seam.
- **To a Swift package**, only for outside users. Measure the decoders without `-O3` first. Add whole-file `#if TARGET_OS_OSX` guards to the platform halves, since a package compiles every file on every platform. Keep C++ out of public headers. Tag `0.x` until the API settles. `waveform/Waveform` keeps its own `Package.swift` throughout, since it is pure C++ and already standalone.

## The boundary check

This repo's `project.yml` has one test bundle per piece. Each sets `USE_HEADERMAP: NO`, `ALWAYS_SEARCH_USER_PATHS: NO`, and `GCC_PREFIX_HEADER: ""`, with header search paths for only its piece and the pieces it declares. An import outside them fails to compile here. Each piece also builds for iOS, so an AppKit leak fails here too. Each portable piece also builds alone with CMake.

`scripts/checks/check-pieces.sh` checks the rest:

- every piece has a template, a test bundle, and an `AGENTS.md`
- every template's paths stay inside its piece
- every import between pieces is in the dependency list above
- a portable piece depends only on portable pieces
- the platform rule: only `Mac/` and `iOS/` are platform-specific
- no `#if DEBUG` in a shipping header
- the classes with no prefix, listed
- the other app's name appears nowhere

CI runs `make check-pieces`, `make test`, `make build-ios`, and `make analyze CONFIG=Release`. GitHub Actions is free for a public repo, macOS runners included.

## The work, in order

**Decoupling happens in Vibe first**, under Vibe's gates, with no piece moved. Then each move is mechanical. Each move is a pull request here, plus one in Vibe that bumps the submodule and deletes what moved.

### Phase 0: setup and experiments

Choose the license. Then answer eight questions with throwaway specs and branches, and record each answer here:

1. Paths in an included spec resolve relative to the included file, so the submodule can sit anywhere.
2. A template can list other templates, which the stacks need, and `${excludedPlatform}` substitutes from `templateAttributes`.
3. A template's header search paths join the target's, rather than replace them.
4. A test bundle with the headermap off fails on a stray import of an app header.
5. `xcodegen dump` keeps an included spec's templates. Vibe's `perf.py` builds its benchmark tool from that dump.
6. The pilot passes the performance proof.
7. A package dependency by path accepts `unsafeFlags`, and one by URL refuses them.
8. `actions/checkout` with `submodules: recursive` reaches every CI job in Vibe.

### Phase 1: the cuts in Vibe

Small pull requests in Vibe remove every reach from the moving code into Vibe's own. When they are done, this returns nothing in Vibe:

```
grep -rln 'AppSettings\|AppTheme\|VibeStrings.h\|FolderAccessManager\|PlaylistFile.h\|DebugWireFormat' \
  Vibe/Audio Vibe/Loading Vibe/WaveformUI Vibe/Controls | grep -v Loading/iOS/Dropbox
```

**Settings, strings, and app reaches:**

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

**The seams between pieces**, found from the import graph of Vibe's shared code:

13. **`AudioTrack` splits.** A small value naming a file and an optional frame window moves to Decode, with its source and cache keys. The player, both caches, the CUE reader, the folder walk, Now Playing, and the play queue take that value or a URL. The row keeps the tags, the analyzed tempo and key, the display names, and the rule that tags beat analysis, and it stays in Vibe. This is the largest cut and comes first, since most of the others build on it.
14. **`AudioFileOpenRules.h` splits.** It holds the open's delivery states, path spelling, and the network mount's read-ahead rules, and four areas import it. Each part goes to the piece that owns it.
15. **The file loader stops naming the audio file handle.** Its opener is already a block. The handle it serves becomes a small protocol for interrupting reads and holding a stream. Its call into `AudioTrack` to forget memoized cache keys becomes a handler block.
16. **Tags returns art bytes and takes a byte-range reader.** Today the TagLib wrapper returns an artwork extractor and reads remote ranges through the materializer.
17. **The waveform decode takes observers of each mono block.** Today it builds the tempo and key analyzers itself. The app attaches them.
18. **The CUE and M3U readers return records**, and Vibe mints its rows from them.
19. **Now Playing takes a snapshot value**, and the play queue holds values, instead of `AudioTrack`.
20. **The link store splits.** The share-link rules and the link client move. The store, which names tracks and holds strings, stays in Vibe.
21. **The shell pieces take what they read.** The folder-grant manager's panel text, the pitch fader's labels and font, and the drawn controls' number formatting are pushed in by the app. The Sparkle wiring takes its beta channel as a value.

### Phase 2: the pilot, DSP with the varispeed

The smallest real piece goes first. `AudioVarispeed` is Vibe's own windowed-sinc converter for the pitch fader. Its distortion sits near −150 dB, against −83 to −135 dB for Apple's Varispeed unit. It is flat to 20 kHz and a bit-perfect pass-through at zero pitch. It costs about 0.2% of one core at 48 kHz.

It is already a library in all but location. Its API is plain C. It imports only system headers and the realtime macros. It has one caller in Vibe. Its tests and its benchmark stand alone.

The pilot proves every step the later moves will take: `git filter-repo`, the template, the CMake file, this repo's CI, the submodule in Vibe, `make project`, worktrees, Vibe's CI checkout, and `perf.py`. **Done when** Vibe's checks pass with the varispeed coming from here, the `pitch` benchmark shows no change, and this repo's CI runs `AudioVarispeedTests`.

### Phase 3: third_party

TagLib, dr_mp3, dr_flac, dr_wav, r8brain, PINCache, PINOperation, ogg, vorbis, and Sparkle move, each with its flags and its notes on Vibe's fixes. They depend on nothing, and Vibe's binary is unchanged after. The third-party notices split. This repo lists its pieces' licenses, and Vibe points here.

### Phase 4: core, and the portable pieces

`core/Common`, `core/Graphics`, then the rest of DSP, Analysis, Tags, Playlists, and ShareLinks. **Done when** `perf.py --analyze` proves Vibe's tempo and key results exact.

### Phase 5: files

FileLoading, HTTP, RemoteFiles, DiskCache, and SandboxAccess. Vibe's Dropbox mirror subclasses RemoteFiles and stays in Vibe.

### Phase 6: waveform data

This waits for #294 to merge in Vibe. Then `Packages/WaveformCore` moves whole to `waveform/Waveform`, with its `Package.swift` and tests, and `AudioWaveform.h` with its codable form moves beside it.

### Phase 7: audio and media

Decode, Meter, FX, OutputDevices, and Player, then Metadata, FolderScan, and PlayQueue. The engine's tests move with them, including the render-pump suite and its fixtures. **Done when** Vibe's checks pass against this repo, this repo's CI passes on its own, and the performance proof holds.

### Phase 8: waveform drawing and controls

WaveformLoading, WaveformStyles, WaveformView, and Controls. **Done when** Vibe's waveform benchmark pictures are byte-identical and screenshots on both platforms match. **The other app can start after this phase.**

### Phase 9: system and dev

NowPlaying, AppOpening, Updates, DebugChannel, and iOSDriver.

### Phase 10: docs

Each directory's `AGENTS.md` moves with it. The engine's own guarantees move to this repo's `AGENTS.md`: the handle-open ceiling, the meter's place in the render, and the waveform theme's precedence. Vibe keeps the guarantees that span app and engine, each naming its side here. Vibe's audio-quality measurements and its component performance charts move too.

### Later

- **WaveformStyles becomes portable C++.** Each style becomes a function from columns to painted pixels, and WaveformView keeps only the layer hosting. That makes a waveform VST possible without AppKit. It is a rewrite, not a move, so it is its own phase, proven by byte-identical benchmark pictures.
- **Windows.** The portable pieces get fallbacks for vDSP and simd. Apple's LZFSE is open source under BSD, so it can be vendored and waveform archives stay readable everywhere. The Apple path keeps Accelerate.
- **tools/.** Vibe's release, notarization, App Store upload, Homebrew, and layout-check scripts, and its stress and performance harnesses, are general too. They move once each takes its app's names and paths from a config file.
- **The HTTP road.** Streaming over HTTP into the engine is planned in Vibe ([share links](https://github.com/cmicali/vibe/blob/main/docs/future/share-links.md) Phase 2, and [streaming from any source](https://github.com/cmicali/vibe/blob/main/docs/future/streaming-any-source.md) Phase 1). Once the engine lives here, that work lands here.

## New types

The cuts add four small types. Each replaces a dependency on an app class:

- the value naming a file and its frame window
- the protocol of a handle the file loader serves
- the observer block of the waveform decode
- the record of a playlist entry

## TRAPs

- **A checkout without the submodule compiles nothing from here and fails late.** Every consumer's `make project`, benchmark worktrees, and CI checkouts must update it.
- **YAML anchors do not cross `include:` files.** A consumer's own flag anchors cannot reach a template's entries. Every flag lives in its template.
- **The headermap hides a crossed boundary.** In any project holding two pieces, an import by basename resolves across them. Only this repo's headermap-off bundles make the compiler refuse.
- **`xcodegen dump` leaves templates unresolved.** A tool that rebuilds a consumer's target from the dump must copy `templates` and `templateAttributes`. Otherwise it builds without the pieces.
- **Vibe's analyzer gate drops findings by the substring `/ThirdParty/`** (`scripts/build/analyze.sh`). Vendored code here sits under `third_party/`, so the gate must also drop `/third_party/` before Phase 3 lands, or it fails on TagLib's findings.

## Costs

- **About thirty pieces.** Each has a template, a test bundle, and a doc. The stacks keep a consumer's list short.
- **Most engine changes also change app code.** Since 2026-04-01, 232 commits changed Vibe's engine, and 167 of them (72%) also changed Vibe's app code. After a move, each is a commit here, then a submodule bump. One editing session covers both through the submodule.
- **Many changes span pieces.** 90 of those commits (39%) changed more than one of the old products. That is why this is one repo and not one per piece.
- **Agent docs split across two repos.** An agent in an app must read this repo's `AGENTS.md` before changing a piece. Each app's root doc says so.
- **Vibe's two test source lists stay until each piece's tests move here.** Vibe's tests build production sources with their own flags, which is the reason compiling in was chosen.
