# FreeMusic API Audit

This document records the API surface discovered from
`https://music.sy110.eu.org/music` and maps it to the Flutter native car music
app roadmap.

## Execution Order

The near-term project order is:

1. Complete and test the FreeMusic API client and data models.
2. Redesign the landscape UI around real API states until the app is usable.
3. Resume CarLife work after the core app can search, browse, play, queue, and
   show lyrics reliably.

Existing CarLife work is retained. It is useful integration foundation, but it
should not drive the next feature sequence before API coverage and UI usability
are stable.

## Discovery Notes

- Public app entry: `https://music.sy110.eu.org/music`.
- Music page chunk: `assets/FreeMusicApp-B7hgi_yj.js`.
- Shared API helper: `assets/main-CTVbnThO.js`.
- Base API URL: `https://music.sy110.eu.org/api/v1/freemusic`.
- Direct validation was rerun after local proxy shutdown. The environment
  reported `No proxy detected on port 10808 - direct connection`.
- Repeatable probe script: `scripts/test_free_music_api.ps1`.

Run the probe with:

```powershell
.\scripts\test_free_music_api.ps1
```

The script tests public read-only endpoints and authenticated read-only
endpoints. Mutating endpoints are listed but skipped by default. Only run them
with `-IncludeMutating` against a safe test account.

## Currently Implemented In Flutter

| Endpoint | Current Flutter Method | Coverage |
| --- | --- | --- |
| `GET /sources` | `FreeMusicApi.fetchSources` | Implemented for source labels and default source filtering. |
| `GET /search` with `type=song` | `FreeMusicApi.searchSongs` | Implemented for song search and pagination. |
| `GET /search/hot` | `FreeMusicApi.fetchHotSearchKeywords` | Implemented for home/search landing keyword chips. |
| `GET /recommend` | `FreeMusicApi.fetchRecommendations` | Implemented for home playlists. |
| `GET /playlist/page` | `FreeMusicApi.fetchPlaylistSongs` | Implemented for playlist song paging. |
| `GET /qualities` | `FreeMusicApi.fetchQualities` | Implemented for now-playing quality chips. |
| `GET /song_url` | `FreeMusicApi.resolveSongUrl` | Implemented for playback URL resolution. |
| `GET /lyric` | `FreeMusicApi.fetchLyrics` | Implemented for plain LRC lyrics. |
| `GET /yrc` | `FreeMusicApi.fetchEnhancedLyrics` | Implemented as the first lyric lookup, with `/lyric` fallback. |

## Public Read-Only APIs To Keep

These endpoints were validated without a local proxy and should remain in the
project API plan.

| Endpoint | Method | Parameters | Observed Status | Purpose |
| --- | --- | --- | --- | --- |
| `/sources` | `GET` | none | `200` | Available music sources and display names. |
| `/search` | `GET` | `q`, `type=song`, `page`, optional repeated `sources` | `200` | Song search. |
| `/search` | `GET` | `q`, `type=playlist`, `page`, optional `sources` | `200` | Playlist search. |
| `/search` | `GET` | `q`, `type=album`, `page`, optional `sources` | `200` | Album search. |
| `/search` | `GET` | `q`, `type=artist`, `page`, optional `sources` | `200` | Artist search. |
| `/search/hot` | `GET` | none | `200` | Hot keywords for empty search state. |
| `/search/suggest` | `GET` | `q` | `200` | Search suggestions. |
| `/recommend` | `GET` | optional repeated `sources` | `200` | Recommended playlists. |
| `/playlist` | `GET` | `id`, `source` | `200` | Full playlist/fallback playlist loading. |
| `/playlist/page` | `GET` | `id`, `source`, `offset`, `size` | `200` | Paged playlist songs. |
| `/playlist/resolve` | `GET` | playlist link or platform metadata | `400` with current sample | Keep for future external playlist import; sample params need follow-up. |
| `/album/songs` | `GET` | `name`, optional `artist`, `page`, `size` | `200` | Album detail songs. |
| `/qualities` | `GET` | `name`, `artist`, `duration` | `200` | Available audio qualities. |
| `/song_url` | `GET` | `id`, `source`, `name`, `artist`, optional `duration`, `br` | `200` | Generic playable URL resolution. |
| `/play_url` | `GET` | `rid`, `br` | `200` | Kuwo-oriented playable URL resolution. |
| `/lyric` | `GET` | `id`, `source`, `name`, `artist` | `200` | Plain LRC lyrics. |
| `/yrc` | `GET` | `id`, `source` | `200` | Enhanced lyric payload with `lrc` and optional `yrc`. |
| `/switch_source` | `GET` | `name`, `artist`, `source`, `target`, `duration` | `200` or `404` | Fallback to another source when current source cannot play. |
| `/toplist/netease` | `GET` | none | `200` | Netease top-list menu. |
| `/toplist/kuwo/menu` | `GET` | none | `200` | Kuwo top-list menu. |
| `/toplist/kuwo/songs` | `GET` | `bangid`, `page`, `size` | `200` | Paged Kuwo chart songs. |
| `/toplist/kuwo/all` | `GET` | `bangid` | `200` | Full Kuwo chart songs. |
| `/kuwo/playlist/tags` | `GET` | none | `200` | Kuwo playlist category tags. |
| `/kuwo/playlist/byTag` | `GET` | `id`, `pn`, `rn`, `order` | `200` | Kuwo playlists by tag. |
| `/kuwo/artists` | `GET` | `category`, `pn`, `rn`, optional `prefix` | `200` | Kuwo artist directory. |
| `/personal_fm` | `GET` | none | `200` | One-tap personal FM/recommend song. |
| `/download` | `HEAD`/`GET` | `id`, `source`, optional `name`, `artist`, `duration`, `br`, `rid`, `dl_token` | `200` with HEAD sample | Download URL shape; playback app should not prioritize it. |

## Authenticated Read-Only APIs To Keep

These endpoints are part of the web app API helper. Without a browser login
session most library endpoints return `401`, which is expected and captured by
the probe script.

| Endpoint | Method | Observed Status Without Login | Purpose |
| --- | --- | --- | --- |
| `/favorites` | `GET` | `401` | Favorite song library. |
| `/favorite_ids` | `GET` | `401` | Fast favorite-state lookup. |
| `/collections` | `GET` | `401` | User collection list. |
| `/collection?id=...` | `GET` | `401` | Collection detail. |
| `/saved_playlists` | `GET` | `401` | User-saved playlists. |
| `/recent_plays` | `GET` | `401` | Recent playback history. |
| `/settings` | `GET` | `401` | Web music player settings. |
| `/recommend-playlists` | `GET` | `200` in current unauthenticated probe | Server-managed recommended playlists. |
| `/config` | `GET` | `200` in current unauthenticated probe | Server/global music config. |
| `/mounted/directories` | `GET` | `401` | Mounted local/cloud music directories. |
| `/mounted/tracks` | `GET` | `401` | Tracks from a mounted directory. |

## Mutating APIs To Keep But Skip By Default

These are preserved for future feature work. They are intentionally skipped by
`scripts/test_free_music_api.ps1` unless `-IncludeMutating` is passed.

| Endpoint | Method | Purpose |
| --- | --- | --- |
| `/favorites` | `POST` | Add favorite song. |
| `/favorites` | `DELETE` | Remove favorite song. |
| `/collections` | `POST` | Create collection. |
| `/collections/{id}` | `PUT` | Update collection. |
| `/collections/{id}` | `DELETE` | Delete collection. |
| `/collections/{id}/songs` | `POST` | Add song to collection. |
| `/collections/{id}/songs` | `DELETE` | Remove song from collection. |
| `/saved_playlists` | `POST` | Save playlist. |
| `/saved_playlists` | `DELETE` | Remove saved playlist. |
| `/recent_plays` | `POST` | Record a play. |
| `/recent_plays` | `DELETE` | Clear recent plays. |
| `/recent_plays/song` | `DELETE` | Remove one recent play. |
| `/settings` | `PUT` | Save player settings. |
| `/recommend-playlists` | `POST` | Add recommended playlist. |
| `/config` | `PUT` | Update global music config. |
| `/mounted/directories` | `POST` | Save mounted directory. |
| `/mounted/directories/{id}/refresh` | `POST` | Refresh mounted directory. |
| `/mounted/directories/{id}` | `DELETE` | Delete mounted directory. |
| `/download-deduct` | `POST` | Deduct download cost/entitlement. |

## Observed Models

### Source

```json
{
  "all_sources": ["netease", "kuwo"],
  "default_sources": ["netease", "kuwo"],
  "descriptions": {
    "kuwo": "酷我音乐",
    "netease": "网易云音乐"
  }
}
```

### Song

Observed fields across search, playlist, album, chart, and personal FM:

- `id`
- `name`
- `artist`
- `album`
- `album_id`
- `duration`
- `size`
- `bitrate`
- `source`
- `url`
- `ext`
- `cover`
- `link`
- Web local-library fields: `storageId`, `filePath`, `lyricText`

### Playlist

Observed fields:

- `id`
- `name`
- `cover`
- `track_count`
- `play_count`
- `creator`
- `description`
- `source`
- `link`
- optional `extra`

### Album

Observed search fields:

- `albumid`
- `name`
- `artist`
- `pic`
- `musiccnt`
- `pub`
- `source`

### Artist

Observed search fields:

- `artistid`
- `name`
- `pic`
- `songnum`
- `source`

### Quality

Observed fields from `/qualities`:

- `matchedName`
- `matchedArtist`
- `qualities[].br`
- `qualities[].format`
- `qualities[].size`
- `qualities[].name`

## Recommended Client Implementation Stages

### Stage 1: API Completion Before UI Polish

- `[x]` Add source model and `fetchSources()`.
- `[~]` Add hot search and search suggestion methods. Hot search is implemented;
  suggestions remain pending.
- Expand search models for playlist, album, and artist results.
- Add `/playlist` fallback in addition to `/playlist/page`.
- `[~]` Add quality model and resolver default selection. Quality retrieval is
  implemented for UI display; playback bitrate selection still uses the current
  default.
- `[x]` Add enhanced lyric method using `/yrc`, with fallback to `/lyric`.
- Add source-switch method for failed playback URL resolution.

### Stage 2: UI Around Real Data

- `[x]` Use `/sources` for source labels and default API source filtering.
- `[~]` Use `/search/hot` and `/search/suggest` for the search landing state.
  Hot keywords are implemented; live suggestions remain pending.
- Build playlist, album, and chart browsing surfaces from the typed models.
- Remove demo placeholders once the corresponding API states exist.
- Design empty, loading, error, timeout, retry, and partial-data states first,
  then tune the visual layout.

### Stage 3: Playback Reliability

This is the hard prerequisite for CarLife. CarLife projects **data** (queue +
current track metadata + playback state) onto the head unit's native controls,
not the Flutter UI. If this layer is unstable, the projection breaks even when
the in-app UI looks fine. Stage 3 is **not done** until every item below is
checked.

#### Current state (verified against code on 2026-06-10)

- `/switch_source` fallback: **NOT wired** (zero references in `lib/`). This is
  the core Stage 3 gap.
- `/song_url` (`free_music_api.dart`): resolves a URL but **throws on failure
  with no fallback** — a dead source makes playback silently fail.
- Request timeouts: only `update_check_service.dart` uses `.timeout()`. **No
  playback-path API call has a timeout**, so a slow endpoint spins forever on
  the head unit.
- Android background/lock-screen media notification: missing transport buttons.
  Root cause is `androidNotificationOngoing: false` in
  `music_audio_handler.dart` (the `controls` array and manifest are correct).

#### Acceptance checklist (Definition of Done — playback)

Bitrate & source resolution:
- [ ] Use `/qualities` + user preference to choose playback bitrate (currently
      retrieved for display only; playback still uses the default `br`).
- [ ] Wire `/switch_source` so that when `/song_url` fails or returns an
      unusable/empty/non-HTTP URL, the handler retries via the alternate source
      before surfacing an error to the user.
- [ ] `/song_url` failure no longer throws to the UI as an unhandled error; it
      degrades to switch-source, then to a clear "this track can't play, skipping"
      state.

Resilience:
- [ ] Add a timeout (suggest 10–12s) to every playback-path request:
      `/song_url`, `/switch_source`, `/playlist`, `/playlist/page`, `/lyric`,
      `/yrc`, `/qualities`.
- [ ] On timeout/failure of a slow endpoint, the UI shows a recoverable error
      with retry — never an infinite spinner.
- [ ] Playback stall monitor (already present in `music_audio_handler.dart`)
      cooperates with switch-source: a stalled track auto-recovers or skips,
      it does not hang.

Queue as single source of truth:
- [ ] The native queue is the one source read by: in-app UI, the Android media
      notification, and (later) CarLife. No second queue state anywhere.
- [ ] Search → play → next/prev → switch-source → reorder/clear queue all keep
      the three consumers consistent (in-app, notification, lock screen agree
      on title/artist/cover/position).

Background / lock-screen media controls (also the manual CarLife smoke test):
- [ ] Set `androidNotificationOngoing: true` so the media notification renders
      as a full foreground media notification on all tested ROMs.
- [ ] Lock screen / background notification shows three working transport
      buttons (previous / play-pause / next) and they actually control playback.
- [ ] Notification shows correct title, artist, and cover art (`artUri`).
- [ ] **Smoke test rule:** lock the phone and operate playback using ONLY the
      Android notification. If that is flawless, the queue/media-session data is
      stable enough to drive CarLife.

### Stage 4: CarLife Resume Point

- Keep the existing CarLife SDK bridge and jar location.
- Resume CarLife only after **every Stage 3 checkbox is closed**, so the
  projection layer receives complete and stable queue metadata. A polished UI
  alone does NOT qualify — Stage 3 reliability is the gate.

## Latest Direct Verification

Run:

```powershell
.\scripts\test_free_music_api.ps1
```

Result on 2026-06-09 after local proxy shutdown:

- All public read-only probes passed.
- Authenticated library probes returned expected `401` without login, except
  `/recommend-playlists` and `/config`, which returned `200` in the current
  unauthenticated environment.
- Mutating probes were listed and skipped by default.
