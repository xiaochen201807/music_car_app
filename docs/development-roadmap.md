# Development Roadmap

This project started as a WebView wrapper for a remote music site. It is now a
native Flutter music app for landscape car head units.

Status markers:

- `[x]` Implemented and covered by local checks/tests.
- `[~]` Implemented in code, but still needs real-device or real-service
  validation.
- `[ ]` Not implemented yet.

## Current Scope

The current implementation includes a native Flutter shell plus the existing
native audio foundation:

1. `[x]` Flutter renders the main music experience without WebView.
2. `[~]` Flutter is being rebuilt as a portrait-first app. The portrait shell,
   Spotify-inspired home dashboard, compact settings groups, Material 3 theme
   switch, recommendation shelves, timeline, mini-player, and immersive player
   are wired. Regular pages now swipe through a kept-alive `PageView`, while
   the full-screen player opens as an overlay; real-device portrait validation
   remains.
3. `[x]` The UI provides home, search entry, recommendation, now-playing, queue,
   favorites, lyrics entry, and mini-player surfaces.
4. `[x]` In-app update checking and APK installation support remain available.
5. `[x]` `audio_service` and `just_audio` remain the playback/media-session
   foundation.
6. `[~]` Baidu CarLife package probe, launch bridge, platform SDK initialization,
   and current-queue template callbacks are wired; AppKey, real connection, and
   head-unit validation remain pending.
7. `[~]` Android media-button plumbing exists through `audio_service`, with ADB
   fixes for play/pause recursion, busy skip handling, and repeat/shuffle sync;
   full foreground/background/screen-off validation on the packaged build still
   remains.
8. `[~]` iOS Now Playing and remote command behavior are wired through
   background audio/session dependencies, but still need real-device validation.
   The optional Flutter CarPlay plugin is currently disabled because the
   GitHub-hosted Xcode SDK rejects its current Swift CarPlay API usage.

## Target Architecture

The native car-media architecture is:

1. `[x]` Flutter owns the visible UI.
2. `[~]` Flutter loads search, playlist, artwork, and lyric data from native API
   clients.
3. `[x]` Flutter creates a complete native playback queue for search results.
4. `[x]` `audio_service.queue` exposes the complete queue instead of a single
   current item.
5. `[x]` `PlaybackState.queueIndex` points at the active queue item.
6. `[x]` `skipToQueueItem(index)` plays a selected queue item directly.
7. `[~]` `skipToNext`, `skipToPrevious`, and automatic completion use the native
   queue path; real media-button/head-unit validation is still pending.
8. `[x]` Repeat, shuffle, and sequential modes are represented natively.
9. `[x]` Queue and playback state persist locally for app/process restarts.
10. `[x]` Favorite songs persist locally and can be replayed as a native queue.

Implementation record:

- See `docs/work-log.md` for the chronological work log and current evidence.
- See `docs/free-music-api-audit.md` for the FreeMusic API inventory and the
  repeatable endpoint probe script.

## Current Execution Order

The implementation sequence is now gated as follows:

1. `[~]` Complete and test the FreeMusic API client surface first. Keep every
   discovered endpoint documented, even when it is not part of the first UI
   release.
2. `[~]` Redesign the page layout around portrait-first real API data,
   loading, empty, error, retry, playlist, queue, lyrics, and playback states.
   The Spotify-inspired portrait home and compact settings structure are now
   active.
3. `[~]` Harden playback reliability with quality selection, source switching,
   timeouts, and retry behavior. Manual quality tiers are wired, player-load
   failures no longer poison later playback, and resolver/source-switch paths
   preserve the preferred bitrate; real-service validation remains.
4. `[~]` Keep existing Android CarLife SDK work, but resume car-projection
   product integration only after the core app is usable without projection.

## Musify Reference Optimization Track

The sibling `../Musify-master` checkout is useful as a reference for mature
Flutter music-app behavior, but it should stay a reference rather than a source
copy target because Musify is GPL-licensed and its product shape is much larger
than this car/head-unit app.

Reference items to adapt with local implementations:

- `[x]` Playback-state throttling: reduce redundant `audio_service` state
  emissions while preserving active-playback heartbeat and meaningful seek or
  buffering changes.
- `[x]` Stable queue-entry identity: avoid media-browser selection ambiguity
  when a queue contains duplicate songs from the same source.
- `[x]` Completion/error guardrails: track consecutive playback failures and
  stop or skip deterministically after repeated resolver/player errors.
- `[ ]` Playlist/offline download queue: add bounded concurrent downloads and
  cancellable progress for full playlists instead of only per-track cache
  operations.
- `[ ]` API cache policy: add short-lived memory caching for search, playlist,
  lyric, source, and quality calls before adding heavier persistent stores.
- `[~]` Settings notifiers: move cross-page settings such as quality,
  repeat/shuffle, update checks, cache behavior, and projection options behind
  explicit app-level notifiers instead of scattered preference reads. Theme mode
  and default playback bitrate now live in `AppSettingsController`; repeat,
  shuffle, update checks, cache behavior, and projection options remain.

## State And UI Separation Order

Current priority is to shrink `main.dart` into composition and event wiring
only. Keep each extraction behavior-preserving, covered by tests, and small
enough to review.

1. `[x]` Move theme mode and default bitrate persistence into
   `AppSettingsController`.
2. `[x]` Extract `QueueController` as the single owner for queue contents,
   current index, current song, reorder/remove rules, and playback mode.
3. `[~]` Extract `PlaybackController` as the single owner for play, pause,
   skip, seek, volume intent, resolver calls, and coordination with
   `NativeAudioController` / `MusicAudioHandler`. The first controller now
   owns basic playback action dispatch, debounce, queue-action busy state,
   playback mode writes, seek, and volume state; full platform bridge routing
   remains.
4. `[~]` Extract `LibraryController` and `SearchController` for search,
   pagination, recommendations, playlist details, favorites, downloads, lyrics,
   and quality loading. `LibraryController` now owns favorite songs, loading
   state, favorite keys, optimistic favorite toggles, persistence, and rollback
   on save failure. `MusicSearchController` now owns search queries, request-id
   guards, pagination, search/load-more errors, results, recommendation
   playlists, recommendation loading state, and recommendation errors.
   `DownloadController` now owns downloaded-track keys, downloaded-song
   projection, download quality lookup, download stream subscriptions, cache
   deletion, and download completion notifications. Playlist details, lyrics,
   and quality loading still need to move behind controllers.
5. `[x]` Introduce `PlayerUiState`, a view model that UI subscribes to instead
   of recomputing player truth from `AudioHandler`, `MediaItem`, queue lists,
   and page-local fields. `PlayerUiStateController` now owns the
   `AudioHandler` to `PlaybackUiState` projection for app state and the portrait
   shell.
6. `[x]` Extract `PlatformMediaBridge` so lock-screen media buttons, Bluetooth,
   Android CarLife, and future projection integrations call the unified
   controllers instead of page methods.
7. `[x]` After the above chain is stable, compare Musify's local queue model,
   playback state machine, cache policy, and player-page decomposition for
   targeted ideas only.

## Main Risks

- The FreeMusic APIs may change, rate-limit, or return temporary audio URLs.
- Some playable URLs may require request headers, cookies, or referer handling.
- Native queue state must stay consistent across app UI, Android notification,
  media buttons, and head-unit callbacks.
- Android Auto and Apple CarPlay are separate platform integrations; a good
  phone/tablet/car-head-unit app does not automatically become an approved
  Android Auto or CarPlay template app.
- Apple CarPlay full app surfaces require separate iOS project work and
  CarPlay Audio entitlement signing; the current release path keeps that scene
  registration disabled.

## Implementation Phases

### Phase 1: Native UI Shell

- `[x]` Remove the WebView runtime path.
- `[x]` Remove the old embedded browser dependency.
- `[x]` Remove the standalone WebView probe script.
- `[x]` Add the iOS-style car music design asset under `docs/ui`.
- `[x]` Build a native Flutter shell with large touch targets and a landscape
  layout.
- `[~]` Align the primary prototype states: home/search, full-screen now
  playing, playback queue, and persistent mini-player. Settings now carries the
  larger CarLife/update actions so the home page stays focused on music.
- `[x]` Keep app update checking reachable from the native UI.

Exit criteria:

- `[x]` Widget tests render the native shell.
- `[x]` Static search finds no WebView dependency or runtime references in
  `lib`, `test`, `pubspec.yaml`, or `pubspec.lock`.

### Phase 2: Native Data Sources

- `[x]` Add native search API methods with result pagination support.
- `[x]` Audit the upstream `/api/v1/freemusic` surface and add a repeatable
  PowerShell probe script under `scripts/test_free_music_api.ps1`.
- `[~]` Add recommendation loading, playlist detail browsing, and offset-based
  playlist pagination; offline and large-playlist validation is still pending.
- `[~]` Add typed client methods for sources, hot search, suggestions,
  playlist search, album search, artist search, album songs, qualities, YRC,
  source switching, charts, and personal FM. Sources, hot search, qualities,
  and YRC are now implemented.
- `[~]` Add artwork plus lyric loading and playback-position lyric highlighting
  from search/playback metadata. Lyrics now prefer `/yrc` and fall back to
  `/lyric`.
- `[~]` Replace demo UI data with real API-backed models for paged search,
  queue, and recommended playlists.
- `[~]` Add loading, empty, retry, and offline states for search and the
  prototype-aligned recommendation surface. Home recommendation cards and the
  search results area now stay visible above the mini-player; richer offline
  recovery remains pending.
- `[x]` Add a local favorites list backed by `SharedPreferences`, with favorite
  toggles in search, playlist rows, and now-playing surfaces.
- `[x]` Apply the cold glassmorphism UI design system with shared tokens,
  `GlassCard`, cached artwork placeholders, and the rebuilt home
  recommendation grid.
- `[~]` Add a portrait-first Material 3 shell with dynamic artwork color,
  recommendation grid, timeline, bottom mini-player/navigation, and immersive
  full-screen player. The portrait shell now pauses visual animation work while
  backgrounded, disables the heaviest glass effects during page motion, removes
  the waveform seekbar, uses a paper-style light theme, splits high-frequency
  playback position updates away from stable page rebuilds, and preserves
  dynamic album-color atmosphere in dark mode; full real-device visual
  validation remains pending.
- `[~]` Use audited API data in the prototype UI: source labels, hot search
  chips, recommendation playlists, queue songs, quality chips, and lyric
  preview are wired to FreeMusic responses where client coverage exists.

Exit criteria:

- `[x]` The app can search and select real songs without a WebView.
- `[~]` Song metadata, artwork, paged playlist songs, and synced lyric
  highlighting appear in the native UI for API-backed playback. The player now
  supports draggable seek, inline resolving/buffering state, lyric retry, manual
  lyric scroll lock/restore, and quality-switch progress preservation; slow-net
  and real-device validation remains pending.

### Phase 3: Complete Native Queue

- `[x]` Store the full queue in the audio layer.
- `[x]` Publish complete `audio_service.queue` metadata.
- `[x]` Publish correct `PlaybackState.queueIndex`.
- `[x]` Implement `skipToQueueItem(index)`.
- `[x]` Implement repeat, shuffle, and sequential playback modes.
- `[x]` Let the native queue decide the next item after completion.
- `[x]` Persist queue and current playback item locally.

Exit criteria:

- `[~]` Notification and media-button previous/next/seek controls are wired in
  code; foreground/background/screen-off real-device validation is still
  pending.
- `[ ]` Selecting a queue item from a compatible car/media surface starts that
  item directly.

### Phase 4: Android Car Validation

- `[~]` Keep Android Auto media metadata and media-browser service declarations
  valid.
- `[~]` Validate Android media buttons by ADB and real device logs. ADB
  reproduction on `V2284A` found pause/skip command recursion and input latency;
  the code path is patched and still needs packaged-build retest.
- `[ ]` Validate compatible car head-unit controls.
- `[ ]` Validate notification controls while the app is backgrounded.

Exit criteria:

- `[ ]` A compatible Android car system can pause, resume, skip, and browse the
  native queue.

### Phase 5: Baidu CarLife

- `[x]` Add Android package visibility declarations for common CarLife packages.
- `[x]` Add Flutter service wrapper for CarLife status, launch, and structured
  playback-context sync calls.
- `[x]` Add Android MethodChannel implementation for package probe, launch
  fallback, AppKey status, and playback-context sync.
- `[x]` Keep the CarLife service bridge available while hiding the phone-app
  settings entry until product validation resumes.
- `[~]` Link `Carlife_android_platformsdk_2.2.0.jar`; project AppKey,
  certification, and official integration validation are still pending.
- `[~]` Replace the cache-only `syncPlaybackContext` placeholder with SDK
  initialization, jump, album-list, and song-list callbacks; live CarLife
  connection and audio-byte streaming remain pending.
- `[x]` Cache current queue, metadata, artwork, current audio URL, and playback
  state in the Android CarLife bridge.
- `[~]` Route CarLife song-data selection requests to Flutter queue-item
  playback; play, pause, next, and previous callbacks are not exposed by the
  current SDK jar and need approved-SDK validation.
- `[ ]` Validate on a CarLife-capable head unit.

Exit criteria:

- `[ ]` A CarLife-capable car system can discover/sync music content and control
  playback through the native audio queue.

### Phase 6: Apple CarPlay Evaluation

- `[ ]` Evaluate `flutter_carplay` on a dedicated iOS branch.
- `[ ]` Add a minimal CarPlay root template with tabs or lists.
- `[ ]` Connect CarPlay list selection to the native queue.
- `[ ]` Connect CarPlay Now Playing metadata and controls.
- `[ ]` Validate in Xcode CarPlay Simulator.
- `[ ]` Validate entitlement/signing requirements separately from Android APK
  releases.

Exit criteria:

- `[ ]` The iOS app can show a CarPlay music surface in the simulator or a
  properly signed real-device setup.

## Release And Online Update Status

- `[x]` Android GitHub Actions builds release APKs with `--split-per-abi`.
- `[x]` `v*` tag builds generate `update.json` and attach it to the GitHub
  Release with the APK assets.
- `[x]` `v*` tag builds publish Android APKs and the latest `update.json` to
  Cloudflare R2, with APK asset URLs preferring R2 and GitHub Release URLs kept
  as fallbacks.
- `[x]` Cloudflare R2 release directories are pruned after upload, keeping only
  the newest 3 `v*` versions under the project prefix.
- `[x]` The app checks `MUSIC_CAR_UPDATE_MANIFEST_URL` first when configured.
- `[x]` The app falls back to the GitHub latest release API when no custom
  manifest is configured.
- `[x]` The app chooses the best APK for the device ABI before downloading.
- `[x]` Android uses `DownloadManager` plus a polling fallback to open the
  system installer after download.
- `[~]` iOS unsigned IPA artifacts are built by GitHub Actions, but installation
  still requires a separate Apple signing flow.
