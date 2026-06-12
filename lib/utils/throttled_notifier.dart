import 'dart:async';

import '../free_music_api.dart';
import '../native_audio_controller.dart';

class ThrottledNotifier {
  Timer? _notifyTimer;
  final void Function() _notify;
  final Duration throttleDuration;

  ThrottledNotifier(
    this._notify, {
    this.throttleDuration = const Duration(milliseconds: 120),
  });

  void notify() {
    _notifyTimer?.cancel();
    _notifyTimer = Timer(throttleDuration, _notify);
  }

  void dispose() {
    _notifyTimer?.cancel();
  }
}
