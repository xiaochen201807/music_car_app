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
- Tapping a recommended playlist loads the first `/playlist/page` result page
  and hands those songs to the native playback queue.
- Playback uses `audio_service` plus `just_audio`.
- `NativeAudioController` can resolve FreeMusic song URLs, persist a queue, and
  skip through a synced probe queue.
- Native playback modes now cover sequential, repeat-all, repeat-one, and
  shuffle behavior, and the selected mode is persisted.
- Android exposes a CarLife MethodChannel for package probe, launch fallback,
  and a placeholder playback sync call.
- `docs/development-roadmap.md` tracks the larger implementation phases.

Open gaps toward the full goal:

- Playlist first-page loading is API-backed; load-more pagination and full
  playlist detail browsing are still pending.
- Lyrics are API-backed for the current search/playback queue, but lyric timing
  is not yet synchronized to the playback position.
- Repeat, shuffle, artwork loading, and queue behavior still need real
  media-button/head-unit and real-service validation.
- CarLife SDK/AAR integration is still missing; current support is package
  probe and launch fallback only.
- Real Android head-unit and CarLife-capable device validation is still needed.

Next implementation focus:

- Add playlist load-more pagination and richer playlist detail browsing.
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

- Added `FreeMusicPlaylistPage` and `FreeMusicApi.fetchPlaylistSongs`, calling
  `/playlist/page` with `id`, `source`, `offset`, and `size`.
- Recommended playlist selection now loads the first page of songs and plays the
  first item through the same native queue path used by search results.
- Playlist-loaded songs become the visible playback queue and keep lyrics,
  artwork, media-session queue metadata, and skip controls on the existing
  native audio path.
- The home recommendation lists now show a loading state while playlist songs
  are being fetched.

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

## 2026-06-09 - Playlist Detail Pagination

Implemented in this increment:

- Recommended playlist cards now open a native playlist detail sheet instead of
  immediately replacing playback with the first page.
- The playlist sheet shows playlist cover, creator/source metadata, loaded song
  count, total count, song artwork, artist/album text, and duration.
- Playlist songs are fetched through `/playlist/page` with offset-based paging
  and a native load-more/retry footer.
- Selecting any loaded playlist song starts playback from that song while using
  the currently loaded playlist page range as the native queue.

Verification in this increment:

- `dart format lib/main.dart`
- `flutter analyze`
- `flutter test`

Packaging note:

- No local release package was built. Release packaging remains delegated to
  GitHub Actions after commit and push.

## 2026-06-09 - CarLife Playback Context Cache

Implemented in this increment:

- Added a structured `CarLifePlaybackContext` model for current song metadata,
  artwork, duration, position, playback state, queue items, and active queue
  index.
- The Flutter CarLife bridge now sends the full playback context over the
  `music_car_app/carlife` MethodChannel instead of only title, artist, and
  playing state.
- Android `MainActivity` now normalizes and caches the latest CarLife playback
  context, returning a context summary while still reporting `sdk_missing` until
  a real Baidu CarLife SDK adapter is linked.
- The native CarLife card can manually sync the current playback context, and
  opening CarLife first attempts a silent context sync.
- Search, playlist selection, queue selection, and media next/previous actions
  now refresh the CarLife context cache after the native queue changes.
- Media next/previous UI state now follows `NativeAudioController.currentIndex`,
  so shuffle and repeat modes do not desynchronize the visible queue index.

Verification in this increment:

- `dart format lib/main.dart lib/services/carlife_service.dart test/carlife_service_test.dart`
- `flutter analyze`
- `flutter test test/carlife_service_test.dart`

Packaging note:

- No local release package was built. Release packaging remains delegated to
  GitHub Actions after commit and push.

## 2026-06-09 - Synced Lyric Highlighting

Implemented in this increment:

- The native lyric sheet now subscribes to `audio_service` playback position
  while open.
- Parsed LRC lyrics use the current playback position to identify the active
  lyric line.
- The active lyric line is visually highlighted and automatically scrolled near
  the center of the lyric sheet for car-screen readability.
- Added a pure `activeLyricLineIndex` helper with tests for pre-roll, in-line,
  boundary, and post-song lyric positions.

Verification in this increment:

- `dart format lib/main.dart test/lyrics_sync_test.dart`
- `flutter analyze`
- `flutter test test/lyrics_sync_test.dart test/widget_test.dart`

Packaging note:

- No local release package was built. Release packaging remains delegated to
  GitHub Actions after commit and push.

## 2026-06-09 - Search Result Pagination

Implemented in this increment:

- Native search now tracks FreeMusic `page` and `hasMore` metadata.
- Search results can load additional pages without replacing the existing list.
- The search result footer shows loading, retry, load-more, and all-loaded
  states using the shared load-more control.
- Selecting any loaded search result still builds the native playback queue from
  the full loaded result set, so media buttons and CarLife context sync can use
  the expanded queue.

Verification in this increment:

- `dart format lib/main.dart`
- `flutter analyze`
- `flutter test`

Packaging note:

- No local release package was built. Release packaging remains delegated to
  GitHub Actions after commit and push.
