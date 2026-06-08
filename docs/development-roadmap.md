# Development Roadmap

This project currently starts as a simple Flutter WebView wrapper for the music
site. The long-term target is a car-friendly media app where Flutter owns audio
playback and exposes a native media session for car controls.

## Current Scope

The current implementation is a WebView shell:

1. Flutter loads `https://music.sy110.eu.org/music` in `InAppWebView`.
2. The web page owns audio playback.
3. Flutter provides the car shell: landscape orientation, immersive mode,
   wakelock, large navigation buttons, and debug logging.

This means the app currently covers the first part of the desired workflow only.
It does not yet expose native media sessions, notification controls, steering
wheel controls, or CarPlay/Android Auto media integration.

## Target Architecture

The target car-media architecture is:

1. Flutter WebView loads the music web page.
2. Flutter injects JavaScript to observe the page player and audio state.
3. JavaScript sends song metadata and playback intent to Flutter.
4. Flutter receives `title`, `artist`, `coverUrl`, and `audioUrl`.
5. Flutter uses `just_audio` to play the real `audioUrl`.
6. `audio_service` publishes playback metadata to the system media session.
7. iOS Now Playing, Android notification controls, and compatible car systems
   read the system media session.
8. Car or steering-wheel controls call back into `audio_service`.
9. `audio_service` controls `just_audio`, then syncs state back to the WebView
   when needed.

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

## Implementation Phases

### Phase 1: Player Discovery

- Inject a document-start JavaScript bridge into the WebView.
- Detect current song metadata from the page player.
- Detect the real media source from `<audio>`, player stores, network-visible
  fields, or controlled page APIs.
- Send observed player state to Flutter through a JavaScript handler.
- Add debug logging for observed `title`, `artist`, `coverUrl`, `audioUrl`,
  duration, current time, and playing state.

Exit criteria:

- A debug build can show the current song metadata in Flutter logs.
- At least one real song produces a playable candidate `audioUrl`.

### Phase 2: Native Audio Proof

- Add `just_audio`.
- Test whether Flutter can play the captured `audioUrl` directly.
- Preserve required request headers if the site needs cookies or `Referer`.
- Keep the WebView page visible but prevent double playback where possible.

Exit criteria:

- Flutter can play, pause, seek, and stop one captured track.
- Playback survives the same URLs and headers used by the web page.

### Phase 3: System Media Session

- Add `audio_service` and a single audio handler.
- Publish `title`, `artist`, `coverUrl`, duration, and playback state.
- Wire Android notification controls and iOS Now Playing metadata.
- Handle play, pause, seek, next, and previous callbacks.

Exit criteria:

- Android notification controls operate the Flutter audio engine.
- iOS Now Playing shows correct metadata when running on iOS.

### Phase 4: WebView Synchronization

- When native playback changes, call page JavaScript to update the visible UI.
- When the user clicks play, pause, next, or previous in the page, route the
  action to Flutter instead of letting the page create independent playback.
- Add drift detection so Flutter can recover if the page changes songs without
  sending a clean event.

Exit criteria:

- WebView UI and native playback stay consistent through play, pause, next,
  previous, and song selection.

### Phase 5: Car Controls

- Validate Android media-button and compatible steering-wheel callbacks through
  `audio_service`.
- Validate Android head-unit notification/media-session behavior on real car
  hardware or a head-unit test device.
- Document what works for ordinary Android car systems versus Android Auto and
  CarPlay.

Exit criteria:

- A compatible Android car system can pause, resume, and skip tracks from
  physical or system media controls.
- Remaining Android Auto or CarPlay requirements are documented separately.
