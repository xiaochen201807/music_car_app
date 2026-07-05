import 'package:flutter_test/flutter_test.dart';
import 'package:audio_service/audio_service.dart';
import 'package:music_car_app/controllers/playback_controller.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:music_car_app/music_audio_handler.dart';
import 'package:music_car_app/native_audio_controller.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  test('pause and previous commands are debounced', () async {
    final _FakePlaybackBackend backend = _FakePlaybackBackend();
    final PlaybackController controller = PlaybackController.withBackend(
      backend: backend,
      commandDebounce: const Duration(milliseconds: 500),
    );
    final DateTime start = DateTime(2026, 1, 1, 12);

    expect(await controller.pauseNativePlayback(now: start), isTrue);
    expect(
      await controller.pauseNativePlayback(
        now: start.add(const Duration(milliseconds: 200)),
      ),
      isFalse,
    );
    expect(
      await controller.pauseNativePlayback(
        now: start.add(const Duration(milliseconds: 700)),
      ),
      isTrue,
    );

    expect(await controller.skipToPrevious(now: start), isTrue);
    expect(
      await controller.skipToPrevious(
        now: start.add(const Duration(milliseconds: 200)),
      ),
      isFalse,
    );

    expect(backend.pauseCalls, 2);
    expect(backend.previousCalls, 1);
  });

  test('playback actions delegate through backend', () async {
    final _FakePlaybackBackend backend = _FakePlaybackBackend();
    final PlaybackController controller = PlaybackController.withBackend(
      backend: backend,
    );
    final FreeMusicSong song = _song('1');
    final PlayerProbeSnapshot snapshot = PlayerProbeSnapshot(
      audioUrl: '',
      playing: true,
      song: song,
    );

    expect(await controller.resumeNativePlayback(), isTrue);
    expect(await controller.skipToNext(), isTrue);
    expect(await controller.playSnapshot(snapshot), isTrue);
    expect(await controller.skipToQueueIndex(2), isTrue);
    expect(await controller.playSong(song), isTrue);
    await controller.setPlaybackMode(NativePlaybackMode.shuffle);
    expect(await controller.cyclePlaybackMode(), NativePlaybackMode.repeatOne);
    await controller.seekNative(const Duration(seconds: 42));

    expect(backend.calls, <String>[
      'resume',
      'next',
      'sync:1',
      'queue:2',
      'playSong:1',
      'mode:shuffle',
      'cycle',
      'seek:42000',
    ]);
  });

  test('queue action busy flag is owned by playback controller', () {
    final PlaybackController controller = PlaybackController.withBackend(
      backend: _FakePlaybackBackend(),
    );

    expect(controller.queueActionBusy, isFalse);
    expect(controller.beginQueueAction(), isTrue);
    expect(controller.queueActionBusy, isTrue);
    expect(controller.beginQueueAction(), isFalse);
    controller.endQueueAction();
    expect(controller.queueActionBusy, isFalse);
  });

  test('volume state is clamped even without an audio handler', () async {
    final PlaybackController controller = PlaybackController.withBackend(
      backend: _FakePlaybackBackend(),
    );

    await controller.setVolume(1.5);
    expect(controller.volume, 1.0);

    await controller.setVolume(-0.5);
    expect(controller.volume, 0.0);
  });

  test('togglePlayback delegates to audio handler real-state click', () async {
    final _FakeNativeAudioPlayer player = _FakeNativeAudioPlayer()
      ..isPlaying = true;
    final MusicAudioHandler handler = MusicAudioHandler(player: player);
    final PlaybackController controller = PlaybackController.withBackend(
      backend: _FakePlaybackBackend(),
      audioHandler: handler,
    );

    handler.playbackState.add(PlaybackState(playing: false));
    await controller.togglePlayback();

    expect(player.isPlaying, isFalse);
    expect(player.pauseCalls, 1);
    expect(player.playCalls, 0);

    await handler.dispose();
  });
}

class _FakePlaybackBackend implements PlaybackBackend {
  final List<String> calls = <String>[];
  int pauseCalls = 0;
  int previousCalls = 0;

  @override
  Duration get position => const Duration(seconds: 12);

  @override
  Future<NativePlaybackMode> cyclePlaybackMode() async {
    calls.add('cycle');
    return NativePlaybackMode.repeatOne;
  }

  @override
  Future<bool> pausePlayback() async {
    calls.add('pause');
    pauseCalls += 1;
    return true;
  }

  @override
  Future<bool> playSong(FreeMusicSong song) async {
    calls.add('playSong:${song.id}');
    return true;
  }

  @override
  Future<bool> resumePlayback() async {
    calls.add('resume');
    return true;
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
  }

  @override
  Future<void> setPlaybackMode(NativePlaybackMode mode) async {
    calls.add('mode:${mode.storageValue}');
  }

  @override
  Future<bool> skipToNext() async {
    calls.add('next');
    return true;
  }

  @override
  Future<bool> skipToPrevious() async {
    calls.add('previous');
    previousCalls += 1;
    return true;
  }

  @override
  Future<bool> skipToQueueIndex(int index) async {
    calls.add('queue:$index');
    return true;
  }

  @override
  Future<bool> syncFromProbe(PlayerProbeSnapshot snapshot) async {
    calls.add('sync:${snapshot.song?.id ?? ''}');
    return true;
  }
}

FreeMusicSong _song(String id) {
  return FreeMusicSong(
    id: id,
    source: 'kuwo',
    name: 'Song $id',
    artist: 'Artist',
    duration: 120,
  );
}

class _FakeNativeAudioPlayer implements NativeAudioPlayer {
  bool isPlaying = false;
  int playCalls = 0;
  int pauseCalls = 0;

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
  Future<void> dispose() async {}

  @override
  Future<void> loadFromSnapshot(
    String url,
    PlayerProbeSnapshot snapshot,
  ) async {}

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    isPlaying = false;
  }

  @override
  Future<void> pauseDirect() => pause();

  @override
  Future<void> play() async {
    playCalls += 1;
    isPlaying = true;
  }

  @override
  Future<void> playDirect() => play();

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<Duration?> setUrl(String url) async => Duration.zero;

  @override
  Future<void> stop() async {
    isPlaying = false;
  }
}
