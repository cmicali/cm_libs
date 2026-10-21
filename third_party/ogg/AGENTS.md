# third_party/ogg

[libogg](https://github.com/xiph/ogg) 1.3.6, commit `be05b13e` of xiph/ogg. Its page reader is what `third_party/vorbis` reads Ogg Vorbis through. It is unmodified. Other authors' code: **do not restyle it.** It depends on nothing. Its template is `VibeLibsOgg`.

## What is vendored

`ogg.h`, `os_types.h`, the framing, and the bit reader, flat in this directory. Its `config_types.h` is not needed, since `os_types.h` has an Apple branch.

## Building

Callers include `<ogg/ogg.h>`, so the template searches `third_party/` itself. Its C files build as the dr_ decoders do: `-O3` in every configuration, `-w`, and the static analyzer off.

**TRAP: none of its headers may join an app's project.** Xcode's headermap finds a header by its name from any target. So the template adds only the C files (`includes: ["*.c"]`), as `third_party/vorbis`'s does.

When updating, copy the same file set from upstream, check that it still links, and run Vibe's `make test-audio`. `testOggVorbis` and the CoreAudio fuzz family read every Vorbis fixture through it.

## License

BSD 3-Clause, in `LICENSE.txt` (upstream's `COPYING`, renamed so a build leaves it out of an app's bundle). Copyright (c) 2002, Xiph.org Foundation. `THIRD-PARTY-NOTICES.md` at the repo root has the notice.
