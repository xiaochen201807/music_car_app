# Work Log

This file keeps the implementation record inside the repository so progress is
not dependent on chat context.

## 2026-06-10 - Portrait Namida-Inspired UI Foundation

Implemented in this increment:

- Created the first portrait-first native shell on the
  `codex/portrait-music-redesign` branch while keeping the existing FreeMusic
  API, native playback controller, audio service, favorites, and CarLife
  service paths intact.
- Changed app orientation preference from landscape to portrait.
- Added Material 3 Light/Dark theme support with a settings-page theme mode
  switch.
- Added cover-palette extraction through `palette_generator` and used the
  current artwork color as a dynamic seed for the portrait UI.
- Replaced the default visible shell with a portrait layout: home search hero,
  recommendation grid cards, playback timeline, library page, bottom mini
  player/navigation, and an immersive full-screen player.
- Added a Namida-inspired waveform seekbar and hooked it to the existing
  `audio_service` seek path.
- Kept CarLife controls reachable from the portrait settings page.

Verification in this increment:

- Updated the widget test to cover the portrait shell, library page, player
  page, and settings page.

## 2026-06-10 - Local Favorites List

Implemented in this increment:

- Added a local `FavoriteSongStore` backed by `SharedPreferences`, preserving
  FreeMusic song metadata and de-duplicating by source plus song id.
- Added a side-navigation Favorites tab with an empty state, song count, play
  all action, per-song playback, and remove-from-favorites control.
- Added favorite toggles to search results, playlist song rows, the side
  now-playing panel, and the full-screen now-playing panel.
- Kept the active favorite visual treatment on the red heart only; surrounding
  cards and inactive buttons continue to use neutral glass tokens.

Verification in this increment:

- Added `test/favorite_song_store_test.dart` for persistence, de-duplication,
  metadata restoration, and favorite key generation.

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
- Android links the Baidu CarLife platform SDK jar, exposes a CarLife
  MethodChannel for package probe, launch fallback, AppKey status, and playback
  context sync, and can answer SDK album/song-list requests from the current
  native queue.
- `docs/development-roadmap.md` tracks the larger implementation phases.

Open gaps toward the full goal:

- Playlist first-page loading is API-backed; load-more pagination and full
  playlist detail browsing are still pending.
- Lyrics are API-backed for the current search/playback queue, but lyric timing
  is not yet synchronized to the playback position.
- Repeat, shuffle, artwork loading, and queue behavior still need real
  media-button/head-unit and real-service validation.
- CarLife platform SDK wiring is in progress, but project AppKey provisioning,
  real CarLife connection, audio-byte streaming, and CarLife-capable head-unit
  validation are still needed.
- Real Android head-unit and CarLife-capable device validation is still needed.

Next implementation focus:

- Complete the FreeMusic API client surface from `docs/free-music-api-audit.md`.
- Redesign the landscape page layout around real API data and robust loading,
  empty, error, retry, queue, lyrics, and playback states.
- Keep existing CarLife work, but defer further CarLife product integration
  until the main app is usable without projection.
- Keep tests and roadmap status updated with each increment.

## 2026-06-09 - FreeMusic API Audit

Implemented in this increment:

- Revalidated `https://music.sy110.eu.org/music` after the local proxy was
  disabled; requests now run with direct connectivity.
- Located the web music API helper in `assets/main-CTVbnThO.js` and preserved
  the full discovered `/api/v1/freemusic` endpoint inventory.
- Added `docs/free-music-api-audit.md` covering public read-only APIs,
  authenticated read-only APIs, mutating APIs, observed models, and the new
  API-first execution order.
- Added `scripts/test_free_music_api.ps1`, a repeatable endpoint probe. It
  tests all public read-only endpoints, checks authenticated read-only endpoints
  for `200` or expected `401`, and lists mutating endpoints while skipping them
  by default.
- Preserved existing CarLife progress in the plan, but moved further CarLife
  product work behind API completion, usable UI layout, and playback
  reliability.

Verification in this increment:

- `.\scripts\test_free_music_api.ps1`

Result:

- All public read-only endpoint probes passed.
- Authenticated library endpoints returned expected `401` without login, except
  `/recommend-playlists` and `/config`, which are currently readable and
  returned `200`.
- Mutating endpoint probes were skipped by default.

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

## 2026-06-09 - CarLife Platform SDK Bridge

Implemented in this increment:

- Split CarLife SDK-linked status from AppKey configuration status so the UI can
  distinguish `sdk_platform_unconfigured`, initialized, and connected states.
- Added current `audioUrl` to the Flutter CarLife playback context and Android
  context cache, allowing the active `CLSong.mediaUrl` to carry the resolved
  HTTP playback URL when available.
- Android now retains the CarLife MethodChannel and maps `CLGetSongDataReq`
  into a Flutter `selectQueueItem` control callback before returning an
  explicit `audio_stream_not_available` SDK response.
- The Android SDK callback now serves album-list and song-list requests from
  the cached native queue while keeping `audio_service`/Flutter playback as the
  single playback authority.
- Updated CarLife documentation, README notes, and roadmap status to describe
  the platform SDK bridge, AppKey requirement, current queue-template support,
  and remaining real-device/audio-stream gaps.

Verification in this increment:

- `dart format lib/main.dart lib/services/carlife_service.dart test/carlife_service_test.dart`
- `flutter analyze`
- `flutter test`

Android compile note:

- Android Kotlin compile could not be run directly because this checkout has
  `android/gradle/wrapper/gradle-wrapper.properties` but no `gradlew`,
  `gradlew.bat`, or wrapper jar, and no system Gradle/Kotlin compiler was
  available. No local `flutter build apk` was run because release/deliverable
  packaging remains delegated to GitHub Actions.

Packaging note:

- No local release package was built. Release packaging remains delegated to
  GitHub Actions after commit and push.

## 2026-06-09 - Design-System UI Rebuild

Implemented in this increment:

- Added `lib/theme/design_tokens.dart` as the UI token source for the cold
  palette, spacing, radii, type styles, shadows, glass alpha values, and
  restricted accent gradient.
- Added `lib/widgets/glass_card.dart` with shared `GlassCard` and `GlassPill`
  implementations using clipped `BackdropFilter` blur.
- Reworked `lib/main.dart` to use the cold atmosphere background, neutral
  glass surfaces, tokenized radii, the spec-aligned 3 hero + 5 square home
  recommendation grid, gradient progress bars, and unified circular transport
  controls.
- Closed the mini-player ghost-circle bug by replacing the mini transport
  `IconButton.styleFrom(fixedSize: ...)` path with a single
  `_CircleControlButton` based on `Container + CircleBorder + InkWell`.
- Added `cached_network_image: 3.4.1` and routed artwork through cached image
  loading with placeholder and error states.
- Removed the old warm demo colors and restricted the accent gradient to the
  approved UI locations: primary play controls, progress played segments, and
  active navigation/queue indicators.

Verification in this increment:

- `dart format lib/main.dart lib/theme/design_tokens.dart lib/widgets/glass_card.dart`
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `rg "0xFFFF5C93|0xFFFFB86B|Image\\.network|IconButton\\.styleFrom\\(" lib`
- `rg --pcre2 "BorderRadius\\.circular\\((?!AppRadius|radius|borderRadius)" lib`

Packaging note:

- No local release package was built. Release packaging remains delegated to
  GitHub Actions after commit and push.

## 2026-06-09 - Home/Search Visibility Fix

Implemented in this increment:

- Changed startup music loading to initialize FreeMusic sources and hot-search
  keywords before requesting recommendations, so `/recommend` uses the same
  active source list as search.
- Reworked the home music surface into a compact search strip plus a dedicated
  recommendation-card area, keeping playlist cards visible above the persistent
  mini-player on landscape screens.
- Reworked the search surface into a compact search strip plus a dedicated
  results area with a visible result count, clearer landing state, and retained
  load-more behavior.
- Removed the unused home readiness strip after the layout was simplified.
- Made `scripts/test_free_music_api.ps1` compatible with default Windows
  PowerShell by avoiding raw non-ASCII query literals and adding
  `-UseBasicParsing` for `Invoke-WebRequest`.
- Bumped the app version to `1.0.15+15` for the follow-up UI/API visibility
  release.

Verification in this increment:

- `dart format lib/main.dart`
- `flutter analyze`
- `flutter test`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test_free_music_api.ps1`

Observed API status:

- The repeatable FreeMusic probe now passes for the non-mutating endpoints,
  including `/sources`, `/search`, `/search/hot`, `/recommend`,
  `/playlist/page`, `/song_url`, `/lyric`, `/yrc`, qualities, charts, and
  authenticated endpoints that are expected to return `401` without login.

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

## 2026-06-09 - Prototype UI State Alignment

Implemented in this increment:

- Reworked the landscape shell around the prototype states in
  `docs/ui/native-ios-music-app-design.png` instead of only adjusting the home
  page.
- Simplified the default recommendation/home page into a focused online-library
  card with a prominent search field, horizontal recommendation cards, and a
  compact readiness strip.
- Added a dedicated full-screen `正在播放` page with large album artwork,
  lyric preview, quality chips, progress, and large transport controls.
- Reworked the `播放队列` page into the prototype-style numbered queue list
  with clear/edit action slots, selected-track emphasis, and drag-handle
  affordances.
- Reworked the bottom mini-player into a persistent compact state with artwork,
  title/artist, progress, primary transport controls, playback mode, and lyrics
  access.
- Moved the large `百度 CarLife` card out of the home page and into `设置`, so
  the integration remains available without cluttering the main music task.

Verification in this increment:

- `dart format lib/main.dart test/widget_test.dart`
- `flutter analyze`
- `flutter test test/widget_test.dart`

Packaging note:

- No local release package was built. Release packaging remains delegated to
  GitHub Actions after commit and push.

## 2026-06-09 - Prototype UI API Wiring

Implemented in this increment:

- Added typed `FreeMusicApi` coverage for the already audited public endpoints:
  `/sources`, `/search/hot`, `/qualities`, and `/yrc`.
- The app now loads `/sources` and `/search/hot` at startup. Source metadata is
  used for source labels and the default source list is passed into search and
  recommendation requests.
- Home/search UI now shows real hot keyword chips from `/search/hot`; tapping a
  keyword writes it into the search field and runs `/search`.
- Song playback now refreshes available quality metadata from `/qualities`, and
  the full-screen now-playing page renders those quality chips instead of fixed
  prototype labels.
- Lyrics loading now tries `/yrc` first through `fetchEnhancedLyrics`, then
  falls back to `/lyric`; the full-screen now-playing page renders the current
  and next lyric lines from the parsed API result.
- Follow-up fix: `/search` and `/recommend` source filters must be serialized
  as repeated `sources=netease&sources=kuwo` parameters. A comma-joined
  `sources=netease,kuwo` value returns HTTP 200 with empty result sets, which
  made the UI look like recommendations and search were unavailable.

Verification in this increment:

- `dart format lib/free_music_api.dart lib/main.dart test/free_music_api_test.dart test/widget_test.dart`
- `flutter analyze`
- `flutter test test/free_music_api_test.dart test/widget_test.dart`
- `.\scripts\test_free_music_api.ps1`

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

## 2026-06-09 - Media Seek Controls

Implemented in this increment:

- `MusicAudioHandler` now implements `fastForward` and `rewind` for 15-second
  relative seeking.
- `seekForward(begin)` and `seekBackward(begin)` now support press-and-hold
  style media-session controls with repeated bounded seeks.
- Seek operations are clamped to the current media duration and never seek below
  zero.
- Tests cover fast-forward, rewind, and immediate seek-forward/seek-backward
  behavior for notification/head-unit media controls.

Verification in this increment:

- `dart format lib/music_audio_handler.dart test/music_audio_handler_test.dart`
- `flutter analyze`
- `flutter test test/music_audio_handler_test.dart`

ADB status:

- `adb version` works locally.
- No Android device was connected when checked with `adb devices -l`.

Packaging note:

- No local release package was built. Release packaging remains delegated to
  GitHub Actions after commit and push.

## 2026-06-09 - Auto Queue Completion

Implemented in this increment:

- `MusicAudioHandler` next/previous callbacks now return whether the native
  queue actually handled the request.
- Natural track completion now asks `NativeAudioController` for the next queue
  item, preserving sequential, repeat-all, repeat-one, and shuffle behavior.
- Sequential playback at the end of the queue now stops cleanly instead of
  staying in a repeated completed auto-skip state.
- The app UI callback still refreshes the selected queue item, lyrics, and
  CarLife playback context only after a real queue transition occurs.

Verification in this increment:

- `dart format lib/music_audio_handler.dart lib/main.dart test/music_audio_handler_test.dart`
- `flutter test test/music_audio_handler_test.dart`
- `flutter test test/native_audio_controller_test.dart`

Packaging note:

- No local release package was built. Release packaging remains delegated to
  GitHub Actions after commit and push.

