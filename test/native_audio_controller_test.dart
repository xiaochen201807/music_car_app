import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:music_car_app/native_audio_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('PlayerProbeSnapshot parses probe payload', () {
    final PlayerProbeSnapshot snapshot = PlayerProbeSnapshot.fromPayload(
      <Object?, Object?>{
        'audioUrl': 'https://example.com/song.mp3',
        'playing': true,
        'title': '晴天',
        'artist': '周杰伦',
        'coverUrl': 'https://example.com/cover.jpg',
        'currentTime': 12.5,
        'duration': '269',
        'currentIndex': 1,
        'playlist': <Map<String, Object?>>[
          <String, Object?>{
            'id': '1',
            'source': 'kuwo',
            'name': '七里香',
            'artist': '周杰伦',
            'duration': 290,
          },
          <String, Object?>{
            'id': '2',
            'source': 'kuwo',
            'name': '晴天',
            'artist': '周杰伦',
            'duration': 269,
          },
        ],
      },
    );

    expect(snapshot.hasAudioUrl, isTrue);
    expect(snapshot.playing, isTrue);
    expect(snapshot.debugTitle, '晴天 - 周杰伦');
    expect(snapshot.currentTime, const Duration(milliseconds: 12500));
    expect(snapshot.duration, const Duration(seconds: 269));
    expect(snapshot.currentIndex, 1);
    expect(snapshot.playlist, hasLength(2));
    expect(snapshot.playlist.last.name, '晴天');
  });

  test('NativeAudioController ignores payloads without audio URLs', () async {
    final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
    final NativeAudioController controller = NativeAudioController(
      player: player,
    );

    final bool handled = await controller.syncFromProbe(
      const PlayerProbeSnapshot(audioUrl: '', playing: true),
    );

    expect(handled, isFalse);
    expect(player.calls, isEmpty);
  });

  test('NativeAudioController loads URL once and plays or pauses', () async {
    final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
    final NativeAudioController controller = NativeAudioController(
      player: player,
    );

    await controller.syncFromProbe(
      const PlayerProbeSnapshot(
        audioUrl: 'https://example.com/song.mp3',
        playing: true,
        currentTime: Duration(seconds: 3),
        title: '晴天',
        artist: '周杰伦',
      ),
    );
    await controller.syncFromProbe(
      const PlayerProbeSnapshot(
        audioUrl: 'https://example.com/song.mp3',
        playing: false,
      ),
    );

    expect(player.calls, <String>[
      'setUrl:https://example.com/song.mp3',
      'seek:3000',
      'play',
      'pause',
    ]);
  });

  test('NativeAudioController resolves audio URL from song metadata', () async {
    final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
    final FreeMusicApi api = FreeMusicApi(
      client: MockClient((http.Request request) async {
        if (_isAuthRequest(request)) {
          return _authResponse();
        }
        expect(request.url.path, '/api/music/songs/url/kuwo/228908');
        expect(request.url.queryParameters['name'], '晴天');
        return _songUrlResponse('https://example.com/resolved.mp3');
      }),
    );
    final NativeAudioController controller = NativeAudioController(
      player: player,
      api: api,
    );

    final bool handled = await controller.syncFromProbe(
      const PlayerProbeSnapshot(
        audioUrl: '',
        playing: true,
        song: FreeMusicSong(
          id: '228908',
          source: 'kuwo',
          name: '晴天',
          artist: '周杰伦',
          duration: 269,
        ),
        title: '晴天',
        artist: '周杰伦',
      ),
    );

    expect(handled, isTrue);
    expect(player.calls, <String>[
      'setUrl:https://example.com/resolved.mp3',
      'play',
    ]);
  });

  test('NativeAudioController skips tracks from synced page queue', () async {
    final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
    final FreeMusicApi api = _resolvingApi();
    final NativeAudioController controller = NativeAudioController(
      player: player,
      api: api,
    );
    await controller.setPlaybackMode(NativePlaybackMode.sequential);

    await controller.syncFromProbe(
      const PlayerProbeSnapshot(
        audioUrl: 'https://example.com/1.mp3',
        playing: true,
        currentIndex: 0,
        song: FreeMusicSong(
          id: '1',
          source: 'kuwo',
          name: '七里香',
          artist: '周杰伦',
          duration: 290,
          album: '七里香',
          cover: 'https://example.com/cover-1.jpg',
        ),
        playlist: <FreeMusicSong>[
          FreeMusicSong(
            id: '1',
            source: 'kuwo',
            name: '七里香',
            artist: '周杰伦',
            duration: 290,
            album: '七里香',
            cover: 'https://example.com/cover-1.jpg',
          ),
          FreeMusicSong(
            id: '2',
            source: 'kuwo',
            name: '晴天',
            artist: '周杰伦',
            duration: 269,
          ),
        ],
      ),
    );

    expect(await controller.skipToNext(), isTrue);
    expect(controller.currentIndex, 1);
    expect(await controller.skipToPrevious(), isTrue);
    expect(controller.currentIndex, 0);
    expect(await controller.skipToPrevious(), isFalse);
    expect(player.calls, <String>[
      'setUrl:https://example.com/1.mp3',
      'play',
      'setUrl:https://example.com/2.mp3',
      'play',
      'setUrl:https://example.com/1.mp3',
      'play',
    ]);
  });

  test(
    'NativeAudioController keeps playback paused when pause is requested during skip load',
    () async {
      final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
      final Completer<void> resolveStarted = Completer<void>();
      final Completer<void> releaseResolve = Completer<void>();
      final FreeMusicApi api = _resolvingApi(
        beforeResolve: (String id) async {
          if (id == '2' && !resolveStarted.isCompleted) {
            resolveStarted.complete();
            await releaseResolve.future;
          }
        },
      );
      final NativeAudioController controller = NativeAudioController(
        player: player,
        api: api,
      );

      await controller.syncFromProbe(
        const PlayerProbeSnapshot(
          audioUrl: 'https://example.com/1.mp3',
          playing: true,
          currentIndex: 0,
          song: FreeMusicSong(
            id: '1',
            source: 'kuwo',
            name: '七里香',
            artist: '周杰伦',
            duration: 290,
          ),
          playlist: <FreeMusicSong>[
            FreeMusicSong(
              id: '1',
              source: 'kuwo',
              name: '七里香',
              artist: '周杰伦',
              duration: 290,
            ),
            FreeMusicSong(
              id: '2',
              source: 'kuwo',
              name: '晴天',
              artist: '周杰伦',
              duration: 269,
            ),
          ],
        ),
      );
      player.calls.clear();

      final Future<bool> skipFuture = controller.skipToNext();
      await resolveStarted.future;
      expect(await controller.pausePlayback(), isTrue);
      releaseResolve.complete();

      expect(await skipFuture, isTrue);
      expect(controller.currentIndex, 1);
      expect(player.isPlaying, isFalse);
      expect(player.calls, isNot(contains('play')));
      expect(player.calls.last, 'pause');
    },
  );

  test('NativeAudioController repeats all from queue boundaries', () async {
    final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
    final FreeMusicApi api = _resolvingApi();
    final NativeAudioController controller = NativeAudioController(
      player: player,
      api: api,
    );

    await controller.syncFromProbe(
      const PlayerProbeSnapshot(
        audioUrl: 'https://example.com/2.mp3',
        playing: true,
        currentIndex: 1,
        song: FreeMusicSong(
          id: '2',
          source: 'kuwo',
          name: '晴天',
          artist: '周杰伦',
          duration: 269,
        ),
        playlist: <FreeMusicSong>[
          FreeMusicSong(
            id: '1',
            source: 'kuwo',
            name: '七里香',
            artist: '周杰伦',
            duration: 290,
          ),
          FreeMusicSong(
            id: '2',
            source: 'kuwo',
            name: '晴天',
            artist: '周杰伦',
            duration: 269,
          ),
        ],
      ),
    );
    await controller.setPlaybackMode(NativePlaybackMode.repeatAll);

    expect(await controller.skipToNext(), isTrue);
    expect(controller.currentIndex, 0);
    expect(await controller.skipToPrevious(), isTrue);
    expect(controller.currentIndex, 1);
  });

  test(
    'NativeAudioController repeat one reloads the current queue item',
    () async {
      final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
      final FreeMusicApi api = _resolvingApi();
      final NativeAudioController controller = NativeAudioController(
        player: player,
        api: api,
      );

      await controller.syncFromProbe(
        const PlayerProbeSnapshot(
          audioUrl: 'https://example.com/1.mp3',
          playing: true,
          currentIndex: 0,
          song: FreeMusicSong(
            id: '1',
            source: 'kuwo',
            name: '七里香',
            artist: '周杰伦',
            duration: 290,
          ),
          playlist: <FreeMusicSong>[
            FreeMusicSong(
              id: '1',
              source: 'kuwo',
              name: '七里香',
              artist: '周杰伦',
              duration: 290,
            ),
            FreeMusicSong(
              id: '2',
              source: 'kuwo',
              name: '晴天',
              artist: '周杰伦',
              duration: 269,
            ),
          ],
        ),
      );
      await controller.setPlaybackMode(NativePlaybackMode.repeatOne);
      player.calls.clear();

      expect(await controller.skipToNext(), isTrue);
      expect(controller.currentIndex, 0);
      expect(player.calls, <String>[
        'setUrl:https://example.com/1.mp3',
        'play',
      ]);
    },
  );

  test('NativeAudioController shuffle skips to another queue item', () async {
    final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
    final FreeMusicApi api = _resolvingApi();
    final NativeAudioController controller = NativeAudioController(
      player: player,
      api: api,
    );

    await controller.syncFromProbe(
      const PlayerProbeSnapshot(
        audioUrl: 'https://example.com/1.mp3',
        playing: true,
        currentIndex: 0,
        song: FreeMusicSong(
          id: '1',
          source: 'kuwo',
          name: '七里香',
          artist: '周杰伦',
          duration: 290,
          album: '七里香',
          cover: 'https://example.com/cover-1.jpg',
        ),
        playlist: <FreeMusicSong>[
          FreeMusicSong(
            id: '1',
            source: 'kuwo',
            name: '七里香',
            artist: '周杰伦',
            duration: 290,
            album: '七里香',
            cover: 'https://example.com/cover-1.jpg',
          ),
          FreeMusicSong(
            id: '2',
            source: 'kuwo',
            name: '晴天',
            artist: '周杰伦',
            duration: 269,
          ),
        ],
      ),
    );
    await controller.setPlaybackMode(NativePlaybackMode.shuffle);

    expect(await controller.skipToNext(), isTrue);
    expect(controller.currentIndex, 1);
  });

  test('NativeAudioController persists playback mode', () async {
    final NativeAudioController firstController = NativeAudioController(
      player: FakeNativeAudioPlayer(),
    );

    await firstController.setPlaybackMode(NativePlaybackMode.shuffle);

    final NativeAudioController restoredController = NativeAudioController(
      player: FakeNativeAudioPlayer(),
    );

    await restoredController.syncQueueFromProbe(
      const PlayerProbeSnapshot(audioUrl: '', playing: false),
    );

    expect(restoredController.playbackMode, NativePlaybackMode.shuffle);
  });

  test('NativeAudioController plays a selected queue index directly', () async {
    final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
    final FreeMusicApi api = _resolvingApi();
    final NativeAudioController controller = NativeAudioController(
      player: player,
      api: api,
    );

    await controller.syncQueueFromProbe(
      const PlayerProbeSnapshot(
        audioUrl: '',
        playing: false,
        currentIndex: 0,
        playlist: <FreeMusicSong>[
          FreeMusicSong(
            id: '1',
            source: 'kuwo',
            name: '七里香',
            artist: '周杰伦',
            duration: 290,
          ),
          FreeMusicSong(
            id: '2',
            source: 'kuwo',
            name: '晴天',
            artist: '周杰伦',
            duration: 269,
          ),
        ],
      ),
    );

    expect(await controller.skipToQueueIndex(1), isTrue);
    expect(controller.currentIndex, 1);
    expect(await controller.skipToQueueIndex(3), isFalse);

    expect(player.calls, <String>['setUrl:https://example.com/2.mp3', 'play']);
  });

  test('NativeAudioController resumes from loaded track', () async {
    final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
    final NativeAudioController controller = NativeAudioController(
      player: player,
    );

    await controller.syncFromProbe(
      const PlayerProbeSnapshot(
        audioUrl: 'https://example.com/song.mp3',
        playing: false,
        title: '晴天',
      ),
    );
    player.calls.clear();

    expect(await controller.resumePlayback(), isTrue);

    expect(player.calls, <String>[
      'setUrl:https://example.com/song.mp3',
      'play',
    ]);
  });

  test('NativeAudioController resumes from synced queue', () async {
    final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
    final FreeMusicApi api = _resolvingApi();
    final NativeAudioController controller = NativeAudioController(
      player: player,
      api: api,
    );

    await controller.syncQueueFromProbe(
      const PlayerProbeSnapshot(
        audioUrl: '',
        playing: false,
        currentIndex: 1,
        playlist: <FreeMusicSong>[
          FreeMusicSong(
            id: '1',
            source: 'kuwo',
            name: '七里香',
            artist: '周杰伦',
            duration: 290,
          ),
          FreeMusicSong(
            id: '2',
            source: 'kuwo',
            name: '晴天',
            artist: '周杰伦',
            duration: 269,
          ),
        ],
      ),
    );

    expect(await controller.resumePlayback(), isTrue);

    expect(player.calls, <String>['setUrl:https://example.com/2.mp3', 'play']);
  });

  test('NativeAudioController restores persisted track and queue', () async {
    final FakeNativeAudioPlayer firstPlayer = FakeNativeAudioPlayer();
    final NativeAudioController firstController = NativeAudioController(
      player: firstPlayer,
    );

    await firstController.syncFromProbe(
      const PlayerProbeSnapshot(
        audioUrl: 'https://example.com/1.mp3',
        playing: false,
        currentIndex: 0,
        title: '七里香',
        artist: '周杰伦',
        song: FreeMusicSong(
          id: '1',
          source: 'kuwo',
          name: '七里香',
          artist: '周杰伦',
          duration: 290,
          album: '七里香',
          cover: 'https://example.com/cover-1.jpg',
        ),
        playlist: <FreeMusicSong>[
          FreeMusicSong(
            id: '1',
            source: 'kuwo',
            name: '七里香',
            artist: '周杰伦',
            duration: 290,
            album: '七里香',
            cover: 'https://example.com/cover-1.jpg',
          ),
          FreeMusicSong(
            id: '2',
            source: 'kuwo',
            name: '晴天',
            artist: '周杰伦',
            duration: 269,
          ),
        ],
      ),
    );

    final FakeNativeAudioPlayer restoredPlayer = FakeNativeAudioPlayer();
    final FreeMusicApi api = _resolvingApi();
    final NativeAudioController restoredController = NativeAudioController(
      player: restoredPlayer,
      api: api,
    );

    expect(await restoredController.resumePlayback(), isTrue);
    expect(restoredController.playlist.first.album, '七里香');
    expect(
      restoredController.playlist.first.cover,
      'https://example.com/cover-1.jpg',
    );
    expect(await restoredController.skipToNext(), isTrue);

    expect(restoredPlayer.calls, <String>[
      'setUrl:https://example.com/1.mp3',
      'play',
      'setUrl:https://example.com/2.mp3',
      'play',
    ]);
  });

  test(
    'NativeAudioController returns false when primary URL fails without source switch support',
    () async {
      final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
      final FreeMusicApi api = _resolvingApi(failingIds: <String>{'1'});
      final NativeAudioController controller = NativeAudioController(
        player: player,
        api: api,
      );

      final bool handled = await controller.syncFromProbe(
        const PlayerProbeSnapshot(
          audioUrl: '',
          playing: true,
          song: FreeMusicSong(
            id: '1',
            source: 'kuwo',
            name: '晴天',
            artist: '周杰伦',
            duration: 269,
          ),
          title: '晴天',
          artist: '周杰伦',
        ),
      );

      expect(handled, isFalse);
      expect(player.calls, isEmpty);
    },
  );

  test('NativeAudioController recovers after a player load failure', () async {
    final FakeNativeAudioPlayer player = FakeNativeAudioPlayer()
      ..failLoadUrls.add('https://example.com/bad.mp3');
    final NativeAudioController controller = NativeAudioController(
      player: player,
    );

    final bool failed = await controller.syncFromProbe(
      const PlayerProbeSnapshot(
        audioUrl: 'https://example.com/bad.mp3',
        playing: true,
        title: '坏音源',
      ),
    );
    final bool recovered = await controller.syncFromProbe(
      const PlayerProbeSnapshot(
        audioUrl: 'https://example.com/good.mp3',
        playing: true,
        title: '可播放',
      ),
    );

    expect(failed, isFalse);
    expect(recovered, isTrue);
    expect(player.calls, <String>[
      'setUrl:https://example.com/bad.mp3',
      'setUrl:https://example.com/good.mp3',
      'play',
    ]);
  });

  test(
    'NativeAudioController keeps queue usable after failed queue load',
    () async {
      final FakeNativeAudioPlayer player = FakeNativeAudioPlayer()
        ..failLoadUrls.add('https://example.com/2.mp3');
      final FreeMusicApi api = _resolvingApi();
      final NativeAudioController controller = NativeAudioController(
        player: player,
        api: api,
      );

      await controller.syncFromProbe(
        const PlayerProbeSnapshot(
          audioUrl: 'https://example.com/1.mp3',
          playing: true,
          currentIndex: 0,
          song: FreeMusicSong(
            id: '1',
            source: 'kuwo',
            name: '七里香',
            artist: '周杰伦',
            duration: 290,
          ),
          playlist: <FreeMusicSong>[
            FreeMusicSong(
              id: '1',
              source: 'kuwo',
              name: '七里香',
              artist: '周杰伦',
              duration: 290,
            ),
            FreeMusicSong(
              id: '2',
              source: 'kuwo',
              name: '晴天',
              artist: '周杰伦',
              duration: 269,
            ),
          ],
        ),
      );

      // Next track fails to load: chain past it. With repeatAll the walk can
      // recover onto another playable item (here index 0) instead of leaving a
      // dead "playing" session stuck on the bad track.
      expect(await controller.skipToNext(), isTrue);
      expect(controller.currentIndex, 0);
      expect(player.isPlaying, isTrue);

      player.failLoadUrls.clear();
      expect(await controller.skipToNext(), isTrue);
      expect(controller.currentIndex, 1);
    },
  );

  test('NativeAudioController gives up when every source fails', () async {
    final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
    final FreeMusicApi api = _resolvingApi(failingIds: <String>{'1'});
    final NativeAudioController controller = NativeAudioController(
      player: player,
      api: api,
    );

    final bool handled = await controller.syncFromProbe(
      const PlayerProbeSnapshot(
        audioUrl: '',
        playing: true,
        song: FreeMusicSong(
          id: '1',
          source: 'kuwo',
          name: '晴天',
          artist: '周杰伦',
          duration: 269,
        ),
        title: '晴天',
        artist: '周杰伦',
      ),
    );

    expect(handled, isFalse);
    expect(player.calls, isEmpty);
  });

  test('resolved URL LRU is reused across consecutive skips', () async {
    final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
    final FakeNativeAudioPlayer preload = FakeNativeAudioPlayer();
    int resolveCount = 0;
    final FreeMusicApi api = FreeMusicApi(
      client: MockClient((http.Request request) async {
        if (_isAuthRequest(request)) {
          return _authResponse();
        }
        final List<String> segments = request.url.pathSegments;
        if (segments.length >= 5 &&
            request.url.path.startsWith('/api/music/songs/url/')) {
          resolveCount += 1;
          final String id = segments.last;
          return _songUrlResponse('https://example.com/$id.mp3');
        }
        return http.Response('Not Found', 404);
      }),
    );
    final NativeAudioController controller = NativeAudioController(
      player: player,
      api: api,
      preloadPlayer: preload,
      enableAudioPrebuffer: true,
      lookaheadDepth: 3,
    );

    await controller.syncFromProbe(
      const PlayerProbeSnapshot(
        audioUrl: '',
        playing: true,
        currentIndex: 0,
        song: FreeMusicSong(
          id: '1',
          source: 'kuwo',
          name: '七里香',
          artist: '周杰伦',
          duration: 290,
        ),
        playlist: <FreeMusicSong>[
          FreeMusicSong(
            id: '1',
            source: 'kuwo',
            name: '七里香',
            artist: '周杰伦',
            duration: 290,
          ),
          FreeMusicSong(
            id: '2',
            source: 'kuwo',
            name: '晴天',
            artist: '周杰伦',
            duration: 269,
          ),
          FreeMusicSong(
            id: '3',
            source: 'kuwo',
            name: '以父之名',
            artist: '周杰伦',
            duration: 341,
          ),
        ],
      ),
    );
    // Allow lookahead to fill the URL cache for next tracks.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final int afterLookahead = resolveCount;

    expect(await controller.skipToNext(), isTrue);
    expect(controller.currentIndex, 1);
    expect(await controller.skipToNext(), isTrue);
    expect(controller.currentIndex, 2);

    // Skips should hit the short-term URL cache rather than re-resolve.
    expect(resolveCount, afterLookahead);
    expect(controller.resolvedUrlCacheContains(_song('2')), isTrue);
    expect(controller.resolvedUrlCacheContains(_song('3')), isTrue);
  });

  test('stale lookahead cannot overwrite after generation bump', () async {
    final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
    final Completer<void> holdResolve = Completer<void>();
    int resolveStarts = 0;
    final FreeMusicApi api = FreeMusicApi(
      client: MockClient((http.Request request) async {
        if (_isAuthRequest(request)) {
          return _authResponse();
        }
        final List<String> segments = request.url.pathSegments;
        if (segments.length >= 5 &&
            request.url.path.startsWith('/api/music/songs/url/')) {
          resolveStarts += 1;
          final String id = segments.last;
          if (id == '2' && resolveStarts <= 2) {
            await holdResolve.future;
          }
          return _songUrlResponse('https://example.com/$id.mp3');
        }
        return http.Response('Not Found', 404);
      }),
    );
    final NativeAudioController controller = NativeAudioController(
      player: player,
      api: api,
      enableAudioPrebuffer: false,
      lookaheadDepth: 2,
    );

    await controller.syncFromProbe(
      PlayerProbeSnapshot(
        audioUrl: 'https://example.com/1.mp3',
        playing: true,
        currentIndex: 0,
        song: _song('1'),
        playlist: <FreeMusicSong>[_song('1'), _song('2'), _song('3')],
      ),
    );
    final int genAfterLoad = controller.preloadGeneration;

    // Start a skip that bumps generation while a stale resolve is held.
    final Future<bool> skipFuture = controller.skipToNext();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.preloadGeneration, greaterThan(genAfterLoad));

    holdResolve.complete();
    expect(await skipFuture, isTrue);
    // Give stale tasks a chance to finish; they must not crash or regress index.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.currentIndex, 1);
  });

  test('rapid consecutive skips mark rapid transition and skip long fades', () async {
    DateTime now = DateTime(2026, 7, 21, 12, 0, 0);
    final FakeNativeAudioPlayer player = FakeNativeAudioPlayer()..isPlaying = true;
    final FreeMusicApi api = _resolvingApi();
    final NativeAudioController controller = NativeAudioController(
      player: player,
      api: api,
      enableAudioPrebuffer: false,
      clock: () => now,
    );

    await controller.syncFromProbe(
      PlayerProbeSnapshot(
        audioUrl: 'https://example.com/1.mp3',
        playing: true,
        currentIndex: 0,
        song: _song('1'),
        playlist: <FreeMusicSong>[_song('1'), _song('2'), _song('3')],
      ),
    );
    // First queue skip establishes last transition time.
    player.isPlaying = true;
    expect(await controller.skipToNext(), isTrue);
    expect(controller.lastLoadUsedRapidTransition, isFalse);

    now = now.add(const Duration(milliseconds: 200));
    player.isPlaying = true;
    expect(await controller.skipToNext(), isTrue);
    expect(controller.lastLoadUsedRapidTransition, isTrue);
  });

  test('secondary prebuffer player warms the immediate next track', () async {
    final FakeNativeAudioPlayer player = FakeNativeAudioPlayer();
    final FakeNativeAudioPlayer preload = FakeNativeAudioPlayer();
    final FreeMusicApi api = _resolvingApi();
    final NativeAudioController controller = NativeAudioController(
      player: player,
      api: api,
      preloadPlayer: preload,
      enableAudioPrebuffer: true,
      lookaheadDepth: 2,
    );

    await controller.syncFromProbe(
      PlayerProbeSnapshot(
        audioUrl: 'https://example.com/1.mp3',
        playing: true,
        currentIndex: 0,
        song: _song('1'),
        playlist: <FreeMusicSong>[_song('1'), _song('2'), _song('3')],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(controller.prebufferedIndex, 1);
    expect(controller.prebufferedUrl, 'https://example.com/2.mp3');
    expect(preload.lastUrl, 'https://example.com/2.mp3');
    expect(preload.calls, contains('setUrl:https://example.com/2.mp3'));
  });
}

FreeMusicSong _song(String id) {
  return FreeMusicSong(
    id: id,
    source: 'kuwo',
    name: 'song-$id',
    artist: 'artist',
    duration: 200,
  );
}

FreeMusicApi _resolvingApi({
  Set<String> failingIds = const <String>{},
  Future<void> Function(String id)? beforeResolve,
}) {
  return FreeMusicApi(
    client: MockClient((http.Request request) async {
      if (_isAuthRequest(request)) {
        return _authResponse();
      }
      final List<String> segments = request.url.pathSegments;
      if (segments.length >= 5 &&
          request.url.path.startsWith('/api/music/songs/url/')) {
        final String id = segments.last;
        if (beforeResolve != null) {
          await beforeResolve(id);
        }
        if (failingIds.contains(id)) {
          return http.Response('{"code":500,"message":"unavailable"}', 502);
        }
        return _songUrlResponse('https://example.com/$id.mp3');
      }
      return http.Response('Not Found', 404);
    }),
  );
}

bool _isAuthRequest(http.Request request) {
  return request.url.path == '/api/v1/auth/login' ||
      request.url.path == '/api/v1/auth/refresh';
}

http.Response _authResponse() {
  return http.Response(
    '{"code":0,"message":"success","data":{'
    '"access_token":"mock_access_token",'
    '"refresh_token":"mock_refresh_token",'
    '"expires_in":7200}}',
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

http.Response _songUrlResponse(String url) {
  return http.Response(
    '{"code":0,"message":"success","data":{"url":"$url"}}',
    200,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

class FakeNativeAudioPlayer implements NativeAudioPlayer {
  final List<String> calls = <String>[];
  final Set<String> failLoadUrls = <String>{};
  bool isPlaying = false;
  String? lastUrl;

  @override
  Duration get bufferedPosition => Duration.zero;

  @override
  bool get playing => isPlaying;

  @override
  Stream<PlaybackEvent> get playbackEventStream =>
      const Stream<PlaybackEvent>.empty();

  @override
  PlaybackEvent get playbackEvent => PlaybackEvent();

  @override
  Duration get position => Duration.zero;

  @override
  ProcessingState get processingState => ProcessingState.idle;

  @override
  double get speed => 1;

  @override
  int? get androidAudioSessionId => 7;

  @override
  Stream<int?> get androidAudioSessionIdStream => Stream<int?>.value(7);

  @override
  Future<void> dispose() async {
    calls.add('dispose');
  }

  @override
  Future<void> loadFromSnapshot(
    String url,
    PlayerProbeSnapshot snapshot,
  ) async {
    lastUrl = url;
    calls.add('setUrl:$url');
    if (failLoadUrls.contains(url)) {
      throw StateError('failed to load $url');
    }
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    calls.add('pause');
  }

  @override
  Future<void> pauseDirect() async {
    await pause();
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    calls.add('play');
  }

  @override
  Future<void> playDirect() async {
    await play();
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
  }

  @override
  Future<void> setVolume(double volume) async {
    // Volume fades are timing side-effects; keep out of call traces used by
    // core transport assertions. Rapid-skip coverage uses controller flags.
  }

  @override
  Future<Duration?> setUrl(String url) async {
    lastUrl = url;
    calls.add('setUrl:$url');
    if (failLoadUrls.contains(url)) {
      throw StateError('failed to load $url');
    }
    return null;
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    calls.add('stop');
  }
}
