import 'dart:convert';

import 'package:http/http.dart' as http;

class FreeMusicSong {
  const FreeMusicSong({
    required this.id,
    required this.source,
    required this.name,
    required this.artist,
    required this.duration,
    this.album = '',
    this.cover = '',
  });

  final String id;
  final String source;
  final String name;
  final String artist;
  final int duration;
  final String album;
  final String cover;

  bool get canResolve => id.isNotEmpty && source.isNotEmpty;
}

class FreeMusicSearchResult {
  const FreeMusicSearchResult({
    required this.songs,
    required this.hasMore,
    required this.page,
  });

  final List<FreeMusicSong> songs;
  final bool hasMore;
  final int page;
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

  Future<FreeMusicSearchResult> searchSongs(
    String query, {
    int page = 0,
    List<String>? sources,
  }) async {
    final String keyword = query.trim();
    if (keyword.isEmpty) {
      return const FreeMusicSearchResult(
        songs: <FreeMusicSong>[],
        hasMore: false,
        page: 0,
      );
    }

    final Uri uri = Uri.parse('$baseUri/search').replace(
      queryParameters: <String, String>{
        'q': keyword,
        'type': 'song',
        'page': '$page',
        if (sources != null && sources.isNotEmpty)
          'sources': sources.map((String source) => source.trim()).join(','),
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
        'search failed with HTTP ${response.statusCode}',
      );
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException('search returned non-object JSON');
    }
    return FreeMusicSearchResult(
      songs: _songsFromJson(decoded['songs']),
      hasMore: decoded['hasMore'] == true,
      page: _intValue(decoded['page']),
    );
  }

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

List<FreeMusicSong> _songsFromJson(Object? value) {
  if (value is! Iterable) {
    return const <FreeMusicSong>[];
  }
  return value
      .whereType<Map>()
      .map((Map<Object?, Object?> item) {
        return FreeMusicSong(
          id: _stringValue(item['id'] ?? item['songmid'] ?? item['mid']),
          source: _stringValue(item['source']),
          name: _stringValue(item['name'] ?? item['title']),
          artist: _stringValue(item['artist'] ?? item['singer']),
          duration: _intValue(item['duration'] ?? item['interval']),
          album: _stringValue(item['album'] ?? item['albumName']),
          cover: _stringValue(
            item['cover'] ?? item['picUrl'] ?? item['img'] ?? item['artwork'],
          ),
        );
      })
      .where((FreeMusicSong song) => song.canResolve)
      .toList(growable: false);
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

class FreeMusicApiException implements Exception {
  const FreeMusicApiException(this.message);

  final String message;

  @override
  String toString() => 'FreeMusicApiException: $message';
}
