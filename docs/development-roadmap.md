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
2. `[~]` Flutter is being rebuilt as a portrait-first app. The first portrait
   shell, Material 3 theme switch, recommendation grid, timeline, mini-player,
   and immersive player are wired. Regular pages now swipe through a kept-alive
   `PageView`, while the full-screen player opens as an overlay; real-device
   portrait validation remains.
3. `[x]` The UI provides home, search entry, recommendation, now-playing, queue,
   favorites, lyrics entry, and mini-player surfaces.
4. `[x]` In-app update checking and APK installation support remain available.
5. `[x]` `audio_service` and `just_audio` remain the playback/media-session
   foundation.
6. `[~]` Baidu CarLife package probe, launch bridge, platform SDK initialization,
   and current-queue template callbacks are wired; AppKey, real connection, and
   head-unit validation remain pending.
7. `[~]` Android media-button plumbing exists through `audio_service`, but real
   head-unit behavior still needs device validation after the native queue is
   fully connected.
8. `[~]` iOS Now Playing and remote command behavior are wired through
   background audio/session dependencies, but still need real-device validation.

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
   The first Namida-inspired portrait shell is now active.
3. `[ ]` Harden playback reliability with quality selection, source switching,
   timeouts, and retry behavior.
4. `[~]` Keep existing CarLife SDK work, but resume CarLife product integration
   only after the core app is usable without projection.

## Main Risks

- The FreeMusic APIs may change, rate-limit, or return temporary audio URLs.
- Some playable URLs may require request headers, cookies, or referer handling.
- Native queue state must stay consistent across app UI, Android notification,
  media buttons, and head-unit callbacks.
- Android Auto and Apple CarPlay are separate platform integrations; a good
  phone/tablet/car-head-unit app does not automatically become an approved
  Android Auto or CarPlay template app.
- Apple CarPlay full app surfaces require iOS project work and CarPlay Audio
  entitlement signing.

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
  full-screen player with waveform seekbar. Download/cache UI and full
  real-device visual validation remain pending.
- `[~]` Use audited API data in the prototype UI: source labels, hot search
  chips, recommendation playlists, queue songs, quality chips, and lyric
  preview are wired to FreeMusic responses where client coverage exists.

Exit criteria:

- `[x]` The app can search and select real songs without a WebView.
- `[~]` Song metadata, artwork, paged playlist songs, and synced lyric
  highlighting appear in the native UI for API-backed playback.

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
- `[ ]` Validate Android media buttons by ADB and real device logs.
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
- `[x]` Add native UI entry card for `百度 CarLife`.
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
- `[x]` The app checks `MUSIC_CAR_UPDATE_MANIFEST_URL` first when configured.
- `[x]` The app falls back to the GitHub latest release API when no custom
  manifest is configured.
- `[x]` The app chooses the best APK for the device ABI before downloading.
- `[x]` Android uses `DownloadManager` plus a polling fallback to open the
  system installer after download.
- `[~]` iOS unsigned IPA artifacts are built by GitHub Actions, but installation
  still requires a separate Apple signing flow.
