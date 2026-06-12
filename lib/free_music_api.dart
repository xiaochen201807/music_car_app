import 'dart:async';
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
    this.queueEntryId,
  });

  final String id;
  final String source;
  final String name;
  final String artist;
  final int duration;
  final String album;
  final String cover;
  final String? queueEntryId;

  bool get canResolve => id.isNotEmpty && source.isNotEmpty;

  FreeMusicSong withQueueEntryId(String entryId) {
    return FreeMusicSong(
      id: id,
      source: source,
      name: name,
      artist: artist,
      duration: duration,
      album: album,
      cover: cover,
      queueEntryId: entryId,
    );
  }
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

class FreeMusicSources {
  const FreeMusicSources({
    required this.allSources,
    required this.defaultSources,
    required this.descriptions,
  });

  final List<String> allSources;
  final List<String> defaultSources;
  final Map<String, String> descriptions;

  List<String> get activeSources =>
      defaultSources.isNotEmpty ? defaultSources : allSources;

  String labelFor(String source) => descriptions[source] ?? source;
}

class FreeMusicPlaylist {
  const FreeMusicPlaylist({
    required this.id,
    required this.source,
    required this.name,
    this.cover = '',
    this.creator = '',
    this.description = '',
    this.link = '',
    this.trackCount = 0,
    this.playCount = 0,
  });

  final String id;
  final String source;
  final String name;
  final String cover;
  final String creator;
  final String description;
  final String link;
  final int trackCount;
  final int playCount;

  bool get canLoad => id.isNotEmpty && source.isNotEmpty;
}

class FreeMusicRecommendResult {
  const FreeMusicRecommendResult({required this.playlists});

  final List<FreeMusicPlaylist> playlists;
}

class FreeMusicPlaylistPage {
  const FreeMusicPlaylistPage({required this.songs, required this.total});

  final List<FreeMusicSong> songs;
  final int total;
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

/// Result of `/switch_source`: a matched song found on an alternate source.
///
/// The endpoint does not return a playable URL directly — it returns the
/// best-matching song (new `id` + `source`) on another platform, with a
/// [score] confidence in `[0, 1]`. Callers must run the returned [song] back
/// through [FreeMusicApi.resolveSongUrl] to obtain a real audio URL. A low
/// [score] means the match is likely a different recording, so callers should
/// reject results below a confidence threshold.
class FreeMusicSourceSwitch {
  const FreeMusicSourceSwitch({required this.song, required this.score});

  final FreeMusicSong song;
  final double score;
}

class FreeMusicQuality {
  const FreeMusicQuality({
    required this.bitrate,
    required this.name,
    this.format = '',
    this.size = '',
  });

  final String bitrate;
  final String name;
  final String format;
  final String size;
}

class FreeMusicQualityResult {
  const FreeMusicQualityResult({
    required this.matchedName,
    required this.matchedArtist,
    required this.qualities,
  });

  final String matchedName;
  final String matchedArtist;
  final List<FreeMusicQuality> qualities;
}

class FreeMusicLyricLine {
  const FreeMusicLyricLine({required this.time, required this.text});

  final Duration time;
  final String text;
}

class FreeMusicLyrics {
  const FreeMusicLyrics({required this.raw, required this.lines});

  final String raw;
  final List<FreeMusicLyricLine> lines;

  bool get isEmpty => raw.trim().isEmpty && lines.isEmpty;
}

class FreeMusicApi {
  FreeMusicApi({
    http.Client? client,
    this.baseUri = const String.fromEnvironment(
      'FREE_MUSIC_API_BASE',
      defaultValue: 'http://111.119.212.124:18300/music',
    ),
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUri;

  /// Network timeout applied to every request. Playback-path endpoints
  /// (`/song_url`, `/switch_source`, playlist detail, lyrics) are slow and can
  /// hang; without this a stalled request would leave the player — and any
  /// CarLife projection reading the same queue — spinning forever.
  final Duration timeout;

  /// Single choke point for every GET so the [timeout] is impossible to forget
  /// on a new endpoint. Throws [TimeoutException] on expiry, which callers map
  /// to a recoverable error rather than an infinite spinner.
  Future<http.Response> _httpGet(
    Uri uri, {
    Map<String, String> headers = _headers,
  }) {
    return _client.get(uri, headers: headers).timeout(timeout);
  }

  Future<FreeMusicSources> fetchSources() async {
    final Object? decoded = await _getJson('sources');
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException('sources returned non-object JSON');
    }
    final Map<String, String> descriptions = <String, String>{};
    final Object? rawDescriptions = decoded['descriptions'];
    if (rawDescriptions is Map) {
      for (final MapEntry<Object?, Object?> entry in rawDescriptions.entries) {
        final String key = _stringValue(entry.key);
        if (key.isNotEmpty) {
          descriptions[key] = _stringValue(entry.value);
        }
      }
    }
    return FreeMusicSources(
      allSources: _stringList(decoded['all_sources'] ?? decoded['allSources']),
      defaultSources: _stringList(
        decoded['default_sources'] ?? decoded['defaultSources'],
      ),
      descriptions: Map<String, String>.unmodifiable(descriptions),
    );
  }

  Future<List<String>> fetchHotSearchKeywords() async {
    final Object? decoded = await _getJson('search/hot');
    return _extractKeywordList(decoded);
  }

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
      queryParameters: <String, Object>{
        'q': keyword,
        'type': 'song',
        'page': '$page',
        if (sources != null && sources.isNotEmpty)
          'sources': sources
              .map((String source) => source.trim())
              .where((String source) => source.isNotEmpty)
              .toList(growable: false),
      },
    );
    final http.Response response = await _httpGet(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FreeMusicApiException(
        'search failed with HTTP ${response.statusCode}',
      );
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException('search returned non-object JSON');
    }
    // 新 API 返回格式：{ "code": 200, "msg": "success", "data": {...} }
    final Map<String, dynamic> data = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : decoded;
    return FreeMusicSearchResult(
      songs: _songsFromJson(data['songs']),
      hasMore: data['hasMore'] == true,
      page: _intValue(data['page']),
    );
  }

  Future<FreeMusicRecommendResult> fetchRecommendations({
    List<String>? sources,
  }) async {
    final Uri uri = Uri.parse('$baseUri/recommend').replace(
      queryParameters: <String, Object>{
        if (sources != null && sources.isNotEmpty)
          'sources': sources
              .map((String source) => source.trim())
              .where((String source) => source.isNotEmpty)
              .toList(growable: false),
      },
    );
    final http.Response response = await _httpGet(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FreeMusicApiException(
        'recommend failed with HTTP ${response.statusCode}',
      );
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException('recommend returned non-object JSON');
    }
    // 新 API 返回格式：{ "code": 200, "msg": "success", "data": [...] }
    final Object? data = decoded['data'];
    final List<dynamic> playlistsData = data is List ? data : (decoded['playlists'] ?? <dynamic>[]);
    return FreeMusicRecommendResult(
      playlists: _playlistsFromJson(playlistsData),
    );
  }

  Future<FreeMusicPlaylistPage> fetchPlaylistSongs(
    FreeMusicPlaylist playlist, {
    int offset = 0,
    int size = 30,
  }) async {
    if (!playlist.canLoad) {
      return const FreeMusicPlaylistPage(songs: <FreeMusicSong>[], total: 0);
    }
    final Uri uri = Uri.parse('$baseUri/playlist/page').replace(
      queryParameters: <String, String>{
        'id': playlist.id,
        'source': playlist.source,
        'offset': '$offset',
        'size': '$size',
      },
    );
    final http.Response response = await _httpGet(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FreeMusicApiException(
        'playlist/page failed with HTTP ${response.statusCode}',
      );
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException(
        'playlist/page returned non-object JSON',
      );
    }
    // 新 API 返回格式：{ "code": 200, "msg": "success", "data": {...} }
    final Map<String, dynamic> data = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : decoded;
    return FreeMusicPlaylistPage(
      songs: _songsFromJson(data['songs']),
      total: _intValue(data['total']),
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
    final http.Response response = await _httpGet(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FreeMusicApiException(
        'song_url failed with HTTP ${response.statusCode}',
      );
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException('song_url returned non-object JSON');
    }
    // 新 API 返回格式：{ "code": 200, "msg": "success", "data": {...} }
    final Map<String, dynamic> data = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : decoded;
    final String url = '${data['url'] ?? decoded['url'] ?? ''}'.trim();
    if (url.isEmpty) {
      return null;
    }
    return FreeMusicResolvedUrl(
      url: url,
      source: '${decoded['source'] ?? song.source}'.trim(),
      direct: decoded['direct'] == true,
    );
  }

  /// Finds the same track on a different source when the current source cannot
  /// play. Unlike [resolveSongUrl] this does NOT return a playable URL — it
  /// returns the matched song on [target] (new `id` + `source` + a match
  /// `score`). The caller must then call [resolveSongUrl] again with the
  /// returned song to obtain the actual stream URL.
  ///
  /// Returns null when the server has no match (HTTP 404) or the match is below
  /// [minScore]. A low score means the alternate source likely matched a
  /// different recording, so playing it would be worse than surfacing an error.
  Future<FreeMusicSourceSwitch?> switchSource(
    FreeMusicSong song, {
    required String target,
    double minScore = 0.5,
  }) async {
    if (!song.canResolve || target.trim().isEmpty || target == song.source) {
      return null;
    }
    final Uri uri = Uri.parse('$baseUri/switch_source').replace(
      queryParameters: <String, String>{
        'name': song.name,
        'artist': song.artist,
        'source': song.source,
        'target': target.trim(),
        if (song.duration > 0) 'duration': '${song.duration}',
      },
    );
    final http.Response response = await _httpGet(uri);
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FreeMusicApiException(
        'switch_source failed with HTTP ${response.statusCode}',
      );
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException(
        'switch_source returned non-object JSON',
      );
    }
    final FreeMusicSong matched = _songFromMap(decoded);
    if (!matched.canResolve) {
      return null;
    }
    final double score = _doubleValue(decoded['score']);
    if (score < minScore) {
      return null;
    }
    return FreeMusicSourceSwitch(song: matched, score: score);
  }

  Future<FreeMusicQualityResult> fetchQualities(FreeMusicSong song) async {
    if (!song.canResolve) {
      return const FreeMusicQualityResult(
        matchedName: '',
        matchedArtist: '',
        qualities: <FreeMusicQuality>[],
      );
    }
    final Uri uri = Uri.parse('$baseUri/qualities').replace(
      queryParameters: <String, String>{
        'name': song.name,
        'artist': song.artist,
        if (song.duration > 0) 'duration': '${song.duration}',
      },
    );
    final Object? decoded = await _getJsonUri(uri, errorPrefix: 'qualities');
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException('qualities returned non-object JSON');
    }
    return FreeMusicQualityResult(
      matchedName: _stringValue(decoded['matchedName']),
      matchedArtist: _stringValue(decoded['matchedArtist']),
      qualities: _qualitiesFromJson(decoded['qualities']),
    );
  }

  Future<FreeMusicLyrics> fetchEnhancedLyrics(FreeMusicSong song) async {
    if (!song.canResolve) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }
    final Uri uri = Uri.parse('$baseUri/yrc').replace(
      queryParameters: <String, String>{'id': song.id, 'source': song.source},
    );
    final http.Response response = await _httpGet(uri);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final String body = response.body.trim();
      String raw = body;
      try {
        final Object? decoded = jsonDecode(body);
        if (decoded is Map) {
          raw = _stringValue(
            decoded['lrc'] ??
                decoded['lyric'] ??
                decoded['yrc'] ??
                decoded['data'] ??
                '',
          );
        }
      } on FormatException {
        raw = body;
      }
      if (raw.trim().isNotEmpty) {
        return FreeMusicLyrics(raw: raw, lines: _parseLyricLines(raw));
      }
    }
    return fetchLyrics(song);
  }

  Future<FreeMusicLyrics> fetchLyrics(FreeMusicSong song) async {
    if (!song.canResolve) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }
    final Uri uri = Uri.parse('$baseUri/lyric').replace(
      queryParameters: <String, String>{
        'id': song.id,
        'source': song.source,
        'name': song.name,
        'artist': song.artist,
      },
    );
    final http.Response response = await _httpGet(
      uri,
      headers: const <String, String>{
        'Accept': 'text/plain, application/json',
        'Referer': 'https://music.sy110.eu.org/music',
        'User-Agent': 'Mozilla/5.0 MusicCarApp',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FreeMusicApiException(
        'lyric failed with HTTP ${response.statusCode}',
      );
    }
    final String raw = response.body.trim();
    return FreeMusicLyrics(raw: raw, lines: _parseLyricLines(raw));
  }

  void close() {
    _client.close();
  }

  Future<Object?> _getJson(String path) async {
    final Uri uri = Uri.parse('$baseUri/$path');
    return _getJsonUri(uri, errorPrefix: path);
  }

  Future<Object?> _getJsonUri(Uri uri, {required String errorPrefix}) async {
    final http.Response response = await _httpGet(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FreeMusicApiException(
        '$errorPrefix failed with HTTP ${response.statusCode}',
      );
    }
    return jsonDecode(response.body);
  }
}

const Map<String, String> _headers = <String, String>{
  'Accept': 'application/json',
  'Referer': 'https://music.sy110.eu.org/music',
  'User-Agent': 'Mozilla/5.0 MusicCarApp',
};

List<String> _stringList(Object? value) {
  if (value is Iterable) {
    return value
        .map(_stringValue)
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

List<String> _extractKeywordList(Object? value) {
  if (value is Iterable) {
    return value
        .map((Object? item) {
          if (item is Map) {
            return _stringValue(
              item['keyword'] ??
                  item['name'] ??
                  item['searchWord'] ??
                  item['q'],
            );
          }
          return _stringValue(item);
        })
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is Map) {
    for (final String key in <String>[
      'keywords',
      'hots',
      'hot',
      'data',
      'result',
      'list',
    ]) {
      final List<String> keywords = _extractKeywordList(value[key]);
      if (keywords.isNotEmpty) {
        return keywords;
      }
    }
  }
  return const <String>[];
}

List<FreeMusicQuality> _qualitiesFromJson(Object? value) {
  if (value is! Iterable) {
    return const <FreeMusicQuality>[];
  }
  return value
      .whereType<Map>()
      .map((Map<Object?, Object?> item) {
        return FreeMusicQuality(
          bitrate: _stringValue(item['br'] ?? item['bitrate']),
          name: _stringValue(item['name'] ?? item['label']),
          format: _stringValue(item['format']),
          size: _stringValue(item['size']),
        );
      })
      .where(
        (FreeMusicQuality quality) =>
            quality.bitrate.isNotEmpty || quality.name.isNotEmpty,
      )
      .toList(growable: false);
}

List<FreeMusicLyricLine> _parseLyricLines(String raw) {
  final RegExp timePattern = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
  final List<FreeMusicLyricLine> lines = <FreeMusicLyricLine>[];
  for (final String rawLine in raw.split(RegExp(r'\r?\n'))) {
    final Iterable<RegExpMatch> matches = timePattern.allMatches(rawLine);
    if (matches.isEmpty) {
      continue;
    }
    final String text = rawLine.replaceAll(timePattern, '').trim();
    if (text.isEmpty) {
      continue;
    }
    for (final RegExpMatch match in matches) {
      final int minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final int seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      final String fraction = match.group(3) ?? '';
      final int milliseconds = fraction.isEmpty
          ? 0
          : int.parse(fraction.padRight(3, '0').substring(0, 3));
      lines.add(
        FreeMusicLyricLine(
          time: Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          ),
          text: text,
        ),
      );
    }
  }
  lines.sort((FreeMusicLyricLine a, FreeMusicLyricLine b) {
    return a.time.compareTo(b.time);
  });
  return List<FreeMusicLyricLine>.unmodifiable(lines);
}

List<FreeMusicPlaylist> _playlistsFromJson(Object? value) {
  if (value is! Iterable) {
    return const <FreeMusicPlaylist>[];
  }
  return value
      .whereType<Map>()
      .map((Map<Object?, Object?> item) {
        return FreeMusicPlaylist(
          id: _stringValue(item['id']),
          source: _stringValue(item['source']),
          name: _stringValue(item['name'] ?? item['title']),
          cover: _stringValue(item['cover'] ?? item['picUrl'] ?? item['img']),
          creator: _stringValue(item['creator'] ?? item['author']),
          description: _stringValue(item['description']),
          link: _stringValue(item['link']),
          trackCount: _intValue(item['track_count'] ?? item['trackCount']),
          playCount: _intValue(item['play_count'] ?? item['playCount']),
        );
      })
      .where((FreeMusicPlaylist playlist) => playlist.canLoad)
      .toList(growable: false);
}

List<FreeMusicSong> _songsFromJson(Object? value) {
  if (value is! Iterable) {
    return const <FreeMusicSong>[];
  }
  return value
      .whereType<Map>()
      .map(_songFromMap)
      .where((FreeMusicSong song) => song.canResolve)
      .toList(growable: false);
}

FreeMusicSong _songFromMap(Map<Object?, Object?> item) {
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

double _doubleValue(Object? value) {
  if (value is num && value.isFinite) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

class FreeMusicApiException implements Exception {
  const FreeMusicApiException(this.message);

  final String message;

  @override
  String toString() => 'FreeMusicApiException: $message';
}
