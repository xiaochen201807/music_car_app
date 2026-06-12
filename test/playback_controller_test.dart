import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/controllers/playback_controller.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:music_car_app/native_audio_controller.dart';

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
