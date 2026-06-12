import 'package:shared_preferences/shared_preferences.dart';

import '../free_music_api.dart';

class LyricOffsetStore {
  static const String _keyPrefix = 'lyric_offset_';

  static String _songKey(FreeMusicSong song) => '${song.source}:${song.id}';

  Future<Duration> getOffset(FreeMusicSong song) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyPrefix + _songKey(song);
    final ms = prefs.getInt(key) ?? 0;
    return Duration(milliseconds: ms);
  }

  Future<void> setOffset(FreeMusicSong song, Duration offset) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyPrefix + _songKey(song);
    await prefs.setInt(key, offset.inMilliseconds);
  }

  Future<void> clearOffset(FreeMusicSong song) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyPrefix + _songKey(song);
    await prefs.remove(key);
  }
}
