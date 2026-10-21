# third_party/PINOperation

[PINOperation](https://github.com/pinterest/PINOperation), Pinterest's operation queue, which `third_party/PINCache` runs on. Other authors' code: **do not restyle it.** It depends on nothing. Its template is `VibeLibsPINOperation`.

## Building

Its files import each other as `<PINOperation/...>`, so the template searches `third_party/` itself, and this directory too. Its sources build with the static analyzer off and `-Wno-documentation-html`. `LICENSE.txt` and `PrivacyInfo.xcprivacy` stay out of an app's bundle.

## Fixes of our own

**`PINOperationQueue.m` is modified once**, marked `Vibe:` as PINCache's changes are. Its semaphore queue runs at utility QoS. Without that, a user-initiated enqueue waits on a semaphore that utility operations signal. The Thread Performance Checker flags that priority inversion.

## License

Apache License 2.0, in `LICENSE.txt`. Copyright (c) 2015 Pinterest. `THIRD-PARTY-NOTICES.md` at the repo root has the notice.
