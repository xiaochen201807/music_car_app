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
        expect(request.url.path, '/api/v1/freemusic/song_url');
        expect(request.url.queryParameters['id'], '228908');
        return http.Response(
          '{"direct":true,"source":"kuwo","url":"https://example.com/resolved.mp3"}',
          200,
        );
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
    final FreeMusicApi api = FreeMusicApi(
      client: MockClient((http.Request request) async {
        final String id = request.url.queryParameters['id'] ?? '';
        return http.Response(
          '{"direct":true,"source":"kuwo","url":"https://example.com/$id.mp3"}',
          200,
        );
      }),
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
    final FreeMusicApi api = FreeMusicApi(
      client: MockClient((http.Request request) async {
        final String id = request.url.queryParameters['id'] ?? '';
        return http.Response(
          '{"direct":true,"source":"kuwo","url":"https://example.com/$id.mp3"}',
          200,
        );
      }),
    );
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
    final FreeMusicApi api = FreeMusicApi(
      client: MockClient((http.Request request) async {
        expect(request.url.queryParameters['id'], '2');
        return http.Response(
          '{"direct":true,"source":"kuwo","url":"https://example.com/2.mp3"}',
          200,
        );
      }),
    );
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
    final FreeMusicApi api = FreeMusicApi(
      client: MockClient((http.Request request) async {
        expect(request.url.queryParameters['id'], '2');
        return http.Response(
          '{"direct":true,"source":"kuwo","url":"https://example.com/2.mp3"}',
          200,
        );
      }),
    );
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
}

FreeMusicApi _resolvingApi() {
  return FreeMusicApi(
    client: MockClient((http.Request request) async {
      final String id = request.url.queryParameters['id'] ?? '';
      return http.Response(
        '{"direct":true,"source":"kuwo","url":"https://example.com/$id.mp3"}',
        200,
      );
    }),
  );
}

class FakeNativeAudioPlayer implements NativeAudioPlayer {
  final List<String> calls = <String>[];

  @override
  Duration get bufferedPosition => Duration.zero;

  @override
  bool get playing => false;

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
  Future<void> dispose() async {
    calls.add('dispose');
  }

  @override
  Future<void> loadFromSnapshot(
    String url,
    PlayerProbeSnapshot snapshot,
  ) async {
    calls.add('setUrl:$url');
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> play() async {
    calls.add('play');
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
  }

  @override
  Future<Duration?> setUrl(String url) async {
    calls.add('setUrl:$url');
    return null;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }
}
