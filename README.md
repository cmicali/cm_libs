# vibe-libs

A toolbox of small libraries for macOS and iOS apps. Each library is a piece an app can take on its own. Take the whole audio player, or only the waveform data, or only TagLib.

The first pieces come from [Vibe](https://github.com/cmicali/vibe). Anything in Vibe that another app could use is a candidate. It moves when a second app needs it.

**The first four pieces are here**: `core/Common`, with the realtime-effects brackets, `core/Graphics`, with Vibe's image, color, and font helpers, `audio/DSP`, with Vibe's varispeed, and `ui/Controls`, with Vibe's drawn mac controls. The plan for the rest is [docs/plan.md](docs/plan.md).

## The pieces

| Group | Pieces |
| --- | --- |
| `core/` | **Common**: logging, diagnostics, paths, work lanes. **Graphics**: images, colors, and typography. |
| `files/` | **FileLoading**: local, iCloud, and network-share files, read even while they download. **RemoteFiles**, **HTTP**, **ShareLinks**, **SandboxAccess**, **DiskCache**. |
| `audio/` | **AudioTypes**, **DSP**, **Analysis** (tempo and key), **Decode**, **Meter**, **FX**, **OutputDevices**, and **Player**: gapless, crossfading, bit-perfect playback. |
| `media/` | **Tags**, **Metadata** (tags, art, and their cache), **Playlists** (CUE and M3U), **FolderScan**, **PlayQueue**. |
| `waveform/` | **Waveform** (the data), **WaveformStyles**, **WaveformLoading**, **WaveformView**. |
| `ui/` | **Controls**: loading and equalizer indicators, and mac buttons, sliders, image views, and a pitch fader. **SettingsWindow**: a System Settings window with a sidebar, search, history, and form views. **Shortcuts**: remappable shortcuts and their recorder pane. Both macOS only. |
| `system/` | **NowPlaying**, **AppOpening**, **Updates** (Sparkle). |
| `dev/` | **DebugChannel**, **iOSDriver**. |
| `third_party/` | TagLib, dr_mp3, dr_flac, dr_wav, r8brain-free-src, PINCache, PINOperation, ogg, vorbis, and Sparkle, each a piece of its own. |

## How an app uses it

An app adds this repo as a git submodule at `vibe-libs/`. Its XcodeGen `project.yml` includes `vibe-libs/vibe-libs.yml` and lists the pieces it wants as templates on its targets. The pieces' sources compile into the app as its own files, so they build exactly as they would in the app's own tree.

## License

Apache 2.0, in `LICENSE`. The libraries under `third_party/` keep their own licenses.
