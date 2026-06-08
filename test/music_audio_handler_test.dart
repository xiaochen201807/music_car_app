import 'package:just_audio/just_audio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/music_audio_handler.dart';
import 'package:music_car_app/native_audio_controller.dart';

class _FakeNativeAudioPlayer implements NativeAudioPlayer {
  bool isPlaying = false;
  Duration currentPosition = Duration.zero;

  @override
  Duration get bufferedPosition => Duration.zero;

  @override
  bool get playing => isPlaying;

  @override
  Stream<PlaybackEvent> get playbackEventStream =>
      const Stream<PlaybackEvent>.empty();

  @override
  Duration get position => currentPosition;

  @override
  ProcessingState get processingState => ProcessingState.idle;

  @override
  double get speed => 1;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> loadFromSnapshot(
    String url,
    PlayerProbeSnapshot snapshot,
  ) async {}

  @override
  Future<void> pause() async {
    isPlaying = false;
  }

  @override
  Future<void> play() async {
    isPlaying = true;
  }

  @override
  Future<void> seek(Duration position) async {
    currentPosition = position;
  }

  @override
  Future<Duration?> setUrl(String url) async => Duration.zero;

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('autoSkipToNextAfterCompletion triggers next once', () async {
    final MusicAudioHandler handler = MusicAudioHandler();
    int nextCalls = 0;
    handler.onSkipToNextTrack = () async {
      nextCalls += 1;
    };

    await handler.autoSkipToNextAfterCompletion();
    await handler.autoSkipToNextAfterCompletion();

    expect(nextCalls, 1);

    await handler.dispose();
  });

  test('loadFromSnapshot exposes current item as a browsable queue', () async {
    final MusicAudioHandler handler = MusicAudioHandler(
      player: _FakeNativeAudioPlayer(),
    );

    await handler.loadFromSnapshot(
      'https://example.com/song.mp3',
      const PlayerProbeSnapshot(
        audioUrl: 'https://example.com/song.mp3',
        playing: true,
        title: '晴天',
        artist: '周杰伦',
      ),
    );

    final children = await handler.getChildren('root');

    expect(children, hasLength(1));
    expect(children.single.title, '晴天');
    expect(children.single.artist, '周杰伦');
    expect(children.single.playable, isTrue);

    await handler.dispose();
  });

  test(
    'checkForPlaybackStall skips next after ten seconds without progress',
    () async {
      final _FakeNativeAudioPlayer player = _FakeNativeAudioPlayer()
        ..isPlaying = true
        ..currentPosition = const Duration(seconds: 30);
      final MusicAudioHandler handler = MusicAudioHandler(player: player);
      int nextCalls = 0;
      handler.onSkipToNextTrack = () async {
        nextCalls += 1;
      };

      await handler.loadFromSnapshot(
        'https://example.com/song.mp3',
        const PlayerProbeSnapshot(
          audioUrl: 'https://example.com/song.mp3',
          playing: true,
          title: '晴天',
        ),
      );

      final DateTime start = DateTime(2026, 1, 1, 12);
      await handler.checkForPlaybackStall(start);
      await handler.checkForPlaybackStall(
        start.add(const Duration(seconds: 9)),
      );
      expect(nextCalls, 0);

      await handler.checkForPlaybackStall(
        start.add(const Duration(seconds: 10)),
      );
      expect(nextCalls, 1);

      await handler.checkForPlaybackStall(
        start.add(const Duration(seconds: 12)),
      );
      expect(nextCalls, 1);

      await handler.dispose();
    },
  );

  test('checkForPlaybackStall ignores paused playback', () async {
    final _FakeNativeAudioPlayer player = _FakeNativeAudioPlayer()
      ..isPlaying = false
      ..currentPosition = const Duration(seconds: 30);
    final MusicAudioHandler handler = MusicAudioHandler(player: player);
    int nextCalls = 0;
    handler.onSkipToNextTrack = () async {
      nextCalls += 1;
    };

    await handler.loadFromSnapshot(
      'https://example.com/song.mp3',
      const PlayerProbeSnapshot(
        audioUrl: 'https://example.com/song.mp3',
        playing: false,
        title: '晴天',
      ),
    );

    final DateTime start = DateTime(2026, 1, 1, 12);
    await handler.checkForPlaybackStall(start);
    await handler.checkForPlaybackStall(start.add(const Duration(seconds: 30)));

    expect(nextCalls, 0);

    await handler.dispose();
  });
}
