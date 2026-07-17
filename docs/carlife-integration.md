# Baidu CarLife Integration

This document tracks the Baidu CarLife workstream for the native music app.

## Current Implementation

The app currently implements a CarLife platform-SDK bridge:

- Android package visibility declarations for common CarLife packages.
- Android `MethodChannel` named `music_car_app/carlife`.
- Flutter service wrapper in `lib/services/carlife_service.dart`.
- Settings section **车载互联** with open / sync actions and live status text.
- Package status probe for installed/launchable CarLife apps.
- `openCarLife` action with app launch, market page, and web fallback.
- `android/app/libs/Carlife_android_platformsdk_2.2.0.jar` is linked by
  `android/app/build.gradle.kts`.
- `CARLIFE_APP_KEY` can be supplied by Gradle property or environment variable
  and is surfaced separately from the SDK-linked status.
- `syncPlaybackContext` accepts and caches current song, queue, artwork,
  current audio URL, duration, position, and playback state.
- `CLPlatformManager` is initialized when an AppKey is configured, and
  `CLGetAlbumListReq` / `CLGetSongListReq` are answered from the cached native
  queue.
- `CLGetSongDataReq` dispatches a Flutter `selectQueueItem` control callback so
  the phone app can switch playback to the requested queue item. The response
  still reports that CarLife byte streaming is unavailable.
- Native `onConnected` now pushes `onConnectionChanged` back to Flutter so the
  settings card and silent re-sync can react without a manual refresh.

This is intentionally not marked as complete CarLife support yet. The app now
links the Baidu platform SDK and can provide a current-queue music template to
that SDK, but production behavior still depends on a project AppKey, platform
approval, a real CarLife connection, and a validated audio-stream strategy.

## Current SDK Hook

`MainActivity.kt` currently uses the cached `lastCarLifePlaybackContext` as the
single handoff point between Flutter playback and the CarLife SDK callback:

- `CLGetAlbumListReq` returns one album named `当前播放队列`.
- `CLGetSongListReq` returns paged songs from the current native queue.
- The active song id is built as `source:id`, matching the Flutter queue
  metadata.
- The current item can include `CLSong.mediaUrl` when the Flutter media session
  has a resolved HTTP audio URL.
- `CLGetSongDataReq` routes selection back to Flutter and returns
  `phone_playback_dispatched_audio_stream_not_available` unless the item is not
  found.
- Platform bridge handles play / pause / next / previous / selectQueueItem from
  CarLife control callbacks.

## Remaining production work

- Configure and protect the project-specific `CARLIFE_APP_KEY` in GitHub
  Actions or release secrets.
- Validate `CLPlatformManager.init`, connection state, and request callbacks on
  a CarLife-capable device/head unit.
- Decide whether CarLife should receive direct media URLs, SDK song-data byte
  chunks, or phone-side playback only.
- Add byte-streaming through `CLSongData` only if the approved SDK flow requires
  the app to provide audio bytes to CarLife.
- Keep `audio_service` as the single playback authority.

## Validation Checklist

- Install APK on an Android phone and install Baidu CarLife.
- Configure `CARLIFE_APP_KEY` for the Android build if validating the SDK path.
- Open Settings → 车载互联 and confirm status text.
- Play a song, tap sync, open CarLife, and confirm queue/select behavior.
- Uninstall CarLife and confirm market/web fallback.

## References

- Baidu CarLife app integration example: https://carlife.baidu.com/carlife/example
- Baidu CarLife+ open platform process: https://online.carlife.baidu.com/carlife/caroem/start
- Open-source vehicle-side CarLife reference: https://github.com/674809/carlife
