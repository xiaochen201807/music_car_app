import '../free_music_api.dart';

/// Tracks consecutive unplayable items so we auto-skip bad tracks but eventually
/// stop instead of spinning forever.
///
/// Every failed play attempt increments the streak (across different songs).
/// A successful play resets the counter. When [maxConsecutiveFailures] is
/// reached, callers should stop auto-skipping and force a paused media-session.
class PlaybackErrorTracker {
  PlaybackErrorTracker({this.maxConsecutiveFailures = 5});

  final int maxConsecutiveFailures;
  int _consecutiveFailures = 0;
  String? _lastFailedSongKey;

  int get consecutiveFailures => _consecutiveFailures;

  String? get lastFailedSongKey => _lastFailedSongKey;

  void recordSuccess() {
    _consecutiveFailures = 0;
    _lastFailedSongKey = null;
  }

  /// Returns `true` when the consecutive-failure budget is exhausted.
  bool recordFailure(FreeMusicSong song) {
    _consecutiveFailures += 1;
    _lastFailedSongKey = _songKey(song);
    return shouldStop;
  }

  bool get shouldStop => _consecutiveFailures >= maxConsecutiveFailures;

  void reset() {
    _consecutiveFailures = 0;
    _lastFailedSongKey = null;
  }

  String _songKey(FreeMusicSong song) => '${song.source}:${song.id}';
}
