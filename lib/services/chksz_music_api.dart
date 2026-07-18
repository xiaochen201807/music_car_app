import 'dart:convert';

import 'package:http/http.dart' as http;

import '../free_music_api.dart';

/// Free multi-platform music API hosted at https://api.chksz.com/
///
/// Used as a **backup** for search / URL resolve / lyrics when the primary
/// sy110 backend cannot produce a playable result. No authentication is
/// required. Response shapes differ per platform and are normalized here into
/// [FreeMusicSong] / [FreeMusicResolvedUrl] / [FreeMusicLyrics].
class ChkSzMusicApi {
  ChkSzMusicApi({
    http.Client? client,
    this.baseUri = defaultBaseUri,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  static const String defaultBaseUri = 'https://api.chksz.com';

  /// Platforms this backup API can serve.
  static const List<String> supportedSources = <String>[
    'netease',
    'qq',
    'kugou',
  ];

  final http.Client _client;
  final bool _ownsClient;
  final String baseUri;
  final Duration timeout;

  bool supportsSource(String source) =>
      supportedSources.contains(source.trim().toLowerCase());

  Future<FreeMusicSearchResult> searchSongs(
    String query, {
    required String source,
    int page = 0,
    int limit = 20,
  }) async {
    final String keyword = query.trim();
    if (keyword.isEmpty) {
      return FreeMusicSearchResult(
        songs: const <FreeMusicSong>[],
        hasMore: false,
        page: page,
      );
    }

    switch (source.trim().toLowerCase()) {
      case 'netease':
        return _searchNetease(keyword, page: page, limit: limit);
      case 'qq':
        return _searchQq(keyword, page: page, limit: limit);
      case 'kugou':
        return _searchKugou(keyword, page: page, limit: limit);
      default:
        return FreeMusicSearchResult(
          songs: const <FreeMusicSong>[],
          hasMore: false,
          page: page,
        );
    }
  }

  Future<FreeMusicResolvedUrl?> resolveSongUrl(
    FreeMusicSong song, {
    String bitrate = '320kmp3',
  }) async {
    if (!song.canResolve || !supportsSource(song.source)) {
      return null;
    }

    switch (song.source.trim().toLowerCase()) {
      case 'netease':
        return _resolveNetease(song.id, level: mapBitrateToLevel(bitrate));
      case 'qq':
        return _resolveQq(song.id);
      case 'kugou':
        return _resolveKugou(song.id);
      default:
        return null;
    }
  }

  Future<FreeMusicLyrics> fetchLyrics(FreeMusicSong song) async {
    if (!song.canResolve) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }

    switch (song.source.trim().toLowerCase()) {
      case 'netease':
        return _fetchNeteaseLyrics(song.id);
      case 'qq':
        return _fetchQqLyrics(song.id);
      case 'kugou':
        return _fetchKugouLyrics(song.id);
      default:
        return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }
  }

  /// Netease playlist tracks via `/api/163_playlist`. Other sources return
  /// empty — ChKSz only documents a 163 playlist endpoint.
  Future<FreeMusicPlaylistPage> fetchPlaylistSongs(
    FreeMusicPlaylist playlist, {
    int offset = 0,
    int size = 30,
  }) async {
    if (!playlist.canLoad) {
      return const FreeMusicPlaylistPage(songs: <FreeMusicSong>[], total: 0);
    }
    final String source = playlist.source.trim().toLowerCase();
    if (source != 'netease' && source != 'netease_music' && source != '163') {
      return const FreeMusicPlaylistPage(songs: <FreeMusicSong>[], total: 0);
    }
    if (playlist.id.isEmpty) {
      return const FreeMusicPlaylistPage(songs: <FreeMusicSong>[], total: 0);
    }

    final Uri uri = Uri.parse('$baseUri/api/163_playlist').replace(
      queryParameters: <String, String>{'id': playlist.id},
    );
    final Object? decoded = await _getJson(uri, allowErrorBody: true);
    if (decoded is! Map<String, dynamic>) {
      return const FreeMusicPlaylistPage(songs: <FreeMusicSong>[], total: 0);
    }
    if (decoded['code'] != null && _intValue(decoded['code']) != 200) {
      // Some responses only wrap data without a top-level code.
      if (decoded['data'] is! Map) {
        return const FreeMusicPlaylistPage(songs: <FreeMusicSong>[], total: 0);
      }
    }

    final Map<String, dynamic>? data = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : null;
    if (data == null) {
      return const FreeMusicPlaylistPage(songs: <FreeMusicSong>[], total: 0);
    }

    final List<dynamic> tracks =
        data['tracks'] as List<dynamic>? ??
        data['songs'] as List<dynamic>? ??
        const <dynamic>[];
    final int total = _intValue(data['trackCount']).clamp(0, 1 << 30);
    final int resolvedTotal = total > 0 ? total : tracks.length;

    final List<FreeMusicSong> allSongs = tracks
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) {
          final Map<String, dynamic> map = item.cast<String, dynamic>();
          final Object? album = map['al'] ?? map['album'];
          final int durationMs = _intValue(map['dt'] ?? map['duration']);
          final int durationSec = durationMs > 10000
              ? durationMs ~/ 1000
              : durationMs;
          return FreeMusicSong(
            id: _stringValue(map['id']),
            source: 'netease',
            name: _stringValue(map['name']),
            artist: _artistsToString(map['ar'] ?? map['artists']),
            album: _albumName(album),
            duration: durationSec,
            cover: _stringValue(
              map['picUrl'] ??
                  map['cover'] ??
                  (album is Map ? album['picUrl'] : null),
            ),
          );
        })
        .where((FreeMusicSong song) => song.canResolve)
        .toList(growable: false);

    final int safeOffset = offset < 0 ? 0 : offset;
    final int safeSize = size < 1 ? 30 : size;
    final List<FreeMusicSong> pageSongs = allSongs
        .skip(safeOffset)
        .take(safeSize)
        .toList(growable: false);

    return FreeMusicPlaylistPage(
      songs: pageSongs,
      total: resolvedTotal > 0 ? resolvedTotal : allSongs.length,
    );
  }

  /// Search [target] for the closest match of [song] (by name + artist).
  /// Used when the primary source cannot resolve a URL and we need a
  /// cross-source fallback.
  Future<FreeMusicSourceSwitch?> matchSong(
    FreeMusicSong song, {
    required String target,
    double minScore = 0.5,
  }) async {
    final String source = target.trim().toLowerCase();
    if (!supportsSource(source)) {
      return null;
    }

    final String query = _buildMatchQuery(song);
    if (query.isEmpty) {
      return null;
    }

    final FreeMusicSearchResult result = await searchSongs(
      query,
      source: source,
      limit: 10,
    );
    FreeMusicSong? best;
    double bestScore = 0;
    for (final FreeMusicSong candidate in result.songs) {
      final double score = _matchScore(song, candidate);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    if (best == null || bestScore < minScore) {
      return null;
    }
    return FreeMusicSourceSwitch(song: best, score: bestScore);
  }

  /// Maps app bitrate preferences (e.g. `320kmp3`, `flac`) to ChKSz netease
  /// `level` values.
  static String mapBitrateToLevel(String bitrate) {
    final String value = bitrate.trim().toLowerCase();
    if (value.contains('jymaster') || value.contains('master')) {
      return 'jymaster';
    }
    if (value.contains('hires') || value.contains('hi-res') || value.contains('hi_res')) {
      return 'hires';
    }
    if (value.contains('flac') ||
        value.contains('lossless') ||
        value.contains('ape') ||
        value == '999' ||
        value.contains('999k')) {
      return 'lossless';
    }
    if (value.contains('320') ||
        value.contains('exhigh') ||
        value.contains('192') ||
        value.contains('256')) {
      return 'exhigh';
    }
    if (value.contains('128') ||
        value.contains('96') ||
        value.contains('64') ||
        value.contains('48') ||
        value.contains('standard')) {
      return 'standard';
    }
    // App default preferred bitrate is 320kmp3.
    return 'exhigh';
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Netease
  // ---------------------------------------------------------------------------

  Future<FreeMusicSearchResult> _searchNetease(
    String keyword, {
    required int page,
    required int limit,
  }) async {
    final int safeLimit = limit.clamp(1, 100);
    final int offset = page < 0 ? 0 : page * safeLimit;
    final Uri uri = Uri.parse('$baseUri/api/163_search').replace(
      queryParameters: <String, String>{
        'keyword': keyword,
        'limit': '$safeLimit',
        'offset': '$offset',
      },
    );

    final Object? decoded = await _getJson(uri);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException('chksz 163_search returned non-object JSON');
    }
    if (decoded['code'] != null && _intValue(decoded['code']) != 200) {
      throw FreeMusicApiException(
        'chksz 163_search failed: ${decoded['msg'] ?? decoded['code']}',
      );
    }

    final Object? data = decoded['data'];
    final List<dynamic> list;
    final int total;
    if (data is Map<String, dynamic>) {
      list = data['songs'] as List<dynamic>? ??
          data['list'] as List<dynamic>? ??
          const <dynamic>[];
      total = _intValue(data['total']);
    } else if (data is List<dynamic>) {
      list = data;
      total = data.length;
    } else {
      list = const <dynamic>[];
      total = 0;
    }

    final List<FreeMusicSong> songs = list
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) {
          final Map<String, dynamic> map = item.cast<String, dynamic>();
          final int durationMs = _intValue(map['duration'] ?? map['dt']);
          final int durationSec = durationMs > 10000
              ? durationMs ~/ 1000
              : durationMs;
          return FreeMusicSong(
            id: _stringValue(map['id']),
            source: 'netease',
            name: _stringValue(map['name']),
            artist: _artistsToString(map['artists'] ?? map['ar']),
            album: _albumName(map['album'] ?? map['al']),
            duration: durationSec,
            cover: _stringValue(
              map['picUrl'] ??
                  map['cover'] ??
                  (map['al'] is Map ? (map['al'] as Map)['picUrl'] : null),
            ),
          );
        })
        .where((FreeMusicSong song) => song.canResolve)
        .toList(growable: false);

    final bool hasMore = total > 0
        ? (offset + songs.length) < total
        : songs.length >= safeLimit;

    return FreeMusicSearchResult(
      songs: songs,
      hasMore: hasMore,
      page: page,
    );
  }

  Future<FreeMusicResolvedUrl?> _resolveNetease(
    String id, {
    required String level,
  }) async {
    if (id.isEmpty) {
      return null;
    }
    // Prefer the requested level, then step down so a missing high-tier
    // quality does not fail the whole resolve.
    final List<String> levels = <String>[
      level,
      if (level != 'exhigh') 'exhigh',
      if (level != 'standard') 'standard',
      if (level != 'lossless') 'lossless',
    ];
    final Set<String> tried = <String>{};
    for (final String candidate in levels) {
      if (!tried.add(candidate)) {
        continue;
      }
      final Uri uri = Uri.parse('$baseUri/api/163_music').replace(
        queryParameters: <String, String>{
          'id': id,
          'level': candidate,
          'type': 'json',
        },
      );
      final Object? decoded = await _getJson(uri, allowErrorBody: true);
      if (decoded is! Map<String, dynamic>) {
        continue;
      }
      if (_intValue(decoded['code']) != 200) {
        continue;
      }
      final Map<String, dynamic>? data =
          decoded['data'] is Map<String, dynamic>
          ? decoded['data'] as Map<String, dynamic>
          : null;
      final String url = _stringValue(data?['url'] ?? decoded['url']);
      if (url.isEmpty) {
        continue;
      }
      return FreeMusicResolvedUrl(url: url, source: 'netease', direct: true);
    }
    return null;
  }

  Future<FreeMusicLyrics> _fetchNeteaseLyrics(String id) async {
    if (id.isEmpty) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }
    final Uri uri = Uri.parse(
      '$baseUri/api/163_lyric',
    ).replace(queryParameters: <String, String>{'id': id});
    final Object? decoded = await _getJson(uri, allowErrorBody: true);
    if (decoded is! Map<String, dynamic>) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }
    if (_intValue(decoded['code']) != 200 && decoded['code'] != null) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }
    final Map<String, dynamic>? data = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : null;
    final String raw = _stringValue(data?['lrc'] ?? data?['lyric']);
    if (raw.isEmpty) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }
    return FreeMusicLyrics(raw: raw, lines: _parseLrc(raw));
  }

  // ---------------------------------------------------------------------------
  // QQ Music
  // ---------------------------------------------------------------------------

  Future<FreeMusicSearchResult> _searchQq(
    String keyword, {
    required int page,
    required int limit,
  }) async {
    // QQ endpoint only supports first-page style search with `num`.
    if (page > 0) {
      return FreeMusicSearchResult(
        songs: const <FreeMusicSong>[],
        hasMore: false,
        page: page,
      );
    }
    final int safeLimit = limit.clamp(1, 50);
    final Uri uri = Uri.parse('$baseUri/api/qq_music').replace(
      queryParameters: <String, String>{
        'msg': keyword,
        'num': '$safeLimit',
        'type': 'json',
      },
    );
    final Object? decoded = await _getJson(uri);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException('chksz qq_music search returned non-object JSON');
    }
    final List<dynamic> list =
        decoded['list'] as List<dynamic>? ??
        (decoded['data'] is Map
            ? (decoded['data'] as Map)['list'] as List<dynamic>?
            : null) ??
        const <dynamic>[];
    final List<FreeMusicSong> songs = list
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) {
          final Map<String, dynamic> map = item.cast<String, dynamic>();
          return FreeMusicSong(
            id: _stringValue(map['id'] ?? map['mid'] ?? map['songmid']),
            source: 'qq',
            name: _stringValue(map['name'] ?? map['songname'] ?? map['title']),
            artist: _artistsToString(
              map['artists'] ?? map['singer'] ?? map['singername'],
            ),
            album: _albumName(map['album'] ?? map['albumname']),
            duration: _durationSeconds(map['duration'] ?? map['interval']),
            cover: _coverFromQq(map),
          );
        })
        .where((FreeMusicSong song) => song.canResolve)
        .toList(growable: false);

    return FreeMusicSearchResult(
      songs: songs,
      hasMore: false,
      page: page,
    );
  }

  Future<FreeMusicResolvedUrl?> _resolveQq(String mid) async {
    if (mid.isEmpty) {
      return null;
    }
    final Uri uri = Uri.parse('$baseUri/api/qq_music').replace(
      queryParameters: <String, String>{'mid': mid, 'type': 'json'},
    );
    final Object? decoded = await _getJson(uri, allowErrorBody: true);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final String url = _stringValue(
      decoded['url'] ??
          (decoded['data'] is Map ? (decoded['data'] as Map)['url'] : null),
    );
    if (url.isEmpty) {
      return null;
    }
    return FreeMusicResolvedUrl(url: url, source: 'qq', direct: true);
  }

  Future<FreeMusicLyrics> _fetchQqLyrics(String mid) async {
    if (mid.isEmpty) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }
    // Resolve payload already embeds lyrics for many tracks.
    final Uri uri = Uri.parse('$baseUri/api/qq_music').replace(
      queryParameters: <String, String>{'mid': mid, 'type': 'json'},
    );
    final Object? decoded = await _getJson(uri, allowErrorBody: true);
    if (decoded is! Map<String, dynamic>) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }
    final Object? lyricNode = decoded['lyric'] ??
        (decoded['data'] is Map ? (decoded['data'] as Map)['lyric'] : null);
    final String raw = lyricNode is Map
        ? _stringValue(lyricNode['text'] ?? lyricNode['lrc'])
        : _stringValue(lyricNode);
    if (raw.isEmpty) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }
    return FreeMusicLyrics(raw: raw, lines: _parseLrc(raw));
  }

  // ---------------------------------------------------------------------------
  // Kugou
  // ---------------------------------------------------------------------------

  Future<FreeMusicSearchResult> _searchKugou(
    String keyword, {
    required int page,
    required int limit,
  }) async {
    if (page > 0) {
      return FreeMusicSearchResult(
        songs: const <FreeMusicSong>[],
        hasMore: false,
        page: page,
      );
    }
    final Uri uri = Uri.parse('$baseUri/api/kugou_music').replace(
      queryParameters: <String, String>{'msg': keyword},
    );
    final Object? decoded = await _getJson(uri);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException(
        'chksz kugou_music search returned non-object JSON',
      );
    }
    final List<dynamic> list =
        decoded['list'] as List<dynamic>? ??
        (decoded['data'] is Map
            ? (decoded['data'] as Map)['list'] as List<dynamic>?
            : null) ??
        const <dynamic>[];
    final int total = _intValue(decoded['total']);
    final List<FreeMusicSong> songs = list
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) {
          final Map<String, dynamic> map = item.cast<String, dynamic>();
          return FreeMusicSong(
            id: _stringValue(map['id'] ?? map['hash'] ?? map['FileHash']),
            source: 'kugou',
            name: _stringValue(
              map['SongName'] ?? map['songName'] ?? map['name'] ?? map['FileName'],
            ),
            artist: _stringValue(
              map['SingerName'] ?? map['singerName'] ?? map['artist'],
            ),
            album: _stringValue(map['AlbumName'] ?? map['albumName'] ?? map['album']),
            duration: _durationSeconds(map['Duration'] ?? map['duration'] ?? map['timeLength']),
            cover: _stringValue(
              map['Image'] ?? map['albumImage'] ?? map['cover'] ?? map['img'],
            ),
          );
        })
        .where((FreeMusicSong song) => song.canResolve)
        .toList(growable: false);

    final int take = limit.clamp(1, songs.isEmpty ? 1 : songs.length);
    final List<FreeMusicSong> pageSongs = songs.take(take).toList(growable: false);
    final bool hasMore = total > 0
        ? pageSongs.length < total
        : songs.length > take;

    return FreeMusicSearchResult(
      songs: pageSongs,
      hasMore: hasMore,
      page: page,
    );
  }

  Future<FreeMusicResolvedUrl?> _resolveKugou(String id) async {
    if (id.isEmpty) {
      return null;
    }
    final Uri uri = Uri.parse(
      '$baseUri/api/kugou_music',
    ).replace(queryParameters: <String, String>{'id': id});
    final Object? decoded = await _getJson(uri, allowErrorBody: true);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final Map<String, dynamic>? data = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : null;
    final String url = _stringValue(data?['url'] ?? decoded['url']);
    if (url.isEmpty) {
      return null;
    }
    return FreeMusicResolvedUrl(url: url, source: 'kugou', direct: true);
  }

  Future<FreeMusicLyrics> _fetchKugouLyrics(String id) async {
    if (id.isEmpty) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }
    final Uri uri = Uri.parse(
      '$baseUri/api/kugou_music',
    ).replace(queryParameters: <String, String>{'id': id});
    final Object? decoded = await _getJson(uri, allowErrorBody: true);
    if (decoded is! Map<String, dynamic>) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }
    final Map<String, dynamic>? data = decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : null;
    final String raw = _stringValue(data?['lyrics'] ?? data?['lyric'] ?? data?['lrc']);
    if (raw.isEmpty) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }
    return FreeMusicLyrics(raw: raw, lines: _parseLrc(raw));
  }

  // ---------------------------------------------------------------------------
  // HTTP + helpers
  // ---------------------------------------------------------------------------

  Future<Object?> _getJson(Uri uri, {bool allowErrorBody = false}) async {
    final http.Response response = await _client
        .get(
          uri,
          headers: const <String, String>{
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 MusicCarApp/ChkSzBackup',
          },
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (!allowErrorBody) {
        throw FreeMusicApiException(
          'chksz request failed with HTTP ${response.statusCode}: ${uri.path}',
        );
      }
      if (response.body.isEmpty) {
        return null;
      }
    }

    if (response.body.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(response.body);
    } on FormatException {
      if (allowErrorBody) {
        return null;
      }
      throw FreeMusicApiException(
        'chksz returned non-JSON body for ${uri.path}',
      );
    }
  }

  static String _buildMatchQuery(FreeMusicSong song) {
    final String name = song.name.trim();
    final String artist = song.artist.trim();
    if (name.isEmpty && artist.isEmpty) {
      return '';
    }
    if (name.isEmpty) {
      return artist;
    }
    if (artist.isEmpty) {
      return name;
    }
    return '$name $artist';
  }

  static double _matchScore(FreeMusicSong expected, FreeMusicSong candidate) {
    final String expectedName = _normalize(expected.name);
    final String candidateName = _normalize(candidate.name);
    final String expectedArtist = _normalize(expected.artist);
    final String candidateArtist = _normalize(candidate.artist);

    double score = 0;
    if (expectedName.isNotEmpty && candidateName.isNotEmpty) {
      if (expectedName == candidateName) {
        score += 0.55;
      } else if (candidateName.contains(expectedName) ||
          expectedName.contains(candidateName)) {
        score += 0.35;
      }
    }
    if (expectedArtist.isNotEmpty && candidateArtist.isNotEmpty) {
      if (expectedArtist == candidateArtist) {
        score += 0.35;
      } else if (candidateArtist.contains(expectedArtist) ||
          expectedArtist.contains(candidateArtist)) {
        score += 0.2;
      } else {
        // Split multi-artist strings (a/b, a;b, a&b).
        final Set<String> expectedParts = expectedArtist
            .split(RegExp(r'[/;&,、|]+'))
            .map(_normalize)
            .where((String s) => s.isNotEmpty)
            .toSet();
        final Set<String> candidateParts = candidateArtist
            .split(RegExp(r'[/;&,、|]+'))
            .map(_normalize)
            .where((String s) => s.isNotEmpty)
            .toSet();
        if (expectedParts.intersection(candidateParts).isNotEmpty) {
          score += 0.2;
        }
      }
    }
    if (expected.duration > 0 && candidate.duration > 0) {
      final int delta = (expected.duration - candidate.duration).abs();
      if (delta <= 2) {
        score += 0.1;
      } else if (delta <= 5) {
        score += 0.05;
      }
    }
    return score;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\s　]+'), '')
        .replaceAll(RegExp(r'[（(].*?[)）]'), '')
        .replaceAll(RegExp(r'[\[【].*?[\]】]'), '');
  }

  static String _artistsToString(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value.trim();
    }
    if (value is List) {
      final List<String> names = value
          .map((Object? item) {
            if (item is Map) {
              return _stringValue(item['name'] ?? item['Name']);
            }
            return _stringValue(item);
          })
          .where((String name) => name.isNotEmpty)
          .toList(growable: false);
      return names.join('/');
    }
    if (value is Map) {
      return _stringValue(value['name'] ?? value['Name']);
    }
    return _stringValue(value);
  }

  static String _albumName(Object? value) {
    if (value is Map) {
      return _stringValue(value['name'] ?? value['Name'] ?? value['title']);
    }
    return _stringValue(value);
  }

  static String _coverFromQq(Map<String, dynamic> map) {
    final Object? cover = map['cover'];
    if (cover is Map) {
      return _stringValue(
        cover['large'] ?? cover['medium'] ?? cover['small'] ?? cover['url'],
      );
    }
    return _stringValue(
      cover ?? map['pic'] ?? map['albumPic'] ?? map['imgurl'],
    );
  }

  static int _durationSeconds(Object? value) {
    final int raw = _intValue(value);
    if (raw <= 0) {
      return 0;
    }
    // Heuristic: values above 10_000 are almost always milliseconds.
    if (raw > 10000) {
      return raw ~/ 1000;
    }
    return raw;
  }

  static List<FreeMusicLyricLine> _parseLrc(String raw) {
    final RegExp pattern = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
    final List<FreeMusicLyricLine> lines = <FreeMusicLyricLine>[];
    for (final String line in raw.split(RegExp(r'\r?\n'))) {
      final Iterable<RegExpMatch> matches = pattern.allMatches(line);
      if (matches.isEmpty) {
        continue;
      }
      final String text = line.replaceAll(pattern, '').trim();
      if (text.isEmpty) {
        continue;
      }
      for (final RegExpMatch match in matches) {
        final int minutes = int.tryParse(match.group(1) ?? '') ?? 0;
        final int seconds = int.tryParse(match.group(2) ?? '') ?? 0;
        final String frac = match.group(3) ?? '0';
        final int millis = frac.length == 2
            ? (int.tryParse(frac) ?? 0) * 10
            : int.tryParse(frac.padRight(3, '0').substring(0, 3)) ?? 0;
        lines.add(
          FreeMusicLyricLine(
            time: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: millis,
            ),
            text: text,
          ),
        );
      }
    }
    lines.sort(
      (FreeMusicLyricLine a, FreeMusicLyricLine b) =>
          a.time.compareTo(b.time),
    );
    return lines;
  }

  static String _stringValue(Object? value) {
    if (value == null) {
      return '';
    }
    return '$value'.trim();
  }

  static int _intValue(Object? value) {
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
}
