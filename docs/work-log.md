# Work Log

This file keeps the implementation record inside the repository so progress is
not dependent on chat context.

## 2026-06-09

Objective: build a native music app with common car music features and Baidu
CarLife support.

Current evidence:

- The Flutter app already renders a native landscape music shell instead of a
  WebView.
- The search tab can call the FreeMusic `/search` endpoint directly and select
  real songs into the native playback queue.
- Playback uses `audio_service` plus `just_audio`.
- `NativeAudioController` can resolve FreeMusic song URLs, persist a queue, and
  skip through a synced probe queue.
- Android exposes a CarLife MethodChannel for package probe, launch fallback,
  and a placeholder playback sync call.
- `docs/development-roadmap.md` tracks the larger implementation phases.

Open gaps toward the full goal:

- Recommendations, playlists, artwork image rendering, and lyrics are not yet
  fully API-backed in the Flutter UI.
- Repeat modes and shuffle mode need native behavior.
- CarLife SDK/AAR integration is still missing; current support is package
  probe and launch fallback only.
- Real Android head-unit and CarLife-capable device validation is still needed.

Next implementation focus:

- Publish the complete playback queue through `audio_service`.
- Route `skipToQueueItem` through the native queue.
- Add repeat/shuffle state handling in the native audio controller.
- Keep tests and roadmap status updated with each increment.

Implemented in this increment:

- `MusicAudioHandler.loadFromSnapshot` now publishes a complete queue from the
  probe playlist when present.
- `PlaybackState.queueIndex` now reflects the active queue item.
- `MusicAudioHandler.skipToQueueItem` and `playMediaItem` now route queue
  selections to a native callback.
- `NativeAudioController.skipToQueueIndex` can resolve and play a selected queue
  item directly.
- Tests cover complete queue publication and direct queue-item playback.

Build and release execution requirement added:

- AI agents must not create release packages locally unless explicitly asked.
- Deliverable builds must be produced by committing and pushing to GitHub, then using GitHub Actions artifacts or releases.
- The rule is recorded in root `AGENTS.md`.

Implemented in this increment:

- `FreeMusicApi.searchSongs` now calls the discovered FreeMusic search endpoint
  with `q`, `type=song`, `page`, and optional `sources` query parameters.
- `FreeMusicSearchResult` and extended `FreeMusicSong` metadata parse search
  results defensively, including null song lists.
- The native search tab now has a real search input, loading, empty, and error
  states.
- Tapping a search result resolves and plays that song through
  `NativeAudioController.syncFromProbe`, while syncing the whole search result
  page into the native queue.
- The queue panel now shows the real search-backed queue after playback starts,
  with the existing demo queue retained only as an empty-state placeholder.

Verification in this increment:

- `dart format lib/free_music_api.dart lib/main.dart test/free_music_api_test.dart`
- `flutter analyze`
- `flutter test`

Packaging note:

- No local release package was built. Release packaging remains delegated to
  GitHub Actions after commit and push.
