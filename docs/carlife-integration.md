# Baidu CarLife Integration

This document tracks the Baidu CarLife workstream for the native music app.

## Current Implementation

The app currently implements a CarLife platform-SDK bridge:

- Android package visibility declarations for common CarLife packages.
- Android `MethodChannel` named `music_car_app/carlife`.
- Flutter service wrapper in `lib/services/carlife_service.dart`.
- Native UI entry card labeled `百度 CarLife`.
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

This is intentionally not marked as complete CarLife support yet. The app now
links the Baidu platform SDK and can provide a current-queue music template to
that SDK, but production behavior still depends on a project AppKey, platform
approval, a real CarLife connection, and a validated audio-stream strategy.

## Why This Shape

Baidu's public CarLife example describes a platform workflow where an app is
submitted, reviewed, enabled server-side, and then shown in CarLife's music
surface. The same example says the app should also provide its own CarLife
entry, and if CarLife is installed, users can sync music/program lists into
CarLife.

Baidu's CarLife+ open platform page describes an application, integration, and
certification flow where Baidu assigns the required documents or SDK according
to the project type. That means a production music integration should be built
against the SDK/documentation received from Baidu, not guessed from unrelated
vehicle-side protocol code.

The open-source `674809/carlife` repository is useful reference material for
the CarLife protocol and vehicle/head-unit side. It is not a ready Flutter
phone-app SDK for injecting our music app into CarLife.

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

The remaining production work is:

- Configure and protect the project-specific `CARLIFE_APP_KEY` in GitHub
  Actions or release secrets.
- Validate `CLPlatformManager.init`, connection state, and request callbacks on
  a CarLife-capable device/head unit.
- Decide whether CarLife should receive direct media URLs, SDK song-data byte
  chunks, or phone-side playback only.
- Add byte-streaming through `CLSongData` only if the approved SDK flow requires
  the app to provide audio bytes to CarLife.
- Confirm whether the approved SDK exposes play, pause, previous, and next
  controls beyond the list/song-data request types present in the current jar.
- Keep `audio_service` as the single playback authority.

## Validation Checklist

- Install APK on an Android phone.
- Install Baidu CarLife on the same phone.
- Configure `CARLIFE_APP_KEY` for the Android build if validating the SDK path.
- Open the app and confirm the `百度 CarLife` card reports either
  `SDK 待配置 AppKey`, `SDK 已初始化`, or `SDK 已连接` as appropriate.
- Play a real search or playlist song, tap the CarLife sync icon, and confirm
  the app reports cached or initialized SDK state without losing the queue.
- Tap `打开` and confirm Baidu CarLife starts after attempting silent context
  sync.
- From CarLife, request the current album/song list and confirm it reflects the
  app's current queue.
- Select a song from the CarLife list and confirm phone-side playback switches
  to that queue item, while the SDK response clearly reports that byte streaming
  is still unavailable.
- Uninstall CarLife or test a clean device and confirm the button opens an
  install/web fallback.
- Connect to a CarLife-capable head unit and validate metadata, queue paging,
  selected-item behavior, and any SDK control callbacks exposed by the approved
  integration.

## References

- Baidu CarLife app integration example: https://carlife.baidu.com/carlife/example
- Baidu CarLife+ open platform process: https://online.carlife.baidu.com/carlife/caroem/start
- Open-source vehicle-side CarLife reference: https://github.com/674809/carlife
