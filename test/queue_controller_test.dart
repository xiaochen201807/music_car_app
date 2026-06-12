import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/controllers/queue_controller.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:music_car_app/native_audio_controller.dart';

void main() {
  test('replace selects current song and exposes an immutable queue', () {
    final QueueController controller = QueueController();
    final List<FreeMusicSong> songs = <FreeMusicSong>[_song('1'), _song('2')];

    expect(controller.replace(songs, 1), isTrue);

    expect(controller.queue.length, 2);
    expect(controller.queue[0].id, songs[0].id);
    expect(controller.queue[1].id, songs[1].id);
    expect(controller.selectedIndex, 1);
    expect(controller.currentSong?.id, songs[1].id);
    expect(() => controller.queue.add(_song('3')), throwsUnsupportedError);

    controller.dispose();
  });

  test('append keeps current selection unless queue was empty', () {
    final QueueController controller = QueueController();
    final FreeMusicSong first = _song('1');
    final FreeMusicSong second = _song('2');

    expect(controller.appendToEnd(first), isTrue);
    expect(controller.currentSong?.id, first.id);
    expect(controller.selectedIndex, 0);

    expect(controller.appendToEnd(second), isFalse);
    expect(controller.currentSong?.id, first.id);
    expect(controller.selectedIndex, 0);
    expect(controller.queue.length, 2);

    controller.dispose();
  });

  test(
    'reorder updates selected index without changing current song identity',
    () {
      final QueueController controller = QueueController();
      final FreeMusicSong first = _song('1');
      final FreeMusicSong second = _song('2');
      final FreeMusicSong third = _song('3');
      controller.replace(<FreeMusicSong>[first, second, third], 1);

      final QueueReorderResult? preview = controller.previewReorder(0, 3);
      expect(preview, isNotNull);
      expect(preview!.queue.length, 3);
      expect(preview.queue[0].id, second.id);
      expect(preview.nextIndex, 0);
      expect(preview.currentSong?.id, second.id);

      expect(controller.reorder(0, 3), isTrue);
      expect(controller.queue.length, 3);
      expect(controller.selectedIndex, 0);
      expect(controller.currentSong?.id, second.id);

      controller.dispose();
    },
  );

  test('removeAt keeps a valid current index and reports removed song', () {
    final QueueController controller = QueueController();
    final FreeMusicSong first = _song('1');
    final FreeMusicSong second = _song('2');
    final FreeMusicSong third = _song('3');
    controller.replace(<FreeMusicSong>[first, second, third], 2);

    final QueueRemovalResult? result = controller.removeAt(1);

    expect(result, isNotNull);
    expect(result!.removedSong.id, second.id);
    expect(result.removedSong.source, second.source);
    expect(result.queue.length, 2);
    expect(result.nextIndex, 1);
    expect(result.nextCurrentSong.id, third.id);
    expect(result.nextCurrentSong.source, third.source);
    expect(controller.queue.length, 2);
    expect(controller.selectedIndex, 1);
    expect(controller.currentSong?.id, third.id);

    controller.dispose();
  });

  test(
    'playback mode belongs to queue state and avoids duplicate notifications',
    () async {
      final QueueController controller = QueueController();
      int notifyCount = 0;
      controller.addListener(() {
        notifyCount += 1;
      });

      controller.setPlaybackMode(NativePlaybackMode.shuffle);
      controller.setPlaybackMode(NativePlaybackMode.shuffle);

      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(controller.playbackMode, NativePlaybackMode.shuffle);
      expect(notifyCount, 1);

      controller.dispose();
    },
  );
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
