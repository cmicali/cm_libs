# vibe-libs

A toolbox of small libraries for macOS and iOS apps. Each library is a piece an app can take on its own. Take the whole audio player, or only the waveform data, or only TagLib.

The first pieces come from [Vibe](https://github.com/cmicali/vibe). Anything in Vibe that another app could use is a candidate. It moves when a second app needs it.

**The first two pieces are here**: `core/Common`, with the realtime-effects brackets, and `audio/DSP`, with Vibe's varispeed. The plan for the rest is [docs/plan.md](docs/plan.md).

## The pieces

| Group | Pieces |
| --- | --- |
| `core/` | **Common**: logging, diagnostics, paths, work lanes. **Graphics**: images and colors. |
| `files/` | **FileLoading**: local, iCloud, and network-share files, read even while they download. **RemoteFiles**, **HTTP**, **ShareLinks**, **SandboxAccess**, **DiskCache**. |
| `audio/` | **AudioTypes**, **DSP**, **Analysis** (tempo and key), **Decode**, **Meter**, **FX**, **OutputDevices**, and **Player**: gapless, crossfading, bit-perfect playback. |
| `media/` | **Tags**, **Metadata** (tags, art, and their cache), **Playlists** (CUE and M3U), **FolderScan**, **PlayQueue**. |
| `waveform/` | **Waveform** (the data), **WaveformStyles**, **WaveformLoading**, **WaveformView**. |
| `ui/` | **Controls**: loading and equalizer indicators, and mac buttons, sliders, and a pitch fader. |
| `system/` | **NowPlaying**, **AppOpening**, **Updates** (Sparkle). |
| `dev/` | **DebugChannel**, **iOSDriver**. |
| `third_party/` | TagLib, dr_mp3, dr_flac, dr_wav, r8brain-free-src, PINCache, PINOperation, ogg, vorbis, and Sparkle, each a piece of its own. |

## How an app uses it

An app adds this repo as a git submodule at `vibe-libs/`. Its XcodeGen `project.yml` includes `vibe-libs/vibe-libs.yml` and lists the pieces it wants as templates on its targets. The pieces' sources compile into the app as its own files, so they build exactly as they would in the app's own tree.

## License

Not chosen yet. Until one is, nothing here is licensed for reuse.
