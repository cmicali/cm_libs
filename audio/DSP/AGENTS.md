# audio/DSP

Realtime signal stages a render can host. **Today it holds `AudioVarispeed`**, the pitch fader's stage, moved from Vibe. The rest of the DSP piece follows as its users move: the resampler wrapper, the fades, the FX math, and the band math (`docs/plan.md`). The analysis framing went to `audio/Analysis`, its only user.

## AudioVarispeed

**A pitch stage with a plain C API.** A host creates a stage, sets its pitch from its own queue, and renders slices on the audio thread through an input callback that pulls the source. It needs no type of any app. The stage owns the kernel and its tables, the ring, the position, the bypass at zero, the engage and disengage, and the replay. Vibe hosts one per source segment, before its FX, at the bus rate.

**At zero pitch it is a bit-perfect pass-through**: nothing converted, delayed or copied. The bypass is what makes zero exact, since the kernel is a low-pass at a ratio of 1 too. A stage builds no kernel until the pitch first leaves zero.

**The kernel** is a Kaiser-windowed sinc with a 64-frame half-width before stretching. It reads a polyphase table with cubic interpolation across phases and sums in double. Its −6 dB point is 22 kHz at 48 kHz, the same fraction of any rate. Above a ratio of 1 it is stretched by the ratio, so its cutoff follows the output's Nyquist. `VibeVarispeedSetPitch` builds a new stretch's table on the caller's queue and publishes it by pointer. The render ramps the ratio across each slice, so a drag glides. A slice that ramps the ratio down keeps the table it last used, which is stretched for where the ramp starts. The target's table would let the start of the ramp fold back.

**TRAP: a replaced table is freed only once the render no longer uses it** (`VibeVarispeedRetire`). The host decides when no render is inside. Vibe's player does it after the render leaves.

**The edges.** Leaving zero, the stage plays whole slices directly until it has recorded at least the widest kernel's half-width in its ring. It then starts the converter at the next source frame, its ratio ramped from 1, and pulls the source into the ring a half-width ahead. Returning to zero replays the frames it had pulled ahead before the source continues. Those are the source's own samples, so from the first frame after the return the output is the source exactly, with no frame skipped or repeated. At zero pitch settled, the ring is not written. The ring's size and the engage's history derive from the kernel's constants in `AudioVarispeed.m`, the one home of its geometry.

**The latency off zero is the kernel's half-width and one or two frames, and nothing else.** That is 64 input frames, and ceil(64 × ratio) above a ratio of 1. A host that reports what is heard adds it.

## Tests

`Tests/audio/DSP/AudioVarispeedTests.m` drives the stage alone, with random schedules of pitch and slice size, mono, and the pitch moved from another thread. Run it under the thread sanitizer when the stage's threading changes.

The tests that render the stage through a player stay with that player. In Vibe they are `testPitchQuality`, which holds the stage to −145 dB of distortion and false tones, flat to 20 kHz, and the edge and position tests in its render suite. Vibe's `pitch` benchmark group measures its cost beside Apple's Varispeed unit.
