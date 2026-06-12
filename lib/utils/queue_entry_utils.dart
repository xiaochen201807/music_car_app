import '../free_music_api.dart';

class QueueEntryIdManager {
  int _counter = 0;

  String nextId() {
    return 'queue-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
  }

  FreeMusicSong ensureId(FreeMusicSong song) {
    if (song.queueEntryId != null && song.queueEntryId!.isNotEmpty) {
      return song;
    }
    return song.withQueueEntryId(nextId());
  }

  List<FreeMusicSong> ensureIds(List<FreeMusicSong> songs) {
    return songs.map(ensureId).toList();
  }
}
