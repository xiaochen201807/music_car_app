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
    expect(tracker.consecutiveFailures, 0);
  });

  test('recordFailure counts consecutive failures across different songs', () {
    final tracker = PlaybackErrorTracker(maxConsecutiveFailures: 3);

    expect(tracker.recordFailure(_song('1')), isFalse);
    expect(tracker.consecutiveFailures, 1);

    expect(tracker.recordFailure(_song('2')), isFalse);
    expect(tracker.consecutiveFailures, 2);

    // Third consecutive failure exhausts the budget.
    expect(tracker.recordFailure(_song('3')), isTrue);
    expect(tracker.shouldStop, isTrue);
  });

  test('recordFailure also accumulates for the same song', () {
    final tracker = PlaybackErrorTracker(maxConsecutiveFailures: 2);
    final song = _song('1');

    expect(tracker.recordFailure(song), isFalse);
    expect(tracker.recordFailure(song), isTrue);
  });

  test('reset clears all failure state', () {
    final tracker = PlaybackErrorTracker(maxConsecutiveFailures: 2);
    final song = _song('1');

    tracker.recordFailure(song);
    tracker.recordFailure(song);
    tracker.reset();

    expect(tracker.shouldStop, isFalse);
    expect(tracker.consecutiveFailures, 0);
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
