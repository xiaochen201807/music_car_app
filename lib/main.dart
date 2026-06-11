import 'dart:async';

import 'package:audio_service/audio_service.dart';
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
import 'models/playback_ui_state.dart';
import 'native_audio_controller.dart';
import 'services/app_installer_service.dart';
import 'services/download_service.dart';
import 'services/carlife_service.dart';
import 'services/update_check_service.dart';
import 'theme/design_tokens.dart';
import 'widgets/luxury_loading_indicator.dart';
import 'features/settings/cache_manager_page.dart';
import 'features/home/playlist_details_page.dart';
import 'app/music_app_state_scope.dart';
import 'features/shell/portrait_music_shell.dart';
import 'utils/cover_palette_manager.dart';

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
  final ColorScheme baseColorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  final ColorScheme colorScheme = brightness == Brightness.light
      ? baseColorScheme.copyWith(
          surface: AppColor.paperBase,
          surfaceContainer: AppColor.paperWarm,
          surfaceContainerHighest: AppColor.paperCool,
          onSurface: AppColor.paperInk,
          onSurfaceVariant: AppColor.paperMuted,
          primaryContainer: AppColor.paperAccentContainer,
          onPrimaryContainer: AppColor.paperOnAccentContainer,
          outline: AppColor.paperStrokeHairline,
          shadow: AppColor.paperShadow,
        )
      : baseColorScheme;
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
  State<NativeMusicHomePage> createState() => NativeMusicHomePageState();
}

class NativeMusicHomePageState extends State<NativeMusicHomePage>
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
  bool _visualAnimationsEnabled = true;
  int _searchRequestId = 0;
  int _lyricsRequestId = 0;
  int _qualitiesRequestId = 0;
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
  String _preferredBitrate = '320kmp3';
  bool _isPlayerActionBusy = false;
  final List<StreamSubscription<double>> _downloadSubscriptions = <StreamSubscription<double>>[];

  PlaybackUiState get playbackState {
    final MusicAudioHandler? handler = widget.audioHandler;
    return handler == null
        ? const PlaybackUiState()
        : PlaybackUiState.fromAudioService(
            handler.playbackState.valueOrNull,
            handler.mediaItem.valueOrNull,
          );
  }

  @override
  void initState() {
    super.initState();
    _downloadService = DownloadService(_freeMusicApi);
    unawaited(_downloadService.init());
    unawaited(_loadPreferredBitrate());
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
    unawaited(_nativeAudioController.flush());
    unawaited(_nativeAudioController.dispose());
    _freeMusicApi.close();
    _searchController.dispose();
    _updateCheckService.dispose();
    for (final StreamSubscription<double> sub in _downloadSubscriptions) {
      unawaited(sub.cancel());
    }
    _downloadSubscriptions.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool animationsEnabled = state == AppLifecycleState.resumed;
    if (_visualAnimationsEnabled != animationsEnabled && mounted) {
      setState(() {
        _visualAnimationsEnabled = animationsEnabled;
      });
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(WakelockPlus.enable());
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    } else if (state == AppLifecycleState.paused) {
      unawaited(_nativeAudioController.flush());
    }
  }

  String get preferredBitrate => _preferredBitrate;

  Future<void> _loadPreferredBitrate() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? br = prefs.getString('preferred_bitrate');
      if (br != null && mounted) {
        setState(() {
          _preferredBitrate = br;
        });
      }
    } catch (_) {}
  }

  Future<void> setPreferredBitrate(String br) async {
    if (_preferredBitrate == br) {
      return;
    }
    setState(() {
      _preferredBitrate = br;
    });
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('preferred_bitrate', br);
    } catch (_) {}
  }

  Future<bool> _resumeNativePlayback() async {
    if (_isPlayerActionBusy) {
      return false;
    }
    _isPlayerActionBusy = true;
    try {
      final bool handled = await _nativeAudioController.resumePlayback();
      return handled;
    } finally {
      if (mounted) {
        setState(() {
          _isPlayerActionBusy = false;
        });
      }
    }
  }

  Future<bool> _skipToNextTrack() async {
    if (_isPlayerActionBusy) {
      return false;
    }
    _isPlayerActionBusy = true;
    try {
      final bool handled = await _nativeAudioController.skipToNext();
      if (!mounted || !handled) {
        return handled;
      }
      _syncSelectedQueueIndexFromAudioController();
      return true;
    } finally {
      if (mounted) {
        setState(() {
          _isPlayerActionBusy = false;
        });
      }
    }
  }

  Future<bool> _skipToPreviousTrack() async {
    if (_isPlayerActionBusy) {
      return false;
    }
    _isPlayerActionBusy = true;
    try {
      final bool handled = await _nativeAudioController.skipToPrevious();
      if (!mounted || !handled) {
        return handled;
      }
      _syncSelectedQueueIndexFromAudioController();
      return true;
    } finally {
      if (mounted) {
        setState(() {
          _isPlayerActionBusy = false;
        });
      }
    }
  }

  void _syncSelectedQueueIndexFromAudioController() {
    final PlaybackQueueContext context = _nativeAudioController.getPlaybackContext();
    final int index = context.currentIndex;
    final List<FreeMusicSong> controllerQueue = context.playlist;
    if (index < 0 || controllerQueue.isEmpty || index >= controllerQueue.length) {
      return;
    }
    final bool needQueueUpdate = _playbackQueue.length != controllerQueue.length;
    final FreeMusicSong song = controllerQueue[index];

    setState(() {
      if (needQueueUpdate) {
        _playbackQueue = controllerQueue;
      }
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
    try {
      await Future.wait(<Future<void>>[
        _restorePlaybackSession().catchError((Object e) => debugPrint('[startup] restore failed: $e')),
        _loadFavoriteSongs().catchError((Object e) => debugPrint('[startup] load favorites failed: $e')),
        _loadApiBootstrap().catchError((Object e) => debugPrint('[startup] load api bootstrap failed: $e')),
      ]);
      if (!mounted) {
        return;
      }
      await _loadRecommendations().catchError((Object e) => debugPrint('[startup] load recommendations failed: $e'));
    } catch (error) {
      debugPrint('[main] startup loading failed: $error');
    }
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
      final Color color = await CoverPaletteManager.instance.getColor(cover);
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

    _isSearchingMusic = true;
    if (!_isLoadingMoreSearchResults) {
      _searchHasMore = false;
    }
    setState(() {
      _isLoadingMoreSearchResults = false;
      _searchError = '';
      _searchLoadMoreError = '';
      _lastSearchQuery = query;
      _searchPage = 0;
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
    if (query.isEmpty ||
        !_searchHasMore ||
        _isLoadingMoreSearchResults ||
        _isSearchingMusic) {
      return;
    }
    final int requestId = _searchRequestId;
    if (requestId != _searchRequestId || _isSearchingMusic) {
      return;
    }
    _isLoadingMoreSearchResults = true;
    setState(() {
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
    return _downloadService
        .getAllCachedTracks()
        .map<String>((CachedTrack t) => '${t.source}_${t.id}')
        .toSet();
  }

  List<FreeMusicSong> get _downloadedSongs {
    return _downloadService.getAllCachedTracks().map<FreeMusicSong>((
      CachedTrack track,
    ) {
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
        final FreeMusicQualityResult res = await _freeMusicApi.fetchQualities(
          song,
        ).timeout(const Duration(seconds: 5));
        qualities = res.qualities;
      } catch (_) {}
      final FreeMusicQuality targetQuality = findBestQuality(
        qualities,
        _preferredBitrate,
      );

      _showSnack('开始下载: ${song.name}');
      final Stream<double> progressStream = _downloadService.downloadTrack(
        song,
        targetQuality,
      );

      late final StreamSubscription<double> subscription;
      subscription = progressStream.listen(
        (double progress) {
          if (progress >= 1.0) {
            _showSnack('下载成功: ${song.name}');
            if (mounted) {
              setState(() {});
            }
            subscription.cancel();
            _downloadSubscriptions.remove(subscription);
          }
        },
        onError: (Object error) {
          _showSnack('下载失败: $error');
          subscription.cancel();
          _downloadSubscriptions.remove(subscription);
        },
        onDone: () {
          subscription.cancel();
          _downloadSubscriptions.remove(subscription);
        },
        cancelOnError: true,
      );
      _downloadSubscriptions.add(subscription);
    } catch (e) {
      _showSnack('下载失败: $e');
    }
  }

  Future<void> _deleteSongCache(FreeMusicSong song) async {
    try {
      await _downloadService.deleteTrack(song.source, song.id);
      _showSnack('已删除本地缓存: ${song.name}');
      if (mounted) {
        setState(() {});
      }
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
    final bool isQueueEmpty = _playbackQueue.isEmpty;
    final List<FreeMusicSong> newQueue = <FreeMusicSong>[
      ..._playbackQueue,
      song,
    ];
    final int currentIdx = isQueueEmpty
        ? 0
        : (_selectedQueueIndex >= 0 && _selectedQueueIndex < _playbackQueue.length
            ? _selectedQueueIndex
            : 0);
    final FreeMusicSong? nextCurrentSong = isQueueEmpty ? song : _currentSong;

    await _nativeAudioController.syncQueueFromProbe(
      PlayerProbeSnapshot(
        audioUrl: '',
        playing: false,
        song: nextCurrentSong,
        playlist: newQueue,
        currentIndex: currentIdx,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _playbackQueue = List<FreeMusicSong>.unmodifiable(newQueue);
      if (isQueueEmpty) {
        _selectedQueueIndex = 0;
        _currentSong = song;
      }
    });
    _showSnack('已加入播放队列：${song.name}');
    if (isQueueEmpty) {
      unawaited(_updateCoverSeed(song));
      unawaited(_loadLyricsForSong(song));
      unawaited(_loadQualitiesForSong(song));
    }
  }

  Future<void> _playSongQueue(List<FreeMusicSong> songs, int index) async {
    if (index < 0 || index >= songs.length) {
      return;
    }
    if (_isPlayerActionBusy) {
      return;
    }
    _isPlayerActionBusy = true;
    final FreeMusicSong song = songs[index];
    final FreeMusicSong? oldSong = _currentSong;
    final int oldIndex = _selectedQueueIndex;
    final List<FreeMusicSong> oldQueue = _playbackQueue;

    setState(() {
      _playbackQueue = List<FreeMusicSong>.unmodifiable(songs);
      _selectedQueueIndex = index;
      _currentSong = song;
    });

    try {
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
        if (_currentSong?.id == song.id && _currentSong?.source == song.source) {
          setState(() {
            _playbackQueue = oldQueue;
            _selectedQueueIndex = oldIndex;
            _currentSong = oldSong;
            if (oldSong == null) {
              _isLoadingLyrics = false;
              _isLoadingQualities = false;
              _lyricsError = '';
              _qualityError = '';
              _currentLyrics = null;
              _currentQualities = const <FreeMusicQuality>[];
            }
          });
          if (oldSong != null) {
            unawaited(_loadLyricsForSong(oldSong));
            unawaited(_loadQualitiesForSong(oldSong));
          }
        }
        return;
      }
      unawaited(_updateCoverSeed(song));
      unawaited(_loadLyricsForSong(song));
      unawaited(_loadQualitiesForSong(song));
      unawaited(_syncCarLifePlaybackContext(showResult: false));
    } finally {
      if (mounted) {
        setState(() {
          _isPlayerActionBusy = false;
        });
      }
    }
  }

  Future<bool> _skipToQueueItem(int index) async {
    if (index < 0 || index >= _playbackQueue.length) {
      return false;
    }
    if (_isPlayerActionBusy) {
      return false;
    }
    _isPlayerActionBusy = true;
    final FreeMusicSong? oldSong = _currentSong;
    final int oldIndex = _selectedQueueIndex;
    final FreeMusicSong targetSong = _playbackQueue[index];

    setState(() {
      _selectedQueueIndex = index;
      _currentSong = targetSong;
    });

    try {
      final bool handled = await _nativeAudioController.skipToQueueIndex(index);
      if (!mounted) {
        return false;
      }
      if (!handled) {
        _showSnack('切歌失败：${targetSong.name}');
        if (_currentSong?.id == targetSong.id && _currentSong?.source == targetSong.source) {
          setState(() {
            _selectedQueueIndex = oldIndex;
            _currentSong = oldSong;
            if (oldSong == null) {
              _isLoadingLyrics = false;
              _isLoadingQualities = false;
              _lyricsError = '';
              _qualityError = '';
              _currentLyrics = null;
              _currentQualities = const <FreeMusicQuality>[];
            }
          });
          if (oldSong != null) {
            unawaited(_loadLyricsForSong(oldSong));
            unawaited(_loadQualitiesForSong(oldSong));
          }
        }
        return false;
      }
      unawaited(_updateCoverSeed(targetSong));
      unawaited(_loadLyricsForSong(targetSong));
      unawaited(_loadQualitiesForSong(targetSong));
      unawaited(_syncCarLifePlaybackContext(showResult: false));
      return true;
    } finally {
      if (mounted) {
        setState(() {
          _isPlayerActionBusy = false;
        });
      }
    }
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
        final bool handled = await _skipToQueueItem(index);
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
    final int requestId = ++_lyricsRequestId;
    if (!song.canResolve) {
      if (mounted) {
        setState(() {
          _isLoadingLyrics = false;
          _lyricsError = '';
          _currentLyrics = null;
        });
      }
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
      ).timeout(const Duration(seconds: 5));
      if (!mounted ||
          requestId != _lyricsRequestId ||
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
      if (!mounted ||
          requestId != _lyricsRequestId ||
          _currentSong?.id != song.id ||
          _currentSong?.source != song.source) {
        return;
      }
      setState(() {
        _lyricsError = error.message;
        _isLoadingLyrics = false;
      });
      widget.audioHandler?.updateLyrics(const []);
    } catch (error) {
      if (!mounted ||
          requestId != _lyricsRequestId ||
          _currentSong?.id != song.id ||
          _currentSong?.source != song.source) {
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
    final int requestId = ++_qualitiesRequestId;
    setState(() {
      _isLoadingQualities = true;
      _qualityError = '';
      _currentQualities = const <FreeMusicQuality>[];
    });
    try {
      final FreeMusicQualityResult result = await _freeMusicApi.fetchQualities(
        song,
      ).timeout(const Duration(seconds: 5));
      if (!mounted ||
          requestId != _qualitiesRequestId ||
          _currentSong?.id != song.id ||
          _currentSong?.source != song.source) {
        return;
      }
      setState(() {
        _currentQualities = List<FreeMusicQuality>.unmodifiable(
          result.qualities,
        );
        _isLoadingQualities = false;
      });
    } on FreeMusicApiException catch (error) {
      if (!mounted ||
          requestId != _qualitiesRequestId ||
          _currentSong?.id != song.id ||
          _currentSong?.source != song.source) {
        return;
      }
      setState(() {
        _qualityError = error.message;
        _isLoadingQualities = false;
      });
    } catch (error) {
      if (!mounted ||
          requestId != _qualitiesRequestId ||
          _currentSong?.id != song.id ||
          _currentSong?.source != song.source) {
        return;
      }
      setState(() {
        _qualityError = '音质加载失败：$error';
        _isLoadingQualities = false;
      });
    }
  }

  Future<void> _changePlaybackQuality(FreeMusicQuality quality) async {
    if (_isPlayerActionBusy) {
      return;
    }
    _isPlayerActionBusy = true;
    try {
      await setPreferredBitrate(quality.bitrate);
      if (!mounted) return;
      final FreeMusicSong? current = _currentSong;
      if (current != null) {
        final Duration currentPosition = _nativeAudioController.position;
        await _nativeAudioController.playSong(current);
        if (!mounted) return;
        if (currentPosition != Duration.zero) {
          await _nativeAudioController.seek(currentPosition);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPlayerActionBusy = false;
        });
      }
    }
  }

  int _parseBitrateValue(String bitrateStr) {
    final String str = bitrateStr.toLowerCase();
    if (str.contains('flac') ||
        str.contains('lossless') ||
        str.contains('无损')) {
      return 1000;
    }
    final RegExp reg = RegExp(r'\d+');
    final Match? match = reg.firstMatch(str);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 128;
    }
    if (str.contains('aac')) {
      return 48;
    }
    if (str.contains('mp3')) {
      return 128;
    }
    return 128;
  }

  FreeMusicQuality findBestQuality(
    List<FreeMusicQuality> qualities,
    String preferredBitrate,
  ) {
    if (qualities.isEmpty) {
      return const FreeMusicQuality(name: '标准', bitrate: '48kaac');
    }
    final int targetValue = _parseBitrateValue(preferredBitrate);
    FreeMusicQuality bestQuality = qualities.first;
    int minDifference = (targetValue - _parseBitrateValue(bestQuality.bitrate))
        .abs();

    for (final FreeMusicQuality q in qualities) {
      final int value = _parseBitrateValue(q.bitrate);
      final int diff = (targetValue - value).abs();
      if (diff < minDifference) {
        minDifference = diff;
        bestQuality = q;
      }
    }
    return bestQuality;
  }

  bool _isLosslessQuality(FreeMusicQuality quality) {
    final String combined =
        '${quality.bitrate} ${quality.name} ${quality.format}'.toLowerCase();
    return combined.contains('flac') ||
        combined.contains('lossless') ||
        combined.contains('无损');
  }

  String _qualityTierValue(String bitrate, {FreeMusicQuality? quality}) {
    final String value = bitrate.toLowerCase();
    if (value.contains('flac') ||
        value.contains('lossless') ||
        value.contains('无损') ||
        (quality != null && _isLosslessQuality(quality))) {
      return 'lossless';
    }
    final int bitrateValue = _parseBitrateValue(bitrate);
    if (bitrateValue >= 192) {
      return 'extreme';
    }
    if (bitrateValue >= 128) {
      return 'higher';
    }
    return 'standard';
  }

  String _qualityIdentity(FreeMusicQuality quality) {
    return <String>[
      quality.bitrate,
      quality.format,
      quality.size,
      quality.name,
    ].join('|');
  }

  FreeMusicQuality? _closestQuality(
    Iterable<FreeMusicQuality> qualities,
    int targetValue,
    Set<String> usedIds,
  ) {
    FreeMusicQuality? bestQuality;
    int? minDifference;
    for (final FreeMusicQuality quality in qualities) {
      if (usedIds.contains(_qualityIdentity(quality))) {
        continue;
      }
      final int difference = (_parseBitrateValue(quality.bitrate) - targetValue)
          .abs();
      if (minDifference == null || difference < minDifference) {
        minDifference = difference;
        bestQuality = quality;
      }
    }
    return bestQuality;
  }

  FreeMusicQuality? _highestQuality(
    Iterable<FreeMusicQuality> qualities,
    Set<String> usedIds,
  ) {
    FreeMusicQuality? bestQuality;
    for (final FreeMusicQuality quality in qualities) {
      if (usedIds.contains(_qualityIdentity(quality))) {
        continue;
      }
      if (bestQuality == null ||
          _parseBitrateValue(quality.bitrate) >
              _parseBitrateValue(bestQuality.bitrate)) {
        bestQuality = quality;
      }
    }
    return bestQuality;
  }

  List<_QualitySheetOption> _qualitySheetOptions(
    List<FreeMusicQuality> qualities,
  ) {
    final List<FreeMusicQuality> lossyQualities = qualities
        .where((FreeMusicQuality quality) => !_isLosslessQuality(quality))
        .toList(growable: false);
    final List<FreeMusicQuality> losslessQualities = qualities
        .where(_isLosslessQuality)
        .toList(growable: false);
    final Set<String> usedIds = <String>{};

    FreeMusicQuality? pickClosestLossy(
      int targetValue, {
      bool Function(FreeMusicQuality quality)? where,
    }) {
      final FreeMusicQuality? quality = _closestQuality(
        where == null ? lossyQualities : lossyQualities.where(where),
        targetValue,
        usedIds,
      );
      if (quality != null) {
        usedIds.add(_qualityIdentity(quality));
      }
      return quality;
    }

    FreeMusicQuality? pickHighestLossy({
      bool Function(FreeMusicQuality quality)? where,
    }) {
      final FreeMusicQuality? quality = _highestQuality(
        where == null ? lossyQualities : lossyQualities.where(where),
        usedIds,
      );
      if (quality != null) {
        usedIds.add(_qualityIdentity(quality));
      }
      return quality;
    }

    final FreeMusicQuality? standardQuality = pickClosestLossy(
      48,
      where: (FreeMusicQuality quality) =>
          _parseBitrateValue(quality.bitrate) < 128,
    );
    final FreeMusicQuality? higherQuality = pickClosestLossy(
      128,
      where: (FreeMusicQuality quality) =>
          _parseBitrateValue(quality.bitrate) >= 128 &&
          _parseBitrateValue(quality.bitrate) < 192,
    );
    final FreeMusicQuality? extremeQuality = pickHighestLossy(
      where: (FreeMusicQuality quality) =>
          _parseBitrateValue(quality.bitrate) >= 192,
    );
    final FreeMusicQuality? losslessQuality = _highestQuality(
      losslessQualities,
      const <String>{},
    );

    return <_QualitySheetOption>[
      _QualitySheetOption(
        tier: 'standard',
        label: '标准',
        unavailableText: '当前歌曲暂无标准音源',
        quality: standardQuality,
      ),
      _QualitySheetOption(
        tier: 'higher',
        label: '较高',
        unavailableText: '当前歌曲暂无较高音源',
        quality: higherQuality,
      ),
      _QualitySheetOption(
        tier: 'extreme',
        label: '极高',
        unavailableText: '当前歌曲暂无极高音源',
        quality: extremeQuality,
      ),
      _QualitySheetOption(
        tier: 'lossless',
        label: '无损',
        unavailableText: '当前歌曲暂无无损音源',
        quality: losslessQuality,
      ),
    ];
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
          content = Padding(
            padding: const EdgeInsets.all(AppSpace.xl3),
            child: Center(child: LuxuryLoadingIndicator()),
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
          final FreeMusicQuality selectedQuality = findBestQuality(
            qualities,
            _preferredBitrate,
          );
          final String selectedQualityTier = _qualityTierValue(
            selectedQuality.bitrate,
            quality: selectedQuality,
          );
          final List<_QualitySheetOption> qualityOptions = _qualitySheetOptions(
            qualities,
          );
          content = ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.xl,
              vertical: AppSpace.md,
            ),
            itemCount: qualityOptions.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpace.xs),
            itemBuilder: (BuildContext context, int index) {
              final _QualitySheetOption option = qualityOptions[index];
              final FreeMusicQuality? quality = option.quality;
              final String subtitle = quality == null
                  ? option.unavailableText
                  : <String>[
                      if (quality.format.isNotEmpty) quality.format,
                      if (quality.size.isNotEmpty) quality.size,
                      if (quality.bitrate.isNotEmpty) quality.bitrate,
                    ].join(' · ');
              final bool isSelected =
                  quality != null && option.tier == selectedQualityTier;
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                enabled: quality != null,
                tileColor: isSelected
                    ? colors.primaryContainer.withValues(alpha: 0.25)
                    : null,
                leading: Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: quality == null
                      ? colors.onSurfaceVariant.withValues(alpha: 0.38)
                      : isSelected
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                title: Text(
                  option.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: quality == null
                        ? colors.onSurfaceVariant.withValues(alpha: 0.55)
                        : null,
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
                onTap: quality == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        unawaited(_changePlaybackQuality(quality));
                      },
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

  // ==========================================
  // Public Getters for MusicAppStateScope
  // ==========================================
  int get selectedTab => _selectedTab;
  int get selectedQueueIndex => _selectedQueueIndex;
  List<FreeMusicSong> get playbackQueue => _playbackQueue;
  List<FreeMusicSong> get favoriteSongs => _favoriteSongs;
  Set<String> get favoriteSongKeys => _favoriteSongKeys;
  bool get isLoadingFavorites => _isLoadingFavorites;
  FreeMusicSong? get currentSong => _currentSong;
  Color get coverSeedColor => _coverSeedColor;
  TextEditingController get searchController => _searchController;
  List<FreeMusicSong> get searchResults => _searchResults;
  bool get isSearchingMusic => _isSearchingMusic;
  bool get isLoadingMoreSearchResults => _isLoadingMoreSearchResults;
  bool get searchHasMore => _searchHasMore;
  String get searchError => _searchError;
  String get searchLoadMoreError => _searchLoadMoreError;
  String get lastSearchQuery => _lastSearchQuery;
  FreeMusicSources? get musicSources => _musicSources;
  bool get isLoadingApiBootstrap => _isLoadingApiBootstrap;
  String get apiBootstrapError => _apiBootstrapError;
  List<String> get hotSearchKeywords => _hotSearchKeywords;
  List<FreeMusicPlaylist> get recommendedPlaylists => _recommendedPlaylists;
  bool get isLoadingRecommendations => _isLoadingRecommendations;
  String get recommendationError => _recommendationError;
  NativePlaybackMode get playbackMode => _playbackMode;
  FreeMusicLyrics? get currentLyrics => _currentLyrics;
  bool get isLoadingLyrics => _isLoadingLyrics;
  String get lyricsError => _lyricsError;
  List<FreeMusicQuality> get currentQualities => _currentQualities;
  bool get isLoadingQualities => _isLoadingQualities;
  String get qualityError => _qualityError;
  CarLifeStatus get carLifeStatus => _carLifeStatus;
  bool get isCheckingUpdate => _isCheckingUpdate;
  bool get isInstallingUpdate => _isInstallingUpdate;
  bool get isCheckingCarLife => _isCheckingCarLife;
  bool get isSyncingCarLife => _isSyncingCarLife;
  Set<String> get downloadedSongKeys => _downloadedSongKeys;
  List<FreeMusicSong> get downloadedSongs => _downloadedSongs;
  bool get visualAnimationsEnabled => _visualAnimationsEnabled;

  // ==========================================
  // Public Actions for MusicAppStateScope
  // ==========================================
  void selectTab(int index) {
    setState(() {
      _selectedTab = index;
    });
  }

  Future<void> skipToQueueIndex(int index) => _skipToQueueItem(index);
  Future<void> skipToQueueItem(int index) => _skipToQueueItem(index);
  Future<void> searchSongs() => _searchSongs();
  Future<void> loadMoreSearchResults() => _loadMoreSearchResults();
  Future<void> playSearchResult(int index) => _playSearchResult(index);
  Future<void> addSearchResultToQueue(int index) =>
      _addSearchResultToQueue(index);
  Future<void> toggleFavoriteSong(FreeMusicSong song) =>
      _toggleFavoriteSong(song);
  Future<void> playFavoriteSong(int index) => _playFavoriteSong(index);
  Future<void> playAllFavorites() => _playAllFavorites();
  void openPlaylistDetails(FreeMusicPlaylist playlist) =>
      _openPlaylistDetails(playlist);
  Future<void> togglePlayback(bool playing) => _togglePlayback(playing);
  Future<void> cyclePlaybackMode() => _cyclePlaybackMode();
  void showQualitySheet() => _showQualitySheet();
  Future<void> seekPlayback(Duration position) => _seekPlayback(position);
  Future<bool> skipToPreviousTrack() => _skipToPreviousTrack();
  Future<bool> skipToNextTrack() => _skipToNextTrack();
  Future<void> openCarLife() => _openCarLife();
  Future<void> syncCarLifePlaybackContext({required bool showResult}) =>
      _syncCarLifePlaybackContext(showResult: showResult);
  Future<void> refreshCarLifeStatus() => _refreshCarLifeStatus();
  Future<void> checkForUpdate() => _checkForUpdate();

  void openDownloads() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            CacheManagerPage(downloadService: _downloadService),
      ),
    );
  }

  Future<void> playDownloadedSong(int index) => _playDownloadedSong(index);
  Future<void> playAllDownloadedSongs() => _playAllDownloadedSongs();
  Future<void> downloadSong(FreeMusicSong song) => _downloadSong(song);
  Future<void> deleteSongCache(FreeMusicSong song) => _deleteSongCache(song);

  @override
  Widget build(BuildContext context) {
    return MusicAppStateScope(
      state: this,
      currentSong: _currentSong,
      selectedQueueIndex: _selectedQueueIndex,
      playbackQueue: _playbackQueue,
      playbackMode: _playbackMode,
      searchResults: _searchResults,
      favoriteSongs: _favoriteSongs,
      selectedTab: _selectedTab,
      isLoadingRecommendations: _isLoadingRecommendations,
      isLoadingApiBootstrap: _isLoadingApiBootstrap,
      recommendationError: _recommendationError,
      apiBootstrapError: _apiBootstrapError,
      child: const PortraitMusicScaffold(),
    );
  }
}

class _QualitySheetOption {
  const _QualitySheetOption({
    required this.tier,
    required this.label,
    required this.unavailableText,
    required this.quality,
  });

  final String tier;
  final String label;
  final String unavailableText;
  final FreeMusicQuality? quality;
}

// ==========================================
// Global Conversion Helpers
// ==========================================
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
