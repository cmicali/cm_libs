# core/Common

What every other piece may use, and nothing else. Every piece may import from it, so it depends on nothing.

**Today it holds `CMMMacros.h` and its one definition, `CMMMacros.m`.** A file imports `CMMMacros.h` explicitly. No piece relies on a prefix header. An app's prefix header may import it too, as Vibe's does.

## The realtime-effects brackets

`VIBE_REALTIME_CHECKED_BEGIN`, `VIBE_REALTIME_UNCHECKED_BEGIN` and `VIBE_REALTIME_END`. Code between a checked bracket and its end compiles under `-Werror=function-effects`, so a `CA_REALTIME_API` function there cannot allocate, lock, log, dispatch or message. An unchecked bracket covers only the one-line shims around calls the checker cannot see, each documented at its site. This half is plain C, so a C file may use it.

## Logging

`LogError`, `LogWarn`, `LogInfo`, `LogDebug` and `LogTiming` wrap `os_log`. They are Objective-C only.

- **The subsystem is the main bundle's identifier**, read once, so each app's messages stream under its own name. Vibe's two apps share one identifier, `com.commonwealthrecordings.Vibe`. A test bundle's messages land under its runner's identifier.
- **`VIBE_VERBOSE_LOGGING`** is the app's build setting. At 1, info and debug are written at Default level, so they are kept for a later export. Unset, as in this repo's own builds, it reads as 0.
- **A message is formatted only when something will take it**: `os_log` at its level, or the mirror.

**`CMMLogMirror` is a second sink for every message, at every level, with its type.** It is NULL unless an app sets it. Vibe's debug build sets it before `main` when launched with `--log-stderr`, to bring a device's logs back over the console. A shipping build leaves it NULL, so each log pays one load and no call. Set it once, before anything logs. It is a plain global, not a lock-guarded value.

**TRAP: `CMMMacros.h` has no `#if DEBUG` and names no app type.** Every piece and every app imports it, and a shipping header may not carry debug surface. That is why the mirror is a hook the app installs, not a debug-only branch in the header.

## Still in Vibe

Vibe's signpost and work-tally macros stay in its prefix header for now. They are debug-only in every file that uses them, the waveform renderers among them, so they need their own design when those pieces move. The plan has the rest of what this piece will hold: the stall sampler, the work tally, path spelling, the disk key, the work lanes, and build provenance (`docs/plan.md`).
