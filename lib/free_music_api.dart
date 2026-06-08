import 'dart:convert';

import 'package:http/http.dart' as http;

class FreeMusicSong {
  const FreeMusicSong({
    required this.id,
    required this.source,
    required this.name,
    required this.artist,
    required this.duration,
  });

  final String id;
  final String source;
  final String name;
  final String artist;
  final int duration;

  bool get canResolve => id.isNotEmpty && source.isNotEmpty;
}

class FreeMusicResolvedUrl {
  const FreeMusicResolvedUrl({
    required this.url,
    required this.source,
    required this.direct,
  });

  final String url;
  final String source;
  final bool direct;
}

class FreeMusicApi {
  FreeMusicApi({
    http.Client? client,
    this.baseUri = const String.fromEnvironment(
      'FREE_MUSIC_API_BASE',
      defaultValue: 'https://music.sy110.eu.org/api/v1/freemusic',
    ),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUri;

  Future<FreeMusicResolvedUrl?> resolveSongUrl(
    FreeMusicSong song, {
    String bitrate = '320kmp3',
  }) async {
    if (!song.canResolve) {
      return null;
    }
    final Uri uri = Uri.parse('$baseUri/song_url').replace(
      queryParameters: <String, String>{
        'id': song.id,
        'source': song.source,
        'name': song.name,
        'artist': song.artist,
        if (song.duration > 0) 'duration': '${song.duration}',
        'br': bitrate,
      },
    );
    final http.Response response = await _client.get(
      uri,
      headers: const <String, String>{
        'Accept': 'application/json',
        'Referer': 'https://music.sy110.eu.org/music',
        'User-Agent': 'Mozilla/5.0 MusicCarApp',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FreeMusicApiException(
        'song_url failed with HTTP ${response.statusCode}',
      );
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException('song_url returned non-object JSON');
    }
    final String url = '${decoded['url'] ?? ''}'.trim();
    if (url.isEmpty) {
      return null;
    }
    return FreeMusicResolvedUrl(
      url: url,
      source: '${decoded['source'] ?? song.source}'.trim(),
      direct: decoded['direct'] == true,
    );
  }

  void close() {
    _client.close();
  }
}

class FreeMusicApiException implements Exception {
  const FreeMusicApiException(this.message);

  final String message;

  @override
  String toString() => 'FreeMusicApiException: $message';
}
