# Device Validation Matrix

This checklist turns the car/head-unit parts of the roadmap into repeatable
release evidence.

| Surface | Device | Required Checks |
| --- | --- | --- |
| Android phone | Physical Android 12+ | play, pause, next, previous, seek, notification metadata |
| Android head unit | Car/head-unit build or representative tablet | large touch targets, portrait layout, network recovery |
| Bluetooth media keys | Headset or car controls | play/pause/next/previous update the same queue index |
| Lock screen | Android notification/media session | title, artist, artwork, queue index, repeat/shuffle |
| iOS unsigned IPA | Physical iPhone | install smoke, launch, search, play/pause, background audio |
| CarLife bridge | Android device with CarLife available | status probe, playback context sync, lyrics sync diagnostics |

## Evidence Format

For every release candidate, record:

- app version/build and tag
- device model and OS version
- workflow run IDs for Android and iOS
- pass/fail for each required check
- exported diagnostics payload when a check fails

## Failure Handling

- Playback mismatch: attach diagnostics from Settings and note the queue index.
- Media button failure: capture `adb shell dumpsys media_session` when possible.
- iOS install failure: keep the unsigned IPA run ID and device error message.
- CarLife failure: keep status probe output and do not re-expose user-facing
  CarLife UI unless the product scope changes.
