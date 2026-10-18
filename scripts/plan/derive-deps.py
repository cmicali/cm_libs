"""Derive cm_libs' dependency map from a Vibe tree's imports.

Usage: python3 -I scripts/plan/derive-deps.py <root> [--sites]

<root> holds a Vibe checkout's Vibe/, Packages/, Tests/iOSDriver/ and
project.yml, for example
`git archive origin/main Vibe Packages Tests/iOSDriver project.yml` unpacked.
Run it before the moves, and after each cut, and update the map in
docs/plan.md in the same change.

Each source file is assigned to the piece the plan moves it into ("app" for
code that stays in Vibe). Every #import and #include, quoted or angled, is
resolved to a file in the tree, and the piece-to-piece edges are printed.
With --sites it also prints the files behind each edge.

<root> must also hold Vibe's project.yml, whose app header search paths
the resolver follows.

Resolution follows the compiler, never the filesystem's order:
  1. A quoted include looks in the including file's own directory first.
  2. Then both kinds look through the app's header search paths, in the
     order project.yml lists them.
  3. Then, as Xcode's headermap does, a quoted include may match a header by
     its basename anywhere in the tree, but only if exactly one matches.
  4. An include listed in EXPLICIT resolves to the file named there.
An include that still matches more than one file is reported as ambiguous,
and the script exits 1 without printing a map. Add an EXPLICIT entry, naming
the header the build really uses, to settle it. An angled include that
matches nothing is a system header and is skipped.
"""
import os
import re
import sys
from collections import defaultdict

root = sys.argv[1]
show_sites = "--sites" in sys.argv
inc = re.compile(r'^\s*#\s*(?:import|include)\s+([<"])([^>"]+)[>"]', re.M)

# (piece, path prefix relative to root). First match wins.
PIECES = [
    # third_party: each vendored library
    ("third_party/taglib", "Vibe/ThirdParty/taglib/"),
    ("third_party/dr_mp3", "Vibe/ThirdParty/dr_mp3/"),
    ("third_party/dr_flac", "Vibe/ThirdParty/dr_flac/"),
    ("third_party/dr_wav", "Vibe/ThirdParty/dr_wav/"),
    ("third_party/r8brain", "Vibe/ThirdParty/r8brain/"),
    ("third_party/PINCache", "Vibe/ThirdParty/PINCache/"),
    ("third_party/PINOperation", "Vibe/ThirdParty/PINOperation/"),
    ("third_party/ogg", "Vibe/ThirdParty/ogg/"),
    ("third_party/vorbis", "Vibe/ThirdParty/vorbis/"),
    ("third_party/Sparkle", "Vibe/ThirdParty/Sparkle/"),
    # debug seams and simulators go with the class they open
    ("audio/Player", "Vibe/Debug/Seams/AudioPlayer+"),
    ("audio/Player", "Vibe/Debug/Simulators/VibeManualRenderPump"),
    ("audio/Decode", "Vibe/Debug/Seams/AudioFileHandle+"),
    ("audio/FX", "Vibe/Debug/Seams/AudioFX+"),
    ("audio/Meter", "Vibe/Debug/Seams/AudioLevel"),
    ("files/FileLoading", "Vibe/Debug/Seams/AudioFileMaterializationCoordinator+"),
    ("files/FileLoading", "Vibe/Debug/Seams/AudioLoadingConfiguration+"),
    ("files/FileLoading", "Vibe/Debug/Seams/CloudFileMaterializer+"),
    ("files/FileLoading", "Vibe/Debug/Seams/DownloadProgressMonitor+"),
    ("files/FileLoading", "Vibe/Debug/Seams/PlaceholderFiles+"),
    ("files/FileLoading", "Vibe/Debug/Simulators/VibeFakeCloud"),
    ("files/ShareLinks", "Vibe/Debug/Simulators/VibeFakeHTTP"),
    ("media/Metadata", "Vibe/Debug/Seams/AudioTrackMetadata"),
    ("waveform/WaveformLoading", "Vibe/Debug/Seams/AudioWaveformCache+"),
    ("ui/Controls", "Vibe/Debug/Seams/EqualizerIndicatorView+"),
    ("core/Common", "Vibe/Debug/Oracles/VibeWorkTally"),
    ("core/Common", "Vibe/Debug/Oracles/AudioLoadTiming"),
    ("dev/DebugChannel", "Vibe/Debug/Channel/"),
    # core
    ("core/Common", "Vibe/Util/HelperMacros"),
    ("core/Common", "Vibe/Util/StallWatch"),
    ("core/Common", "Vibe/Util/FilePaths"),
    ("core/Common", "Vibe/Util/VibeWeakProxy"),
    ("core/Common", "Vibe/Util/UIUpdate"),
    ("core/Common", "Vibe/Util/Categories/NSURL+Emptiness"),
    ("core/Common", "Vibe/Util/Categories/NSURL+FileIdentity"),
    ("core/Common", "Vibe/Util/Categories/NSBundle+BuildInfo"),
    ("core/Common", "Vibe/Loading/Claim/AudioWorkScheduler"),
    ("core/Common", "Vibe/Loading/Claim/AudioWorkAdmissionRules"),
    ("core/Graphics", "Vibe/Common/PlatformTypes"),
    ("core/Graphics", "Vibe/Common/PlatformImage"),
    ("core/Graphics", "Vibe/Common/PlatformColor"),
    ("core/Graphics", "Vibe/Util/Mac/NSView+DarkMode"),
    ("core/Graphics", "Vibe/Util/Mac/NSColor+OKLCH"),
    ("core/Graphics", "Vibe/Util/Mac/NSImage+Util"),
    ("core/Graphics", "Vibe/Util/iOS/UIView+DarkMode"),
    ("core/Graphics", "Vibe/Util/iOS/UIImage+DominantColor"),
    ("core/Graphics", "Vibe/Util/iOS/UIImage+Blur"),
    # files
    ("files/DiskCache", "Vibe/Audio/PINCache+VibeAudioCache"),
    ("core/Common", "Vibe/Util/Categories/NSURL+Hash"),
    ("files/HTTP", "Vibe/Loading/Net/HTTPTransfer"),
    ("files/RemoteFiles", "Vibe/Loading/Net/RemotePlaceholderStore"),
    ("app", "Vibe/Loading/Net/LinkStore"),
    ("files/ShareLinks", "Vibe/Loading/Net/"),
    ("app", "Vibe/Loading/iOS/"),
    ("files/FileLoading", "Vibe/Loading/"),
    ("files/SandboxAccess", "Vibe/Mac/App/FolderAccess"),
    # audio
    ("audio/DSP", "Vibe/Audio/FX/AudioVarispeed"),
    ("audio/DSP", "Vibe/Audio/FX/AudioFXMath"),
    ("audio/DSP", "Vibe/Audio/FadeMath"),
    ("audio/DSP", "Vibe/Audio/AudioResampler"),
    ("audio/DSP", "Vibe/Audio/Analysis/AnalysisFramerMath"),
    ("audio/DSP", "Vibe/Audio/Levels/AudioLevelMath"),
    ("audio/FX", "Vibe/Audio/FX/"),
    ("audio/Analysis", "Vibe/Audio/Analysis/"),
    ("audio/AudioTypes", "Vibe/Audio/MusicalKey"),
    ("audio/Meter", "Vibe/Audio/Levels/"),
    ("audio/Player", "Vibe/Audio/Mac/Devices/AudioPlayer+"),
    ("audio/OutputDevices", "Vibe/Audio/Mac/Devices/"),
    ("audio/Player", "Vibe/Audio/iOS/AudioPlayer+"),
    ("audio/OutputDevices", "Vibe/Audio/iOS/"),
    ("audio/Decode", "Vibe/Audio/AudioFileHandle"),
    ("audio/AudioTypes", "Vibe/Audio/AudioFileFormat"),
    ("audio/AudioTypes", "Vibe/Audio/PlaybackIntent"),
    ("audio/AudioTypes", "Vibe/Common/PlayableExtensions"),
    ("app", "Vibe/Audio/AudioTrack"),
    # media
    ("media/Tags", "Vibe/Audio/Metadata/TagLibAudioFile"),
    ("media/Tags", "Vibe/Util/Categories/NSString+CPPStrings"),
    ("media/Metadata", "Vibe/Audio/Metadata/"),
    # waveform
    ("waveform/Waveform", "Packages/WaveformCore/Sources/"),
    ("waveform/Waveform", "Vibe/Audio/Waveform/AudioWaveform."),
    ("waveform/WaveformLoading", "Vibe/Audio/Waveform/"),
    ("audio/Player", "Vibe/Audio/"),
    ("waveform/WaveformStyles", "Vibe/WaveformUI/Renderers/"),
    ("waveform/WaveformStyles", "Vibe/WaveformUI/WaveformTheme"),
    ("waveform/WaveformStyles", "Vibe/WaveformUI/WaveformZoomMath"),
    ("waveform/WaveformView", "Vibe/WaveformUI/"),
    # ui, system, media/playlists
    ("app", "Vibe/Mac/Controls/ArtworkImageView"),
    ("ui/Controls", "Vibe/Mac/Controls/"),
    ("ui/Controls", "Vibe/Controls/"),
    ("system/NowPlaying", "Vibe/NowPlaying/"),
    ("system/AppOpening", "Vibe/Mac/App/OpenBurstCoalescer"),
    ("system/AppOpening", "Vibe/Mac/App/OpenRequestCoordinator"),
    ("media/PlayQueue", "Vibe/Playlist/Playlist."),
    ("media/PlayQueue", "Vibe/Common/RepeatMode"),
    ("media/Playlists", "Vibe/Playlist/PlaylistFile"),
    ("media/FolderScan", "Vibe/Playlist/FolderWalk"),
    ("media/FolderScan", "Vibe/Common/FolderOpenSort"),
    ("media/FolderScan", "Vibe/iOS/Search/FileSearch"),
    ("dev/iOSDriver", "Tests/iOSDriver/"),
    ("app", ""),
]


def piece_of(rel):
    for name, prefix in PIECES:
        if rel.startswith(prefix):
            return name
    return "app"


SRC = (".h", ".hpp", ".hh", ".m", ".mm", ".c", ".cc", ".cpp", ".inc", ".tcc")
files = []
for top in ("Vibe", "Packages", "Tests/iOSDriver"):
    for dirpath, _, names in os.walk(os.path.join(root, top)):
        for n in names:
            if n.endswith(SRC):
                files.append(os.path.relpath(os.path.join(dirpath, n), root))

by_base = defaultdict(list)
for f in files:
    by_base[os.path.basename(f)].append(f)
file_set = set(files)

# (including file, spelling) -> the file the build uses, for a collision the
# search paths cannot settle. Each entry says why.
EXPLICIT = {}


def search_paths():
    """The app's HEADER_SEARCH_PATHS from project.yml, relative to root."""
    paths, inside = [], False
    with open(os.path.join(root, "project.yml")) as fh:
        for line in fh:
            if "HEADER_SEARCH_PATHS: &vibe-header-search-paths" in line:
                inside = True
                continue
            if not inside:
                continue
            stripped = line.strip()
            if stripped.startswith("#") or not stripped:
                continue
            if not stripped.startswith("- "):
                break
            value = stripped[2:].split("#")[0].strip().strip('"')
            if value.startswith("$(SRCROOT)/"):
                paths.append(value[len("$(SRCROOT)/"):])
    if not paths:
        sys.exit("no app header search paths found in project.yml")
    return paths


SEARCH = search_paths()
ambiguous = []


def resolve(src, kind, spelling):
    explicit = EXPLICIT.get((src, spelling))
    if explicit:
        return explicit
    if kind == '"':
        local = os.path.normpath(os.path.join(os.path.dirname(src), spelling))
        if local in file_set:
            return local
    for directory in SEARCH:
        candidate = os.path.normpath(os.path.join(directory, spelling))
        if candidate in file_set:
            return candidate
    if kind != '"':
        return None
    cands = [c for c in by_base.get(os.path.basename(spelling), [])
             if c == spelling or c.endswith("/" + spelling)]
    if len(cands) == 1:
        return cands[0]
    if len(cands) > 1:
        ambiguous.append((src, spelling, cands))
    return None


edges = defaultdict(lambda: defaultdict(set))
for f in files:
    src = piece_of(f)
    if src == "app":
        continue
    with open(os.path.join(root, f), errors="replace") as fh:
        text = fh.read()
    for kind, spelling in inc.findall(text):
        target = resolve(f, kind, spelling)
        if not target:
            continue
        dst = piece_of(target)
        if dst != src:
            edges[src][dst].add(f"{f.split('/')[-1]} -> {spelling}")

if ambiguous:
    for src, spelling, cands in ambiguous:
        print(f"ambiguous: {src} includes \"{spelling}\": {', '.join(cands)}", file=sys.stderr)
    sys.exit(1)

for src in sorted(edges):
    deps = sorted(d for d in edges[src])
    print(f"{src:28} -> {', '.join(deps)}")
    if show_sites:
        for d in deps:
            sites = sorted(edges[src][d])
            print(f"    {d:26} {len(sites):3}  " + "; ".join(sites[:3]) + (" ..." if len(sites) > 3 else ""))
