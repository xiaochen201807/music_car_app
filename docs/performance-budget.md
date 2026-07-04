# Performance Budget

Music Car uses these budgets as the first automated quality bar for the
v1.2.0 experience roadmap.

| Path | Budget | Owner | Evidence |
| --- | ---: | --- | --- |
| `app_start_to_interactive` | 2500 ms | startup | telemetry event or manual trace |
| `search_first_page` | 2500 ms | search | `MusicSearchController` telemetry |
| `play_request_to_ready` | 3500 ms | playback | `NativeAudioController` telemetry |
| `lyrics_load` | 2000 ms | lyrics | metadata controller telemetry |
| `playlist_first_page` | 3000 ms | playlist | playlist detail telemetry |

## Release Gate

Before a tagged release:

1. Run `dart run scripts/app_quality_gate.dart`.
2. Run `flutter analyze`.
3. Run `flutter test`.
4. Export diagnostics from Settings after at least one search and one playback
   attempt, then confirm the payload contains no cookie, token, or URL query
   secret.
5. Compare any measured budget violation with the table above and either fix it
   before release or document the exception in `docs/work-log.md`.

## Notes

- The budgets are intentionally strict enough to catch obvious regressions but
  not a replacement for real-device profiling.
- Release packaging still happens only in GitHub Actions.
- Any new high-frequency path must add a named telemetry event before it is
  accepted as roadmap work.
