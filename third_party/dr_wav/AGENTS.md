# third_party/dr_wav

dr_wav from [dr_libs](https://github.com/mackron/dr_libs), upstream commit `dfe83776`, dr_wav 0.14.6-dev. It is Vibe's decoder for WAV, W64, RF64, and AIFF(-C), of integer and float PCM, A-law, mu-law, and ADPCM (Vibe's `docs/audio-quality.md`). Other authors' code: **do not restyle it.** It depends on nothing. Its template is `VibeLibsDrWav`.

Vibe offers it only a file that starts with a RIFF, RF64, Wave64, or FORM header. It reads the stream itself, through the reads of `audio/Decode`'s `AudioFileHandle` and the same callbacks as dr_flac, and answers the file's facts. An AIFF's CHAN chunk and its COMM chunk's sample width reach the handle through dr_wav's chunk callback. dr_wav rounds that width up to whole bytes.

## Building

`dr_wav.c` is ours, the one implementation unit, without stdio. It raises `DRWAV_MAX_SAMPLE_RATE` from upstream's 384 kHz to 768 kHz. The template builds it as dr_mp3's: `-O3` in every configuration, `-w`, and the static analyzer off. Apps include `"dr_wav/dr_wav.h"`, so the template searches `third_party/` itself.

## Fixes of our own

**`dr_wav.h` is modified** on the `vibe-wav-fixes` branch of `cmicali/dr_libs`.

Fixes:

- An AIFF's SSND offset and block size fields were counted as audio. Forward seeks landed late in any AIFF with a chunk after SSND.
- AIFF-C A-law and mu-law bytes were shifted as signed 8-bit samples.
- Unsigned 8-bit silence converted to 1/255.
- A COMM, fact, or ds64 count was trusted past the data.
- PCM seeks were placed from the frame count less the bytes remaining. A seek past 2 GB stepped in `INT_MAX` bytes, a partial frame each.
- Data sizes of 0, 0xFFFFFFFF, or wrapped past 4 GB. The 0xFFFFFFFF recount reads from the end of the file.
- An IMA ADPCM block cut short was counted by bytes, not groups. An MS ADPCM one was counted by a whole header however little of it was there.
- COMM chunks of 23 bytes, of odd size, or of more than 18.
- A fmt chunk after the data.
- Four chunk sizes that hung the open, and a long seek with no `onTell`, found by fuzzing.
- The MS ADPCM sample update overflowing.
- A damaged ADPCM block ended the stream or dropped out of the timeline. It is now silence in its place.
- W64 padding.
- The MS ADPCM fact count was never used.
- The AIFF rate's 80-bit conversion overflowing.
- WAV ADPCM block sizes that cannot decode.
- ADPCM data shorter than one block header, whose count came from a fact chunk past the data.

An RF64 file may state its real size in place of 0xFFFFFFFF. A fmt chunk of 17 bytes is read, and its pad byte is not taken for a cbSize.

MS ADPCM uses the stream's coefficient table instead of the built-in seven pairs. The decoder accepts up to the 256 pairs a block's predictor can name, as CoreAudio does. A table cut short of its count, or one of no pairs, is refused. MS ADPCM prediction has one implementation.

Added formats are AIFF-C twos, in24, in32, 42ni, 23ni, and ima4. The ima4 decoder carries its predictor across packets as CoreAudio does. It saves decoder state every 64 packets for exact seeks. PCM, float, and G.711 read into the f32 output and convert in place with NEON or SSE2 at scalar accuracy. `drwav_read_pcm_frames_f32_planar` converts stereo straight into one buffer per channel with NEON. ADPCM reads ahead 16 KB at a time and seeks from the block holding the target.

## Updating

**The fixes live as a commit series on the `cmicali/dr_libs` fork**, based on upstream's `dfe83776`, with one change per commit. Keep `dr_wav.h` equal to its branch's tip. Change the decoder on its branch in a clone of the fork. Never change only this copy, and never use a scratch worktree for the fork. Commit and push the branch before copying the header here.

When re-vendoring from upstream, diff the copy against `dfe83776` and re-apply what upstream has not merged. Then run Vibe's `make test-audio`. Its `testDrWAVDecodesAsAppleDoes` and `testDrWAVSurvivesWhatDamagesFiles` fail on upstream's copy.

## License

Public domain (the Unlicense) or MIT No Attribution, at the recipient's choice. vibe-libs and Vibe use it under MIT No Attribution. Both texts are at the end of `dr_wav.h`. That license permits the fixes and additions without condition. `THIRD-PARTY-NOTICES.md` at the repo root has the notice.
