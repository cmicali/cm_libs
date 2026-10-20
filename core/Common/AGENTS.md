# core/Common

What every other piece may use, and nothing else. Every piece may import from it, so it depends on nothing.

**Today it holds only `VibeMacros.h`, a header.** A file imports `VibeMacros.h` explicitly. No piece relies on a prefix header. An app's prefix header may import it too, as Vibe's does.

## The realtime-effects brackets

`VIBE_REALTIME_CHECKED_BEGIN`, `VIBE_REALTIME_UNCHECKED_BEGIN` and `VIBE_REALTIME_END`. Code between a checked bracket and its end compiles under `-Werror=function-effects`, so a `CA_REALTIME_API` function there cannot allocate, lock, log, dispatch or message. An unchecked bracket covers only the one-line shims around calls the checker cannot see, each documented at its site. This half is plain C, so a C file may use it.

`Tests/core/Common/CommonProbe.m` compiles the header alone, with a function under the checked bracket. The macOS tests call it, and the iOS target compiles it. A new header here gets an import in the probe.

## Logging

`LogError`, `LogWarn`, `LogInfo`, `LogDebug` and `LogTiming` wrap `os_log`. They are Objective-C only.

- **The subsystem is the main bundle's identifier**, read once, so each app's messages stream under its own name. Vibe's two apps share one identifier, `com.commonwealthrecordings.Vibe`. A test bundle's messages land under its runner's identifier.
- **`VIBE_VERBOSE_LOGGING`** is the app's build setting. At 1, info and debug are written at Default level, so they are kept for a later export. Unset, as in this repo's own builds, it reads as 0.
- **A message is formatted only when `os_log` takes its level.**

**To see messages on stderr, an app sets `OS_ACTIVITY_DT_MODE=1` in the process's environment.** `os_log` then copies every message it keeps to stderr, which is how Xcode's console gets them. Vibe's device workflow passes it through `devicectl`. Debug-level messages need their level enabled, or an app that logs them at Default, as Vibe's verbose builds do.

**TRAP: `VibeLogWants` and `VibeLogEmit` hold nothing but the `os_log` calls.** Every log site in every piece inlines them. With a stderr hook there, Vibe's metadata-scan benchmarks retired 2 to 3% more instructions, although they never log. The system's own switch costs the call sites nothing.

**TRAP: `VibeMacros.h` has no `#if DEBUG` and names no app type.** Every piece and every app imports it, and a shipping header may not carry debug surface.

## Still in Vibe

Vibe's signpost and work-tally macros stay in its prefix header for now. They are debug-only in every file that uses them, the waveform renderers among them, so they need their own design when those pieces move. The plan has the rest of what this piece will hold: the stall sampler, the work tally, path spelling, the disk key, the work lanes, and build provenance (`docs/plan.md`).
