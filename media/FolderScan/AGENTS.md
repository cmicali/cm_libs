# media/FolderScan

The folder walk: whatever the user opened, a file, a folder, or a playlist file, as an ordered list of entries. It depends on `audio/AudioTypes`, for the playable extensions, on `files/FileLoading`, for the placeholder checks, on `media/Playlists`, for the readers and the entry record, and on `core/Common`, for the emptiness test and the log macros. **Today it holds what Vibe moved here.** None of it reads an app's settings, strings, or types.

| File | Owns |
| --- | --- |
| `FolderWalk.{h,m}` | the walk, one file's entries, the listing a browser draws, the read-denied test, and the handlers an app installs. `FolderWalk.h` states each method's contract |
| `FolderWalkInternal.h` | the synchronous expansion steps, for the tests and an app's benchmarks |
| `FolderOpenSort.h` | the order a folder's tracks land in, as an enum. An app keeps its stored identifiers |

## The walk stays ignorant on purpose

**The walk returns `PlaylistEntry` records, and the caller makes its rows from them.** Vibe's are made by `AudioTrack rowsForEntries:`. The walk runs on background workers, never the main thread. `expandAndFilterList:sortedBy:completion:` runs four wide and completes on its worker, so the caller makes its rows there and then goes to main. Callers order overlapping results themselves.

**It calls no one. What it discovers is reported through handler blocks the app installs at launch.** Each is a value the walk copies under a lock and reads from its workers.

- `setPlaylistFolderGrantHandler:`: the grant a playlist file's unreadable entries need. It runs on a worker and blocks until answered. Only the macOS build asks it.
- `setWalkedFileHandler:`: a rank for each file a folder walk lists, by name. The walk keeps the first best-ranked file of each directory and knows nothing of what the rank means. Vibe installs folder art's cover rank.
- `setWalkedDirectoriesHandler:` and `setBulkOpenDirectoriesHandler:`: the folders it listed with the file it kept in each, and a bulk open's loose folders. An app's cover resolver can take them rather than pay for its own listing.

**Unset handlers mean the walk still works and throws the extra facts away.** That is what the tests install. A walk that called a singleton behind a setting, a grant, and a modal panel could not be tested. `FolderWalkInternal.h` exposes the synchronous expansion steps for those tests. Do not import it outside `FolderWalk.m`, the tests, and an app's benchmarks.

## The order is a parameter

**The folder-open order is a parameter, not a setting read.** `expandAndFilterList:sortedBy:completion:`, `entriesInDirectory:sortedBy:`, and `listDirectory:sortedBy:folders:playlists:audio:` take a `VibeFolderOpenSort`. The app reads its setting on main with the rest of its open snapshot and passes it in. One open then cannot straddle a settings change, and the walk stays testable with no defaults store. `FolderOpenSort.h` holds only the enum. An app keeps the setting's stored identifiers and its display names.

**The order applies only to what the walk expanded.** The user's top-level URLs and a playlist file's order are kept. A recursive walk sorts by whole path, so subfolders stay grouped. Newest first prefetches `NSURLContentModificationDateKey` in the enumeration. Name breaks equal dates, as for a folder copied in one go. As received is APFS hash order on a local volume, effectively random. It is meaningful only on a file provider, whose listing order is what the choice exists for. **TRAP: decorate the dates and names once, never read them in the comparator** (the file's `TRAP:` says why).

## Links

**A symbolic link to a folder is a folder, and the walk is the only thing that can say so.** **TRAP: `NSURLIsDirectoryKey` is lstat-shaped**, and `NSFileManager` neither accepts a link as a walk root (ENOTDIR) nor descends into one it meets. Left alone, a dragged `~/Music/NAS` link would open to nothing. `VibeResolvedDirectoryPath` resolves with `realpath(3)`. `URLByResolvingSymlinksInPath` would not do, since it leaves a `/private` prefix as it found it. The walk keeps its own work list of roots. Each directory link becomes another root, held back until the current enumeration finishes, so it can be tested against everything that enumeration covered. **The answer is spelled as the target, not the link**, so the entries and the walked-directories handler name one folder. A `covered` set of every directory passed through ends a link cycle. With `skipDescendants`, it also keeps a link into an already-listed subtree from listing it twice. A link to a file stays a file. A **dangling** link is dropped.

The emptiness filter answers NO to anything it cannot stat, so a sandbox denial reaches the real open. Without the dangling rule, a broken `Song.mp3` link would become an unplayable entry.

## One file's entries

**Every file's entries are made by `entriesForFile:`, the only place a walk reads an audio file's contents.** A FLAC of 100 MB or more, a whole album or mix, is opened for an embedded sheet (`media/Playlists`' `cueEntriesEmbeddedInFLACAtURL:`). A cloud placeholder is not, since the read would download it. Neither is a FLAC a sidecar sheet claimed. The size comes prefetched with the walk's other resource keys, so the gate costs a network volume no stat per file. The emptiness filter uses that size too. The walk drops an empty file itself, and a link by its target's stat. `expandAndFilterList:` stats only the entries no walk listed. `entriesInDirectory:sortedBy:`, the listing a browser draws, judges its files through the same function (`VibeListedFileIsEmpty`), dangling links included.

The playable extensions are `audio/AudioTypes`' `PlayableExtensions`. The walk's filter and the readers' entry rungs both read it, so neither can grow a format the other lacks.

## Playlist files in a walk

**A playlist file expands in place only when it is opened at top level.** Inside a folder walk an M3U is dropped, since it would double every track the walk found.

**A CUE sheet in a walk stands in for its files** (`entriesForWalk:`). Its entries take its sorted place, and the files it names are claimed. A claimed file neither loads whole nor is cut again by a later sheet. Without the claim, `Album.cue` beside `Album (UTF-8).cue` would list every track twice. A sheet's entries must name supported, nonempty files that were listed or are readable. A sheet beside the file outranks the one inside it.

**The walk passes its listing to the readers as `knownFiles`.** Every rung then answers in the listing's spelling, which is what the walk claims. `testEveryResolutionRungClaimsTheListedFileUnderEverySpelling` covers every rung. An entry readable nowhere still yields its primary candidate. That is what lets the walk ask the grant handler for the playlist's folder.

**TRAP: a playlist entry that is a remote placeholder counts as readable before `access(2)` is asked.** Its mode denies its owner, and `access(2)` reads that as a sandbox denial. Asked the other way round, an M3U naming a placeholder raises a grant panel (`expandPlaylistFile:`).

## Tests

`Tests/media/FolderScan/` holds Vibe's tests of the walk and the listing: the extension filter, the folder walk and its orders, the top-level list, playlist files and the grant handler, dataless files, concurrency, and symbolic links. They run over temporary folders and read entries. A windowed entry reads as its file plus its window, through `audio/AudioTypes`' `VibeKeyByAppendingCueWindow`. The embedded-sheet tests write their FLAC headers with `Tests/Support/FLACFixtures.h`. The dataless test sets FileLoading's probe, so the bundle builds with `DEBUG` on in every configuration.

**A temporary folder has two spellings, and both turn up.** `NSTemporaryDirectory()` returns `/var/folders/…`, and `/var` is a link to `/private/var`. The walk answers in the resolved form, while the readers standardize, which drops the `/private` prefix again. The tests resolve their root with `realpath(3)` and strip either spelling when they compare.

The minimal consumer walks a folder of two tracks and an M3U in each order, and opens the M3U alone.

What Vibe adds stays in Vibe: the handlers it installs, its rows made from entries, and the cover rank, with their tests.
