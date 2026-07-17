# CarPlay Integration

Apple CarPlay support for the native music app.

## Current Implementation

- Flutter bridge: `lib/services/carplay_service.dart`
- Native scene: `ios/Runner/CarPlaySceneDelegate.swift` (`CarPlayBridge` +
  `CarPlaySceneDelegate`)
- Channel: `music_car_app/carplay`
- Settings row shows connection status under **车载互联**
- Entitlement: `com.apple.developer.carplay-audio` in
  `ios/Runner/Runner.entitlements`
- Info.plist registers `CPTemplateApplicationSceneSessionRoleApplication`

### What the car screen shows

When CarPlay connects, the app presents a list template with:

1. **正在播放** — current title / artist / play-pause toggle
2. **当前队列** — queue items; tapping one asks Flutter to
   `selectQueueItem`

### What Flutter pushes

On media-item / playback-state changes, and after track switches, Flutter
calls `syncNowPlaying` with:

- title / artist / album / coverUrl
- playing / durationMs / positionMs
- queueIndex + queue (`id/source/name/artist/album/cover/duration`)

### Controls back into the app

Native → Flutter `onControl` actions:

- `play` / `pause`
- `next` / `previous`
- `selectQueueItem` with `queueIndex`

These are wired in `main.dart` to `PlaybackController` + queue re-sync so
lyrics/cover stay consistent with the phone UI.

## Remaining production steps

1. Enable the **CarPlay Audio** capability for the App ID in Apple Developer.
2. Ensure the provisioning profile includes the CarPlay entitlement.
3. Validate on a real head unit or Xcode CarPlay simulator:
   - connect / disconnect status updates in Settings
   - queue list matches phone queue
   - play/pause/skip and queue item selection work
4. Optionally add a richer Now Playing template / album art loading once the
   audio entitlement is approved.

## Why not a Flutter plugin only

`audio_service` already owns the media session / Now Playing center. CarPlay
list templates still need a native `CPTemplateApplicationScene`. This app
keeps Dart as the playback authority and only uses native code for the
template surface.
