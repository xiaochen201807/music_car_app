# 车载音乐

Flutter WebView shell for `https://music.sy110.eu.org/music`, based on the `bbtotal` project's `flutter_inappwebview` approach.

## What It Does

- Opens the music page directly on launch.
- Forces landscape orientation for car head units.
- Uses immersive sticky mode to hide system chrome.
- Keeps the screen awake while the app is open.
- Allows WebView media playback without an extra user gesture.
- Provides large back, forward, home, reload, and fullscreen controls.
- Logs WebView navigation and console output in debug builds.

## GitHub Actions Build

Push this project to GitHub and run the `Android APK` workflow from the Actions tab. It also runs automatically on pushes to `main`, pull requests to `main`, and `v*` tags.

The workflow runs:

```sh
flutter pub get
flutter analyze lib test
flutter test
flutter build apk --release
```

The APK is uploaded as the `car-music-release-apk` workflow artifact.

## Notes

This is a normal Android/iOS WebView app for direct installation on phones, tablets, or Android-based car head units. Android Auto and CarPlay require native media-session/template integrations and are not covered by a plain WebView wrapper.

As of 2026-06-08, the site settings API returns the site name `关站,下次再见`, but the `/music` SPA still loads the music UI after the boot screen. Playback availability depends on the remote site's current APIs and audio sources.

See [Development Roadmap](docs/development-roadmap.md) for the planned upgrade from a WebView shell to a native audio engine with system media-session controls.
