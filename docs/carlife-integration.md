# Baidu CarLife Integration

This document tracks the Baidu CarLife workstream for the native music app.

## Current Implementation

The app currently implements a first-stage CarLife bridge:

- Android package visibility declarations for common CarLife packages.
- Android `MethodChannel` named `music_car_app/carlife`.
- Flutter service wrapper in `lib/services/carlife_service.dart`.
- Native UI entry card labeled `百度 CarLife`.
- Package status probe for installed/launchable CarLife apps.
- `openCarLife` action with app launch, market page, and web fallback.
- Placeholder `syncPlaybackContext` method that returns `sdk_missing`.

This is intentionally not marked as full CarLife SDK support yet. It gives the
APK a testable CarLife entry and establishes the app-side API that the real SDK
adapter can replace.

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

## Next SDK Hook

When the CarLife SDK/AAR/documentation is available, replace the placeholder
implementation in `MainActivity.kt`:

```kotlin
private fun syncPlaybackContext(): Map<String, Any?> {
    val packageName = findInstalledCarLifePackage()
    return mapOf(
        "supported" to false,
        "packageName" to (packageName ?: ""),
        "reason" to "sdk_missing",
    )
}
```

The expected production behavior is:

- Send the current native queue or agreed playlist/program list to CarLife.
- Publish current title, artist, artwork, duration, and playback state.
- Let CarLife control play, pause, previous, next, and selected queue item.
- Keep `audio_service` as the single playback authority.
- Return `supported: true` only when the SDK call succeeds.

## Validation Checklist

- Install APK on an Android phone.
- Install Baidu CarLife on the same phone.
- Open the app and confirm the `百度 CarLife` card says `已安装，可拉起`.
- Tap `打开` and confirm Baidu CarLife starts.
- Uninstall CarLife or test a clean device and confirm the button opens an
  install/web fallback.
- After SDK integration, connect to a CarLife-capable head unit and validate
  music sync plus controls.

## References

- Baidu CarLife app integration example: https://carlife.baidu.com/carlife/example
- Baidu CarLife+ open platform process: https://online.carlife.baidu.com/carlife/caroem/start
- Open-source vehicle-side CarLife reference: https://github.com/674809/carlife
