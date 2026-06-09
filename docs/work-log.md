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
- Search result artwork is retained in the native song model, persisted with the
  queue, published to `audio_service.queue`, and shown in the native UI when a
  cover URL is available.
- The app can fetch FreeMusic synced LRC lyrics and show them in a native lyric
  sheet from the mini-player.
- The home page can load FreeMusic recommended playlists from `/recommend` and
  render them with real playlist artwork and metadata.
- Playback uses `audio_service` plus `just_audio`.
- `NativeAudioController` can resolve FreeMusic song URLs, persist a queue, and
  skip through a synced probe queue.
- Native playback modes now cover sequential, repeat-all, repeat-one, and
  shuffle behavior, and the selected mode is persisted.
- Android exposes a CarLife MethodChannel for package probe, launch fallback,
  and a placeholder playback sync call.
- `docs/development-roadmap.md` tracks the larger implementation phases.

Open gaps toward the full goal:

- Playlist song pagination/loading is not fully API-backed yet.
- Lyrics are API-backed for the current search/playback queue, but lyric timing
  is not yet synchronized to the playback position.
- Repeat, shuffle, artwork loading, and queue behavior still need real
  media-button/head-unit and real-service validation.
- CarLife SDK/AAR integration is still missing; current support is package
  probe and launch fallback only.
- Real Android head-unit and CarLife-capable device validation is still needed.

Next implementation focus:

- Add playlist detail/song loading and queue handoff from recommended playlists.
- Synchronize lyric highlighting to playback position.
- Continue CarLife SDK integration beyond package probe and launch fallback.
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

Implemented in this increment:

- Added `FreeMusicPlaylist` and `FreeMusicRecommendResult` models.
- Added `FreeMusicApi.fetchRecommendations`, calling `/recommend` with optional
  `sources` filtering and defensive playlist parsing.
- The native home page now loads recommendations on startup and replaces the
  demo home list with real recommended playlist rows when available.
- Recommended playlist rows show real artwork, creator/source, track count, and
  a placeholder selection path for the next playlist-detail increment.

Verification in this increment:

- `dart format lib/free_music_api.dart lib/main.dart test/free_music_api_test.dart`
- `flutter analyze`
- `flutter test`

Packaging note:

- No local release package was built. Release packaging remains delegated to
  GitHub Actions after commit and push.

Implemented in this increment:

- Discovered the FreeMusic lyric endpoint used by the remote frontend:
  `/lyric?id=...&source=...&name=...&artist=...`.
- Added `FreeMusicApi.fetchLyrics`, `FreeMusicLyrics`, and
  `FreeMusicLyricLine` with LRC timestamp parsing and multi-timestamp line
  expansion.
- Search result playback and queue item selection now trigger lyric loading for
  the active `FreeMusicSong`.
- The mini-player lyric control opens a native lyric sheet with loading, error,
  empty, raw-text, and parsed synced-line states.

Verification in this increment:

- `dart format lib/free_music_api.dart lib/main.dart test/free_music_api_test.dart`
- `flutter analyze`
- `flutter test`

Packaging note:

- No local release package was built. Release packaging remains delegated to
  GitHub Actions after commit and push.

Implemented in this increment:

- `PlayerProbeSnapshot` and persisted queue JSON now retain `FreeMusicSong`
  album and cover metadata.
- Queue item loading passes song cover URLs into the playback snapshot, so the
  current `MediaItem` can expose artwork.
- `MusicAudioHandler` now publishes album and `artUri` metadata for every item
  in `audio_service.queue`.
- The native UI now uses a shared artwork view that loads network cover images
  for search results, queue rows, the now-playing panel, and the mini-player,
  with the previous gradient tile retained as a fallback.

Verification in this increment:

- `dart format lib/native_audio_controller.dart lib/music_audio_handler.dart lib/main.dart test/music_audio_handler_test.dart test/native_audio_controller_test.dart`
- `flutter analyze`
- `flutter test`

Packaging note:

- No local release package was built. Release packaging remains delegated to
  GitHub Actions after commit and push.

Implemented in this increment:

- Added `NativePlaybackMode` with sequential, repeat-all, repeat-one, and
  shuffle modes.
- `NativeAudioController.skipToNext` and `skipToPrevious` now respect the
  selected playback mode, including queue wrapping and random item selection.
- Playback mode is persisted with the native queue state and restored after app
  restart.
- `MusicAudioHandler` now publishes `AudioServiceRepeatMode` and
  `AudioServiceShuffleMode` through `PlaybackState`, and accepts media-session
  repeat/shuffle commands.
- The native UI exposes a playback-mode control in both the main now-playing
  panel and mini-player.

Verification in this increment:

- `dart format lib/native_audio_controller.dart lib/music_audio_handler.dart lib/main.dart test/native_audio_controller_test.dart test/music_audio_handler_test.dart`
- `flutter analyze`
- `flutter test`

Packaging note:

- No local release package was built. Release packaging remains delegated to
  GitHub Actions after commit and push.
