import 'package:just_audio/just_audio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/music_audio_handler.dart';
import 'package:music_car_app/native_audio_controller.dart';

class _FakeNativeAudioPlayer implements NativeAudioPlayer {
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
  Future<void> dispose() async {}

  @override
  Future<void> loadFromSnapshot(
    String url,
    PlayerProbeSnapshot snapshot,
  ) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

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
}
