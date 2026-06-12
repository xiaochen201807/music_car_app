import 'package:flutter/foundation.dart';

import '../favorite_song_store.dart';
import '../free_music_api.dart';

class FavoriteChangeResult {
  const FavoriteChangeResult({
    required this.song,
    required this.removing,
    required this.songs,
  });

  final FreeMusicSong song;
  final bool removing;
  final List<FreeMusicSong> songs;
}

class LibraryController extends ChangeNotifier {
  LibraryController({FavoriteSongStore? favoriteSongStore})
    : _favoriteSongStore = favoriteSongStore ?? FavoriteSongStore();

  final FavoriteSongStore _favoriteSongStore;

  List<FreeMusicSong> _favoriteSongs = const <FreeMusicSong>[];
  bool _isLoadingFavorites = false;

  List<FreeMusicSong> get favoriteSongs => _favoriteSongs;

  bool get isLoadingFavorites => _isLoadingFavorites;

  Set<String> get favoriteSongKeys {
    return _favoriteSongs.map(favoriteSongKey).toSet();
  }

  bool isFavorite(FreeMusicSong song) {
    return favoriteSongKeys.contains(favoriteSongKey(song));
  }

  Future<void> loadFavorites() async {
    _setLoadingFavorites(true);
    try {
      final List<FreeMusicSong> songs = await _favoriteSongStore.load();
      _favoriteSongs = List<FreeMusicSong>.unmodifiable(songs);
      _setLoadingFavorites(false, notify: false);
      notifyListeners();
    } catch (_) {
      _setLoadingFavorites(false);
      rethrow;
    }
  }

  Future<FavoriteChangeResult> toggleFavorite(FreeMusicSong song) async {
    if (!song.canResolve) {
      throw ArgumentError.value(song, 'song', 'Song cannot be resolved');
    }

    final List<FreeMusicSong> oldSongs = _favoriteSongs;
    final String key = favoriteSongKey(song);
    final bool removing = favoriteSongKeys.contains(key);
    final List<FreeMusicSong> nextSongs = removing
        ? _favoriteSongs
              .where((FreeMusicSong item) => favoriteSongKey(item) != key)
              .toList(growable: false)
        : <FreeMusicSong>[song, ..._favoriteSongs];

    _favoriteSongs = List<FreeMusicSong>.unmodifiable(nextSongs);
    notifyListeners();

    try {
      await _favoriteSongStore.save(nextSongs);
    } catch (_) {
      _favoriteSongs = oldSongs;
      notifyListeners();
      rethrow;
    }

    return FavoriteChangeResult(
      song: song,
      removing: removing,
      songs: _favoriteSongs,
    );
  }

  void _setLoadingFavorites(bool loading, {bool notify = true}) {
    if (_isLoadingFavorites == loading) {
      return;
    }
    _isLoadingFavorites = loading;
    if (notify) {
      notifyListeners();
    }
  }
}
