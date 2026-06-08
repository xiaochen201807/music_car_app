# Development Roadmap

This project started as a simple Flutter WebView wrapper for the music site. It
is now moving toward a car-friendly media app where Flutter owns audio playback
and exposes a native media session for car controls.

Status markers:

- `[x]` Implemented and covered by local checks/tests.
- `[~]` Implemented in code, but still needs real-device or real-site
  validation.
- `[ ]` Not implemented yet.

## Current Scope

The current implementation includes a WebView shell plus a native audio handoff:

1. `[x]` Flutter loads `https://music.sy110.eu.org/music` in `InAppWebView`.
2. `[x]` Flutter injects a document-start player probe script.
3. `[x]` Flutter provides the car shell: landscape orientation, immersive mode,
   wakelock, large navigation buttons, update controls, and debug logging.
4. `[x]` Flutter can take over playback through `just_audio` when the page
   exposes a usable audio URL or resolvable song metadata.
5. `[x]` Flutter exposes playback through `audio_service` and Android media
   button plumbing.
6. `[~]` Android media-app discovery is declared through the Android Auto media
   metadata file and `MediaBrowserService`; it still needs head-unit validation.
7. `[~]` iOS Now Playing and physical car controls are wired through background
   audio and a music audio session, but still need real-device validation.

Android Auto and CarPlay app surfaces are still outside the current scope. They
require platform-specific media/template integration beyond a plain WebView APK.
In particular, a full CarPlay app icon/template surface requires Apple-approved
CarPlay Audio entitlement signing; an unsigned IPA can only provide ordinary
system playback/Now Playing behavior.

## Target Architecture

The target car-media architecture status is:

1. `[x]` Flutter WebView loads the music web page.
2. `[x]` Flutter injects JavaScript to observe the page player and audio state.
3. `[x]` JavaScript sends song metadata and playback state to Flutter.
4. `[x]` Flutter receives `title`, `artist`, `coverUrl`, and `audioUrl`.
5. `[x]` Flutter uses `just_audio` to play a real or resolved `audioUrl`.
6. `[x]` `audio_service` publishes playback metadata to the system media
   session.
7. `[~]` Android notification controls and iOS Now Playing are wired through
   `audio_service` and `audio_session`, but iOS/device behavior still needs
   physical validation.
8. `[~]` Car or steering-wheel controls can call back into `audio_service` via
   the Android media button receiver, but this still needs head-unit validation.
9. `[~]` `audio_service` controls `just_audio`; next/previous can call back into
   the WebView. Full visible UI sync for every page action is still incomplete.

In this model, the WebView remains the UI for search, playlists, lyrics, and
site-specific flows. Flutter becomes the real audio engine.

## Main Risks

- The site may not expose a stable `<audio>` element.
- The playable URL may be temporary, signed, or refreshed per song.
- Audio requests may require cookies, `Referer`, or custom headers.
- If Flutter takes over playback, the web page's own player UI can drift from
  the real native playback state.
- Next, previous, and playlist behavior must be coordinated between Flutter and
  the page. That can be done by page JavaScript calling Flutter, or by Flutter
  calling page JavaScript.
- Android notification and many head-unit media keys can work through
  `audio_service`, but Android Auto and CarPlay app surfaces require native
  platform-specific media/template integration beyond a plain WebView APK.
- Full iOS CarPlay app entry requires Apple-approved CarPlay Audio entitlement
  signing. Unsigned IPA builds cannot add that entitlement by themselves.

## Implementation Phases

### Phase 1: Player Discovery

- `[x]` Inject a document-start JavaScript bridge into the WebView.
- `[x]` Detect current song metadata from the page player.
- `[x]` Detect the real media source from `<audio>`, player stores,
  network-visible
  fields, or controlled page APIs.
- `[x]` Send observed player state to Flutter through a JavaScript handler.
- `[x]` Add debug logging for observed `title`, `artist`, `coverUrl`,
  `audioUrl`,
  duration, current time, and playing state.

Exit criteria:

- `[x]` A debug build can show the current song metadata in Flutter logs.
- `[~]` At least one real song can produce a playable candidate `audioUrl` via
  direct page audio or the FreeMusic `song_url` API. This is covered by mocked
  tests and still needs live-site playback validation.

### Phase 2: Native Audio Proof

- `[x]` Add `just_audio`.
- `[x]` Route captured or resolved audio URLs into a native audio controller.
- `[~]` Test whether Flutter can play the captured `audioUrl` directly. The
  controller is unit-tested with fakes; live URL playback still needs device
  validation.
- `[~]` Preserve required request headers if the site needs cookies or
  `Referer`. The FreeMusic API resolver sends `Referer` and `User-Agent`; final
  audio playback headers still need live validation.
- `[x]` Keep the WebView page visible but prevent double playback where
  possible by pausing/muting page audio after native handoff.

Exit criteria:

- `[x]` Flutter can play, pause, seek, and stop through the native audio
  controller.
- `[~]` Playback survives the same URLs and headers used by the web page. Needs
  live-site validation.

### Phase 3: System Media Session

- `[x]` Add `audio_service` and a single audio handler.
- `[x]` Publish `title`, `artist`, `coverUrl`, duration, and playback state.
- `[x]` Wire Android notification controls through `AudioService`,
  `MediaButtonReceiver`, and the foreground media service manifest entries.
- `[x]` Declare Android Auto media metadata with `automotive_app_desc.xml`.
- `[~]` Expose a minimal browsable media queue for compatible Android car
  systems. This is implemented but still needs head-unit validation.
- `[~]` Wire iOS Now Playing metadata through `audio_service` and configure the
  shared audio session for music playback; still needs iOS device validation.
- `[x]` Handle play, pause, seek, next, and previous callbacks in the audio
  handler.

Exit criteria:

- `[~]` Android notification controls operate the Flutter audio engine. Code is
  wired; needs device validation.
- `[~]` iOS Now Playing shows correct metadata when running on iOS. Needs
  device validation.

### Phase 4: WebView Synchronization

- `[~]` When native playback changes, call page JavaScript to update the visible
  UI. Current implementation pauses/mutes page audio and can click next/previous
  controls; full UI state mirroring is not complete.
- `[~]` When the user clicks play, pause, next, or previous in the page, route the
  action to Flutter instead of letting the page create independent playback.
  Current implementation observes the page action after it happens, takes over
  native playback, and suppresses duplicate page audio.
- `[x]` Add drift detection so Flutter can recover if the page changes songs
  without sending a clean event. The probe uses mutation observation and
  interval scans.

Exit criteria:

- `[~]` WebView UI and native playback stay consistent through play, pause, next,
  previous, and song selection.

### Phase 5: Car Controls

- `[~]` Validate Android media-button and compatible steering-wheel callbacks
  through `audio_service`.
- `[~]` Android head-unit discovery is declared as a media app, but needs real
  car hardware or a head-unit test device.
- `[ ]` Validate iOS Now Playing / Remote Command behavior while connected to a
  CarPlay-capable head unit.
- `[ ]` Apply for and sign with Apple CarPlay Audio entitlement if the app must
  appear as a full CarPlay app surface.
- `[x]` Document what works for ordinary Android car systems versus Android Auto and
  CarPlay.

Exit criteria:

- `[ ]` A compatible Android car system can pause, resume, and skip tracks from
  physical or system media controls.
- `[x]` Remaining Android Auto or CarPlay requirements are documented separately.

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
- `[~]` The `v1.0.0` tag release build is currently running in GitHub Actions;
  release artifacts should be verified after both Android and iOS workflows
  complete.
