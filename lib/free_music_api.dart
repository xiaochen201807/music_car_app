import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'services/sy110_auth_service.dart';

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

  factory FreeMusicPlaylist.fromMap(Map<String, dynamic> map) {
    return FreeMusicPlaylist(
      id: '${map['id'] ?? ''}',
      source: '${map['source'] ?? ''}',
      name: '${map['name'] ?? ''}',
      cover: '${map['cover'] ?? ''}',
      creator: '${map['creator'] ?? ''}',
      description: '${map['description'] ?? ''}',
      link: '${map['link'] ?? ''}',
      trackCount: _mapInt(map['trackCount']),
      playCount: _mapInt(map['playCount']),
    );
  }

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

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'source': source,
      'name': name,
      'cover': cover,
      'creator': creator,
      'description': description,
      'link': link,
      'trackCount': trackCount,
      'playCount': playCount,
    };
  }
}

int _mapInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
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
  const FreeMusicLyricLine({
    required this.time,
    required this.text,
    this.words,
  });

  final Duration time;
  final String text;
  final List<FreeMusicLyricWord>? words;
}

class FreeMusicLyricWord {
  const FreeMusicLyricWord({
    required this.time,
    required this.text,
    required this.duration,
  });

  final Duration time;
  final String text;
  final Duration duration;
}

class FreeMusicLyrics {
  const FreeMusicLyrics({
    required this.raw,
    required this.lines,
    this.hasWordTimestamps = false,
  });

  final String raw;
  final List<FreeMusicLyricLine> lines;
  final bool hasWordTimestamps;

  bool get isEmpty => raw.trim().isEmpty && lines.isEmpty;
}

class FreeMusicChart {
  const FreeMusicChart({
    required this.id,
    required this.source,
    required this.name,
    this.description = '',
    this.cover = '',
    this.group = '',
    this.official = false,
  });

  final String id;
  final String source;
  final String name;
  final String description;
  final String cover;
  final String group;
  final bool official;
}

class FreeMusicCategory {
  const FreeMusicCategory({
    required this.id,
    required this.name,
    this.parentId = '',
  });

  final String id;
  final String name;
  final String parentId;
}

class FreeMusicApi {
  FreeMusicApi({
    http.Client? client,
    this.baseUri = 'https://music.sy110.eu.org',
    this.timeout = const Duration(seconds: 12),
    String? authUsername,
    String? authPassword,
  }) : _client = client ?? http.Client(),
       _authService = Sy110AuthService(
         client: client,
         username: authUsername,
         password: authPassword,
       );

  final http.Client _client;
  final String baseUri;
  final Sy110AuthService _authService;

  /// Network timeout applied to every request.
  final Duration timeout;

  /// Single choke point for every GET with authentication
  Future<http.Response> _httpGet(
    Uri uri, {
    Map<String, String>? additionalHeaders,
  }) async {
    final Map<String, String> authHeaders = await _authService.getAuthHeaders();
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0 MusicCarApp',
      ...authHeaders,
      ...?additionalHeaders,
    };

    return _client.get(uri, headers: headers).timeout(timeout);
  }

  /// POST request with authentication
  Future<http.Response> _httpPost(
    Uri uri, {
    required Map<String, dynamic> body,
    Map<String, String>? additionalHeaders,
  }) async {
    final Map<String, String> authHeaders = await _authService.getAuthHeaders();
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 MusicCarApp',
      ...authHeaders,
      ...?additionalHeaders,
    };

    return _client
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(timeout);
  }

  Future<FreeMusicSources> fetchSources() async {
    // sy110 支持的音乐源
    return const FreeMusicSources(
      allSources: <String>['kuwo', 'netease', 'qq', 'kugou'],
      defaultSources: <String>['kuwo', 'netease'],
      descriptions: <String, String>{
        'kuwo': '酷我音乐',
        'netease': '网易云音乐',
        'qq': 'QQ音乐',
        'kugou': '酷狗音乐',
      },
    );
  }

  Future<List<String>> fetchHotSearchKeywords() async {
    // sy110 暂无热搜接口，返回空列表
    return const <String>[];
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

    // 默认使用网易云音乐搜索
    final String source = (sources != null && sources.isNotEmpty)
        ? sources.first
        : 'netease';

    final Uri uri = Uri.parse('$baseUri/api/music/search/songs').replace(
      queryParameters: <String, String>{
        'q': keyword,
        'source': source,
        'page': '${page + 1}', // sy110 API 从1开始
        'page_size': '20',
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

    if (decoded['code'] != 0) {
      throw FreeMusicApiException(
        'search failed: ${decoded['message'] ?? 'unknown error'}',
      );
    }

    final Map<String, dynamic>? data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) {
      return const FreeMusicSearchResult(
        songs: <FreeMusicSong>[],
        hasMore: false,
        page: 0,
      );
    }

    final List<dynamic> list = data['list'] as List<dynamic>? ?? <dynamic>[];

    final List<FreeMusicSong> songs = list
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            return null;
          }

          return _songFromSy110Map(item);
        })
        .whereType<FreeMusicSong>()
        .toList();

    // sy110 暂时没有返回总数，默认有更多
    final bool hasMore = songs.length >= 20;

    return FreeMusicSearchResult(songs: songs, hasMore: hasMore, page: page);
  }

  Future<FreeMusicRecommendResult> fetchRecommendations({
    List<String>? sources,
  }) async {
    // 使用分类歌单接口获取推荐
    final String source = (sources != null && sources.isNotEmpty)
        ? sources.first
        : 'kugou';

    final Uri uri =
        Uri.parse('$baseUri/api/music/playlists/category/$source/全部').replace(
          queryParameters: <String, String>{'page': '1', 'page_size': '20'},
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

    if (decoded['code'] != 0) {
      return const FreeMusicRecommendResult(playlists: <FreeMusicPlaylist>[]);
    }

    final Map<String, dynamic>? data = decoded['data'] as Map<String, dynamic>?;
    final List<dynamic> list = data?['list'] as List<dynamic>? ?? <dynamic>[];

    final List<FreeMusicPlaylist> playlists = list
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            return null;
          }

          return FreeMusicPlaylist(
            id: _stringValue(item['id']),
            source: _stringValue(item['source']),
            name: _stringValue(item['name']),
            cover: _stringValue(item['cover']),
            creator: _stringValue(item['creator']),
            description: _stringValue(item['description']),
            trackCount: _intValue(item['trackCount']),
            playCount: _intValue(item['playCount']),
          );
        })
        .whereType<FreeMusicPlaylist>()
        .toList();

    return FreeMusicRecommendResult(playlists: playlists);
  }

  Future<FreeMusicPlaylistPage> fetchPlaylistSongs(
    FreeMusicPlaylist playlist, {
    int offset = 0,
    int size = 30,
  }) async {
    if (!playlist.canLoad) {
      return const FreeMusicPlaylistPage(songs: <FreeMusicSong>[], total: 0);
    }

    final int page = (offset ~/ size) + 1;

    final Uri uri =
        Uri.parse(
          '$baseUri/api/music/playlists/songs/${playlist.source}/${playlist.id}',
        ).replace(
          queryParameters: <String, String>{
            'page': '$page',
            'page_size': '$size',
          },
        );

    final http.Response response = await _httpGet(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FreeMusicApiException(
        'playlist failed with HTTP ${response.statusCode}',
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException('playlist returned non-object JSON');
    }

    if (decoded['code'] != 0) {
      return const FreeMusicPlaylistPage(songs: <FreeMusicSong>[], total: 0);
    }

    final Map<String, dynamic>? data = decoded['data'] as Map<String, dynamic>?;
    final List<dynamic> list = data?['list'] as List<dynamic>? ?? <dynamic>[];

    final List<FreeMusicSong> songs = list
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            return null;
          }
          return _songFromSy110Map(item);
        })
        .whereType<FreeMusicSong>()
        .skip(offset % size)
        .take(size)
        .toList();

    return FreeMusicPlaylistPage(songs: songs, total: list.length);
  }

  Future<FreeMusicResolvedUrl?> resolveSongUrl(
    FreeMusicSong song, {
    String bitrate = '320kmp3',
  }) async {
    if (!song.canResolve) {
      return null;
    }

    final Uri uri =
        Uri.parse(
          '$baseUri/api/music/songs/url/${song.source}/${song.id}',
        ).replace(
          queryParameters: <String, String>{
            'name': song.name,
            'artist': song.artist,
            'duration_ms': '${song.duration * 1000}',
            if (bitrate.isNotEmpty) 'quality': bitrate,
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

    if (decoded['code'] != 0) {
      return null;
    }

    final Map<String, dynamic>? data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) {
      return null;
    }

    final String url = _stringValue(data['url']);
    final bool playable = data['playable'] as bool? ?? url.isNotEmpty;

    if (url.isEmpty || !playable) {
      return null;
    }

    return FreeMusicResolvedUrl(url: url, source: song.source, direct: true);
  }

  Future<FreeMusicSourceSwitch?> switchSource(
    FreeMusicSong song, {
    required String target,
    double minScore = 0.5,
  }) async {
    // sy110 暂无跨源切换接口，返回 null
    return null;
  }

  Future<FreeMusicQualityResult> fetchQualities(FreeMusicSong song) async {
    // sy110 的搜索结果中已包含音质信息，这里返回空列表
    return const FreeMusicQualityResult(
      matchedName: '',
      matchedArtist: '',
      qualities: <FreeMusicQuality>[],
    );
  }

  Future<FreeMusicLyrics> fetchEnhancedLyrics(FreeMusicSong song) async {
    return fetchLyrics(song, needWord: true);
  }

  Future<FreeMusicLyrics> fetchLyrics(
    FreeMusicSong song, {
    bool needWord = false,
  }) async {
    if (!song.canResolve) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }

    final Uri uri = Uri.parse('$baseUri/api/music/lyrics/discover').replace(
      queryParameters: <String, String>{
        'id': song.id,
        'source': song.source,
        'name': song.name,
        'artist': song.artist,
        'duration_ms': '${song.duration * 1000}',
        'need_word': needWord ? 'true' : 'false',
        't': '${DateTime.now().millisecondsSinceEpoch}',
      },
    );

    final http.Response response = await _httpGet(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }

    if (decoded['code'] != 0) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }

    final Map<String, dynamic>? data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }

    final Map<String, dynamic>? selected =
        data['selected'] as Map<String, dynamic>?;
    if (selected == null) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }

    final String raw = _stringValue(selected['raw']);
    if (raw.isEmpty) {
      return const FreeMusicLyrics(raw: '', lines: <FreeMusicLyricLine>[]);
    }

    final List<dynamic> linesData =
        selected['lines'] as List<dynamic>? ?? <dynamic>[];

    final List<FreeMusicLyricLine> lines = linesData
        .map((dynamic lineItem) {
          if (lineItem is! Map<String, dynamic>) {
            return null;
          }

          final int startMs = _intValue(lineItem['startMs']);
          final String text = _stringValue(lineItem['text']);

          List<FreeMusicLyricWord>? words;
          if (needWord && lineItem.containsKey('words')) {
            final List<dynamic> wordsData =
                lineItem['words'] as List<dynamic>? ?? <dynamic>[];
            words = wordsData
                .map((dynamic wordItem) {
                  if (wordItem is! Map<String, dynamic>) {
                    return null;
                  }

                  final int wordStartMs = _intValue(wordItem['startMs']);
                  final int wordEndMs = _intValue(wordItem['endMs']);
                  final String wordText = _stringValue(wordItem['text']);

                  return FreeMusicLyricWord(
                    time: Duration(milliseconds: wordStartMs),
                    text: wordText,
                    duration: Duration(milliseconds: wordEndMs - wordStartMs),
                  );
                })
                .whereType<FreeMusicLyricWord>()
                .toList();
          }

          return FreeMusicLyricLine(
            time: Duration(milliseconds: startMs),
            text: text,
            words: words,
          );
        })
        .whereType<FreeMusicLyricLine>()
        .toList();

    return FreeMusicLyrics(
      raw: raw,
      lines: lines,
      hasWordTimestamps:
          needWord && lines.any((FreeMusicLyricLine l) => l.words != null),
    );
  }

  /// 获取榜单列表
  Future<List<FreeMusicChart>> fetchCharts({String source = 'kuwo'}) async {
    final Uri uri = Uri.parse(
      '$baseUri/api/music/charts',
    ).replace(queryParameters: <String, String>{'source': source});

    final http.Response response = await _httpGet(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FreeMusicApiException(
        'charts failed with HTTP ${response.statusCode}',
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException('charts returned non-object JSON');
    }

    if (decoded['code'] != 0) {
      return const <FreeMusicChart>[];
    }

    final List<dynamic> data = decoded['data'] as List<dynamic>? ?? <dynamic>[];

    return data
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            return null;
          }

          return FreeMusicChart(
            id: _stringValue(item['id']),
            source: _stringValue(item['source']),
            name: _stringValue(item['name']),
            description: _stringValue(item['description']),
            cover: _stringValue(item['cover']),
            group: _stringValue(item['group']),
            official: item['official'] as bool? ?? false,
          );
        })
        .whereType<FreeMusicChart>()
        .toList();
  }

  /// 获取歌单分类列表
  Future<List<FreeMusicCategory>> fetchPlaylistCategories({
    String source = 'kuwo',
  }) async {
    final Uri uri = Uri.parse(
      '$baseUri/api/music/playlists/categories/$source',
    );

    final http.Response response = await _httpGet(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FreeMusicApiException(
        'categories failed with HTTP ${response.statusCode}',
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException('categories returned non-object JSON');
    }

    if (decoded['code'] != 0) {
      return const <FreeMusicCategory>[];
    }

    final List<dynamic> data = decoded['data'] as List<dynamic>? ?? <dynamic>[];

    return data
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            return null;
          }

          return FreeMusicCategory(
            id: _stringValue(item['id']),
            name: _stringValue(item['name']),
            parentId: _stringValue(item['parentId']),
          );
        })
        .whereType<FreeMusicCategory>()
        .toList();
  }

  /// 获取指定分类下的歌单列表
  Future<List<FreeMusicPlaylist>> fetchPlaylistsByCategory({
    required String source,
    required String categoryId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final Uri uri =
        Uri.parse(
          '$baseUri/api/music/playlists/category/$source/$categoryId',
        ).replace(
          queryParameters: <String, String>{
            'page': '$page',
            'page_size': '$pageSize',
          },
        );

    final http.Response response = await _httpGet(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FreeMusicApiException(
        'playlists by category failed with HTTP ${response.statusCode}',
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException(
        'playlists by category returned non-object JSON',
      );
    }

    if (decoded['code'] != 0) {
      return const <FreeMusicPlaylist>[];
    }

    final Map<String, dynamic>? data = decoded['data'] as Map<String, dynamic>?;
    final List<dynamic> list = data?['list'] as List<dynamic>? ?? <dynamic>[];

    return list
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            return null;
          }

          return FreeMusicPlaylist(
            id: _stringValue(item['id']),
            source: _stringValue(item['source']),
            name: _stringValue(item['name']),
            cover: _stringValue(item['cover']),
            creator: _stringValue(item['creator']),
            description: _stringValue(item['description']),
            trackCount: _intValue(item['trackCount']),
            playCount: _intValue(item['playCount']),
          );
        })
        .whereType<FreeMusicPlaylist>()
        .toList();
  }

  /// 获取收藏列表
  Future<List<FreeMusicSong>> fetchFavorites() async {
    final Uri uri = Uri.parse('$baseUri/api/v1/music/favorites');

    final http.Response response = await _httpGet(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FreeMusicApiException(
        'favorites failed with HTTP ${response.statusCode}',
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException('favorites returned non-object JSON');
    }

    if (decoded['code'] != 0) {
      return const <FreeMusicSong>[];
    }

    final Map<String, dynamic>? data = decoded['data'] as Map<String, dynamic>?;
    final List<dynamic> songs = data?['songs'] as List<dynamic>? ?? <dynamic>[];

    return songs
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            return null;
          }

          // 收藏列表返回的格式可能与搜索不同，需要适配
          return FreeMusicSong(
            id: _stringValue(item['id']),
            source: _stringValue(item['source']),
            name: _stringValue(item['name']),
            artist: _stringValue(item['artist']),
            album: _stringValue(item['album']),
            duration: _intValue(item['duration']),
            cover: _stringValue(item['cover']),
          );
        })
        .whereType<FreeMusicSong>()
        .toList();
  }

  /// 添加到收藏
  Future<bool> addToFavorites(FreeMusicSong song) async {
    final Uri uri = Uri.parse('$baseUri/api/v1/music/favorites');

    final http.Response response = await _httpPost(
      uri,
      body: <String, dynamic>{
        'id': song.id,
        'source': song.source,
        'name': song.name,
        'artist': song.artist,
        if (song.album.isNotEmpty) 'album': song.album,
        if (song.duration > 0) 'duration': song.duration,
        if (song.cover.isNotEmpty) 'cover': song.cover,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return false;
    }

    return decoded['code'] == 0;
  }

  /// 从收藏中移除
  Future<bool> removeFromFavorites(FreeMusicSong song) async {
    final Uri uri = Uri.parse(
      '$baseUri/api/v1/music/favorites/${song.id}',
    ).replace(queryParameters: <String, String>{'source': song.source});

    final http.Response response = await _client
        .delete(uri, headers: await _authService.getAuthHeaders())
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return false;
    }

    return decoded['code'] == 0;
  }

  /// 获取播放历史
  Future<List<FreeMusicSong>> fetchRecentPlays() async {
    final Uri uri = Uri.parse('$baseUri/api/v1/music/recent_plays');

    final http.Response response = await _httpGet(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FreeMusicApiException(
        'recent plays failed with HTTP ${response.statusCode}',
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FreeMusicApiException(
        'recent plays returned non-object JSON',
      );
    }

    if (decoded['code'] != 0) {
      return const <FreeMusicSong>[];
    }

    final Map<String, dynamic>? data = decoded['data'] as Map<String, dynamic>?;
    final List<dynamic> plays = data?['plays'] as List<dynamic>? ?? <dynamic>[];

    return plays
        .map((dynamic item) {
          if (item is! Map<String, dynamic>) {
            return null;
          }

          return FreeMusicSong(
            id: _stringValue(item['id']),
            source: _stringValue(item['source']),
            name: _stringValue(item['name']),
            artist: _stringValue(item['artist']),
            album: _stringValue(item['album']),
            duration: _intValue(item['duration']),
            cover: _stringValue(item['cover']),
          );
        })
        .whereType<FreeMusicSong>()
        .toList();
  }

  /// 添加播放记录
  Future<bool> addRecentPlay(FreeMusicSong song) async {
    final Uri uri = Uri.parse('$baseUri/api/v1/music/recent_plays');

    final http.Response response = await _httpPost(
      uri,
      body: <String, dynamic>{
        'id': song.id,
        'source': song.source,
        'name': song.name,
        'artist': song.artist,
        'duration': song.duration,
        if (song.album.isNotEmpty) 'album': song.album,
        if (song.cover.isNotEmpty) 'cover': song.cover,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return false;
    }

    return decoded['code'] == 0;
  }

  void close() {
    _client.close();
    _authService.close();
  }

  /// 从 sy110 API 返回的 Map 构建 FreeMusicSong
  FreeMusicSong _songFromSy110Map(Map<String, dynamic> item) {
    // 提取歌手信息
    String artist = '';
    final dynamic artists = item['artists'];
    if (artists is List && artists.isNotEmpty) {
      final List<String> artistNames = artists
          .map((dynamic a) {
            if (a is Map<String, dynamic>) {
              return _stringValue(a['name']);
            }
            return '';
          })
          .where((String name) => name.isNotEmpty)
          .toList();
      artist = artistNames.join('/');
    }

    // 提取专辑信息
    String album = '';
    String cover = '';
    final dynamic albumData = item['album'];
    if (albumData is Map<String, dynamic>) {
      album = _stringValue(albumData['name']);
      cover = _stringValue(albumData['cover']);
    }

    // 如果没有专辑封面，使用歌曲封面
    if (cover.isEmpty) {
      cover = _stringValue(item['cover']);
    }

    final int durationMs = _intValue(item['durationMs']);

    return FreeMusicSong(
      id: _stringValue(item['id']),
      source: _stringValue(item['source']),
      name: _stringValue(item['name']),
      artist: artist,
      album: album,
      duration: durationMs ~/ 1000,
      cover: cover,
    );
  }
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
