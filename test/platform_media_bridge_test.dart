import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/controllers/playback_controller.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:music_car_app/native_audio_controller.dart';
import 'package:music_car_app/services/carlife_service.dart';
import 'package:music_car_app/services/platform_media_bridge.dart';

void main() {
  test(
    'external skip next notifies track-changed (UI queue may still be stale)',
    () async {
      final _FakePlaybackBackend backend = _FakePlaybackBackend()
        ..nextResult = true;
      final PlaybackController playback = PlaybackController.withBackend(
        backend: backend,
      );
      final PlatformMediaBridge bridge = PlatformMediaBridge(
        playbackController: playback,
        carLifeService: CarLifeService(),
      );

      int notifyCount = 0;
      bridge.onTrackChanged = () {
        notifyCount += 1;
      };

      final bool handled = await bridge.handleExternalSkipNext();

      expect(handled, isTrue);
      expect(backend.skipNextCalls, 1);
      // Bridge must always fire after a successful skip so the UI can re-sync
      // lyrics from NativeAudioController rather than the stale QueueController.
      expect(notifyCount, 1);
    },
  );

  test('external skip previous notifies track-changed after success', () async {
    final _FakePlaybackBackend backend = _FakePlaybackBackend()
      ..previousResult = true;
    final PlaybackController playback = PlaybackController.withBackend(
      backend: backend,
    );
    final PlatformMediaBridge bridge = PlatformMediaBridge(
      playbackController: playback,
      carLifeService: CarLifeService(),
    );

    int notifyCount = 0;
    bridge.onTrackChanged = () {
      notifyCount += 1;
    };

    final bool handled = await bridge.handleExternalSkipPrevious();

    expect(handled, isTrue);
    expect(backend.skipPreviousCalls, 1);
    expect(notifyCount, 1);
  });

  test('failed external skip does not notify track-changed', () async {
    final _FakePlaybackBackend backend = _FakePlaybackBackend()
      ..nextResult = false;
    final PlaybackController playback = PlaybackController.withBackend(
      backend: backend,
    );
    final PlatformMediaBridge bridge = PlatformMediaBridge(
      playbackController: playback,
      carLifeService: CarLifeService(),
    );

    int notifyCount = 0;
    bridge.onTrackChanged = () {
      notifyCount += 1;
    };

    final bool handled = await bridge.handleExternalSkipNext();

    expect(handled, isFalse);
    expect(notifyCount, 0);
  });
}

class _FakePlaybackBackend implements PlaybackBackend {
  int skipNextCalls = 0;
  int skipPreviousCalls = 0;
  bool nextResult = true;
  bool previousResult = true;

  @override
  Future<bool> resumePlayback() async => true;

  @override
  Future<bool> pausePlayback() async => true;

  @override
  Future<bool> skipToNext() async {
    skipNextCalls += 1;
    return nextResult;
  }

  @override
  Future<bool> skipToPrevious() async {
    skipPreviousCalls += 1;
    return previousResult;
  }

  @override
  Future<bool> syncFromProbe(PlayerProbeSnapshot snapshot) async => true;

  @override
  Future<bool> skipToQueueIndex(int index) async => true;

  @override
  Future<NativePlaybackMode> cyclePlaybackMode() async {
    return NativePlaybackMode.repeatAll;
  }

  @override
  Future<void> setPlaybackMode(NativePlaybackMode mode) async {}

  @override
  Duration get position => Duration.zero;

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<bool> playSong(FreeMusicSong song) async => true;
}
