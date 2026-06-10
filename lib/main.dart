import 'dart:async';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'favorite_song_store.dart';
import 'free_music_api.dart';
import 'music_audio_handler.dart';
import 'models/app_update_info.dart';
import 'models/cached_track.dart';
import 'models/demo_track.dart';
import 'models/playback_ui_state.dart';
import 'native_audio_controller.dart';
import 'services/app_installer_service.dart';
import 'services/download_service.dart';
import 'services/carlife_service.dart';
import 'services/update_check_service.dart';
import 'theme/design_tokens.dart';
import 'features/home/portrait_home_view.dart';
import 'features/home/playlist_details_page.dart';
import 'features/search/portrait_search_view.dart';
import 'features/library/portrait_library_view.dart';
import 'features/player/portrait_player_view.dart';
import 'features/settings/portrait_settings_view.dart';
import 'features/settings/cache_manager_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await WakelockPlus.enable();

  final MusicAudioHandler audioHandler = await initMusicAudioHandler();

  await _ensureNotificationPermission();

  runApp(MusicCarApp(audioHandler: audioHandler));
}

/// Android 13+ (API 33) gates the media-playback notification behind the
/// runtime [Permission.notification]. Without it the foreground media
/// notification renders without transport controls, so background play has no
/// pause / skip buttons. audio_service neither declares nor requests this
/// permission, so the app must do it. No-op on platforms that grant it
/// implicitly.
Future<void> _ensureNotificationPermission() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  final PermissionStatus status = await Permission.notification.status;
  if (status.isDenied) {
    await Permission.notification.request();
  }
}

class MusicCarApp extends StatefulWidget {
  const MusicCarApp({
    super.key,
    this.homeOverride,
    this.audioHandler,
    this.autoCheckForUpdates = true,
  });

  final Widget? homeOverride;
  final MusicAudioHandler? audioHandler;
  final bool autoCheckForUpdates;

  @override
  State<MusicCarApp> createState() => _MusicCarAppState();
}

class _MusicCarAppState extends State<MusicCarApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? modeString = prefs.getString('theme_mode');
      if (modeString != null) {
        final ThemeMode mode = ThemeMode.values.firstWhere(
          (ThemeMode e) => e.name == modeString,
          orElse: () => ThemeMode.system,
        );
        if (mounted) {
          setState(() {
            _themeMode = mode;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', mode.name);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData lightTheme = _buildAppTheme(
      brightness: Brightness.light,
      seedColor: AppColor.accentVioletStart,
    );
    final ThemeData darkTheme = _buildAppTheme(
      brightness: Brightness.dark,
      seedColor: AppColor.accentVioletStart,
    );
    return MaterialApp(
      title: '车载音乐',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home:
          widget.homeOverride ??
          NativeMusicHomePage(
            audioHandler: widget.audioHandler,
            autoCheckForUpdates: widget.autoCheckForUpdates,
            themeMode: _themeMode,
            onThemeModeChanged: _setThemeMode,
          ),
    );
  }
}

ThemeData _buildAppTheme({
  required Brightness brightness,
  required Color seedColor,
}) {
  final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  return ThemeData(
    fontFamily: 'sans',
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    splashFactory: NoSplash.splashFactory,
    useMaterial3: true,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      },
    ),
  );
}

class NativeMusicHomePage extends StatefulWidget {
  const NativeMusicHomePage({
    super.key,
    this.audioHandler,
    this.autoCheckForUpdates = true,
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
  });

  final MusicAudioHandler? audioHandler;
  final bool autoCheckForUpdates;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<NativeMusicHomePage> createState() => _NativeMusicHomePageState();
}

class _NativeMusicHomePageState extends State<NativeMusicHomePage>
    with WidgetsBindingObserver {
  late final NativeAudioController _nativeAudioController;
  late final DownloadService _downloadService;
  final FavoriteSongStore _favoriteSongStore = FavoriteSongStore();
  final FreeMusicApi _freeMusicApi = FreeMusicApi();
  final TextEditingController _searchController = TextEditingController();
  final UpdateCheckService _updateCheckService = UpdateCheckService();
  final AppInstallerService _appInstallerService = const AppInstallerService();
  final CarLifeService _carLifeService = const CarLifeService();
  CarLifeStatus _carLifeStatus = const CarLifeStatus(
    available: false,
    installed: false,
    launchable: false,
    sdkLinked: false,
    reason: 'unchecked',
  );
  bool _isCheckingUpdate = false;
  bool _isInstallingUpdate = false;
  bool _isCheckingCarLife = false;
  bool _isSyncingCarLife = false;
  bool _hasAutoCheckedUpdate = false;
  bool _isSearchingMusic = false;
  bool _isLoadingMoreSearchResults = false;
  bool _isLoadingRecommendations = false;
  bool _isLoadingLyrics = false;
  bool _isLoadingApiBootstrap = false;
  bool _isLoadingQualities = false;
  bool _isLoadingFavorites = false;
  bool _syncingSessionPlaybackMode = false;
  int _searchRequestId = 0;
  String _searchError = '';
  String _searchLoadMoreError = '';
  String _recommendationError = '';
  String _lyricsError = '';
  String _apiBootstrapError = '';
  String _qualityError = '';
  String _lastSearchQuery = '';
  FreeMusicSources? _musicSources;
  FreeMusicLyrics? _currentLyrics;
  List<String> _hotSearchKeywords = const <String>[];
  List<FreeMusicQuality> _currentQualities = const <FreeMusicQuality>[];
  FreeMusicSong? _currentSong;
  int _searchPage = 0;
  bool _searchHasMore = false;
  List<FreeMusicSong> _searchResults = const <FreeMusicSong>[];
  List<FreeMusicPlaylist> _recommendedPlaylists = const <FreeMusicPlaylist>[];
  List<FreeMusicSong> _playbackQueue = const <FreeMusicSong>[];
  List<FreeMusicSong> _favoriteSongs = const <FreeMusicSong>[];
  NativePlaybackMode _playbackMode = NativePlaybackMode.repeatAll;
  int _selectedTab = 0;
  int _selectedQueueIndex = 0;
  Color _coverSeedColor = AppColor.accentVioletStart;
  String _coverSeedUrl = '';

  @override
  void initState() {
    super.initState();
    _downloadService = DownloadService(_freeMusicApi);
    unawaited(_downloadService.init());
    _nativeAudioController = NativeAudioController(
      player: widget.audioHandler,
      api: _freeMusicApi,
      downloadService: _downloadService,
    );
    widget.audioHandler?.onPlayTrack = _resumeNativePlayback;
    widget.audioHandler?.onSkipToNextTrack = _skipToNextTrack;
    widget.audioHandler?.onSkipToPreviousTrack = _skipToPreviousTrack;
    widget.audioHandler?.onSkipToQueueItem = _skipToQueueItem;
    widget.audioHandler?.onSetRepeatMode = _setRepeatModeFromSession;
    widget.audioHandler?.onSetShuffleMode = _setShuffleModeFromSession;
    _carLifeService.setControlHandler(_handleCarLifeControl);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadStartupMusicContent());
      unawaited(_refreshCarLifeStatus());
      if (widget.autoCheckForUpdates) {
        unawaited(_autoCheckForUpdate());
      }
    });
  }

  List<String>? get _activeSourceIds {
    final List<String> sources =
        _musicSources?.activeSources ?? const <String>[];
    return sources.isEmpty ? null : sources;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.audioHandler?.onSkipToNextTrack == _skipToNextTrack) {
      widget.audioHandler?.onSkipToNextTrack = null;
    }
    if (widget.audioHandler?.onSkipToPreviousTrack == _skipToPreviousTrack) {
      widget.audioHandler?.onSkipToPreviousTrack = null;
    }
    if (widget.audioHandler?.onPlayTrack == _resumeNativePlayback) {
      widget.audioHandler?.onPlayTrack = null;
    }
    if (widget.audioHandler?.onSkipToQueueItem == _skipToQueueItem) {
      widget.audioHandler?.onSkipToQueueItem = null;
    }
    if (widget.audioHandler?.onSetRepeatMode == _setRepeatModeFromSession) {
      widget.audioHandler?.onSetRepeatMode = null;
    }
    if (widget.audioHandler?.onSetShuffleMode == _setShuffleModeFromSession) {
      widget.audioHandler?.onSetShuffleMode = null;
    }
    _carLifeService.setControlHandler(null);
    unawaited(WakelockPlus.disable());
    unawaited(_nativeAudioController.dispose());
    _freeMusicApi.close();
    _searchController.dispose();
    _updateCheckService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(WakelockPlus.enable());
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
  }

  Future<bool> _resumeNativePlayback() {
    return _nativeAudioController.resumePlayback();
  }

  Future<bool> _skipToNextTrack() async {
    final bool handled = await _nativeAudioController.skipToNext();
    if (!mounted || !handled) {
      return handled;
    }
    _syncSelectedQueueIndexFromAudioController();
    return true;
  }

  Future<bool> _skipToPreviousTrack() async {
    final bool handled = await _nativeAudioController.skipToPrevious();
    if (!mounted || !handled) {
      return handled;
    }
    _syncSelectedQueueIndexFromAudioController();
    return true;
  }

  void _syncSelectedQueueIndexFromAudioController() {
    final int index = _nativeAudioController.currentIndex;
    if (index < 0 || index >= _playbackQueue.length) {
      return;
    }
    final FreeMusicSong song = _playbackQueue[index];
    setState(() {
      _selectedQueueIndex = index;
      _currentSong = song;
    });
    unawaited(_loadLyricsForSong(song));
    unawaited(_loadQualitiesForSong(song));
    unawaited(_syncCarLifePlaybackContext(showResult: false));
  }

  Future<void> _loadApiBootstrap() async {
    if (_isLoadingApiBootstrap || !mounted) {
      return;
    }
    setState(() {
      _isLoadingApiBootstrap = true;
      _apiBootstrapError = '';
    });
    try {
      final (FreeMusicSources sources, List<String> hotKeywords) = await (
        _freeMusicApi.fetchSources(),
        _freeMusicApi.fetchHotSearchKeywords(),
      ).wait;
      if (!mounted) {
        return;
      }
      setState(() {
        _musicSources = sources;
        _hotSearchKeywords = List<String>.unmodifiable(hotKeywords.take(8));
        _isLoadingApiBootstrap = false;
      });
    } on FreeMusicApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _apiBootstrapError = error.message;
        _isLoadingApiBootstrap = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _apiBootstrapError = 'API 初始化失败：$error';
        _isLoadingApiBootstrap = false;
      });
    }
  }

  Future<void> _loadStartupMusicContent() async {
    unawaited(_restorePlaybackSession());
    unawaited(_loadFavoriteSongs());
    await _loadApiBootstrap();
    if (!mounted) {
      return;
    }
    await _loadRecommendations();
  }

  Future<void> _loadFavoriteSongs() async {
    setState(() {
      _isLoadingFavorites = true;
    });
    try {
      final List<FreeMusicSong> songs = await _favoriteSongStore.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _favoriteSongs = List<FreeMusicSong>.unmodifiable(songs);
        _isLoadingFavorites = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingFavorites = false;
      });
      _showSnack('收藏列表加载失败：$error');
    }
  }

  Set<String> get _favoriteSongKeys {
    return _favoriteSongs.map(favoriteSongKey).toSet();
  }

  Future<void> _toggleFavoriteSong(FreeMusicSong song) async {
    if (!song.canResolve) {
      _showSnack('这首歌暂时不能收藏');
      return;
    }
    final String key = favoriteSongKey(song);
    final bool removing = _favoriteSongKeys.contains(key);
    final List<FreeMusicSong> nextSongs = removing
        ? _favoriteSongs
              .where((FreeMusicSong item) => favoriteSongKey(item) != key)
              .toList(growable: false)
        : <FreeMusicSong>[song, ..._favoriteSongs];
    setState(() {
      _favoriteSongs = List<FreeMusicSong>.unmodifiable(nextSongs);
    });
    try {
      await _favoriteSongStore.save(nextSongs);
      if (!mounted) {
        return;
      }
      _showSnack(removing ? '已取消收藏：${song.name}' : '已收藏：${song.name}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _loadFavoriteSongs();
      _showSnack('收藏保存失败：$error');
    }
  }

  Future<void> _playFavoriteSong(int index) async {
    if (index < 0 || index >= _favoriteSongs.length) {
      return;
    }
    await _playSongQueue(_favoriteSongs, index);
  }

  Future<void> _playAllFavorites() async {
    if (_favoriteSongs.isEmpty) {
      _showSnack('收藏列表为空');
      return;
    }
    await _playSongQueue(_favoriteSongs, 0);
  }

  Future<void> _updateCoverSeed(FreeMusicSong song) async {
    final String cover = song.cover.trim();
    if (cover.isEmpty || cover == _coverSeedUrl) {
      return;
    }
    _coverSeedUrl = cover;
    try {
      final Color color = await _extractCoverSeedColor(cover);
      if (!mounted) {
        return;
      }
      setState(() {
        _coverSeedColor = color;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _coverSeedColor = AppColor.accentVioletStart;
      });
    }
  }

  Future<Color> _extractCoverSeedColor(String imageUrl) async {
    try {
      final ImageProvider provider = CachedNetworkImageProvider(imageUrl);
      final ImageStream stream = provider.resolve(ImageConfiguration.empty);
      final Completer<ui.Image> completer = Completer<ui.Image>();
      ImageStreamListener? listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          completer.complete(info.image);
          if (listener != null) {
            stream.removeListener(listener);
          }
        },
        onError: (Object exception, StackTrace? stackTrace) {
          completer.completeError(exception);
          if (listener != null) {
            stream.removeListener(listener);
          }
        },
      );
      stream.addListener(listener);

      final ui.Image image = await completer.future.timeout(
        const Duration(milliseconds: 3500),
      );

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        const Rect.fromLTWH(0, 0, 1, 1),
        Paint()..filterQuality = FilterQuality.medium,
      );
      final ui.Picture picture = recorder.endRecording();
      final ui.Image smallImage = await picture.toImage(1, 1);
      final ByteData? byteData = await smallImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData == null || byteData.lengthInBytes < 4) {
        return AppColor.accentVioletStart;
      }

      final int r = byteData.getUint8(0);
      final int g = byteData.getUint8(1);
      final int b = byteData.getUint8(2);

      final HSLColor hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));
      final double s = hsl.saturation.clamp(0.24, 0.48);
      final double l = hsl.lightness.clamp(0.32, 0.62);
      return hsl.withSaturation(s).withLightness(l).toColor();
    } catch (_) {
      return AppColor.accentVioletStart;
    }
  }

  /// Restores the previous playback session (queue + current song) from
  /// [NativeAudioController]'s persisted state, then attempts to resume
  /// playback automatically so the user hears the same song they left off on.
  Future<void> _restorePlaybackSession() async {
    await _nativeAudioController.waitForRestore();
    if (!mounted) {
      return;
    }
    final List<FreeMusicSong> restored = _nativeAudioController.playlist;
    final int restoredIndex = _nativeAudioController.currentIndex;
    if (restored.isEmpty ||
        restoredIndex < 0 ||
        restoredIndex >= restored.length) {
      return;
    }
    final FreeMusicSong song = restored[restoredIndex];
    setState(() {
      _playbackQueue = List<FreeMusicSong>.unmodifiable(restored);
      _selectedQueueIndex = restoredIndex;
      _currentSong = song;
    });
    unawaited(_updateCoverSeed(song));
    unawaited(_loadLyricsForSong(song));
    unawaited(_loadQualitiesForSong(song));
    // Resume playback — NativeAudioController will re-resolve the audio URL
    // if needed, so this is safe to fire-and-forget.
    unawaited(_nativeAudioController.resumePlayback());
  }

  Future<void> _searchSongs() async {
    final String query = _searchController.text.trim();
    final int requestId = ++_searchRequestId;
    if (query.isEmpty) {
      setState(() {
        _lastSearchQuery = '';
        _searchError = '';
        _searchLoadMoreError = '';
        _searchResults = const <FreeMusicSong>[];
        _searchPage = 0;
        _searchHasMore = false;
        _isSearchingMusic = false;
        _isLoadingMoreSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearchingMusic = true;
      _isLoadingMoreSearchResults = false;
      _searchError = '';
      _searchLoadMoreError = '';
      _lastSearchQuery = query;
      _searchPage = 0;
      _searchHasMore = false;
    });

    try {
      final FreeMusicSearchResult result = await _freeMusicApi.searchSongs(
        query,
        page: 0,
        sources: _activeSourceIds,
      );
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      setState(() {
        _searchResults = List<FreeMusicSong>.unmodifiable(result.songs);
        _searchPage = result.page;
        _searchHasMore = result.hasMore;
        _isSearchingMusic = false;
      });
    } on FreeMusicApiException catch (error) {
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      setState(() {
        _searchError = error.message;
        _isSearchingMusic = false;
      });
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      setState(() {
        _searchError = '搜索失败：$error';
        _isSearchingMusic = false;
      });
    }
  }

  Future<void> _loadMoreSearchResults() async {
    final String query = _lastSearchQuery.trim();
    if (query.isEmpty || !_searchHasMore || _isLoadingMoreSearchResults) {
      return;
    }
    final int requestId = _searchRequestId;
    setState(() {
      _isLoadingMoreSearchResults = true;
      _searchLoadMoreError = '';
    });

    try {
      final FreeMusicSearchResult result = await _freeMusicApi.searchSongs(
        query,
        page: _searchPage + 1,
        sources: _activeSourceIds,
      );
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      setState(() {
        _searchResults = List<FreeMusicSong>.unmodifiable(<FreeMusicSong>[
          ..._searchResults,
          ...result.songs,
        ]);
        _searchPage = result.page;
        _searchHasMore = result.hasMore;
        _isLoadingMoreSearchResults = false;
      });
    } on FreeMusicApiException catch (error) {
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      setState(() {
        _searchLoadMoreError = error.message;
        _isLoadingMoreSearchResults = false;
      });
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      setState(() {
        _searchLoadMoreError = '加载更多失败：$error';
        _isLoadingMoreSearchResults = false;
      });
    }
  }

  Future<void> _loadRecommendations() async {
    if (_isLoadingRecommendations || !mounted) {
      return;
    }
    setState(() {
      _isLoadingRecommendations = true;
      _recommendationError = '';
    });
    try {
      final FreeMusicRecommendResult result = await _freeMusicApi
          .fetchRecommendations(sources: const <String>['netease']);
      if (!mounted) {
        return;
      }
      setState(() {
        _recommendedPlaylists = result.playlists;
        _isLoadingRecommendations = false;
      });
    } on FreeMusicApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _recommendationError = error.message;
        _isLoadingRecommendations = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _recommendationError = '推荐加载失败：$error';
        _isLoadingRecommendations = false;
      });
    }
  }

  Set<String> get _downloadedSongKeys {
    return _downloadService.getAllCachedTracks()
        .map<String>((CachedTrack t) => '${t.source}_${t.id}')
        .toSet();
  }

  List<FreeMusicSong> get _downloadedSongs {
    return _downloadService.getAllCachedTracks().map<FreeMusicSong>((CachedTrack track) {
      return FreeMusicSong(
        id: track.id,
        source: track.source,
        name: track.title,
        artist: track.artist,
        cover: track.cover,
        duration: track.duration,
      );
    }).toList();
  }

  Future<void> _downloadSong(FreeMusicSong song) async {
    try {
      _showSnack('正在解析 "${song.name}" 的品质...');
      List<FreeMusicQuality> qualities = const <FreeMusicQuality>[];
      try {
        final FreeMusicQualityResult res =
            await _freeMusicApi.fetchQualities(song);
        qualities = res.qualities;
      } catch (_) {}
      final FreeMusicQuality targetQuality = qualities.isNotEmpty
          ? qualities.first
          : const FreeMusicQuality(name: '标准', bitrate: '128k');

      _showSnack('开始下载: ${song.name}');
      final Stream<double> progressStream =
          _downloadService.downloadTrack(song, targetQuality);

      progressStream.listen(
        (double progress) {
          if (progress >= 1.0) {
            _showSnack('下载成功: ${song.name}');
            if (mounted) {
              setState(() {});
            }
          }
        },
        onError: (Object error) {
          _showSnack('下载失败: $error');
        },
      );
    } catch (e) {
      _showSnack('下载失败: $e');
    }
  }

  Future<void> _deleteSongCache(FreeMusicSong song) async {
    try {
      await _downloadService.deleteTrack(song.source, song.id);
      _showSnack('已删除本地缓存: ${song.name}');
      setState(() {});
    } catch (e) {
      _showSnack('删除失败: $e');
    }
  }

  Future<void> _playDownloadedSong(int index) async {
    final List<FreeMusicSong> list = _downloadedSongs;
    if (index >= 0 && index < list.length) {
      await _playSongQueue(list, index);
    }
  }

  Future<void> _playAllDownloadedSongs() async {
    final List<FreeMusicSong> list = _downloadedSongs;
    if (list.isNotEmpty) {
      await _playSongQueue(list, 0);
    }
  }

  void _openPlaylistDetails(FreeMusicPlaylist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PlaylistDetailsPage(
          playlist: playlist,
          api: _freeMusicApi,
          favoriteSongKeys: _favoriteSongKeys,
          downloadedSongKeys: _downloadedSongKeys,
          onPlay: (List<FreeMusicSong> songs, int index) {
            unawaited(_playSongQueue(songs, index));
          },
          onToggleFavorite: (FreeMusicSong song) {
            unawaited(_toggleFavoriteSong(song));
          },
          onDownload: _downloadSong,
          onDeleteCache: _deleteSongCache,
        ),
      ),
    );
  }

  Future<void> _playSearchResult(int index) async {
    if (index < 0 || index >= _searchResults.length) {
      return;
    }
    await _playSongQueue(_searchResults, index);
  }

  /// Appends [_searchResults[index]] to the end of the playback queue without
  /// changing the currently playing track.
  Future<void> _addSearchResultToQueue(int index) async {
    if (index < 0 || index >= _searchResults.length) {
      return;
    }
    final FreeMusicSong song = _searchResults[index];
    // Avoid duplicates: skip if the exact same song is already the last item.
    if (_playbackQueue.isNotEmpty &&
        _playbackQueue.last.id == song.id &&
        _playbackQueue.last.source == song.source) {
      _showSnack('该歌曲已在队列末尾');
      return;
    }
    final List<FreeMusicSong> newQueue = <FreeMusicSong>[
      ..._playbackQueue,
      song,
    ];
    final int currentIdx =
        _selectedQueueIndex >= 0 && _selectedQueueIndex < _playbackQueue.length
        ? _selectedQueueIndex
        : 0;
    await _nativeAudioController.syncQueueFromProbe(
      PlayerProbeSnapshot(
        audioUrl: '',
        playing: false,
        song: _currentSong,
        playlist: newQueue,
        currentIndex: currentIdx,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _playbackQueue = List<FreeMusicSong>.unmodifiable(newQueue);
    });
    _showSnack('已加入播放队列：${song.name}');
  }

  Future<void> _playSongQueue(List<FreeMusicSong> songs, int index) async {
    if (index < 0 || index >= songs.length) {
      return;
    }
    final FreeMusicSong song = songs[index];
    final bool handled = await _nativeAudioController.syncFromProbe(
      PlayerProbeSnapshot(
        audioUrl: '',
        playing: true,
        song: song,
        playlist: songs,
        currentIndex: index,
        title: song.name,
        artist: song.artist,
        coverUrl: song.cover,
        duration: Duration(seconds: song.duration),
      ),
    );
    if (!mounted) {
      return;
    }
    if (!handled) {
      _showSnack('暂时无法播放：${song.name}');
      return;
    }
    setState(() {
      _playbackQueue = List<FreeMusicSong>.unmodifiable(songs);
      _selectedQueueIndex = index;
      _currentSong = song;
    });
    unawaited(_updateCoverSeed(song));
    unawaited(_loadLyricsForSong(song));
    unawaited(_loadQualitiesForSong(song));
    unawaited(_syncCarLifePlaybackContext(showResult: false));
  }

  Future<void> _skipToQueueItem(int index) async {
    final bool handled = await _nativeAudioController.skipToQueueIndex(index);
    if (!mounted || !handled) {
      return;
    }
    setState(() {
      _selectedQueueIndex = index;
      if (index >= 0 && index < _playbackQueue.length) {
        _currentSong = _playbackQueue[index];
      }
    });
    if (index >= 0 && index < _playbackQueue.length) {
      unawaited(_updateCoverSeed(_playbackQueue[index]));
      unawaited(_loadLyricsForSong(_playbackQueue[index]));
      unawaited(_loadQualitiesForSong(_playbackQueue[index]));
    }
    unawaited(_syncCarLifePlaybackContext(showResult: false));
  }

  Future<CarLifeControlResult> _handleCarLifeControl(
    CarLifeControlCommand command,
  ) async {
    switch (command.action) {
      case CarLifeControlAction.play:
        final bool handled = await _nativeAudioController.resumePlayback();
        if (mounted && handled) {
          _syncSelectedQueueIndexFromAudioController();
        }
        return CarLifeControlResult(
          handled: handled,
          reason: handled ? 'played' : 'play_failed',
          queueIndex: _nativeAudioController.currentIndex,
        );
      case CarLifeControlAction.pause:
        final bool handled = await _nativeAudioController.pausePlayback();
        return CarLifeControlResult(
          handled: handled,
          reason: handled ? 'paused' : 'pause_failed',
          queueIndex: _nativeAudioController.currentIndex,
        );
      case CarLifeControlAction.next:
        final bool handled = await _skipToNextTrack();
        return CarLifeControlResult(
          handled: handled,
          reason: handled ? 'next' : 'next_unavailable',
          queueIndex: _nativeAudioController.currentIndex,
        );
      case CarLifeControlAction.previous:
        final bool handled = await _skipToPreviousTrack();
        return CarLifeControlResult(
          handled: handled,
          reason: handled ? 'previous' : 'previous_unavailable',
          queueIndex: _nativeAudioController.currentIndex,
        );
      case CarLifeControlAction.selectQueueItem:
        final int index = _queueIndexForCarLifeCommand(command);
        if (index < 0) {
          return const CarLifeControlResult(
            handled: false,
            reason: 'queue_item_not_found',
          );
        }
        await _skipToQueueItem(index);
        final bool handled = _nativeAudioController.currentIndex == index;
        return CarLifeControlResult(
          handled: handled,
          reason: handled ? 'queue_item_selected' : 'queue_item_failed',
          queueIndex: _nativeAudioController.currentIndex,
        );
      case CarLifeControlAction.unknown:
        return const CarLifeControlResult(
          handled: false,
          reason: 'unknown_action',
        );
    }
  }

  int _queueIndexForCarLifeCommand(CarLifeControlCommand command) {
    if (command.queueIndex >= 0 && command.queueIndex < _playbackQueue.length) {
      return command.queueIndex;
    }
    if (command.source.isEmpty || command.songId.isEmpty) {
      return -1;
    }
    return _playbackQueue.indexWhere(
      (FreeMusicSong song) =>
          song.source == command.source && song.id == command.songId,
    );
  }

  Future<void> _loadLyricsForSong(FreeMusicSong song) async {
    if (!song.canResolve) {
      widget.audioHandler?.updateLyrics(const []);
      return;
    }
    widget.audioHandler?.updateLyrics(const []);
    setState(() {
      _isLoadingLyrics = true;
      _lyricsError = '';
      _currentLyrics = null;
    });
    try {
      final FreeMusicLyrics lyrics = await _freeMusicApi.fetchEnhancedLyrics(
        song,
      );
      if (!mounted ||
          _currentSong?.id != song.id ||
          _currentSong?.source != song.source) {
        return;
      }
      setState(() {
        _currentLyrics = lyrics;
        _isLoadingLyrics = false;
      });
      widget.audioHandler?.updateLyrics(lyrics.lines);
    } on FreeMusicApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lyricsError = error.message;
        _isLoadingLyrics = false;
      });
      widget.audioHandler?.updateLyrics(const []);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lyricsError = '歌词加载失败：$error';
        _isLoadingLyrics = false;
      });
      widget.audioHandler?.updateLyrics(const []);
    }
  }

  Future<void> _loadQualitiesForSong(FreeMusicSong song) async {
    if (!song.canResolve) {
      return;
    }
    setState(() {
      _isLoadingQualities = true;
      _qualityError = '';
      _currentQualities = const <FreeMusicQuality>[];
    });
    try {
      final FreeMusicQualityResult result = await _freeMusicApi.fetchQualities(
        song,
      );
      if (!mounted ||
          _currentSong?.id != song.id ||
          _currentSong?.source != song.source) {
        return;
      }
      setState(() {
        _currentQualities = List<FreeMusicQuality>.unmodifiable(
          result.qualities.take(4),
        );
        _isLoadingQualities = false;
      });
    } on FreeMusicApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _qualityError = error.message;
        _isLoadingQualities = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _qualityError = '音质加载失败：$error';
        _isLoadingQualities = false;
      });
    }
  }

  void _showQualitySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        final ColorScheme colors = theme.colorScheme;
        final List<FreeMusicQuality> qualities = _currentQualities;
        final bool busy = _isLoadingQualities;
        final String error = _qualityError;

        Widget content;
        if (busy) {
          content = const Padding(
            padding: EdgeInsets.all(AppSpace.xl3),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (error.isNotEmpty) {
          content = Padding(
            padding: const EdgeInsets.all(AppSpace.xl3),
            child: Center(
              child: Text(error, style: theme.textTheme.bodyMedium),
            ),
          );
        } else if (qualities.isEmpty) {
          content = Padding(
            padding: const EdgeInsets.all(AppSpace.xl3),
            child: Center(
              child: Text(
                '暂无可用音质',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          );
        } else {
          content = ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.xl,
              vertical: AppSpace.md,
            ),
            itemCount: qualities.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.xs),
            itemBuilder: (BuildContext context, int index) {
              final FreeMusicQuality q = qualities[index];
              final String label =
                  q.name.isNotEmpty ? q.name : q.bitrate;
              final String subtitle = <String>[
                if (q.format.isNotEmpty) q.format,
                if (q.size.isNotEmpty) q.size,
                if (q.bitrate.isNotEmpty && q.name.isNotEmpty) q.bitrate,
              ].join(' · ');
              final bool isFirst = index == 0;
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                tileColor: isFirst
                    ? colors.primaryContainer.withValues(alpha: 0.25)
                    : null,
                leading: Icon(
                  isFirst
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isFirst ? colors.primary : colors.onSurfaceVariant,
                ),
                title: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: isFirst ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
                subtitle: subtitle.isNotEmpty
                    ? Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      )
                    : null,
                onTap: () => Navigator.pop(context),
              );
            },
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.panel),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: AppSpace.md),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl,
                  AppSpace.lg,
                  AppSpace.xl,
                  AppSpace.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.equalizer_rounded, color: colors.primary),
                    const SizedBox(width: AppSpace.sm),
                    Text(
                      '音质选择',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              content,
              const SizedBox(height: AppSpace.lg),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cyclePlaybackMode() async {
    final NativePlaybackMode mode = await _nativeAudioController
        .cyclePlaybackMode();
    if (!mounted) {
      return;
    }
    await _syncAudioSessionPlaybackMode(mode);
    setState(() {
      _playbackMode = mode;
    });
  }

  Future<void> _setRepeatModeFromSession(
    AudioServiceRepeatMode repeatMode,
  ) async {
    if (_syncingSessionPlaybackMode) {
      return;
    }
    final NativePlaybackMode mode;
    switch (repeatMode) {
      case AudioServiceRepeatMode.one:
        mode = NativePlaybackMode.repeatOne;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        mode = NativePlaybackMode.repeatAll;
      case AudioServiceRepeatMode.none:
        mode = _playbackMode == NativePlaybackMode.shuffle
            ? NativePlaybackMode.shuffle
            : NativePlaybackMode.sequential;
    }
    await _applyPlaybackMode(mode, syncSession: false);
  }

  Future<void> _setShuffleModeFromSession(
    AudioServiceShuffleMode shuffleMode,
  ) async {
    if (_syncingSessionPlaybackMode) {
      return;
    }
    final NativePlaybackMode mode = shuffleMode == AudioServiceShuffleMode.none
        ? NativePlaybackMode.sequential
        : NativePlaybackMode.shuffle;
    await _applyPlaybackMode(mode, syncSession: false);
  }

  Future<void> _applyPlaybackMode(
    NativePlaybackMode mode, {
    required bool syncSession,
  }) async {
    await _nativeAudioController.setPlaybackMode(mode);
    if (!mounted) {
      return;
    }
    if (syncSession) {
      await _syncAudioSessionPlaybackMode(mode);
    }
    setState(() {
      _playbackMode = mode;
    });
  }

  Future<void> _syncAudioSessionPlaybackMode(NativePlaybackMode mode) async {
    final MusicAudioHandler? handler = widget.audioHandler;
    if (handler == null) {
      return;
    }
    _syncingSessionPlaybackMode = true;
    try {
      await handler.setRepeatMode(_repeatModeForNativeMode(mode));
      await handler.setShuffleMode(_shuffleModeForNativeMode(mode));
    } finally {
      _syncingSessionPlaybackMode = false;
    }
  }

  Future<void> _togglePlayback(bool playing) async {
    final MusicAudioHandler? handler = widget.audioHandler;
    if (handler == null) {
      return;
    }
    if (playing) {
      await handler.pause();
    } else {
      await handler.play();
    }
  }

  Future<void> _seekPlayback(Duration position) async {
    await widget.audioHandler?.seek(position);
  }

  Future<void> _refreshCarLifeStatus() async {
    if (_isCheckingCarLife || !mounted) {
      return;
    }
    setState(() {
      _isCheckingCarLife = true;
    });
    final CarLifeStatus status = await _carLifeService.getStatus();
    if (!mounted) {
      return;
    }
    setState(() {
      _carLifeStatus = status;
      _isCheckingCarLife = false;
    });
  }

  Future<void> _openCarLife() async {
    await _syncCarLifePlaybackContext(showResult: false);
    final CarLifeLaunchResult result = await _carLifeService.openCarLife();
    if (!mounted) {
      return;
    }
    await _refreshCarLifeStatus();
    if (result.launched) {
      _showSnack(
        result.reason == 'market_opened' || result.reason == 'web_opened'
            ? '未检测到 CarLife，已打开安装入口。'
            : '已尝试打开百度 CarLife。',
      );
    } else {
      _showSnack('未能打开百度 CarLife：${result.reason}');
    }
  }

  Future<void> _syncCarLifePlaybackContext({required bool showResult}) async {
    if (_isSyncingCarLife || !mounted) {
      return;
    }
    final CarLifePlaybackContext? context = _buildCarLifePlaybackContext();
    if (context == null) {
      if (showResult) {
        _showSnack('请先播放一首歌，再同步到 CarLife。');
      }
      return;
    }
    setState(() {
      _isSyncingCarLife = true;
    });
    final CarLifeSyncResult result = await _carLifeService.syncPlaybackContext(
      title: context.title,
      artist: context.artist,
      playing: context.playing,
      context: context,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isSyncingCarLife = false;
    });
    if (!showResult) {
      return;
    }
    if (result.reason == 'sdk_connected') {
      _showSnack('已同步到 CarLife：${result.syncedTitle}');
    } else if (result.reason == 'sdk_initialized') {
      _showSnack('已提交 CarLife 队列模板，等待 CarLife 连接读取。');
    } else if (result.reason == 'app_key_missing') {
      _showSnack('CarLife SDK 已接入，请先配置 AppKey。');
    } else if (result.reason == 'sdk_missing') {
      _showSnack('已缓存播放上下文，等待 CarLife SDK 接管同步。');
    } else {
      _showSnack('CarLife 同步不可用：${result.reason}');
    }
  }

  CarLifePlaybackContext? _buildCarLifePlaybackContext() {
    final FreeMusicSong? song = _currentSong;
    if (song == null) {
      return null;
    }
    final MusicAudioHandler? handler = widget.audioHandler;
    final MediaItem? mediaItem = handler?.mediaItem.valueOrNull;
    final PlaybackUiState playbackState = handler == null
        ? const PlaybackUiState()
        : PlaybackUiState.fromAudioService(
            handler.playbackState.valueOrNull,
            mediaItem,
          );
    final int queueIndex =
        _selectedQueueIndex >= 0 && _selectedQueueIndex < _playbackQueue.length
        ? _selectedQueueIndex
        : _playbackQueue.indexWhere(
            (FreeMusicSong item) =>
                item.id == song.id && item.source == song.source,
          );
    return CarLifePlaybackContext(
      title: song.name,
      artist: song.artist,
      album: song.album,
      coverUrl: song.cover,
      audioUrl: _carLifeAudioUrlFromMediaItem(mediaItem),
      source: song.source,
      songId: song.id,
      playing: playbackState.playing,
      duration: song.duration > 0
          ? Duration(seconds: song.duration)
          : (playbackState.duration ?? Duration.zero),
      position: playbackState.position,
      queue: _playbackQueue,
      queueIndex: queueIndex,
    );
  }

  String _carLifeAudioUrlFromMediaItem(MediaItem? mediaItem) {
    final Object? extraAudioUrl = mediaItem?.extras?['audioUrl'];
    final String audioUrl = extraAudioUrl is String ? extraAudioUrl.trim() : '';
    if (_isHttpAudioUrl(audioUrl)) {
      return audioUrl;
    }
    final String mediaId = mediaItem?.id.trim() ?? '';
    return _isHttpAudioUrl(mediaId) ? mediaId : '';
  }

  bool _isHttpAudioUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Future<void> _autoCheckForUpdate() async {
    if (_hasAutoCheckedUpdate || !mounted) {
      return;
    }
    _hasAutoCheckedUpdate = true;
    await _checkForUpdate(silentNoUpdate: true, silentErrors: true);
  }

  Future<void> _checkForUpdate({
    bool silentNoUpdate = false,
    bool silentErrors = false,
  }) async {
    if (_isCheckingUpdate) {
      return;
    }
    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final AppUpdateInfo updateInfo = await _updateCheckService
          .checkLatestRelease();
      if (!mounted) {
        return;
      }
      if (silentNoUpdate && !updateInfo.hasUpdate) {
        return;
      }
      await _showUpdateDialog(updateInfo);
    } on UpdateCheckException catch (error) {
      if (!silentErrors && mounted) {
        _showSnack(error.message);
      }
    } catch (error) {
      if (!silentErrors && mounted) {
        _showSnack('检查更新失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  Future<void> _showUpdateDialog(AppUpdateInfo updateInfo) async {
    final String assetText = updateInfo.apkAssets.isEmpty
        ? '未找到 Android APK 下载资源'
        : updateInfo.apkAssets
              .map((AppReleaseAsset asset) {
                final String size = asset.sizeText.isEmpty
                    ? ''
                    : ' (${asset.sizeText})';
                final String abi = asset.abi.isEmpty ? '' : ' ${asset.abi}';
                return '${asset.name}$abi$size';
              })
              .join('\n');

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(updateInfo.hasUpdate ? '发现新版本' : '已是最新版本'),
          content: SingleChildScrollView(
            child: Text(
              <String>[
                '当前版本：${updateInfo.currentVersion}',
                '最新版本：${updateInfo.latestVersion}',
                if (updateInfo.releaseName.isNotEmpty)
                  '发布名称：${updateInfo.releaseName}',
                if (updateInfo.publishedAt != null)
                  '发布时间：${updateInfo.publishedAt!.toLocal()}',
                '',
                assetText,
              ].join('\n'),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
            if (updateInfo.hasUpdate && updateInfo.hasDownloadAssets)
              FilledButton(
                onPressed: _isInstallingUpdate
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        unawaited(_installUpdate(updateInfo));
                      },
                child: const Text('立即更新'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _installUpdate(AppUpdateInfo updateInfo) async {
    if (_isInstallingUpdate) {
      return;
    }
    setState(() {
      _isInstallingUpdate = true;
    });

    try {
      await _appInstallerService.downloadAndInstallBestApk(
        updateInfo.apkAssets,
      );
      if (mounted) {
        _showSnack('安装包开始下载，完成后会自动打开安装界面。');
      }
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == 'install_permission_required') {
        _showSnack(error.message ?? '请允许安装未知来源应用后重试。');
      } else if (updateInfo.releaseUrl.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: updateInfo.releaseUrl));
        _showSnack('自动下载安装失败，发布页链接已复制。');
      } else {
        _showSnack(error.message ?? '下载安装包失败。');
      }
    } on AppInstallerException catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInstallingUpdate = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: _PlaybackStateBuilder(
          audioHandler: widget.audioHandler,
          builder: (BuildContext context, PlaybackUiState playbackState) {
            final DemoTrack currentTrack =
                demoQueue[_selectedQueueIndex % demoQueue.length];
            final Set<String> favoriteSongKeys = _favoriteSongKeys;
            return _NativeMusicScaffold(
              selectedTab: _selectedTab,
              selectedQueueIndex: _selectedQueueIndex,
              queueSongs: _playbackQueue,
              favoriteSongs: _favoriteSongs,
              favoriteSongKeys: favoriteSongKeys,
              favoritesBusy: _isLoadingFavorites,
              currentSong: _currentSong,
              coverSeedColor: _coverSeedColor,
              themeMode: widget.themeMode,
              searchController: _searchController,
              searchResults: _searchResults,
              searchBusy: _isSearchingMusic,
              searchMoreBusy: _isLoadingMoreSearchResults,
              searchCanLoadMore: _searchHasMore,
              searchError: _searchError,
              searchLoadMoreError: _searchLoadMoreError,
              lastSearchQuery: _lastSearchQuery,
              musicSources: _musicSources,
              sourceBusy: _isLoadingApiBootstrap,
              sourceError: _apiBootstrapError,
              hotSearchKeywords: _hotSearchKeywords,
              recommendedPlaylists: _recommendedPlaylists,
              recommendationsBusy: _isLoadingRecommendations,
              recommendationError: _recommendationError,
              playlistSongsBusy: false,
              playbackState: playbackState,
              playbackMode: _playbackMode,
              lyrics: _currentLyrics,
              lyricsAvailable: _currentLyrics?.lines.isNotEmpty ?? false,
              lyricsBusy: _isLoadingLyrics,
              lyricsError: _lyricsError,
              qualities: _currentQualities,
              qualitiesBusy: _isLoadingQualities,
              qualityError: _qualityError,
              currentTrack: currentTrack,
              carLifeStatus: _carLifeStatus,
              updateBusy: _isCheckingUpdate || _isInstallingUpdate,
              carLifeBusy: _isCheckingCarLife || _isSyncingCarLife,
              onSelectTab: (int index) {
                setState(() {
                  _selectedTab = index;
                });
              },
              onSelectQueueIndex: (int index) {
                unawaited(_skipToQueueItem(index));
              },
              onSearch: _searchSongs,
              onLoadMoreSearchResults: _loadMoreSearchResults,
              onPlaySearchResult: (int index) {
                unawaited(_playSearchResult(index));
              },
              onAddToQueue: (int index) {
                unawaited(_addSearchResultToQueue(index));
              },
              onToggleFavorite: (FreeMusicSong song) {
                unawaited(_toggleFavoriteSong(song));
              },
              onPlayFavorite: (int index) {
                unawaited(_playFavoriteSong(index));
              },
              onPlayAllFavorites: () {
                unawaited(_playAllFavorites());
              },
              onThemeModeChanged:
                  widget.onThemeModeChanged ?? (ThemeMode mode) {},

              onSelectPlaylist: _openPlaylistDetails,
              onPlayPause: () => _togglePlayback(playbackState.playing),
              onPlaybackMode: () {
                unawaited(_cyclePlaybackMode());
              },
              onQuality: _showQualitySheet,
              onSeek: (Duration position) {
                unawaited(_seekPlayback(position));
              },
              onPrevious: _skipToPreviousTrack,
              onNext: _skipToNextTrack,
              onOpenCarLife: _openCarLife,
              onSyncCarLife: () {
                unawaited(_syncCarLifePlaybackContext(showResult: true));
              },
              onRefreshCarLife: _refreshCarLifeStatus,
              onCheckUpdate: _checkForUpdate,
              onOpenDownloads: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => CacheManagerPage(
                      downloadService: _downloadService,
                    ),
                  ),
                );
              },
              downloadedSongKeys: _downloadedSongKeys,
              downloadedSongs: _downloadedSongs,
              onPlayDownloaded: _playDownloadedSong,
              onPlayAllDownloaded: _playAllDownloadedSongs,
              onDownload: _downloadSong,
              onDeleteCache: _deleteSongCache,
            );
          },
        ),
      ),
    );
  }
}

class _PlaybackStateBuilder extends StatelessWidget {
  const _PlaybackStateBuilder({
    required this.audioHandler,
    required this.builder,
  });

  final MusicAudioHandler? audioHandler;
  final Widget Function(BuildContext context, PlaybackUiState state) builder;

  @override
  Widget build(BuildContext context) {
    final MusicAudioHandler? handler = audioHandler;
    if (handler == null) {
      return builder(context, const PlaybackUiState());
    }
    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      initialData: handler.playbackState.valueOrNull,
      builder: (BuildContext context, AsyncSnapshot<PlaybackState> snapshot) {
        return StreamBuilder<MediaItem?>(
          stream: handler.mediaItem,
          initialData: handler.mediaItem.valueOrNull,
          builder:
              (BuildContext context, AsyncSnapshot<MediaItem?> itemSnapshot) {
                return builder(
                  context,
                  PlaybackUiState.fromAudioService(
                    snapshot.data,
                    itemSnapshot.data,
                  ),
                );
              },
        );
      },
    );
  }
}



class _NativeMusicScaffold extends StatelessWidget {
  const _NativeMusicScaffold({
    required this.selectedTab,
    required this.selectedQueueIndex,
    required this.queueSongs,
    required this.favoriteSongs,
    required this.favoriteSongKeys,
    required this.favoritesBusy,
    required this.currentSong,
    required this.coverSeedColor,
    required this.themeMode,
    required this.searchController,
    required this.searchResults,
    required this.searchBusy,
    required this.searchMoreBusy,
    required this.searchCanLoadMore,
    required this.searchError,
    required this.searchLoadMoreError,
    required this.lastSearchQuery,
    required this.musicSources,
    required this.sourceBusy,
    required this.sourceError,
    required this.hotSearchKeywords,
    required this.recommendedPlaylists,
    required this.recommendationsBusy,
    required this.recommendationError,
    required this.playlistSongsBusy,
    required this.playbackState,
    required this.playbackMode,
    required this.lyrics,
    required this.lyricsAvailable,
    required this.lyricsBusy,
    required this.lyricsError,
    required this.qualities,
    required this.qualitiesBusy,
    required this.qualityError,
    required this.currentTrack,
    required this.carLifeStatus,
    required this.updateBusy,
    required this.carLifeBusy,
    required this.onSelectTab,
    required this.onSelectQueueIndex,
    required this.onSearch,
    required this.onLoadMoreSearchResults,
    required this.onPlaySearchResult,
    required this.onAddToQueue,
    required this.onToggleFavorite,
    required this.onPlayFavorite,
    required this.onPlayAllFavorites,
    required this.onThemeModeChanged,
    required this.onSelectPlaylist,
    required this.onPlayPause,
    required this.onPlaybackMode,
    required this.onQuality,
    required this.onSeek,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenCarLife,
    required this.onSyncCarLife,
    required this.onRefreshCarLife,
    required this.onCheckUpdate,
    required this.onOpenDownloads,
    required this.downloadedSongKeys,
    required this.downloadedSongs,
    required this.onPlayDownloaded,
    required this.onPlayAllDownloaded,
    required this.onDownload,
    required this.onDeleteCache,
  });

  final int selectedTab;
  final int selectedQueueIndex;
  final List<FreeMusicSong> queueSongs;
  final List<FreeMusicSong> favoriteSongs;
  final Set<String> favoriteSongKeys;
  final bool favoritesBusy;
  final FreeMusicSong? currentSong;
  final Color coverSeedColor;
  final ThemeMode themeMode;
  final TextEditingController searchController;
  final List<FreeMusicSong> searchResults;
  final bool searchBusy;
  final bool searchMoreBusy;
  final bool searchCanLoadMore;
  final String searchError;
  final String searchLoadMoreError;
  final String lastSearchQuery;
  final FreeMusicSources? musicSources;
  final bool sourceBusy;
  final String sourceError;
  final List<String> hotSearchKeywords;
  final List<FreeMusicPlaylist> recommendedPlaylists;
  final bool recommendationsBusy;
  final String recommendationError;
  final bool playlistSongsBusy;
  final PlaybackUiState playbackState;
  final NativePlaybackMode playbackMode;
  final FreeMusicLyrics? lyrics;
  final bool lyricsAvailable;
  final bool lyricsBusy;
  final String lyricsError;
  final List<FreeMusicQuality> qualities;
  final bool qualitiesBusy;
  final String qualityError;
  final DemoTrack currentTrack;
  final CarLifeStatus carLifeStatus;
  final bool updateBusy;
  final bool carLifeBusy;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<int> onSelectQueueIndex;
  final VoidCallback onSearch;
  final VoidCallback onLoadMoreSearchResults;
  final ValueChanged<int> onPlaySearchResult;
  final ValueChanged<int> onAddToQueue;
  final ValueChanged<FreeMusicSong> onToggleFavorite;
  final ValueChanged<int> onPlayFavorite;
  final VoidCallback onPlayAllFavorites;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<FreeMusicPlaylist> onSelectPlaylist;
  final VoidCallback onPlayPause;
  final VoidCallback onPlaybackMode;
  final VoidCallback onQuality;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onOpenCarLife;
  final VoidCallback onSyncCarLife;
  final VoidCallback onRefreshCarLife;
  final VoidCallback onCheckUpdate;
  final VoidCallback onOpenDownloads;
  final Set<String> downloadedSongKeys;
  final List<FreeMusicSong> downloadedSongs;
  final ValueChanged<int> onPlayDownloaded;
  final VoidCallback onPlayAllDownloaded;
  final ValueChanged<FreeMusicSong> onDownload;
  final ValueChanged<FreeMusicSong> onDeleteCache;

  @override
  Widget build(BuildContext context) {
    return _PortraitMusicScaffold(
      selectedTab: selectedTab,
      selectedQueueIndex: selectedQueueIndex,
      queueSongs: queueSongs,
      favoriteSongs: favoriteSongs,
      favoriteSongKeys: favoriteSongKeys,
      favoritesBusy: favoritesBusy,
      currentSong: currentSong,
      coverSeedColor: coverSeedColor,
      themeMode: themeMode,
      searchController: searchController,
      searchResults: searchResults,
      searchBusy: searchBusy,
      searchMoreBusy: searchMoreBusy,
      searchCanLoadMore: searchCanLoadMore,
      searchError: searchError,
      searchLoadMoreError: searchLoadMoreError,
      lastSearchQuery: lastSearchQuery,
      musicSources: musicSources,
      sourceBusy: sourceBusy,
      sourceError: sourceError,
      hotSearchKeywords: hotSearchKeywords,
      recommendedPlaylists: recommendedPlaylists,
      recommendationsBusy: recommendationsBusy,
      recommendationError: recommendationError,
      playlistSongsBusy: playlistSongsBusy,
      playbackState: playbackState,
      playbackMode: playbackMode,
      lyrics: lyrics,
      lyricsAvailable: lyricsAvailable,
      lyricsBusy: lyricsBusy,
      lyricsError: lyricsError,
      qualities: qualities,
      qualitiesBusy: qualitiesBusy,
      qualityError: qualityError,
      currentTrack: currentTrack,
      carLifeStatus: carLifeStatus,
      updateBusy: updateBusy,
      carLifeBusy: carLifeBusy,
      onSelectTab: onSelectTab,
      onSelectQueueIndex: onSelectQueueIndex,
      onSearch: onSearch,
      onLoadMoreSearchResults: onLoadMoreSearchResults,
      onPlaySearchResult: onPlaySearchResult,
      onAddToQueue: onAddToQueue,
      onToggleFavorite: onToggleFavorite,
      onPlayFavorite: onPlayFavorite,
      onPlayAllFavorites: onPlayAllFavorites,
      onThemeModeChanged: onThemeModeChanged,
      onSelectPlaylist: onSelectPlaylist,
      onPlayPause: onPlayPause,
      onPlaybackMode: onPlaybackMode,
      onQuality: onQuality,
      onSeek: onSeek,
      onPrevious: onPrevious,
      onNext: onNext,
      onOpenCarLife: onOpenCarLife,
      onSyncCarLife: onSyncCarLife,
      onRefreshCarLife: onRefreshCarLife,
      onCheckUpdate: onCheckUpdate,
      onOpenDownloads: onOpenDownloads,
      downloadedSongKeys: downloadedSongKeys,
      downloadedSongs: downloadedSongs,
      onPlayDownloaded: onPlayDownloaded,
      onPlayAllDownloaded: onPlayAllDownloaded,
      onDownload: onDownload,
      onDeleteCache: onDeleteCache,
    );
  }
}

class _PortraitMusicScaffold extends StatelessWidget {
  const _PortraitMusicScaffold({
    required this.selectedTab,
    required this.selectedQueueIndex,
    required this.queueSongs,
    required this.favoriteSongs,
    required this.favoriteSongKeys,
    required this.favoritesBusy,
    required this.currentSong,
    required this.coverSeedColor,
    required this.themeMode,
    required this.searchController,
    required this.searchResults,
    required this.searchBusy,
    required this.searchMoreBusy,
    required this.searchCanLoadMore,
    required this.searchError,
    required this.searchLoadMoreError,
    required this.lastSearchQuery,
    required this.musicSources,
    required this.sourceBusy,
    required this.sourceError,
    required this.hotSearchKeywords,
    required this.recommendedPlaylists,
    required this.recommendationsBusy,
    required this.recommendationError,
    required this.playlistSongsBusy,
    required this.playbackState,
    required this.playbackMode,
    required this.lyrics,
    required this.lyricsAvailable,
    required this.lyricsBusy,
    required this.lyricsError,
    required this.qualities,
    required this.qualitiesBusy,
    required this.qualityError,
    required this.currentTrack,
    required this.carLifeStatus,
    required this.updateBusy,
    required this.carLifeBusy,
    required this.onSelectTab,
    required this.onSelectQueueIndex,
    required this.onSearch,
    required this.onLoadMoreSearchResults,
    required this.onPlaySearchResult,
    required this.onAddToQueue,
    required this.onToggleFavorite,
    required this.onPlayFavorite,
    required this.onPlayAllFavorites,
    required this.onThemeModeChanged,
    required this.onSelectPlaylist,
    required this.onPlayPause,
    required this.onPlaybackMode,
    required this.onQuality,
    required this.onSeek,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenCarLife,
    required this.onSyncCarLife,
    required this.onRefreshCarLife,
    required this.onCheckUpdate,
    required this.onOpenDownloads,
    required this.downloadedSongKeys,
    required this.downloadedSongs,
    required this.onPlayDownloaded,
    required this.onPlayAllDownloaded,
    required this.onDownload,
    required this.onDeleteCache,
  });

  final int selectedTab;
  final int selectedQueueIndex;
  final List<FreeMusicSong> queueSongs;
  final List<FreeMusicSong> favoriteSongs;
  final Set<String> favoriteSongKeys;
  final bool favoritesBusy;
  final FreeMusicSong? currentSong;
  final Color coverSeedColor;
  final ThemeMode themeMode;
  final TextEditingController searchController;
  final List<FreeMusicSong> searchResults;
  final bool searchBusy;
  final bool searchMoreBusy;
  final bool searchCanLoadMore;
  final String searchError;
  final String searchLoadMoreError;
  final String lastSearchQuery;
  final FreeMusicSources? musicSources;
  final bool sourceBusy;
  final String sourceError;
  final List<String> hotSearchKeywords;
  final List<FreeMusicPlaylist> recommendedPlaylists;
  final bool recommendationsBusy;
  final String recommendationError;
  final bool playlistSongsBusy;
  final PlaybackUiState playbackState;
  final NativePlaybackMode playbackMode;
  final FreeMusicLyrics? lyrics;
  final bool lyricsAvailable;
  final bool lyricsBusy;
  final String lyricsError;
  final List<FreeMusicQuality> qualities;
  final bool qualitiesBusy;
  final String qualityError;
  final DemoTrack currentTrack;
  final CarLifeStatus carLifeStatus;
  final bool updateBusy;
  final bool carLifeBusy;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<int> onSelectQueueIndex;
  final VoidCallback onSearch;
  final VoidCallback onLoadMoreSearchResults;
  final ValueChanged<int> onPlaySearchResult;
  final ValueChanged<int> onAddToQueue;
  final ValueChanged<FreeMusicSong> onToggleFavorite;
  final ValueChanged<int> onPlayFavorite;
  final VoidCallback onPlayAllFavorites;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<FreeMusicPlaylist> onSelectPlaylist;
  final VoidCallback onPlayPause;
  final VoidCallback onPlaybackMode;
  final VoidCallback onQuality;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onOpenCarLife;
  final VoidCallback onSyncCarLife;
  final VoidCallback onRefreshCarLife;
  final VoidCallback onCheckUpdate;
  final VoidCallback onOpenDownloads;
  final Set<String> downloadedSongKeys;
  final List<FreeMusicSong> downloadedSongs;
  final ValueChanged<int> onPlayDownloaded;
  final VoidCallback onPlayAllDownloaded;
  final ValueChanged<FreeMusicSong> onDownload;
  final ValueChanged<FreeMusicSong> onDeleteCache;

  @override
  Widget build(BuildContext context) {
    final ThemeData baseTheme = Theme.of(context);
    final ColorScheme dynamicScheme = ColorScheme.fromSeed(
      seedColor: coverSeedColor,
      brightness: baseTheme.brightness,
    );
    final ThemeData theme = baseTheme.copyWith(colorScheme: dynamicScheme);

    void runSearchFromHome() {
      if (selectedTab != 1) {
        onSelectTab(1);
      }
      onSearch();
    }

    final Widget page = switch (selectedTab) {
      1 => PortraitSearchView(
        controller: searchController,
        songs: searchResults,
        busy: searchBusy,
        loadMoreBusy: searchMoreBusy,
        canLoadMore: searchCanLoadMore,
        error: searchError,
        loadMoreError: searchLoadMoreError,
        query: lastSearchQuery,
        hotSearchKeywords: hotSearchKeywords,
        favoriteSongKeys: favoriteSongKeys,
        downloadedSongKeys: downloadedSongKeys,
        onSearch: onSearch,
        onHotKeyword: (String keyword) {
          searchController.text = keyword;
          onSearch();
        },
        onLoadMore: onLoadMoreSearchResults,
        onPlay: onPlaySearchResult,
        onAddToQueue: onAddToQueue,
        onToggleFavorite: onToggleFavorite,
        onDownload: onDownload,
      ),
      2 => PortraitLibraryView(
        favoriteSongs: favoriteSongs,
        favoriteSongKeys: favoriteSongKeys,
        favoritesBusy: favoritesBusy,
        queueSongs: queueSongs,
        selectedQueueIndex: selectedQueueIndex,
        onPlayFavorite: onPlayFavorite,
        onPlayAllFavorites: onPlayAllFavorites,
        onToggleFavorite: onToggleFavorite,
        onSelectQueueIndex: onSelectQueueIndex,
        downloadedSongs: downloadedSongs,
        downloadedSongKeys: downloadedSongKeys,
        onPlayDownloaded: onPlayDownloaded,
        onPlayAllDownloaded: onPlayAllDownloaded,
        onDownload: onDownload,
        onDeleteCache: onDeleteCache,
      ),
      4 => PortraitPlayerView(
        currentSong: currentSong,
        fallbackTrack: currentTrack,
        playbackState: playbackState,
        playbackMode: playbackMode,
        coverSeedColor: coverSeedColor,
        lyrics: lyrics,
        lyricsBusy: lyricsBusy,
        lyricsError: lyricsError,
        qualities: qualities,
        qualitiesBusy: qualitiesBusy,
        qualityError: qualityError,
        favorite:
            currentSong != null &&
            favoriteSongKeys.contains(favoriteSongKey(currentSong!)),
        onClose: () => onSelectTab(0),
        onToggleFavorite: currentSong == null
            ? null
            : () => onToggleFavorite(currentSong!),
        onPlayPause: onPlayPause,
        onPlaybackMode: onPlaybackMode,
        onQuality: onQuality,
        onSeek: onSeek,
        onPrevious: onPrevious,
        onNext: onNext,
      ),
      5 => PortraitSettingsView(
        themeMode: themeMode,
        carLifeStatus: carLifeStatus,
        carLifeBusy: carLifeBusy,
        updateBusy: updateBusy,
        onThemeModeChanged: onThemeModeChanged,
        onOpenCarLife: onOpenCarLife,
        onSyncCarLife: onSyncCarLife,
        onRefreshCarLife: onRefreshCarLife,
        onCheckUpdate: onCheckUpdate,
        onOpenDownloads: onOpenDownloads,
      ),
      _ => PortraitHomeView(
        controller: searchController,
        recommendedPlaylists: recommendedPlaylists,
        recommendationsBusy: recommendationsBusy,
        recommendationError: recommendationError,
        playlistSongsBusy: playlistSongsBusy,
        queueSongs: queueSongs,
        searchResults: searchResults,
        favoriteSongs: favoriteSongs,
        hotSearchKeywords: hotSearchKeywords,
        musicSources: musicSources,
        sourceBusy: sourceBusy,
        sourceError: sourceError,
        carLifeStatus: carLifeStatus,
        onSearch: runSearchFromHome,
        onHotKeyword: (String keyword) {
          searchController.text = keyword;
          runSearchFromHome();
        },
        onSelectPlaylist: onSelectPlaylist,
        onOpenFavorites: () => onSelectTab(2),
        onOpenDownloads: () => onSelectTab(5),
      ),
    };

    return Theme(
      data: theme,
      child: _PortraitDynamicBackground(
        seedColor: coverSeedColor,
        child: Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(key: ValueKey<int>(selectedTab), child: page),
          ),
          bottomNavigationBar: selectedTab == 4
              ? null
              : PortraitBottomChrome(
                  selectedTab: selectedTab,
                  currentSong: currentSong,
                  fallbackTrack: currentTrack,
                  playbackState: playbackState,
                  playbackMode: playbackMode,
                  coverSeedColor: coverSeedColor,
                  onSelectTab: onSelectTab,
                  onPlayPause: onPlayPause,
                  onPlaybackMode: onPlaybackMode,
                  onQuality: onQuality,
                  onPrevious: onPrevious,
                  onNext: onNext,
                ),
        ),
      ),
    );
  }
}

class _PortraitDynamicBackground extends StatelessWidget {
  const _PortraitDynamicBackground({
    required this.seedColor,
    required this.child,
  });

  final Color seedColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInOut,
      tween: ColorTween(end: seedColor),
      builder:
          (BuildContext context, Color? animatedColor, Widget? childWidget) {
        final Color currentSeed = animatedColor ?? seedColor;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                currentSeed.withValues(alpha: 0.32),
                colors.surface,
                colors.surface,
              ],
              stops: const <double>[0, 0.38, 1],
            ),
          ),
          child: childWidget,
        );
      },
      child: child,
    );
  }
}

AudioServiceRepeatMode _repeatModeForNativeMode(NativePlaybackMode mode) {
  switch (mode) {
    case NativePlaybackMode.repeatOne:
      return AudioServiceRepeatMode.one;
    case NativePlaybackMode.repeatAll:
      return AudioServiceRepeatMode.all;
    case NativePlaybackMode.sequential:
    case NativePlaybackMode.shuffle:
      return AudioServiceRepeatMode.none;
  }
}

AudioServiceShuffleMode _shuffleModeForNativeMode(NativePlaybackMode mode) {
  return mode == NativePlaybackMode.shuffle
      ? AudioServiceShuffleMode.all
      : AudioServiceShuffleMode.none;
}


