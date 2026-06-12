import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/controllers/library_controller.dart';
import 'package:music_car_app/favorite_song_store.dart';
import 'package:music_car_app/free_music_api.dart';

void main() {
  test('loads favorite songs and exposes immutable state', () async {
    final Completer<List<FreeMusicSong>> loadCompleter =
        Completer<List<FreeMusicSong>>();
    final _FakeFavoriteSongStore store = _FakeFavoriteSongStore(
      onLoad: () => loadCompleter.future,
    );
    final LibraryController controller = LibraryController(
      favoriteSongStore: store,
    );
    final FreeMusicSong song = _song('1');
    final List<bool> loadingStates = <bool>[];
    controller.addListener(() {
      loadingStates.add(controller.isLoadingFavorites);
    });

    final Future<void> loadFuture = controller.loadFavorites();
    expect(controller.isLoadingFavorites, isTrue);

    loadCompleter.complete(<FreeMusicSong>[song]);
    await loadFuture;

    expect(controller.isLoadingFavorites, isFalse);
    expect(controller.favoriteSongs, <FreeMusicSong>[song]);
    expect(controller.favoriteSongKeys, <String>{'kuwo:1'});
    expect(
      () => controller.favoriteSongs.add(_song('2')),
      throwsUnsupportedError,
    );
    expect(loadingStates, <bool>[true, false]);

    controller.dispose();
  });

  test('toggleFavorite adds and removes songs through the store', () async {
    final _FakeFavoriteSongStore store = _FakeFavoriteSongStore();
    final LibraryController controller = LibraryController(
      favoriteSongStore: store,
    );
    final FreeMusicSong song = _song('1');

    final FavoriteChangeResult addResult = await controller.toggleFavorite(
      song,
    );
    expect(addResult.removing, isFalse);
    expect(controller.favoriteSongs, <FreeMusicSong>[song]);
    expect(store.savedSongs.single, <FreeMusicSong>[song]);

    final FavoriteChangeResult removeResult = await controller.toggleFavorite(
      song,
    );
    expect(removeResult.removing, isTrue);
    expect(controller.favoriteSongs, isEmpty);
    expect(store.savedSongs.last, isEmpty);

    controller.dispose();
  });

  test(
    'toggleFavorite rolls back optimistic state when saving fails',
    () async {
      final FreeMusicSong existingSong = _song('1');
      final _FakeFavoriteSongStore store = _FakeFavoriteSongStore(
        initialSongs: <FreeMusicSong>[existingSong],
      );
      final LibraryController controller = LibraryController(
        favoriteSongStore: store,
      );
      await controller.loadFavorites();
      store.saveError = StateError('disk full');

      await expectLater(
        controller.toggleFavorite(_song('2')),
        throwsA(isA<StateError>()),
      );

      expect(controller.favoriteSongs, <FreeMusicSong>[existingSong]);

      controller.dispose();
    },
  );

  test('toggleFavorite rejects unresolvable songs before saving', () async {
    final _FakeFavoriteSongStore store = _FakeFavoriteSongStore();
    final LibraryController controller = LibraryController(
      favoriteSongStore: store,
    );

    await expectLater(
      controller.toggleFavorite(
        const FreeMusicSong(
          id: '',
          source: '',
          name: 'Broken',
          artist: '',
          duration: 0,
        ),
      ),
      throwsArgumentError,
    );

    expect(store.savedSongs, isEmpty);

    controller.dispose();
  });
}

class _FakeFavoriteSongStore implements FavoriteSongStore {
  _FakeFavoriteSongStore({
    this.initialSongs = const <FreeMusicSong>[],
    Future<List<FreeMusicSong>> Function()? onLoad,
  }) : _onLoad = onLoad;

  final List<FreeMusicSong> initialSongs;
  final Future<List<FreeMusicSong>> Function()? _onLoad;
  final List<List<FreeMusicSong>> savedSongs = <List<FreeMusicSong>>[];
  Object? saveError;

  @override
  Future<List<FreeMusicSong>> load() {
    final Future<List<FreeMusicSong>> Function()? onLoad = _onLoad;
    if (onLoad != null) {
      return onLoad();
    }
    return Future<List<FreeMusicSong>>.value(initialSongs);
  }

  @override
  Future<void> save(List<FreeMusicSong> songs) async {
    final Object? error = saveError;
    if (error != null) {
      throw error;
    }
    savedSongs.add(List<FreeMusicSong>.unmodifiable(songs));
  }
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
