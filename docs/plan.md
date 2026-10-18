# cm_libs: the plan

**Status: planned 2026-10-17 and revised after review. Phase 0 done on 2026-10-18. Phase 1, the pilot, in review: this repo's first pieces and Vibe's pull requests #314 and #315.** This replaces the plan of 2026-10-09, written when the repo was called PlaybackKit.

cm_libs is a toolbox of small libraries for macOS and iOS apps. An app takes only the pieces it wants. The first pieces come from [Vibe](https://github.com/cmicali/vibe): its audio engine, file loading, tags, waveform data and drawing, and the third-party code it vendors. Anything else in Vibe that another app could use is a candidate. **A candidate moves when a second app needs it**, so the toolbox grows from real reuse.

Its users are Vibe and another app. Both add it as a git submodule.

## Decided

- **The name is cm_libs, and the prefix for new code is `CMM`.** `CM` alone is CoreMedia's.
- **Code moved from Vibe keeps its names.** A move is `git mv` and nothing else. The `Vibe` C prefix stays.
- **One repo of many pieces, grouped by what they are about.** An app picks pieces, not the whole repo.
- **Apps compile the pieces' sources in their own targets**, through templates in a shared XcodeGen spec. No static libraries and no Swift package for the apps, for now.
- **Third-party code is a piece of its own**, one per library.
- **Extraction first, everything else after.** A move changes no API, no language, and no platform. Portable C or C++ rewrites, new tag fields, and other redesigns are separate work with their own scope and measurements.
- **The playback and waveform path moves first.** The other app builds its first slice on it. Every other piece follows demonstrated reuse.
- **Vibe's waveform engine (PR #294) merged in Vibe before any move**, so the waveform data moves once.

Still open: the license. Apache 2.0, like Vibe, lets code move between the repos freely.

### What changed from the 2026-10-09 plan

| Was | Now | Why |
| --- | --- | --- |
| PlaybackKit, prefix `PBK` | cm_libs, prefix `CMM` for new code | The repo is a toolbox, not only playback. |
| Four products cut along Vibe's directories | Pieces with one job each | Each piece should be usable without its neighbors. |
| Rename every class and C symbol on the move | No rename | A rename touches 441 names in 678 files of Vibe and 88 of #294's 111 files. Folded into the move, it would turn every moved file into a content change and break the performance proof. |
| Static framework targets in the shared spec | Templates the app compiles in | Same run time, and the app's test targets can still build the code with their own flags (below). |
| A prefix header per product | Explicit imports of one macros header | A target has one prefix header, so a piece cannot bring its own. |
| Vendored code inside the engine product | Each library a piece of its own | An app can take TagLib or dr_flac without the engine. |

## How the pieces are cut

1. **One job per piece, named for the job.** Ask whether someone would want it without its neighbors.
2. **Split when it saves a consumer a dependency. Merge when the parts only work together, or when splitting saves nothing.** Tempo and key detection are one piece, because they share their framing and depend on nothing. Tags and Metadata are two pieces, because a tag reader should not drag in the cache, the scan, and the decoders.
3. **A piece's code lives with the piece that reaches into it.** The morph engine is used by the renderers, so it sits with the styles. The device categories on `AudioPlayer` read the player's private state, so they sit in `Player/Mac` and `Player/iOS`. The device and session classes they call do not, so those are their own piece.
4. **Pieces hold the caller's objects, never another piece's model class.** A playable item is any object that adopts a small protocol giving its file, its frame window, its source key, and its disk key. Vibe's `AudioTrack` adopts it. The player, the caches, and the queue keep the caller's object and hand the same one back. A piece that writes results into an item declares a protocol of its own for that, as Metadata does (seam 22). Four identities stay separate:
   - **Source identity** is the source key: the file's path and its window. It names the same stretch of audio, so shared work, claims, and late deliveries match on it. It does not change when the file's contents do.
   - **Version identity** is the disk key: DiskCache's `cacheKey` of the file's size, modification time, and resolved path, with the window appended for a waveform. It names one version of the file, so persisted entries match on it. An item may memoize it. FileLoading's handler tells the app to forget the memo when a download installs a new version.
   - **Entry identity** is the caller's object. Two entries for the same file are two entries.
   - **Submission identity** is the player's own counter for each play. It decides which settlement is current.
5. **Optional work is injected, never imported.** Analyzers ride the waveform decode as observers. Folder art takes its switch and its access check as providers. The file loader takes the opener of the handle it serves.
6. **Every piece is Objective-C or Objective-C++ on Apple's frameworks when it moves.** `waveform/Waveform` is C++, but it calls Accelerate and Compression too. Making any piece portable is a later rewrite with its own measurements (see Later).
7. **Policy stays in apps.** That means which files count as playable, what plays next under which settings, every display string, and every setting.
8. **Fakes live with what they fake.** The manual render pump lives in Player, the fake cloud in FileLoading, and the fake HTTP host in ShareLinks, whose services it imitates.

## The pieces

**●** marks the playback and waveform path, which moves first. The other pieces are candidates that move when a second app needs them. What each piece depends on is listed once, in the dependency map below.

```
cm_libs/
├── AGENTS.md  README.md  LICENSE  docs/plan.md
├── cm_libs.yml          the shared spec: one targetTemplate per piece, plus stack templates
├── project.yml          this repo's own project: one headermap-off test bundle per piece
├── Makefile  .github/workflows/ci.yml  scripts/checks/check-pieces.py
├── scripts/plan/derive-deps.py   re-derives the dependency map from Vibe's imports
│
├── core/
│   ├── Common ●         log, realtime-check and signpost macros; stall sampler, work tally,
│   │                    load timing; path spelling and comparison, file identity and emptiness;
│   │                    the disk key from a file's attributes; fixed-slot work lanes; a weak
│   │                    proxy; a display-paced update timer; build provenance and its script
│   └── Graphics ●       image and color aliases, bounded image decode, hex, blend and OKLCH
│                        colors, dominant color, blur, dark-mode helpers
│
├── files/
│   ├── FileLoading ●    from a path to readable bytes: placeholder checks, downloads, reading
│   │                    a file while it downloads, read-ahead on network mounts, progress, the
│   │                    transfer registry, and one shared download and open per file
│   ├── DiskCache ●      a bounded disk cache over PINCache
│   ├── HTTP             ranged HTTP transfers
│   ├── RemoteFiles      a local placeholder for a file on a server, fetched by range
│   ├── ShareLinks       Dropbox, Google Drive and iCloud share links turned into direct URLs,
│   │                    and the fake HTTP host that stands in for those services in tests
│   └── SandboxAccess    security-scoped bookmarks and folder grants, with the grant panel
│
├── audio/
│   ├── AudioTypes ●     the words every audio piece shares: file format identifiers, the
│   │                    extensions the decoders open, the CUE window math, the musical key
│   ├── DSP ●            varispeed, resampler, fades, FX math, FFT band math, analysis framing
│   ├── Analysis ●       tempo and musical key from PCM
│   ├── Decode ●         open a file or a frame window of it, and read PCM; the playable-item
│   │                    protocol
│   ├── Meter ●          live band levels from inside a render, only while someone looks
│   ├── FX ●             the DJ chain over Apple's audio units
│   ├── OutputDevices ●  Mac/ device discovery, rates, hog mode, format rules, event log;
│   │                    iOS/ the audio session and its route rules
│   └── Player ●         the transport, the voice bus, the master bus, the output unit,
│                        prefetch, gapless, crossfades, open deadlines; Mac/ binding to a
│                        device and bit-perfect output; iOS/ route recovery
├── media/
│   ├── Tags ●           TagLib fields and embedded art bytes
│   ├── Metadata ●       the tag record, the CoreAudio fallback, the cache, the background
│   │                    scan, embedded art and thumbnails, and covers beside the files
│   ├── PlayQueue ●      play order, shuffle, repeat, and what follows a track's end, over
│   │                    opaque entries of the app's own
│   ├── Playlists        CUE sheets, also embedded in FLAC, and M3U, read and written as records
│   └── FolderScan       walk folders and links into files and CUE rows, and search file names
│
├── waveform/
│   ├── Waveform ●       WaveformCore/: the summary, pyramid, deep zoom, raster, and archive,
│   │                    C++ with its own Package.swift; beside it, in Objective-C++, the
│   │                    AudioWaveform name, the mono mix, and CodableAudioWaveform
│   ├── WaveformStyles ● each style's look: its columns, levels, colors, zoom math, and the
│   │                    morph engine that eases between them
│   ├── WaveformLoading ● a file decoded into a summary, with observers on the same pass,
│   │                    cached and shared
│   └── WaveformView ●   the layer host, the macOS view, the iOS scrubber
│
├── ui/
│   └── Controls ●       loading bar and pill, equalizer bars; later, the mac symbol buttons,
│                        drawn controls, detent slider, pitch fader, and image views
│
├── system/
│   ├── NowPlaying       Now Playing info and remote commands, fed a snapshot
│   ├── AppOpening       on the mac, one open request from the batches Launch Services
│   │                    splits it into, delivered in order
│   └── Updates          Sparkle for a direct-download build, compiled out of an App Store build
│
├── dev/
│   ├── DebugChannel     drive and inspect a running debug build from a script
│   └── iOSDriver        taps, drags and pinches in the iOS simulator, for scripts
│
├── third_party/         taglib/ ●  dr_mp3/ ●  dr_flac/ ●  dr_wav/ ●  r8brain/ ●  PINCache/ ●  PINOperation/ ●
│                        ogg/ ●  vorbis/ ●  Sparkle/
│
└── Tests/               one directory per piece, mirroring the tree
```

### The dependency map

Each piece may import only these, besides `core/Common`, which every piece may use. The map is derived from every quoted and angled include in Vibe's tree at `6cb717e0`, with each file assigned to the piece it moves into (`scripts/plan/derive-deps.py`). The script resolves an include as the compiler does: a quoted include in its own directory first, then the app's header search paths from `project.yml`, in order, then a unique basename. **A collision those rules cannot settle fails the script** until an explicit mapping names the header the build uses, so no edge comes from the filesystem's order. TagLib's `<vorbisfile.h>`, for one, is TagLib's own Ogg Vorbis header, which the `taglib/ogg/vorbis` search path finds, not libvorbis's. The table is the map after the planned cuts. **The template for a piece is written from this map, and `check-pieces.sh` fails on any edge missing from it.** Rerun the script after each cut, and update the map in the same change.

| Piece | Depends on |
| --- | --- |
| core/Common | nothing |
| core/Graphics | nothing |
| files/FileLoading | audio/AudioTypes |
| files/DiskCache | third_party/PINCache |
| files/HTTP | nothing |
| files/RemoteFiles | files/FileLoading, files/HTTP |
| files/ShareLinks | files/HTTP |
| files/SandboxAccess | nothing |
| audio/AudioTypes | nothing |
| audio/DSP | third_party/r8brain |
| audio/Analysis | audio/AudioTypes, audio/DSP |
| audio/Decode | files/FileLoading, third_party/dr_mp3, third_party/dr_flac, third_party/dr_wav, third_party/vorbis |
| audio/Meter | audio/DSP |
| audio/FX | audio/DSP |
| audio/OutputDevices | nothing |
| audio/Player | audio/AudioTypes, audio/DSP, audio/Decode, audio/FX, audio/Meter, audio/OutputDevices, files/FileLoading |
| media/Tags | audio/AudioTypes, third_party/taglib |
| media/Metadata | audio/AudioTypes, audio/Decode, media/Tags, files/DiskCache, files/FileLoading, core/Graphics, third_party/taglib, third_party/PINCache |
| media/PlayQueue | nothing: its entries are opaque objects (seam 19) |
| media/Playlists | audio/AudioTypes |
| media/FolderScan | audio/AudioTypes, files/FileLoading, media/Playlists |
| waveform/Waveform | nothing but Accelerate and Compression |
| waveform/WaveformStyles | waveform/Waveform, core/Graphics |
| waveform/WaveformLoading | waveform/Waveform, audio/AudioTypes, audio/Decode, files/DiskCache, files/FileLoading, third_party/PINCache |
| waveform/WaveformView | waveform/WaveformStyles, waveform/Waveform, ui/Controls, core/Graphics |
| ui/Controls | core/Graphics |
| system/NowPlaying | core/Graphics, media/PlayQueue |
| system/AppOpening | nothing |
| system/Updates | third_party/Sparkle |
| dev/DebugChannel | nothing |
| dev/iOSDriver | nothing |
| third_party/PINCache | third_party/PINOperation |
| third_party/vorbis | third_party/ogg |
| every other third_party piece | nothing |

**Edges in today's tree that the cuts remove**, so none of them is declared:

| Edge today | Removed by |
| --- | --- |
| every piece → Vibe's app code | the settings, strings, and reach cuts |
| files/FileLoading → audio/Decode | seam 15, the handle protocol |
| files/FileLoading → dev/DebugChannel | cut 1 |
| files/RemoteFiles → media/Playlists | cut 2 |
| files/ShareLinks → Vibe's `LinkStore` | seam 20: `LinkClient` stops importing the store |
| media/Metadata → files/SandboxAccess | cut 4, folder art's providers |
| media/Tags → media/Metadata, media/Tags → files/FileLoading | seam 16, art bytes and a byte-range reader |
| media/FolderScan → media/Metadata | seam 23, the walk's file handler |
| waveform/WaveformLoading → audio/Analysis | seam 17, the decode's observers |

**Planned edges.** The script reads today's imports, so it cannot see an edge a new type will add. Each new type's owner, and what it implies:

| New type | Owned by | Used by | Edge it adds |
| --- | --- | --- | --- |
| the playable-item protocol | audio/Decode | audio/Player, media/Metadata, waveform/WaveformLoading; adopted by the app's entries | none: each user already depends on Decode |
| Metadata's holder protocol | media/Metadata | adopted by the app's entries | none |
| the handle protocol of FileLoading | files/FileLoading | adopted by audio/Decode's file handle | none: Decode already depends on FileLoading |
| the waveform decode's observer block | waveform/WaveformLoading | the app, which attaches audio/Analysis | none: the app joins them |
| the playlist record, later | media/Playlists | media/FolderScan, the app | none: FolderScan already depends on Playlists |
| the Now Playing snapshot, later | system/NowPlaying | the app | none |

**PlayQueue stays free of all of them.** Its entries are opaque objects, never the playable-item protocol. Declaring that protocol would pull Decode, FileLoading, and the decoders into a play-order list.

**Four placements keep the map acyclic and small.** `WaveformZoomMath.h` sits in WaveformStyles, because three renderers import it. `NSURL+Hash`, the disk key, sits in `core/Common`, so FileLoading and ShareLinks need no cache. `AudioTypes` holds the format identifiers, the playable extensions, the CUE window math, and the musical key, so Tags, Playlists, FolderScan, and Metadata need neither Decode nor Analysis for them. The fake HTTP host sits in ShareLinks, because it imitates those services' hosts.

**A stack is a template that lists other templates.** `cm_libs.yml` offers a few, so an app's `project.yml` stays short. Examples are a Playback stack (Player and everything it needs) and a Waveform stack (the four waveform pieces).

**What a few consumers would take:**

| Consumer | Pieces |
| --- | --- |
| A music player | the Playback and Waveform stacks, Metadata, PlayQueue |
| A tag editor | Tags, Metadata |
| An app that reads users' iCloud and network files | FileLoading, and nothing from audio |
| A DJ tool reading CUE sheets | Playlists |
| A waveform plugin | Waveform today; WaveformStyles once its later C++ rewrite lands |

### What some pieces mean, in plain words

- **FileLoading** turns a path into bytes you can read. The file may be local, an iCloud placeholder that must download first, a file still downloading, or a file on a slow network share. Every request for one file shares one download and one open, so a playlist scan and the play button never download the same file twice. The file the user is waiting on goes first, and background reads step aside.
- **Player** is everything between a decoded file and the speaker. The voice bus, the master bus, the output unit, and the categories that bind them to a device only work together, so they are one piece.
- **OutputDevices** finds the outputs and describes them: on the mac, devices, rates, and formats; on iOS, the audio session and its routes. It knows nothing about the player.
- **PlayQueue** keeps an order over the caller's own entries. It never copies or compares them by content.
- **WaveformLoading** decodes a file into a waveform and caches it. Decoding without caching has no second user, so the two are one piece.

### Analyzing many files

Vibe decodes a waveform only for the track on screen. An app that analyzes a whole library needs more, and it is new behavior in WaveformLoading, built after the move as its own change:

- **A scan request kind**, apart from the track on screen. The app admits one at a time.
- **Admission stops while an open the user waits on is active**, read from FileLoading's foreground state. It resumes when the open settles.
- **An active scan decode is cancelled outright, not detached.** Today a superseded load is detached and finishes its decode, which keeps reading the file. A scan decode that yields must stop reading, and its partial summary is dropped, never filed.
- **The playing track's waveform is never cancelled or delayed** by any of this.
- **Tested on a throttled source**, with Vibe's fake cloud and read-ahead stubs, so a slow file proves the decode yields within one block.
- **Tags have a cache-only path.** `loadCachedMetadata:` reads only the cache and never the file. It is the path for a File Provider placeholder, whose bytes cannot be read without downloading it. A remote placeholder can read its tags by range instead.

### Groupings forced by today's code

- **`Player` holds the master bus and the device categories.** The master bus composes the varispeed, the FX, and the meter. The categories read the player's private state.
- **`WaveformStyles` holds the morph engine.** The renderers drive it directly.
- **`waveform/Waveform` keeps the C++ package whole, and its Darwin part beside it.** The `WaveformCore/` directory, its `Package.swift`, and its tests move unchanged. `AudioWaveform.h` and `.mm`, with `CodableAudioWaveform`, sit beside it in the same piece, outside the package directory. The wrapper is more than the cache's entry: both views hold it, the style registry draws from it, and the widget publisher bakes it. With it in WaveformLoading, drawing would depend on Decode and FileLoading.
- **WaveformLoading's decodes do not go through FileLoading's claims.** The loader opens its own handle. So FileLoading's foreground rule, which yields background downloads to the open the user waits on, never stops a waveform decode of a local file. An app that analyzes many files schedules that itself (below).
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
| A Swift package, linked | slower in Debug | Xcode builds a package with its own settings, unoptimized in Debug. `-O3` for the decoders exists only as `unsafeFlags`, which a package pinned by version may not use. There is no prefix header and no per-file flag. |

Vibe has no link-time optimization today, so files inline across each other only through headers. A library boundary would not change that. The difference is entirely in the flags and the test builds. The number of pieces does not matter either.

**The proof, for the pilot and every move**, run in Vibe with its `vibe-perf` skill:

1. `perf.py compare main main` records the no-op band of retired instructions.
2. `perf.py compare <before the move> <after the move>` keeps every benchmark inside that band.
3. `make test-audio` wall time before and after stays within noise. This catches a lost Debug optimization, which Release benchmarks would not show.

Vibe's audio, render, and signal-quality suites keep running against the moved code at every step. They are the gate that the extraction changed nothing.

### When to switch shapes

- **To static library targets**, when the test targets no longer compile production sources and two consumer targets in one project make the double compile cost real time. The template becomes `type: library.static`, apps change `templates:` to `dependencies:`, and every app and test target gets `OTHER_LDFLAGS: -ObjC`. **TRAP: without `-ObjC`, a static library silently drops category-only objects**, such as the cache-key category and every debug seam.
- **To a Swift package**, only for outside users. Measure the decoders without `-O3` first. Add whole-file `#if TARGET_OS_OSX` guards to the platform halves, since a package compiles every file on every platform. Keep C++ out of public headers. Tag `0.x` until the API settles. `WaveformCore` keeps its own `Package.swift` throughout.

## The boundary check

This repo's `project.yml` has one test bundle per piece. Each sets `USE_HEADERMAP: NO`, `ALWAYS_SEARCH_USER_PATHS: NO`, and `GCC_PREFIX_HEADER: ""`, with header search paths for only its piece and the pieces it declares. An import outside them fails to compile here. Each piece also builds for iOS, so an AppKit leak fails here too.

`scripts/checks/check-pieces.py` checks the rest:

- every piece has a template, a test bundle, and an `AGENTS.md`
- every template's paths stay inside its piece
- every import between pieces is in the dependency map, quoted or angled, and the map has no cycle
- the platform rule: only `Mac/` and `iOS/` are platform-specific
- no `#if DEBUG` in a shipping header
- the classes with no prefix, listed
- the other app's name appears nowhere

CI runs `make check-pieces`, `make test`, and `make build-ios`. `make analyze CONFIG=Release` joins when the first piece with more than the varispeed moves. Until then Vibe's own analyzer run covers the varispeed, since Vibe compiles it. GitHub Actions is free for a public repo, macOS runners included.

## The work, in order

**Correct the boundaries, prove the smallest extraction, move the playback and waveform path, let the other app build on it, then grow from actual reuse.** Each move is a pull request here, plus one in Vibe that bumps the submodule and deletes what moved. Each piece's `AGENTS.md` moves with it.

### Phase 0: setup and experiments

**The license is Apache 2.0** (decided 2026-10-18), Vibe's own, so code moves between the repos under the terms it already has.

The eight build questions, answered on 2026-10-18 with XcodeGen 2.46.0, Xcode 27.1 and Swift 6.4, in throwaway projects:

| # | Question | Answer |
| --- | --- | --- |
| 1 | Do paths in an included spec resolve relative to that spec? | **Yes.** A template's `core/Common` became `cm_libs/core/Common` in the app's project. The submodule can sit anywhere. |
| 2 | Can a template list other templates, and does `${excludedPlatform}` substitute? | **Yes, both.** A piece's template pulled in Common's through its own `templates:`. The `Mac/` half compiled and the `iOS/` half did not. A per-file `-O3` carried through. |
| 3 | Do a template's header search paths join the target's? | **Yes, if the target sets its paths in its own `base`.** Two templates' paths and the app's own all reached the target. **But a value the target takes from a settings group is replaced, not joined.** Vibe's pilot found it: its app targets took TagLib's and WaveformCore's paths from a group, and the template dropped them. Vibe now sets them in each app target's base. |
| 4 | Does a headermap-off build fail on a stray app import? | **Yes**, with `'AppOnly.h' file not found`, while the app's own build of the same file passes. |
| 5 | Does `xcodegen dump` keep an included spec's templates? | **Yes, and better than hoped.** The dump rewrites their paths relative to the app, and a project regenerated from the dump elsewhere has the same file references. So `perf.py`'s rebuild from the dump works unchanged. |
| 6 | Does the pilot pass the performance proof? | **Yes.** Across all 619 component benchmarks, 539 sit within ±0.5% of retired instructions, against 538 with no change at all. Every `pitch.*` benchmark is unchanged to 0.0%. The few that moved fell back into the noise when rerun with 6 rounds (Vibe #315). |
| 7 | When does SwiftPM refuse `unsafeFlags`? | **Only from a dependency pinned by version.** By path, by branch, or by revision, it accepts them. A version-pinned consumer fails with "contains unsafe build flags". This matters only for a future `Package.swift`. |
| 8 | Does `submodules: recursive` reach every CI job in Vibe? | **Yes.** Every job on Vibe #315 passed with the submodule checked out: the Linux checks, which now fail without it, and the macOS, iOS, unit and audio jobs. |

### Phase 1: the pilot, DSP with the varispeed

The smallest real piece goes first, after its one prerequisite. `AudioVarispeed` uses Vibe's realtime-check macros, so cut 12 first moves the macros out of Vibe's prefix header into `CMMMacros.h`. **Only the realtime brackets move in cut 12.** Vibe's log and signpost macros carry debug-only parts, and a shipping header may not hold `#if DEBUG`. They move when the first piece that logs moves, with a design for those parts. **The pilot then moves that header here with the varispeed**, as the first file of `core/Common`. A header left in Vibe would not satisfy this repo's isolated build. Vibe's prefix header imports it from the submodule. Nothing else blocks the pilot.

`AudioVarispeed` is Vibe's own windowed-sinc converter for the pitch fader. Its distortion sits near −150 dB, against −83 to −135 dB for Apple's Varispeed unit. It is flat to 20 kHz and a bit-perfect pass-through at zero pitch. It costs about 0.2% of one core at 48 kHz. Its API is plain C, it has one caller in Vibe, and its tests and benchmark stand alone.

The pilot proves every step the later moves will take: `git filter-repo`, the template, this repo's CI, the submodule in Vibe, `make project`, worktrees, Vibe's CI checkout, and `perf.py`. **Done when** Vibe's checks pass with the varispeed coming from here, the `pitch` benchmark shows no change, and this repo's CI runs `AudioVarispeedTests`.

### Phase 2: the cuts in Vibe, for the playback and waveform path

Small pull requests in Vibe remove every reach from the path's code into Vibe's own. Only the cuts the path needs come now. The rest wait for the piece they serve.

**Settings, strings, and app reaches:**

- **1.** A debug seam stops importing the debug channel's parser.
- **3.** The metadata cache takes a root path, as the waveform cache already does.
- **4.** Folder art stops reading the settings and the mac's folder grants. The app installs both as providers.
- **6.** One header in Vibe turns every error code and style identifier into its localized text. The engine reports codes only.
- **7.** File-info and accessibility formatting move out of the metadata record and the views.
- **8.** The waveform style and theme identifiers move from Vibe's settings into the registry and the theme.
- **9.** The mapping from Vibe's settings onto a waveform theme becomes a category in Vibe.
- **10.** The app pushes the mac waveform view its settings, instead of the view reading them.
- **11.** The app pushes the iOS scrubber its settings, instead of the view reading them.
- **12.** The macros move to `CMMMacros.h`. This one lands before Phase 1.

**The seams between pieces:**

- **13. The playable-item protocol.** A small protocol gives an item's file, frame window, source key, and disk key. Only the pieces that read a file take it: the player, Metadata, and WaveformLoading. Vibe's `AudioTrack` adopts it and stays in Vibe, moving to `Vibe/Playlist/` as the row it is, with its tags, analyzed tempo and key, display names, and the rule that tags beat analysis. They take `id` of the protocol and hand back the same object. The queue takes any object (seam 19). The CUE window math moves to Decode beside it.
- **14. `AudioFileOpenRules.h` splits.** It holds the open's delivery states, path spelling, and the network mount's read-ahead rules, and four areas import it. Each part goes to the piece that owns it.
- **15. The file loader stops naming the audio file handle.** Its opener is already a block. The handle it serves becomes a small protocol for interrupting reads and holding a stream. Its call into `AudioTrack` to forget memoized cache keys becomes a handler block.
- **16. Tags returns art bytes and takes a byte-range reader.** Today the TagLib wrapper returns an artwork extractor and reads remote ranges through the materializer.
- **17. The waveform decode takes observers of each mono block.** Today it builds the tempo and key analyzers itself. The app attaches them.
- **19. The play queue holds opaque entries.** It keeps object identity, as `Playlist` does today, so two entries for one file stay two entries. A scan of every `AudioTrack` member `Playlist.m` calls finds three, and no others:
  - **The URL**, to index the rows of each file, and **the source key**, to stamp a tempo or key onto every row sounding one window. The app passes both as key blocks when it makes the queue. Vibe passes the URL and the source key. A queue made without them has no lookup by file.
  - **`replacementAtURL:`**, which mints the row that replaces another when a file is converted. The queue stops minting rows. Replacing one row takes the replacement object, already made by the app, which must be fresh, never one already in the queue. Replacing every row of a file takes a block that maps each outgoing entry to its replacement, since each row may be a different CUE window. Vibe makes each replacement with `replacementAtURL:`. The queue keeps what it owns: the indexes, both shuffle orders, and one observer event per replaced row.

  So the queue imports no protocol and no app API, and depends on nothing.
- **22. Metadata installs results through a holder protocol of its own.** Today the loader reads an item's installed metadata, installs a result only if none is installed, and delivers only while that result is still installed. It does this through `AudioTrack (Internal)`'s `installMetadataIfUnresolved:` and `deliverIfMetadataStillInstalled:usingBlock:`. Metadata declares those three operations as its own protocol, and Vibe's row adopts it with the methods it has. The check and the install stay atomic in the object that holds the result, so a replaced item never shows a stale result. None of it goes into Decode's playable-item protocol, which stays free of metadata.

- **23. FolderScan reports each walked file to a handler.** Today the walk notes cover-art candidates itself, through Metadata's `FolderArtRules.h`. Metadata's folder art installs the handler instead, as FolderWalk's other launch-installed handlers already work.

**Waiting for their pieces:** cut 2 and seam 20 (RemoteFiles and ShareLinks; seam 20 also stops `LinkClient` importing `LinkStore`), seam 23 (FolderScan), cut 5 (only needed if `AudioTrack` ever moves), seam 18 (Playlists returns records), the Now Playing half of seam 19, and seam 21 (the shell pieces).

**Done when** this returns nothing in Vibe for the path's directories:

```
grep -rln 'AppSettings\|AppTheme\|VibeStrings.h\|FolderAccessManager\|DebugWireFormat\|AudioTrack.h' \
  Vibe/Audio Vibe/Loading/Claim Vibe/Loading/Transfer Vibe/Loading/PlaceholderFiles* \
  Vibe/WaveformUI Vibe/Controls Vibe/Playlist/Playlist.*
```

### Phase 3: move the playback and waveform path

In this order, each its own move:

1. `third_party/`, except Sparkle. Vibe's binary is unchanged after. The third-party notices split.
2. `core/Common` and `core/Graphics`.
3. `audio/AudioTypes`.
4. `files/FileLoading` and `files/DiskCache`.
5. The rest of `audio/`: DSP, Analysis, Decode, Meter, FX, OutputDevices, Player. **Done when** `perf.py --analyze` proves tempo and key exact, and the render suites pass.
6. `media/Tags`, `media/Metadata`, and `media/PlayQueue`.
7. `waveform/`: Waveform, WaveformStyles, WaveformLoading, WaveformView, and the indicators of `ui/Controls`. **Done when** Vibe's waveform benchmark pictures are byte-identical and screenshots on both platforms match.

**The other app's first slice starts after this phase.** It scans a folder, lists its songs, and plays a queue.

### Phase 4: the tag fields

The other app's library needs fields Vibe never reads. `AudioTrackMetadata` today holds title, artist, format, bitrate, sample rate, duration, and tagged tempo and key. This phase adds:

- album, album artist, genre, year, track number and count, disc number and count, and composer
- the compilation flag
- the release identifier, such as MusicBrainz's, where a file carries one

The parse is TagLib's, which already reads title and artist. The metadata archive's version moves, so an entry without the fields is a miss. **That costs every Vibe user one re-parse of their files**, so it ships in an announced Vibe release. Vibe reads none of the fields.

**This phase also decides album grouping.** Grouping by album title alone merges unrelated releases called "Greatest Hits". The key is the release identifier where present. Otherwise it is album artist, album, and year, with the track artist standing in when album artist is missing. A compilation groups by its album under one album artist, never splitting by track artist. The phase writes those rules as a tested `*Rules.h` decision, with fixtures for each case.

### Phase 5: grow from reuse

Each remaining candidate moves when a second app needs it, with the cuts it was waiting for:

- **HTTP, RemoteFiles, and ShareLinks**, when the other app adds a server source. Cut 2 and seam 20 come with them.
- **Playlists and FolderScan**, when the other app reads CUE sheets or walks folders through them. Seam 18 comes with them.
- **NowPlaying**, with the rest of seam 19.
- **SandboxAccess, AppOpening, Updates, the mac controls, DebugChannel, and iOSDriver**, each with its part of seam 21.

### Later

- **Portable rewrites.** Each is its own project, with its own measurements: WaveformStyles as C++ that paints pixels, which a waveform plugin needs; DSP, Analysis, Tags, and Playlists cores in C or C++; fallbacks for vDSP, simd, and Compression. Apple's LZFSE is open source under BSD, so it can be vendored and waveform archives stay readable everywhere. The Apple path keeps Accelerate, and `perf.py compare` proves it unchanged.
- **tools/.** Vibe's release, notarization, App Store upload, Homebrew, and layout-check scripts, and its stress and performance harnesses, are general too. They move once each takes its app's names and paths from a config file.

### Streaming is mostly built

Vibe already has HTTP transfers, ranged reads, remote placeholders, opens that play while a file streams, and render tests through that path against a stub server (`AudioPlayerRenderLinkTests`). A server source such as OpenSubsonic still needs:

- **Authentication.** OpenSubsonic signs each request with a salted token.
- **Catalog integration.** A server's songs become catalog entries with no bookmark and no local path.
- **Identity.** An entry is the server plus the server's item ID, never a URL, since stream URLs carry the token.
- **The original bytes.** OpenSubsonic transcodes unless asked not to, so every stream request passes `format=raw`. A transcoded stream would change the waveform, the analysis, and bit-perfect output.
- **Compatibility tests** against Navidrome, Gonic, Airsonic, and Ampache, which answer the same API differently.

That work belongs to the app that ships the source. FileLoading and Player already moved in Phase 3. HTTP and RemoteFiles move in Phase 5, when the source is built.

## New types

The cuts add these small types. Each replaces a dependency on an app class:

- the playable-item protocol
- Metadata's holder protocol
- the protocol of a handle the file loader serves
- the observer block of the waveform decode
- later, with Playlists: the record of a playlist entry

## TRAPs

- **A template's settings replace a value the target takes from a settings group.** They join only a value in the target's own `base`. So an app sets its own header search paths in `base`, never only through a group (the header of `cm_libs.yml`).
- **A checkout without the submodule compiles nothing from here and fails late.** Every consumer's `make project`, benchmark worktrees, and CI checkouts must update it.
- **YAML anchors do not cross `include:` files.** A consumer's own flag anchors cannot reach a template's entries. Every flag lives in its template.
- **The headermap hides a crossed boundary.** In any project holding two pieces, an import by basename resolves across them. Only this repo's headermap-off bundles make the compiler refuse.
- **`xcodegen dump` leaves templates unresolved.** A tool that rebuilds a consumer's target from the dump must copy `templates` and `templateAttributes`. Otherwise it builds without the pieces.
- **Vibe's analyzer gate drops findings by the substring `/ThirdParty/`** (`scripts/build/analyze.sh`). Vendored code here sits under `third_party/`, so the gate must also drop `/third_party/` before Phase 3 lands, or it fails on TagLib's findings.
- **A queue, a player, or a cache that compares items by content merges duplicates.** Two entries for one file are two entries. Shared work matches by source key, and a persisted entry by disk key.

## Costs

- **About thirty pieces in the end, about twenty for the first path.** Each has a template, a test bundle, and a doc. The stacks keep a consumer's list short.
- **Most engine changes also change app code.** Since 2026-04-01, 232 commits changed Vibe's engine, and 167 of them (72%) also changed Vibe's app code. After a move, each is a commit here, then a submodule bump. One editing session covers both through the submodule.
- **Many changes span pieces.** 90 of those commits (39%) changed more than one of the old products. That is why this is one repo and not one per piece.
- **Agent docs split across two repos.** An agent in an app must read this repo's `AGENTS.md` before changing a piece. Each app's root doc says so.
- **Vibe's two test source lists stay until each piece's tests move here.** Vibe's tests build production sources with their own flags, which is the reason compiling in was chosen.
