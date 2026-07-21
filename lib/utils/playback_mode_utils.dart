import 'package:audio_service/audio_service.dart';

import '../native_audio_controller.dart';

/// Map independent media-session repeat + shuffle axes onto the app's single
/// [NativePlaybackMode]. Shuffle wins when enabled; otherwise repeat decides.
///
/// Critical: `shuffle == none` must NOT force sequential when repeat is still
/// all/one — that was the list-loop → sequential overwrite bug.
NativePlaybackMode nativePlaybackModeFromSessionModes({
  required AudioServiceRepeatMode repeatMode,
  required AudioServiceShuffleMode shuffleMode,
}) {
  if (shuffleMode != AudioServiceShuffleMode.none) {
    return NativePlaybackMode.shuffle;
  }
  switch (repeatMode) {
    case AudioServiceRepeatMode.one:
      return NativePlaybackMode.repeatOne;
    case AudioServiceRepeatMode.all:
    case AudioServiceRepeatMode.group:
      return NativePlaybackMode.repeatAll;
    case AudioServiceRepeatMode.none:
      return NativePlaybackMode.sequential;
  }
}

AudioServiceRepeatMode repeatModeForNativeMode(NativePlaybackMode mode) {
  switch (mode) {
    case NativePlaybackMode.repeatOne:
      return AudioServiceRepeatMode.one;
    case NativePlaybackMode.repeatAll:
      return AudioServiceRepeatMode.all;
    case NativePlaybackMode.sequential:
    case NativePlaybackMode.shuffle:
      return AudioServiceRepeatMode.none;
  }
}

AudioServiceShuffleMode shuffleModeForNativeMode(NativePlaybackMode mode) {
  return mode == NativePlaybackMode.shuffle
      ? AudioServiceShuffleMode.all
      : AudioServiceShuffleMode.none;
}
