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
2. `[x]` Flutter forces landscape orientation, immersive mode, and wakelock for
   car head units.
3. `[x]` The UI provides home, search entry, recommendation, now-playing, queue,
   lyrics entry, and mini-player surfaces.
4. `[x]` In-app update checking and APK installation support remain available.
5. `[x]` `audio_service` and `just_audio` remain the playback/media-session
   foundation.
6. `[x]` Baidu CarLife first-stage package probe and launch bridge are exposed
   through a Flutter/Android MethodChannel.
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

Implementation record:

- See `docs/work-log.md` for the chronological work log and current evidence.

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
- `[x]` Keep app update checking reachable from the native UI.

Exit criteria:

- `[x]` Widget tests render the native shell.
- `[x]` Static search finds no WebView dependency or runtime references in
  `lib`, `test`, `pubspec.yaml`, or `pubspec.lock`.

### Phase 2: Native Data Sources

- `[x]` Add native search API methods.
- `[~]` Add recommendation loading, playlist detail browsing, and offset-based
  playlist pagination; offline and large-playlist validation is still pending.
- `[~]` Add artwork and lyric loading from search/playback metadata.
- `[~]` Replace demo UI data with real API-backed models for search, queue, and
  recommended playlists.
- `[~]` Add loading, empty, retry, and offline states for search.

Exit criteria:

- `[x]` The app can search and select real songs without a WebView.
- `[~]` Song metadata, artwork, lyrics, and paged playlist songs appear in the
  native UI for API-backed playback.

### Phase 3: Complete Native Queue

- `[x]` Store the full queue in the audio layer.
- `[x]` Publish complete `audio_service.queue` metadata.
- `[x]` Publish correct `PlaybackState.queueIndex`.
- `[x]` Implement `skipToQueueItem(index)`.
- `[x]` Implement repeat, shuffle, and sequential playback modes.
- `[~]` Let the native queue decide the next item after completion.
- `[x]` Persist queue and current playback item locally.

Exit criteria:

- `[ ]` Notification and media-button previous/next controls work while the app
  is foregrounded, backgrounded, and screen-off.
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
- `[x]` Add Flutter service wrapper for CarLife status, launch, and playback
  sync calls.
- `[x]` Add Android MethodChannel implementation for package probe and launch
  fallback.
- `[x]` Add native UI entry card for `百度 CarLife`.
- `[ ]` Obtain Baidu CarLife SDK/AAR or project-specific integration
  documentation from the open platform flow.
- `[ ]` Replace the placeholder `syncPlaybackContext` with real SDK sync.
- `[ ]` Sync current queue, metadata, artwork, and playback state to CarLife.
- `[ ]` Receive CarLife play, pause, next, previous, and item-selection
  callbacks and route them to `audio_service`.
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
