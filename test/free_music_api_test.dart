import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_car_app/free_music_api.dart';

void main() {
  test('FreeMusicApi resolves song_url with expected query parameters', () async {
    late Uri requestedUri;
    late Map<String, String> requestedHeaders;
    final FreeMusicApi api = FreeMusicApi(
      baseUri: 'https://music.sy110.eu.org/api/v1/freemusic',
      client: MockClient((http.Request request) async {
        requestedUri = request.url;
        requestedHeaders = request.headers;
        return http.Response(
          '{"direct":true,"source":"kuwo","url":"https://example.com/song.mp3"}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final FreeMusicResolvedUrl? resolved = await api.resolveSongUrl(
      const FreeMusicSong(
        id: '228908',
        source: 'kuwo',
        name: '晴天',
        artist: '周杰伦',
        duration: 269,
      ),
    );

    expect(requestedUri.path, '/api/v1/freemusic/song_url');
    expect(requestedUri.queryParameters['id'], '228908');
    expect(requestedUri.queryParameters['source'], 'kuwo');
    expect(requestedUri.queryParameters['name'], '晴天');
    expect(requestedUri.queryParameters['artist'], '周杰伦');
    expect(requestedUri.queryParameters['duration'], '269');
    expect(requestedUri.queryParameters['br'], '320kmp3');
    expect(requestedHeaders['Referer'], 'https://music.sy110.eu.org/music');
    expect(resolved?.url, 'https://example.com/song.mp3');
    expect(resolved?.source, 'kuwo');
    expect(resolved?.direct, isTrue);
  });

  test('FreeMusicApi returns null when song cannot be resolved', () async {
    final FreeMusicApi api = FreeMusicApi(
      client: MockClient((http.Request request) async {
        fail('Request should not be sent for incomplete songs');
      }),
    );

    final FreeMusicResolvedUrl? resolved = await api.resolveSongUrl(
      const FreeMusicSong(
        id: '',
        source: '',
        name: '',
        artist: '',
        duration: 0,
      ),
    );

    expect(resolved, isNull);
  });
}
