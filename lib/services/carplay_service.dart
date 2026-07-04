import 'package:flutter/foundation.dart';
import '../music_audio_handler.dart';
import '../native_audio_controller.dart';

class CarPlayService {
  CarPlayService(this._audioHandler, this._nativeAudioController);

  final MusicAudioHandler _audioHandler;
  final NativeAudioController _nativeAudioController;

  Future<void> init() async {
    final String title =
        _audioHandler.mediaItem.valueOrNull?.title ?? 'no active item';
    debugPrint(
      '[carplay] Disabled Flutter CarPlay plugin; '
      'title=$title, queue=${_nativeAudioController.playlist.length}',
    );
  }

  void dispose() {
    debugPrint('[carplay] Disposed');
  }
}
