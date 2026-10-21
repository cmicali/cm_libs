# third_party/vorbis

[libvorbis](https://github.com/xiph/vorbis), upstream commit `1b75110b` of xiph/vorbis, after 1.3.7. It is Vibe's Ogg Vorbis decoder on both platforms. It is unmodified. Other authors' code: **do not restyle it.** It depends on `third_party/ogg`. Its template is `VibeLibsVorbis`, which lists `VibeLibsOgg`.

Master is used for the decoder fixes made since the last release, among them a use-after-free in `ov_pcm_page_seek` and large stack allocations.

## What is vendored

Only the decoder: `include/vorbis/codec.h` and `vorbisfile.h`, and the twenty `lib/` files and nineteen headers that link without the encoder's entry points. `bitrate.c`, `envelope.c`, and `psy.c` are encoder code that `block.c` references, so they link but never run.

## Building

The template searches `include/`, so callers include `<vorbis/vorbisfile.h>`. Its C files build as the dr_ decoders do: `-O3` in every configuration, `-w`, and the static analyzer off.

**TRAP: none of its headers may join an app's project.** Xcode's headermap finds a header by its name from any target, and libvorbis's `vorbisfile.h` would answer for TagLib's. So the template adds only `lib/`'s C files (`includes: ["*.c"]`).

**TRAP: an app that also takes `VibeLibsTaglib` lists `VibeLibsVorbis` first.** TagLib keeps its own `vorbis/vorbisfile.h` under `taglib/ogg`. An app's search paths follow the order of its templates, and the first path wins. `make check-pieces` settles `vorbis/vorbisfile.h` as this piece's.

When updating, copy the same file set from upstream, check that it still links, and run Vibe's `make test-audio`. `testOggVorbis` and the CoreAudio fuzz family read every Vorbis fixture through it.

## License

BSD 3-Clause, in `LICENSE.txt` (upstream's `COPYING`, renamed so a build leaves it out of an app's bundle). Copyright (c) 2002-2020, Xiph.org Foundation. `THIRD-PARTY-NOTICES.md` at the repo root has the full text.
