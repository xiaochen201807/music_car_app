import 'package:flutter_test/flutter_test.dart';
import 'package:music_car_app/favorite_song_store.dart';
import 'package:music_car_app/free_music_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'FavoriteSongStore saves and restores unique resolvable songs',
    () async {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final FavoriteSongStore store = FavoriteSongStore(
        preferences: preferences,
      );
      const FreeMusicSong song = FreeMusicSong(
        id: '42',
        source: 'netease',
        name: '晴天',
        artist: '周杰伦',
        duration: 269,
        album: '叶惠美',
        cover: 'https://example.com/cover.jpg',
      );

      await store.save(<FreeMusicSong>[
        song,
        song,
        const FreeMusicSong(
          id: '',
          source: '',
          name: '不可播放',
          artist: '',
          duration: 0,
        ),
      ]);

      final List<FreeMusicSong> restored = await store.load();
      expect(restored, hasLength(1));
      expect(restored.single.id, song.id);
      expect(restored.single.source, song.source);
      expect(restored.single.name, song.name);
      expect(restored.single.artist, song.artist);
      expect(restored.single.album, song.album);
      expect(restored.single.cover, song.cover);
    },
  );

  test('favoriteSongKey combines source and id', () {
    expect(
      favoriteSongKey(
        const FreeMusicSong(
          id: '100',
          source: 'kuwo',
          name: '七里香',
          artist: '周杰伦',
          duration: 290,
        ),
      ),
      'kuwo:100',
    );
  });
}
