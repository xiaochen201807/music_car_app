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

## GitHub Actions Builds

Push this project to GitHub and use the Actions tab for cloud builds.

### Android APK

The `Android APK` workflow runs automatically on pushes to `main`, pull requests to `main`, and `v*` tags. It can also be triggered manually.

It runs:

```sh
flutter pub get
flutter analyze lib test
flutter test
flutter build apk --release --split-per-abi
```

The ABI-split APKs are uploaded as the `car-music-release-apk` workflow
artifact. The in-app updater chooses the best APK for the device ABI before
downloading.

On `v*` tag builds, the workflow also creates or updates the GitHub Release and
attaches both the APK and `update.json`. The app's online update checker can read
GitHub's latest release directly, or read a custom manifest URL provided at
build time with:

```sh
--dart-define=MUSIC_CAR_UPDATE_MANIFEST_URL=https://example.com/update.json
```

For GitHub Actions, set the repository variable `MUSIC_CAR_UPDATE_MANIFEST_URL`
if you want the app to check a CDN/R2-hosted manifest before falling back to the
GitHub latest release API.

### iOS Unsigned IPA

The `iOS Unsigned IPA` workflow runs on `v*` tags and can also be triggered manually.

It runs on GitHub's macOS runner:

```sh
flutter pub get
pod install --repo-update
flutter build ios --release --no-codesign
```

The unsigned IPA is uploaded as the `ios-unsigned-ipa` workflow artifact. On tag builds, it is also attached to the GitHub Release. The IPA must still be signed locally by a tool such as Sideloadly, AltStore, SideStore, or another Apple signing flow before installation.

## Notes

This is a normal Android/iOS WebView app for direct installation on phones, tablets, or Android-based car head units. Android Auto and CarPlay require native media-session/template integrations and are not covered by a plain WebView wrapper.

As of 2026-06-08, the site settings API returns the site name `关站,下次再见`, but the `/music` SPA still loads the music UI after the boot screen. Playback availability depends on the remote site's current APIs and audio sources.

See [Development Roadmap](docs/development-roadmap.md) for the planned upgrade from a WebView shell to a native audio engine with system media-session controls.
