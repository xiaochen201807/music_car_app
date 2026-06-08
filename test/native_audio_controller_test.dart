import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:music_car_app/native_audio_controller.dart';

void main() {
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

  test('pauseWebAudioScript marks native audio as active', () {
    expect(pauseWebAudioScript, contains('__musicCarNativeAudioActive'));
    expect(pauseWebAudioScript, contains('__musicCarSuppressPauseUntil'));
    expect(pauseWebAudioScript, contains('audio.pause()'));
    expect(pauseWebAudioScript, contains('audio.muted = true'));
  });

  test('track skip scripts click WebView player controls', () {
    expect(clickNextTrackScript, contains('.music-btn-next'));
    expect(clickNextTrackScript, contains('button.click()'));
    expect(clickPreviousTrackScript, contains('.music-btn-prev'));
    expect(clickPreviousTrackScript, contains('button.click()'));
  });
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
