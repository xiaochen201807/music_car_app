# Work Log

This file keeps the implementation record inside the repository so progress is
not dependent on chat context.

## 2026-06-09

Objective: build a native music app with common car music features and Baidu
CarLife support.

Current evidence:

- The Flutter app already renders a native landscape music shell instead of a
  WebView.
- Playback uses `audio_service` plus `just_audio`.
- `NativeAudioController` can resolve FreeMusic song URLs, persist a queue, and
  skip through a synced probe queue.
- Android exposes a CarLife MethodChannel for package probe, launch fallback,
  and a placeholder playback sync call.
- `docs/development-roadmap.md` tracks the larger implementation phases.

Open gaps toward the full goal:

- Native search, recommendations, playlists, artwork, and lyrics are not yet
  fully API-backed in the Flutter UI.
- `audio_service.queue` needs to expose the complete native queue with a correct
  active index, not only the current item.
- Direct queue item selection, repeat modes, and shuffle mode need native
  behavior.
- CarLife SDK/AAR integration is still missing; current support is package
  probe and launch fallback only.
- Real Android head-unit and CarLife-capable device validation is still needed.

Next implementation focus:

- Publish the complete playback queue through `audio_service`.
- Route `skipToQueueItem` through the native queue.
- Add repeat/shuffle state handling in the native audio controller.
- Keep tests and roadmap status updated with each increment.

Implemented in this increment:

- `MusicAudioHandler.loadFromSnapshot` now publishes a complete queue from the
  probe playlist when present.
- `PlaybackState.queueIndex` now reflects the active queue item.
- `MusicAudioHandler.skipToQueueItem` and `playMediaItem` now route queue
  selections to a native callback.
- `NativeAudioController.skipToQueueIndex` can resolve and play a selected queue
  item directly.
- Tests cover complete queue publication and direct queue-item playback.

Build and release execution requirement added:

- AI agents must not create release packages locally unless explicitly asked.
- Deliverable builds must be produced by committing and pushing to GitHub, then using GitHub Actions artifacts or releases.
- The rule is recorded in root `AGENTS.md`.
