import '../free_music_api.dart';

class PlaybackErrorTracker {
  PlaybackErrorTracker({this.maxConsecutiveFailures = 3});

  final int maxConsecutiveFailures;
  int _consecutiveFailures = 0;
  String? _lastFailedSongKey;

  void recordSuccess() {
    _consecutiveFailures = 0;
    _lastFailedSongKey = null;
  }

  bool recordFailure(FreeMusicSong song) {
    final String key = _songKey(song);
    if (_lastFailedSongKey == key) {
      _consecutiveFailures++;
    } else {
      _consecutiveFailures = 1;
      _lastFailedSongKey = key;
    }
    return shouldStop;
  }

  bool get shouldStop => _consecutiveFailures >= maxConsecutiveFailures;

  void reset() {
    _consecutiveFailures = 0;
    _lastFailedSongKey = null;
  }

  String _songKey(FreeMusicSong song) => '${song.source}:${song.id}';
}
