import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/native_audio_controller.dart';
import 'package:music_car_app/utils/playback_mode_utils.dart';

void main() {
  group('nativePlaybackModeFromSessionModes', () {
    test('shuffle wins over any repeat mode', () {
      expect(
        nativePlaybackModeFromSessionModes(
          repeatMode: AudioServiceRepeatMode.all,
          shuffleMode: AudioServiceShuffleMode.all,
        ),
        NativePlaybackMode.shuffle,
      );
      expect(
        nativePlaybackModeFromSessionModes(
          repeatMode: AudioServiceRepeatMode.one,
          shuffleMode: AudioServiceShuffleMode.all,
        ),
        NativePlaybackMode.shuffle,
      );
      expect(
        nativePlaybackModeFromSessionModes(
          repeatMode: AudioServiceRepeatMode.none,
          shuffleMode: AudioServiceShuffleMode.all,
        ),
        NativePlaybackMode.shuffle,
      );
    });

    test('shuffle none keeps list-loop and single-loop', () {
      // Regression: shuffle=none must not force sequential when repeat is all/one.
      expect(
        nativePlaybackModeFromSessionModes(
          repeatMode: AudioServiceRepeatMode.all,
          shuffleMode: AudioServiceShuffleMode.none,
        ),
        NativePlaybackMode.repeatAll,
      );
      expect(
        nativePlaybackModeFromSessionModes(
          repeatMode: AudioServiceRepeatMode.group,
          shuffleMode: AudioServiceShuffleMode.none,
        ),
        NativePlaybackMode.repeatAll,
      );
      expect(
        nativePlaybackModeFromSessionModes(
          repeatMode: AudioServiceRepeatMode.one,
          shuffleMode: AudioServiceShuffleMode.none,
        ),
        NativePlaybackMode.repeatOne,
      );
    });

    test('repeat none + shuffle none is sequential', () {
      expect(
        nativePlaybackModeFromSessionModes(
          repeatMode: AudioServiceRepeatMode.none,
          shuffleMode: AudioServiceShuffleMode.none,
        ),
        NativePlaybackMode.sequential,
      );
    });
  });

  group('native ↔ session round-trip helpers', () {
    test('repeatAll publishes all + none and maps back', () {
      final AudioServiceRepeatMode repeat = repeatModeForNativeMode(
        NativePlaybackMode.repeatAll,
      );
      final AudioServiceShuffleMode shuffle = shuffleModeForNativeMode(
        NativePlaybackMode.repeatAll,
      );
      expect(repeat, AudioServiceRepeatMode.all);
      expect(shuffle, AudioServiceShuffleMode.none);
      expect(
        nativePlaybackModeFromSessionModes(
          repeatMode: repeat,
          shuffleMode: shuffle,
        ),
        NativePlaybackMode.repeatAll,
      );
    });

    test('repeatOne publishes one + none and maps back', () {
      final AudioServiceRepeatMode repeat = repeatModeForNativeMode(
        NativePlaybackMode.repeatOne,
      );
      final AudioServiceShuffleMode shuffle = shuffleModeForNativeMode(
        NativePlaybackMode.repeatOne,
      );
      expect(repeat, AudioServiceRepeatMode.one);
      expect(shuffle, AudioServiceShuffleMode.none);
      expect(
        nativePlaybackModeFromSessionModes(
          repeatMode: repeat,
          shuffleMode: shuffle,
        ),
        NativePlaybackMode.repeatOne,
      );
    });

    test('shuffle publishes none + all and maps back', () {
      final AudioServiceRepeatMode repeat = repeatModeForNativeMode(
        NativePlaybackMode.shuffle,
      );
      final AudioServiceShuffleMode shuffle = shuffleModeForNativeMode(
        NativePlaybackMode.shuffle,
      );
      expect(repeat, AudioServiceRepeatMode.none);
      expect(shuffle, AudioServiceShuffleMode.all);
      expect(
        nativePlaybackModeFromSessionModes(
          repeatMode: repeat,
          shuffleMode: shuffle,
        ),
        NativePlaybackMode.shuffle,
      );
    });

    test('sequential publishes none + none and maps back', () {
      final AudioServiceRepeatMode repeat = repeatModeForNativeMode(
        NativePlaybackMode.sequential,
      );
      final AudioServiceShuffleMode shuffle = shuffleModeForNativeMode(
        NativePlaybackMode.sequential,
      );
      expect(repeat, AudioServiceRepeatMode.none);
      expect(shuffle, AudioServiceShuffleMode.none);
      expect(
        nativePlaybackModeFromSessionModes(
          repeatMode: repeat,
          shuffleMode: shuffle,
        ),
        NativePlaybackMode.sequential,
      );
    });
  });
}
