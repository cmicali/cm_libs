# core/Common

What every other piece may use, and nothing else. Every piece may import from it, so it depends on nothing.

**Today it holds only `VibeMacros.h`.** That header carries the realtime-effects brackets: `VIBE_REALTIME_CHECKED_BEGIN`, `VIBE_REALTIME_UNCHECKED_BEGIN` and `VIBE_REALTIME_END`. Code between a checked bracket and its end compiles under `-Werror=function-effects`, so a `CA_REALTIME_API` function there cannot allocate, lock, log, dispatch or message. An unchecked bracket covers only the one-line shims around calls the checker cannot see, each documented at its site.

**A file imports `VibeMacros.h` explicitly.** No piece relies on a prefix header. An app's prefix header may import it too, as Vibe's does.

**TRAP: `VibeMacros.h` has no `#if DEBUG` and names no app type.** Every piece and every app imports it, and a shipping header may not carry debug surface. Vibe's logging and signpost macros have debug-only parts, so they stay in Vibe until a piece that logs moves. They then need a design for those parts first.

The rest of this piece arrives as the pieces that use it move: the log macros, the stall sampler, the work tally, path spelling, the disk key, the work lanes, and build provenance (`docs/plan.md`).
