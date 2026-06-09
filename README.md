# 车载音乐

Native Flutter music app tuned for landscape car head units.

The app no longer embeds the remote music site in a WebView. The main runtime
path is now a native Flutter interface with an iOS-inspired car UI, large touch
targets, a native audio service foundation, and cloud-built Android/iOS release
artifacts.

## What It Does

- Uses a native Flutter shell instead of WebView.
- Forces landscape orientation for car head units.
- Uses immersive sticky mode to hide system chrome.
- Keeps the screen awake while the app is open.
- Provides an iOS-style home, search entry, now-playing panel, queue panel, and
  mini player.
- Provides a first-stage Baidu CarLife entry that can detect and launch the
  CarLife companion app.
- Keeps update checking and APK installation support.
- Uses `audio_service` and `just_audio` as the foundation for background
  playback and system media controls.

The current native UI is the first step of the rewrite. Real search, playlist
loading, lyrics, and a complete native queue are tracked in the development
roadmap.

## UI Design

The native UI reference is stored in:

```text
docs/ui/native-ios-music-app-design.png
```

## GitHub Actions Builds

Push this project to GitHub and use the Actions tab for cloud builds.

### Android APK

The `Android APK` workflow runs automatically on pushes to `main`, pull
requests to `main`, and `v*` tags. It can also be triggered manually.

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
attaches both the APK and `update.json`. The app's online update checker can
read GitHub's latest release directly, or read a custom manifest URL provided at
build time with:

```sh
--dart-define=MUSIC_CAR_UPDATE_MANIFEST_URL=https://example.com/update.json
```

For GitHub Actions, set the repository variable
`MUSIC_CAR_UPDATE_MANIFEST_URL` if you want the app to check a CDN/R2-hosted
manifest before falling back to the GitHub latest release API.

### iOS Unsigned IPA

The `iOS Unsigned IPA` workflow runs on `v*` tags and can also be triggered
manually.

It runs on GitHub's macOS runner:

```sh
flutter pub get
pod install --repo-update
flutter build ios --release --no-codesign
```

The unsigned IPA is uploaded as the `ios-unsigned-ipa` workflow artifact. On tag
builds, it is also attached to the GitHub Release. The IPA must still be signed
locally by an Apple signing flow before installation.

## Car Integrations

Ordinary Android car systems can interact with the app through Android media
session controls once the native queue is fully connected.

Android Auto and Apple CarPlay app surfaces are separate platform integrations:

- Baidu CarLife is tracked separately in
  [CarLife Integration](docs/carlife-integration.md). The current app links the
  Android platform SDK and can expose the current queue template, but full
  production use still needs a project AppKey, CarLife-capable device
  validation, and a confirmed audio-stream strategy.
- Android Auto media browsing depends on `audio_service` queue/media-browser
  metadata and real head-unit validation.
- Apple CarPlay requires an iOS build, CarPlay template integration, and proper
  CarPlay Audio entitlement signing.
- A future CarPlay branch can evaluate `flutter_carplay` for List, Tab Bar, and
  Now Playing templates, but it should stay separate from the Android APK
  release branch.

See [Development Roadmap](docs/development-roadmap.md) for the native music app
rewrite plan.
