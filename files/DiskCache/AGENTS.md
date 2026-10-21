# files/DiskCache

A bounded disk cache over PINCache. It depends on `third_party/PINCache` and on `core/Common`. **Today it holds what Vibe moved here**: one category, `PINCache (VibeAudioCache)`. Vibe's metadata cache and waveform cache both build their stores through it, so their entries live and die on the same terms.

## The store

**`audioCacheWithName:rootPath:` makes a store with the shared byte and age limits.** Each store may hold 1 GiB on disk. An entry untouched for 180 days ages out, since a changed file identity can orphan entries and nothing else would remove them. A nil root puts the store under the user's caches, and a root of the caller's puts it there instead, as a test does. **TRAP: PINDiskCache applies each limit on its own queue**, so a read right after the store is made can still see PINCache's defaults.

**A store's user reads and writes `diskCache` directly, never the memory cache.** On macOS `PINMemoryCache` never evicts. Its cost limit needs a cost for each entry, a disk hit fills it again at cost 0, and its memory-pressure hooks are iOS only. So it would pin every entry ever loaded for the app's life.

**`audioDiskUsageWithCompletion:` counts the entries and their bytes on disk.** The enumeration blocks, so call it on the store's own serial queue. The completion is dispatched to the main thread.

The keys are the caller's. Vibe keys both stores by `core/Common`'s disk key, `NSURL (Hash)`.

## Tests

Vibe had no tests of this category, so `Tests/files/DiskCache/` is new here. It roots a store in a temporary directory, checks the limits, and reads the usage back on main. The minimal consumer does the same, as an app would.
