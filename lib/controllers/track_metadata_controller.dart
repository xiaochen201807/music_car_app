import 'package:flutter/foundation.dart';

import '../free_music_api.dart';

abstract class TrackMetadataClient {
  Future<FreeMusicLyrics> fetchEnhancedLyrics(FreeMusicSong song);

  Future<FreeMusicQualityResult> fetchQualities(FreeMusicSong song);
}

class FreeMusicTrackMetadataClient implements TrackMetadataClient {
  const FreeMusicTrackMetadataClient(this._api);

  final FreeMusicApi _api;

  @override
  Future<FreeMusicLyrics> fetchEnhancedLyrics(FreeMusicSong song) {
    return _api.fetchEnhancedLyrics(song).timeout(const Duration(seconds: 5));
  }

  @override
  Future<FreeMusicQualityResult> fetchQualities(FreeMusicSong song) {
    return _api.fetchQualities(song).timeout(const Duration(seconds: 5));
  }
}

class TrackMetadataController extends ChangeNotifier {
  TrackMetadataController({required TrackMetadataClient client})
    : _client = client;

  final TrackMetadataClient _client;

  bool _isLoadingLyrics = false;
  bool _isLoadingQualities = false;
  int _lyricsRequestId = 0;
  int _qualitiesRequestId = 0;
  String _lyricsError = '';
  String _qualityError = '';
  FreeMusicLyrics? _currentLyrics;
  // 记录当前歌词所属歌曲，切歌后用于校验归属，避免歌词与歌曲错位
  String _currentLyricsKey = '';
  List<FreeMusicQuality> _currentQualities = const <FreeMusicQuality>[];

  bool get isLoadingLyrics => _isLoadingLyrics;

  bool get isLoadingQualities => _isLoadingQualities;

  String get lyricsError => _lyricsError;

  String get qualityError => _qualityError;

  FreeMusicLyrics? get currentLyrics => _currentLyrics;

  /// 当前歌词所属歌曲的标识（source:id），空表示无归属。
  String get currentLyricsKey => _currentLyricsKey;

  static String lyricsKeyFor(FreeMusicSong song) => '${song.source}:${song.id}';

  List<FreeMusicQuality> get currentQualities => _currentQualities;

  void reset() {
    _lyricsRequestId += 1;
    _qualitiesRequestId += 1;
    _isLoadingLyrics = false;
    _isLoadingQualities = false;
    _lyricsError = '';
    _qualityError = '';
    _currentLyrics = null;
    _currentLyricsKey = '';
    _currentQualities = const <FreeMusicQuality>[];
    notifyListeners();
  }

  Future<bool> loadLyricsForSong(FreeMusicSong song) async {
    final int requestId = ++_lyricsRequestId;
    if (!song.canResolve) {
      _isLoadingLyrics = false;
      _lyricsError = '';
      _currentLyrics = null;
      _currentLyricsKey = '';
      notifyListeners();
      return true;
    }

    _isLoadingLyrics = true;
    _lyricsError = '';
    // 立即清空旧歌词与归属标识，避免切歌后短暂显示上一首
    _currentLyrics = null;
    _currentLyricsKey = '';
    notifyListeners();

    try {
      final FreeMusicLyrics lyrics = await _client.fetchEnhancedLyrics(song);
      if (requestId != _lyricsRequestId) {
        return false;
      }
      _currentLyrics = lyrics;
      _currentLyricsKey = lyricsKeyFor(song);
      _isLoadingLyrics = false;
      notifyListeners();
      return true;
    } on FreeMusicApiException catch (error) {
      if (requestId != _lyricsRequestId) {
        return false;
      }
      _lyricsError = error.message;
      _isLoadingLyrics = false;
      notifyListeners();
      return true;
    } catch (error) {
      if (requestId != _lyricsRequestId) {
        return false;
      }
      _lyricsError = '歌词加载失败：$error';
      _isLoadingLyrics = false;
      notifyListeners();
      return true;
    }
  }

  Future<bool> loadQualitiesForSong(FreeMusicSong song) async {
    if (!song.canResolve) {
      return false;
    }
    final int requestId = ++_qualitiesRequestId;
    _isLoadingQualities = true;
    _qualityError = '';
    _currentQualities = const <FreeMusicQuality>[];
    notifyListeners();

    try {
      final FreeMusicQualityResult result = await _client.fetchQualities(song);
      if (requestId != _qualitiesRequestId) {
        return false;
      }
      _currentQualities = List<FreeMusicQuality>.unmodifiable(result.qualities);
      _isLoadingQualities = false;
      notifyListeners();
      return true;
    } on FreeMusicApiException catch (error) {
      if (requestId != _qualitiesRequestId) {
        return false;
      }
      _qualityError = error.message;
      _isLoadingQualities = false;
      notifyListeners();
      return true;
    } catch (error) {
      if (requestId != _qualitiesRequestId) {
        return false;
      }
      _qualityError = '音质加载失败：$error';
      _isLoadingQualities = false;
      notifyListeners();
      return true;
    }
  }
}
