# vibe-libs

A toolbox of small libraries for macOS and iOS apps. Each library is a piece an app can take on its own. Take the whole audio player, or only the waveform data, or only TagLib.

The first pieces come from [Vibe](https://github.com/cmicali/vibe). Anything in Vibe that another app could use is a candidate. It moves when a second app needs it.

**The first forty-one pieces are here**: `core/Common`, with Vibe's macros, path and file helpers, disk key, and work lanes, `core/Graphics`, with Vibe's image, color, and font helpers, `files/FileLoading`, with Vibe's cloud and network file loading and its fake cloud, `files/DiskCache`, with Vibe's bounded disk cache, `files/HTTP`, with Vibe's ranged HTTP transfers, `files/RemoteFiles`, with Vibe's remote placeholder store, `files/ShareLinks`, with Vibe's web link rules, its share-link rewrites and iCloud Drive lookup, and its fake web server, `audio/AudioTypes`, with Vibe's playable-item protocol, CUE window math, musical key, format names, and playable extensions, `audio/DSP`, with Vibe's varispeed, fades, and resampler, `audio/Analysis`, with Vibe's tempo and key analyzers, `audio/OutputDevices`, with Vibe's mac output devices and iOS audio session, `audio/FX`, with Vibe's DJ effects, `audio/Meter`, with Vibe's live band levels, `audio/Decode`, with Vibe's audio file handle and the decoders it hosts, `audio/Player`, with Vibe's playback engine, its output devices' and route recovery's halves, and its manual render pump, `media/Tags`, with Vibe's TagLib wrapper, `media/Metadata`, with Vibe's tag record, metadata cache and scan, embedded art and thumbnails, and folder art, `media/PlayQueue`, with Vibe's play order, shuffle, and repeat, `media/Playlists`, with Vibe's CUE and M3U readers and its M3U writer, `media/FolderScan`, with Vibe's folder walk, `waveform/Waveform`, with Vibe's waveform summary, its reads, raster, and archive, `waveform/WaveformLoading`, with Vibe's waveform loader, its cache, and the observers on its pass, `waveform/WaveformStyles`, with Vibe's waveform styles, their colors, and the morph engine that eases between them, `waveform/WaveformView`, with Vibe's mac waveform view and iOS scrubber, `ui/Controls`, with Vibe's loading and equalizer indicators and its drawn mac controls, `ui/SettingsWindow`, with Vibe's settings window, `ui/Shortcuts`, with Vibe's remappable shortcuts and their pane, `system/NowPlaying`, with Vibe's bridge to the system's Now Playing info and remote commands, `system/AppOpening`, with Vibe's coalescing of the mac's split opens and its ordered delivery of each open, `dev/DebugChannel`, with the transport of Vibe's debug command channel, `dev/iOSDriver`, with Vibe's touch driver for the iOS simulator, `tools/strings`, with Vibe's strings extraction and catalog checks, and the nine libraries Vibe vendored, each a piece under `third_party/`. The plan for the rest is [docs/plan.md](docs/plan.md).

## The pieces

| Group | Pieces |
| --- | --- |
| `core/` | **Common**: logging, diagnostics, paths, file identity, the disk key, and work lanes. **Graphics**: images, colors, and typography. |
| `files/` | **FileLoading**: local, iCloud, and network-share files, read even while they download. **RemoteFiles**, **HTTP**, **ShareLinks**, **SandboxAccess**, **DiskCache**. |
| `audio/` | **AudioTypes**, **DSP**, **Analysis** (tempo and key), **Decode**, **Meter**, **FX**, **OutputDevices**, and **Player**: gapless, crossfading, bit-perfect playback. |
| `media/` | **Tags**: TagLib's fields and embedded art bytes. **Metadata** (tags, art, and their cache), **Playlists** (CUE and M3U), **FolderScan**, **PlayQueue**. |
| `waveform/` | **Waveform** (the data), **WaveformStyles** (each style's look), **WaveformLoading**, **WaveformView**. |
| `ui/` | **Controls**: the loading and equalizer indicators on both platforms, and mac buttons, drawn sliders and switches, image views, and a link label. **SettingsWindow**: a System Settings window with a sidebar, search, history, and form views. **Shortcuts**: remappable shortcuts and their recorder pane. SettingsWindow and Shortcuts are macOS only. |
| `system/` | **NowPlaying**, **AppOpening**, **Updates** (Sparkle). |
| `dev/` | **DebugChannel**: drive and inspect a running debug build from a script. **iOSDriver**: taps, drags, and pinches in the iOS simulator, for scripts. iOSDriver is iOS only. |
| `tools/` | **strings**: an app's strings extraction and catalog checks, configured per app. Scripts, not code an app compiles. |
| `third_party/` | TagLib, dr_mp3, dr_flac, dr_wav, r8brain-free-src, PINCache, PINOperation, libogg, and libvorbis, each a piece of its own. Sparkle joins them with Updates. |

## How an app uses it

An app adds this repo as a git submodule at `vibe-libs/`. Its XcodeGen `project.yml` includes `vibe-libs/vibe-libs.yml` and lists the pieces it wants as templates on its targets. The pieces' sources compile into the app as its own files, so they build exactly as they would in the app's own tree.

## License

Apache 2.0, in `LICENSE`. The libraries under `third_party/` keep their own licenses. [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) lists each one and the license it is used under.
