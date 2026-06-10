import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'free_music_api.dart';

class FavoriteSongStore {
  FavoriteSongStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _preferenceKey = 'favorite_songs_v1';

  final SharedPreferences? _preferences;

  Future<List<FreeMusicSong>> load() async {
    final SharedPreferences preferences = await _getPreferences();
    final String? raw = preferences.getString(_preferenceKey);
    if (raw == null || raw.isEmpty) {
      return const <FreeMusicSong>[];
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Iterable) {
      return const <FreeMusicSong>[];
    }
    return decoded
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) => _songFromMap(item))
        .where((FreeMusicSong song) => song.canResolve)
        .toList(growable: false);
  }

  Future<void> save(List<FreeMusicSong> songs) async {
    final SharedPreferences preferences = await _getPreferences();
    final List<FreeMusicSong> uniqueSongs = _uniqueSongs(songs);
    final String raw = jsonEncode(
      uniqueSongs.map(_songToJson).toList(growable: false),
    );
    await preferences.setString(_preferenceKey, raw);
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ?? SharedPreferences.getInstance();
  }
}

String favoriteSongKey(FreeMusicSong song) {
  return '${song.source}:${song.id}';
}

List<FreeMusicSong> _uniqueSongs(List<FreeMusicSong> songs) {
  final Set<String> seen = <String>{};
  final List<FreeMusicSong> result = <FreeMusicSong>[];
  for (final FreeMusicSong song in songs) {
    final String key = favoriteSongKey(song);
    if (!song.canResolve || seen.contains(key)) {
      continue;
    }
    seen.add(key);
    result.add(song);
  }
  return result;
}

Map<String, Object?> _songToJson(FreeMusicSong song) {
  return <String, Object?>{
    'id': song.id,
    'source': song.source,
    'name': song.name,
    'artist': song.artist,
    'duration': song.duration,
    'album': song.album,
    'cover': song.cover,
  };
}

FreeMusicSong _songFromMap(Map<dynamic, dynamic> item) {
  return FreeMusicSong(
    id: _stringValue(item['id']),
    source: _stringValue(item['source']),
    name: _stringValue(item['name'] ?? item['title']),
    artist: _stringValue(item['artist']),
    duration: _intValue(item['duration']),
    album: _stringValue(item['album']),
    cover: _stringValue(item['cover'] ?? item['coverUrl']),
  );
}

String _stringValue(Object? value) {
  if (value == null) {
    return '';
  }
  return '$value'.trim();
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite) {
    return value.round();
  }
  if (value is String) {
    return double.tryParse(value)?.round() ?? 0;
  }
  return 0;
}
