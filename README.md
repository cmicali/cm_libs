# cm_libs

A toolbox of small libraries for macOS and iOS apps. Each library is a piece an app can take on its own. Take the audio engine, or only the waveform drawing, or only TagLib.

The first pieces come from [Vibe](https://github.com/cmicali/vibe): its audio engine, FX, tempo and key analysis, waveform data and drawing, and the third-party code it vendors. Pieces with nothing to do with audio join later.

**Nothing has moved yet.** The plan is [docs/plan.md](docs/plan.md).

## The pieces

| Piece | What it is |
| --- | --- |
| Audio | The playback engine: file handle and decoders, player, voice bus, resampler, levels, output devices, loading and transfers, metadata, artwork, and the waveform loader and cache |
| FX | Realtime DSP stages a render can host, starting with the varispeed |
| Analysis | BPM and key detection from PCM |
| WaveformData | The waveform summary, its reads, its raster, and its archive |
| WaveformUI | The waveform renderers, the morph engine, the theme rules, and the macOS and iOS views |
| Common | The macros, the platform aliases, and the small helpers every piece uses |
| ThirdParty | TagLib, dr_mp3, dr_flac, dr_wav, r8brain-free-src, PINCache, ogg, and vorbis, each a piece of its own |

## How an app uses it

An app adds this repo as a git submodule at `cm_libs/`. Its XcodeGen `project.yml` includes `cm_libs/cm_libs.yml` and lists the pieces it wants as templates on its targets. The pieces' sources compile into the app as its own files, so they build exactly as they would in the app's own tree.

## License

Not chosen yet. Until one is, nothing here is licensed for reuse.
