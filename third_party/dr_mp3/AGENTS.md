# third_party/dr_mp3

dr_mp3 from [dr_libs](https://github.com/mackron/dr_libs), upstream commit `dfe83776`, dr_mp3 0.7.4. It is Vibe's MPEG decoder for MP1, MP2, and MP3 (Vibe's `docs/audio-quality.md`). Other authors' code: **do not restyle it.** It depends on nothing. Its template is `VibeLibsDrMp3`.

Vibe calls only its frame decoder (`drmp3dec_*`). `audio/Decode`'s `AudioFileHandle` frames the packets itself (`AudioFileHandle+MPEG.m`).

## Building

`dr_mp3.c` is ours, the one implementation unit. It defines `DR_MP3_FLOAT_OUTPUT` itself, and its comment says why. The template builds it with `-O3` in every configuration, so a Debug build decodes as a shipped one does, and with `-w` and the static analyzer off. Apps include `"dr_mp3/dr_mp3.h"`, so the template searches `third_party/` itself.

## Fixes of our own

**`dr_mp3.h` is modified** on the `vibe-mp3-fixes` branch of `cmicali/dr_libs`.

- MPEG-1 Layer III's private bits are no longer read as the first granule's scfsi.
- The 8 kHz row of `g_scf_mixed` (MPEG 2.5 mixed blocks) uses long bands 0–5 and short bands 3–12. Upstream's row reordered 600 lines, 24 floats past the granule, and scaled three bands by an earlier granule's scalefactors.
- In a mixed block, each short window has its own intensity stereo bound, as ISO/IEC 11172-3 specifies. Upstream gave all three windows the highest one, and ISO's l3_10203 stream was off by up to 2.6e-4.

The branch also carries upstream pull requests for the `drmp3` API, which Vibe does not call.

## Updating

**The fixes live as a commit series on the `cmicali/dr_libs` fork**, based on upstream's `dfe83776`, with one change per commit. Keep `dr_mp3.h` equal to its branch's tip. Change the decoder on its branch in a clone of the fork. Never change only this copy, and never use a scratch worktree for the fork. Commit and push the branch before copying the header here.

When re-vendoring from upstream, diff the copy against `dfe83776` and re-apply what upstream has not merged. Then run Vibe's `make test-audio`. Its `testDrMP3DecodesWhatAppleRoundsTo16Bits` holds the decode to Apple's. Its `testDrMP3IgnoresPrivateBits`, `testDrMP3DecodesMixedBlocksAt8kHzAsFFmpegDoes`, and `testDrMP3BoundsIntensityStereoPerWindowInMixedBlocks` fail on upstream's copy.

## License

Public domain (the Unlicense) or MIT No Attribution, at the recipient's choice. vibe-libs and Vibe use it under MIT No Attribution. Both texts are at the end of `dr_mp3.h`. minimp3, the decoder it carries, is CC0. That license permits the fixes without condition. `THIRD-PARTY-NOTICES.md` at the repo root has the notice.
