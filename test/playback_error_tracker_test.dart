import 'package:flutter_test/flutter_test.dart';

import 'package:music_car_app/services/playback_error_tracker.dart';
import 'package:music_car_app/free_music_api.dart';

void main() {
  test('recordSuccess resets consecutive failures', () {
    final tracker = PlaybackErrorTracker(maxConsecutiveFailures: 3);
    final song = _song('1');

    tracker.recordFailure(song);
    tracker.recordFailure(song);
    tracker.recordSuccess();

    expect(tracker.shouldStop, isFalse);
  });

  test('recordFailure tracks consecutive failures for same song', () {
    final tracker = PlaybackErrorTracker(maxConsecutiveFailures: 3);
    final song = _song('1');

    expect(tracker.recordFailure(song), isFalse);
    expect(tracker.shouldStop, isFalse);

    expect(tracker.recordFailure(song), isFalse);
    expect(tracker.shouldStop, isFalse);

    expect(tracker.recordFailure(song), isTrue);
    expect(tracker.shouldStop, isTrue);
  });

  test('recordFailure resets count for different songs', () {
    final tracker = PlaybackErrorTracker(maxConsecutiveFailures: 3);
    final song1 = _song('1');
    final song2 = _song('2');

    tracker.recordFailure(song1);
    tracker.recordFailure(song1);
    tracker.recordFailure(song2);

    expect(tracker.shouldStop, isFalse);
  });

  test('reset clears all failure state', () {
    final tracker = PlaybackErrorTracker(maxConsecutiveFailures: 2);
    final song = _song('1');

    tracker.recordFailure(song);
    tracker.recordFailure(song);
    tracker.reset();

    expect(tracker.shouldStop, isFalse);
  });
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
