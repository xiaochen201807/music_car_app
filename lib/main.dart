import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'free_music_api.dart';
import 'music_audio_handler.dart';
import 'models/app_update_info.dart';
import 'models/playback_ui_state.dart';
import 'native_audio_controller.dart';
import 'services/app_installer_service.dart';
import 'services/app_settings_controller.dart';
import 'services/app_telemetry.dart';
import 'controllers/download_controller.dart';
import 'controllers/library_controller.dart';
import 'controllers/music_search_controller.dart';
import 'controllers/playback_controller.dart';
import 'controllers/player_ui_state_controller.dart';
import 'controllers/queue_controller.dart';
import 'controllers/track_metadata_controller.dart';
import 'services/download_service.dart';
import 'services/carlife_service.dart';
import 'services/carplay_service.dart';
import 'services/platform_media_bridge.dart';
import 'services/update_check_service.dart';
import 'theme/design_tokens.dart';
import 'widgets/luxury_loading_indicator.dart';
import 'features/settings/cache_manager_page.dart';
import 'features/home/playlist_details_page.dart';
import 'app/music_app_state_scope.dart';
import 'features/shell/portrait_music_shell.dart';
import 'utils/cover_palette_manager.dart';
import 'utils/lyrics_utils.dart';

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

  unawaited(_clearAudioCache());

  runApp(MusicCarApp(audioHandler: audioHandler));
}

Future<void> _clearAudioCache() async {
  try {
    final Directory cacheDir = await getTemporaryDirectory();
    final Directory audioCache = Directory('${cacheDir.path}/just_audio_cache');
    if (await audioCache.exists()) {
      await audioCache.delete(recursive: true);
      debugPrint('[cache] Cleared just_audio cache');
    }
  } catch (e) {
    debugPrint('[cache] Failed to clear audio cache: $e');
  }
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
  late final AppSettingsController _settingsController;

  @override
  void initState() {
    super.initState();
    _settingsController = AppSettingsController()
      ..addListener(_handleSettingsChanged);
    unawaited(_settingsController.load());
  }

  void _handleSettingsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _settingsController
      ..removeListener(_handleSettingsChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = _settingsController.themeMode;
    final ThemeData lightTheme = _buildAppTheme(
      brightness: Brightness.light,
      seedColor: AppColor.bmwBlue,
    );
    final ThemeData darkTheme = _buildAppTheme(
      brightness: Brightness.dark,
      seedColor: AppColor.spotifyGreen,
    );
    return MaterialApp(
      title: '车载音乐',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home:
          widget.homeOverride ??
          NativeMusicHomePage(
            audioHandler: widget.audioHandler,
            autoCheckForUpdates: widget.autoCheckForUpdates,
            settingsController: _settingsController,
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
          primary: AppColor.bmwBlue,
          secondary: AppColor.bmwBlueActive,
          onSurface: AppColor.paperInk,
          onSurfaceVariant: AppColor.paperMuted,
          primaryContainer: AppColor.paperAccentContainer,
          onPrimaryContainer: AppColor.paperOnAccentContainer,
          outline: AppColor.paperStrokeHairline,
          shadow: AppColor.paperShadow,
          error: AppColor.error,
        )
      : baseColorScheme.copyWith(
          surface: AppColor.bgBase,
          surfaceContainer: AppColor.glassTint,
          surfaceContainerHighest: AppColor.glowCyan,
          primary: AppColor.spotifyGreen,
          secondary: AppColor.spotifyGreenPressed,
          primaryContainer: AppColor.fillNeutralHover,
          onPrimaryContainer: AppColor.textPrimary,
          onSurface: AppColor.textPrimary,
          onSurfaceVariant: AppColor.textSecondary,
          outline: AppColor.strokeHairline,
          shadow: Colors.black,
          error: AppColor.error,
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
    required this.settingsController,
  });

  final MusicAudioHandler? audioHandler;
  final bool autoCheckForUpdates;
  final AppSettingsController settingsController;

  @override
  State<NativeMusicHomePage> createState() => NativeMusicHomePageState();
}

class NativeMusicHomePageState extends State<NativeMusicHomePage>
    with WidgetsBindingObserver {
  late final NativeAudioController _nativeAudioController;
  late final PlaybackController _playbackController;
  late final DownloadService _downloadService;
  late final DownloadController _downloadController;
  late final MusicSearchController _musicSearchController;
  late final TrackMetadataController _trackMetadataController;
  late final PlatformMediaBridge _mediaBridge;
  final FreeMusicApi _freeMusicApi = FreeMusicApi();
  final AppTelemetry _telemetry = AppTelemetry.instance;
  final TextEditingController _searchController = TextEditingController();
  final UpdateCheckService _updateCheckService = UpdateCheckService();
  OverlayEntry? _activeToastEntry;
  CarLifePlaybackContext? _pendingSyncContext;
  final AppInstallerService _appInstallerService = const AppInstallerService();
  final CarLifeService _carLifeService = const CarLifeService();
  CarPlayService? _carPlayService;
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
  bool _isLoadingApiBootstrap = false;
  bool _visualAnimationsEnabled = true;
  String _apiBootstrapError = '';
  FreeMusicSources? _musicSources;
  List<String> _hotSearchKeywords = const <String>[];
  int _selectedTab = 0;
  final LibraryController _libraryController = LibraryController();
  final PlayerUiStateController _playerUiStateController =
      PlayerUiStateController();
  final QueueController _queueController = QueueController();
  Color _coverSeedColor = AppColor.accentSteelStart;
  String _coverSeedUrl = '';
  Timer? _lyricBroadcastTimer;

  PlayerUiStateController get playerUiStateController {
    return _playerUiStateController;
  }

  PlaybackUiState get playbackState => _playerUiStateController.value;

  FreeMusicSong? get _currentSong => _queueController.currentSong;

  List<FreeMusicSong> get _playbackQueue => _queueController.queue;

  int get _selectedQueueIndex => _queueController.selectedIndex;

  void _handleLibraryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleDownloadChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleTrackMetadataChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint('════════════════════════════════════════════════════════════');
    debugPrint('🚀 App Version: 1.0.73 (Build 10073)');
    debugPrint('✅ Fixes: 设置外观切换双层边框修复');
    debugPrint('════════════════════════════════════════════════════════════');
    _libraryController.addListener(_handleLibraryChanged);
    _musicSearchController = MusicSearchController(
      client: FreeMusicSearchApiClient(_freeMusicApi),
    )..addListener(_handleSearchChanged);
    _trackMetadataController = TrackMetadataController(
      client: FreeMusicTrackMetadataClient(_freeMusicApi),
    )..addListener(_handleTrackMetadataChanged);
    _downloadService = DownloadService(_freeMusicApi);
    unawaited(_downloadService.init());
    _downloadController = DownloadController(
      backend: DownloadServiceBackend(_downloadService),
      qualityClient: FreeMusicDownloadQualityClient(_freeMusicApi),
    )..addListener(_handleDownloadChanged);
    _nativeAudioController = NativeAudioController(
      player: widget.audioHandler,
      api: _freeMusicApi,
      downloadService: _downloadService,
    );
    _playbackController = PlaybackController(
      nativeAudioController: _nativeAudioController,
      audioHandler: widget.audioHandler,
    );
    _playerUiStateController.attach(
      widget.audioHandler == null
          ? null
          : AudioHandlerPlayerUiStateSource(widget.audioHandler!),
    );
    _mediaBridge =
        PlatformMediaBridge(
            playbackController: _playbackController,
            queueController: _queueController,
            trackMetadataController: _trackMetadataController,
            carLifeService: _carLifeService,
            carPlayService: null,
          )
          ..onTrackChanged = _handleTrackChangedFromPlatform
          ..onQueueItemSelected = _skipToQueueItem
          ..onSetRepeatMode = _handleSetRepeatModeFromSession
          ..onSetShuffleMode = _handleSetShuffleModeFromSession
          ..attachToAudioHandler(widget.audioHandler)
          ..attachToCarLife();
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        widget.audioHandler != null) {
      _carPlayService = CarPlayService(
        widget.audioHandler!,
        _nativeAudioController,
      );
      unawaited(_carPlayService!.init());
    }
    WidgetsBinding.instance.addObserver(this);
    _queueController.addListener(_handlePlaybackStateChanged);
    _startLyricBroadcastTimer();
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
    _queueController.removeListener(_handlePlaybackStateChanged);
    _carPlayService?.dispose();
    _lyricBroadcastTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _mediaBridge.detachFromAudioHandler(widget.audioHandler);
    unawaited(WakelockPlus.disable());
    unawaited(_nativeAudioController.flush());
    unawaited(_nativeAudioController.dispose());
    _freeMusicApi.close();
    _searchController.dispose();
    _updateCheckService.dispose();
    _libraryController
      ..removeListener(_handleLibraryChanged)
      ..dispose();
    _musicSearchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _downloadController
      ..removeListener(_handleDownloadChanged)
      ..dispose();
    _trackMetadataController
      ..removeListener(_handleTrackMetadataChanged)
      ..dispose();
    _playerUiStateController.dispose();
    _queueController.dispose();
    _activeToastEntry?.remove();
    _activeToastEntry = null;
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

  String get preferredBitrate => widget.settingsController.preferredBitrate;

  ThemeMode get themeMode => widget.settingsController.themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    await widget.settingsController.setThemeMode(mode);
  }

  Future<void> setPreferredBitrate(String br) async {
    await widget.settingsController.setPreferredBitrate(br);
  }

  FreeMusicSong? _lastLoadedLyricsSong;

  void _handlePlaybackStateChanged() {
    debugPrint('[main] 🔄 QueueController changed, checking song switch');
    final FreeMusicSong? currentSong = _queueController.currentSong;
    if (currentSong != null && currentSong != _lastLoadedLyricsSong) {
      debugPrint(
        '[main] 🎵 Song switched: ${currentSong.name} - ${currentSong.artist}',
      );
      _lastLoadedLyricsSong = currentSong;
      unawaited(_loadLyricsForSong(currentSong));
    }
  }

  void _handleTrackChangedFromPlatform(FreeMusicSong song) {
    if (!mounted) return;
    _syncSelectedQueueIndexFromAudioController();
    unawaited(_updateCoverSeed(song));
    unawaited(_loadLyricsForSong(song));
    unawaited(_loadQualitiesForSong(song));
    unawaited(_syncCarLifePlaybackContext(showResult: false));
  }

  void _syncSelectedQueueIndexFromAudioController() {
    final PlaybackQueueContext context = _nativeAudioController
        .getPlaybackContext();
    final int index = context.currentIndex;
    final List<FreeMusicSong> controllerQueue = context.playlist;
    if (index < 0 ||
        controllerQueue.isEmpty ||
        index >= controllerQueue.length) {
      return;
    }
    final FreeMusicSong song = controllerQueue[index];

    setState(() {
      _queueController.syncCurrentFromExternalQueue(controllerQueue, index);
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
        _restorePlaybackSession().catchError(
          (Object e) => debugPrint('[startup] restore failed: $e'),
        ),
        _loadFavoriteSongs().catchError(
          (Object e) => debugPrint('[startup] load favorites failed: $e'),
        ),
        _loadApiBootstrap().catchError(
          (Object e) => debugPrint('[startup] load api bootstrap failed: $e'),
        ),
        _loadRecommendations().catchError(
          (Object e) => debugPrint('[startup] load recommendations failed: $e'),
        ),
      ]);
    } catch (error) {
      debugPrint('[main] startup loading failed: $error');
    }
  }

  Future<void> _loadFavoriteSongs() async {
    try {
      await _libraryController.loadFavorites();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('收藏列表加载失败：$error');
    }
  }

  Set<String> get _favoriteSongKeys {
    return _libraryController.favoriteSongKeys;
  }

  Future<void> _toggleFavoriteSong(FreeMusicSong song) async {
    if (!song.canResolve) {
      _showSnack('这首歌暂时不能收藏');
      return;
    }
    try {
      final FavoriteChangeResult result = await _libraryController
          .toggleFavorite(song);
      if (!mounted) {
        return;
      }
      _showToast(result.removing ? '已取消收藏：${song.name}' : '已收藏：${song.name}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('收藏保存失败：$error');
    }
  }

  Future<void> _playFavoriteSong(int index) async {
    final List<FreeMusicSong> favoriteSongs = _libraryController.favoriteSongs;
    if (index < 0 || index >= favoriteSongs.length) {
      return;
    }
    await _playSongQueue(favoriteSongs, index);
  }

  Future<void> _playAllFavorites() async {
    final List<FreeMusicSong> favoriteSongs = _libraryController.favoriteSongs;
    if (favoriteSongs.isEmpty) {
      _showSnack('收藏列表为空');
      return;
    }
    await _playSongQueue(favoriteSongs, 0);
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
        _coverSeedColor = AppColor.accentSteelStart;
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
      _queueController.replace(restored, restoredIndex);
    });
    unawaited(_updateCoverSeed(song));
    unawaited(_loadLyricsForSong(song));
    unawaited(_loadQualitiesForSong(song));
    // Resume playback — NativeAudioController will re-resolve the audio URL
    // if needed, so this is safe to fire-and-forget.
    unawaited(_playbackController.resumeNativePlayback());
  }

  Future<void> _searchSongs() async {
    final String query = _searchController.text.trim();
    await _musicSearchController.searchSongsDebounced(
      query,
      sources: _activeSourceIds,
    );
  }

  Future<void> _loadMoreSearchResults() async {
    await _musicSearchController.loadMoreSearchResults(
      sources: _activeSourceIds,
    );
  }

  Future<void> _loadRecommendations() async {
    await _musicSearchController.loadRecommendations(
      sources: const <String>['netease'],
    );
  }

  Set<String> get _downloadedSongKeys {
    return _downloadController.downloadedSongKeys;
  }

  List<FreeMusicSong> get _downloadedSongs =>
      _downloadController.downloadedSongs;

  Future<void> _downloadSong(FreeMusicSong song) async {
    try {
      _showToast('正在解析 "${song.name}" 的品质...');
      _showToast('开始下载: ${song.name}');
      await _downloadController.downloadSong(
        song,
        preferredBitrate: preferredBitrate,
      );
      if (!mounted) {
        return;
      }
      _showToast('下载成功: ${song.name}');
    } catch (e) {
      _showSnack('下载失败: $e');
    }
  }

  Future<void> _deleteSongCache(FreeMusicSong song) async {
    try {
      await _downloadController.deleteSongCache(song);
      _showToast('已删除本地缓存: ${song.name}');
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
          onPlay:
              (List<FreeMusicSong> songs, int index, {bool append = false}) {
                if (append) {
                  _appendSongsToQueue(songs);
                } else {
                  unawaited(_playSongQueue(songs, index));
                }
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
    final List<FreeMusicSong> searchResults =
        _musicSearchController.searchResults;
    if (index < 0 || index >= searchResults.length) {
      return;
    }
    await _playSongQueue(searchResults, index);
  }

  /// Appends the selected search result to the end of the playback queue without
  /// changing the currently playing track.
  Future<void> _addSearchResultToQueue(int index) async {
    final List<FreeMusicSong> searchResults =
        _musicSearchController.searchResults;
    if (index < 0 || index >= searchResults.length) {
      return;
    }
    final FreeMusicSong song = searchResults[index];
    // Avoid duplicates: skip if the exact same song is already the last item.
    if (_queueController.isLastSong(song)) {
      _showToast('该歌曲已在队列末尾');
      return;
    }
    final bool isQueueEmpty = _queueController.isEmpty;
    final List<FreeMusicSong> newQueue = <FreeMusicSong>[
      ..._playbackQueue,
      song,
    ];
    final int currentIdx = _queueController.selectedIndexForAppend();
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
      _queueController.appendToEnd(song);
    });
    _showToast('已加入播放队列：${song.name}');
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
    if (!_playbackController.beginQueueAction()) {
      unawaited(HapticFeedback.lightImpact());
      return;
    }
    final FreeMusicSong song = songs[index];
    final QueueSnapshot oldSnapshot = _queueController.snapshot;

    // 锁仅保护 setState，立即释放；后续网络/音频操作由 NativeAudioController 内部并发控制
    try {
      setState(() {
        _queueController.replace(songs, index);
      });
    } finally {
      _playbackController.endQueueAction();
    }

    // 以下为耗时异步操作（网络解析 URL + 音频加载），不再持有全局锁
    try {
      final bool handled = await _playbackController.playSnapshot(
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
        if (_currentSong?.id == song.id &&
            _currentSong?.source == song.source) {
          setState(() {
            _queueController.restore(oldSnapshot);
            if (oldSnapshot.currentSong == null) {
              _trackMetadataController.reset();
            }
          });
          if (oldSnapshot.currentSong != null) {
            unawaited(_loadLyricsForSong(oldSnapshot.currentSong!));
            unawaited(_loadQualitiesForSong(oldSnapshot.currentSong!));
          }
        }
        return;
      }
      unawaited(_updateCoverSeed(song));
      unawaited(_loadLyricsForSong(song));
      unawaited(_loadQualitiesForSong(song));
      unawaited(_syncCarLifePlaybackContext(showResult: false));
    } catch (e) {
      debugPrint('[main] _playSongQueue error: $e');
      if (mounted) {
        _showSnack('播放失败：${song.name}');
        // 回滚 UI 状态
        if (_currentSong?.id == song.id &&
            _currentSong?.source == song.source) {
          setState(() {
            _queueController.restore(oldSnapshot);
          });
        }
      }
    }
  }

  void _appendSongsToQueue(List<FreeMusicSong> songs) {
    if (songs.isEmpty) return;
    for (final FreeMusicSong song in songs) {
      _queueController.appendToEnd(song);
    }
    _showToast('已添加 ${songs.length} 首歌曲到队列');
  }

  Future<bool> _skipToQueueItem(int index) async {
    if (index < 0 || index >= _playbackQueue.length) {
      return false;
    }
    if (!_playbackController.beginQueueAction()) {
      unawaited(HapticFeedback.lightImpact());
      return false;
    }
    final QueueSnapshot oldSnapshot = _queueController.snapshot;
    final FreeMusicSong targetSong = _playbackQueue[index];

    // 锁仅保护 setState，立即释放
    try {
      setState(() {
        _queueController.selectIndex(index);
      });
    } finally {
      _playbackController.endQueueAction();
    }

    // 耗时异步操作不再持有全局锁
    final bool handled = await _playbackController.skipToQueueIndex(index);
    if (!mounted) {
      return false;
    }
    if (!handled) {
      _showSnack('切歌失败：${targetSong.name}');
      if (_currentSong?.id == targetSong.id &&
          _currentSong?.source == targetSong.source) {
        setState(() {
          _queueController.restore(oldSnapshot);
          if (oldSnapshot.currentSong == null) {
            _trackMetadataController.reset();
          }
        });
        if (oldSnapshot.currentSong != null) {
          unawaited(_loadLyricsForSong(oldSnapshot.currentSong!));
          unawaited(_loadQualitiesForSong(oldSnapshot.currentSong!));
        }
      }
      return false;
    }
    unawaited(_updateCoverSeed(targetSong));
    unawaited(_loadLyricsForSong(targetSong));
    unawaited(_loadQualitiesForSong(targetSong));
    unawaited(_syncCarLifePlaybackContext(showResult: false));
    return true;
  }

  Future<void> _loadLyricsForSong(FreeMusicSong song) async {
    widget.audioHandler?.updateLyrics(const []);
    final bool applied = await _trackMetadataController.loadLyricsForSong(song);
    if (!mounted || !applied) {
      return;
    }
    final FreeMusicLyrics? lyrics = _trackMetadataController.currentLyrics;
    if (lyrics != null) {
      widget.audioHandler?.updateLyrics(lyrics.lines);
    } else {
      widget.audioHandler?.updateLyrics(const []);
    }
  }

  Future<void> _loadQualitiesForSong(FreeMusicSong song) async {
    await _trackMetadataController.loadQualitiesForSong(song);
  }

  Future<void> _changePlaybackQuality(FreeMusicQuality quality) async {
    final String previousBitrate = preferredBitrate;
    await setPreferredBitrate(quality.bitrate);
    _showToast('正在切换音质：${quality.name}');
    if (!mounted) return;
    final FreeMusicSong? current = _currentSong;
    if (current != null) {
      final Duration currentPosition = _playbackController.position;
      final bool handled = await _playbackController.playSong(current);
      if (!mounted) return;
      if (!handled) {
        await setPreferredBitrate(previousBitrate);
        _showSnack('音质切换失败，已恢复原音质');
        return;
      }
      if (currentPosition > Duration.zero) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await _playbackController.seekNative(currentPosition);
      }
    }
    _showToast('已切换音质：${quality.name}');
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

  FreeMusicQuality _fallbackQualityForTier(String tier) {
    switch (tier) {
      case 'standard':
        return const FreeMusicQuality(
          name: '标准',
          bitrate: '48kaac',
          format: 'AAC',
        );
      case 'higher':
        return const FreeMusicQuality(
          name: '较高',
          bitrate: '128kmp3',
          format: 'MP3',
        );
      case 'extreme':
        return const FreeMusicQuality(
          name: '极高',
          bitrate: '320kmp3',
          format: 'MP3',
        );
      case 'lossless':
        return const FreeMusicQuality(
          name: '无损',
          bitrate: 'flac',
          format: 'FLAC',
        );
    }
    return const FreeMusicQuality(name: '极高', bitrate: '320kmp3');
  }

  String _qualitySubtitle(FreeMusicQuality quality, {required bool detected}) {
    final String detail = <String>[
      if (quality.format.isNotEmpty) quality.format,
      if (quality.size.isNotEmpty) quality.size,
      if (quality.bitrate.isNotEmpty) quality.bitrate,
    ].join(' · ');
    if (detected && detail.isNotEmpty) {
      return detail;
    }
    if (detail.isEmpty) {
      return '保存为默认播放偏好';
    }
    return '请求 $detail';
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

    final FreeMusicQuality? detectedStandardQuality = pickClosestLossy(
      48,
      where: (FreeMusicQuality quality) =>
          _parseBitrateValue(quality.bitrate) < 128,
    );
    final FreeMusicQuality? detectedHigherQuality = pickClosestLossy(
      128,
      where: (FreeMusicQuality quality) =>
          _parseBitrateValue(quality.bitrate) >= 128 &&
          _parseBitrateValue(quality.bitrate) < 192,
    );
    final FreeMusicQuality? detectedExtremeQuality = pickHighestLossy(
      where: (FreeMusicQuality quality) =>
          _parseBitrateValue(quality.bitrate) >= 192,
    );
    final FreeMusicQuality? detectedLosslessQuality = _highestQuality(
      losslessQualities,
      const <String>{},
    );

    _QualitySheetOption option(
      String tier,
      String label,
      FreeMusicQuality? quality,
    ) {
      final bool detected = quality != null;
      final FreeMusicQuality resolved =
          quality ?? _fallbackQualityForTier(tier);
      return _QualitySheetOption(
        tier: tier,
        label: label,
        subtitle: _qualitySubtitle(resolved, detected: detected),
        quality: resolved,
      );
    }

    return <_QualitySheetOption>[
      option('standard', '标准', detectedStandardQuality),
      option('higher', '较高', detectedHigherQuality),
      option('extreme', '极高', detectedExtremeQuality),
      option('lossless', '无损', detectedLosslessQuality),
    ];
  }

  void _showQualitySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        final ColorScheme colors = theme.colorScheme;
        final List<FreeMusicQuality> qualities =
            _trackMetadataController.currentQualities;
        final bool busy = _trackMetadataController.isLoadingQualities;
        final String error = _trackMetadataController.qualityError;

        Widget content;
        if (busy) {
          content = Padding(
            padding: const EdgeInsets.all(AppSpace.xl3),
            child: Center(child: LuxuryLoadingIndicator()),
          );
        } else {
          final String selectedQualityTier = _qualityTierValue(
            preferredBitrate,
          );
          final List<_QualitySheetOption> qualityOptions = _qualitySheetOptions(
            qualities,
          );
          content = Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl,
                    AppSpace.sm,
                    AppSpace.xl,
                    AppSpace.xs,
                  ),
                  child: Text(
                    '当前歌曲品质信息暂不可用，仍可手动设置默认音质。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ListView.separated(
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
                  final FreeMusicQuality quality = option.quality;
                  final bool isSelected = option.tier == selectedQualityTier;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    tileColor: isSelected
                        ? colors.primaryContainer.withValues(alpha: 0.25)
                        : null,
                    leading: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    title: Text(
                      option.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      option.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      unawaited(_changePlaybackQuality(quality));
                    },
                  );
                },
              ),
            ],
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
    final NativePlaybackMode mode = await _playbackController
        .cyclePlaybackMode();
    if (!mounted) {
      return;
    }
    final MusicAudioHandler? handler = widget.audioHandler;
    if (handler != null) {
      await handler.setRepeatMode(_repeatModeForNativeMode(mode));
      await handler.setShuffleMode(_shuffleModeForNativeMode(mode));
    }
    setState(() {
      _queueController.setPlaybackMode(mode);
    });
  }

  Future<void> _handleSetRepeatModeFromSession(
    AudioServiceRepeatMode repeatMode,
  ) async {
    final NativePlaybackMode mode;
    switch (repeatMode) {
      case AudioServiceRepeatMode.one:
        mode = NativePlaybackMode.repeatOne;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        mode = NativePlaybackMode.repeatAll;
      case AudioServiceRepeatMode.none:
        mode = playbackMode == NativePlaybackMode.shuffle
            ? NativePlaybackMode.shuffle
            : NativePlaybackMode.sequential;
    }
    await _playbackController.setPlaybackMode(mode);
    if (!mounted) return;
    setState(() {
      _queueController.setPlaybackMode(mode);
    });
  }

  Future<void> _handleSetShuffleModeFromSession(
    AudioServiceShuffleMode shuffleMode,
  ) async {
    final NativePlaybackMode mode = shuffleMode == AudioServiceShuffleMode.none
        ? NativePlaybackMode.sequential
        : NativePlaybackMode.shuffle;
    await _playbackController.setPlaybackMode(mode);
    if (!mounted) return;
    setState(() {
      _queueController.setPlaybackMode(mode);
    });
  }

  Future<void> _togglePlayback(bool playing) async {
    await _playbackController.togglePlayback(playing);
  }

  Future<void> _seekPlayback(Duration position) async {
    await _playbackController.seekPlayback(position);
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
    final CarLifePlaybackContext? context = _buildCarLifePlaybackContext();
    if (context == null) {
      if (showResult) {
        _showSnack('请先播放一首歌，再同步到 CarLife。');
      }
      return;
    }

    if (_isSyncingCarLife) {
      _pendingSyncContext = context;
      return;
    }
    _pendingSyncContext = null;
    setState(() {
      _isSyncingCarLife = true;
    });

    try {
      final CarLifeSyncResult result = await _carLifeService
          .syncPlaybackContext(
            title: context.title,
            artist: context.artist,
            playing: context.playing,
            context: context,
          );
      if (!mounted) {
        return;
      }
      if (showResult) {
        if (result.reason == 'sdk_connected') {
          _showToast('已同步到 CarLife：${result.syncedTitle}');
        } else if (result.reason == 'sdk_initialized') {
          _showToast('已提交 CarLife 队列模板，等待 CarLife 连接读取。');
        } else if (result.reason == 'app_key_missing') {
          _showSnack('CarLife SDK 已接入，请先配置 AppKey。');
        } else if (result.reason == 'sdk_missing') {
          _showToast('已缓存播放上下文，等待 CarLife SDK 接管同步。');
        } else {
          _showSnack('CarLife 同步不可用：${result.reason}');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingCarLife = false;
        });
        if (_pendingSyncContext != null) {
          unawaited(_syncCarLifePlaybackContext(showResult: false));
        }
      }
    }
  }

  CarLifePlaybackContext? _buildCarLifePlaybackContext() {
    final FreeMusicSong? song = _currentSong;
    if (song == null) {
      return null;
    }
    final MusicAudioHandler? handler = widget.audioHandler;
    final MediaItem? mediaItem = handler?.mediaItem.valueOrNull;
    final PlaybackUiState playbackState = this.playbackState;
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

  void _startLyricBroadcastTimer() {
    _lyricBroadcastTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sendLyricBroadcast();
    });
  }

  void _sendLyricBroadcast() {
    final FreeMusicSong? song = _currentSong;
    final FreeMusicLyrics? lyrics = _trackMetadataController.currentLyrics;
    if (song == null) return;

    final PlaybackUiState state = playbackState;
    final Duration position = state.position;

    String currentLyric = '';
    if (lyrics != null && lyrics.lines.isNotEmpty) {
      final int activeIndex = activeLyricLineIndex(
        lyrics.lines,
        position,
        lead: lyricHighlightLead,
      );
      if (activeIndex >= 0 && activeIndex < lyrics.lines.length) {
        currentLyric = lyrics.lines[activeIndex].text;
      }
    }

    unawaited(
      _carLifeService.sendLyricBroadcast(
        lyric: currentLyric,
        title: song.name,
        artist: song.artist,
        album: song.album,
        duration: song.duration > 0
            ? Duration(seconds: song.duration)
            : (state.duration ?? Duration.zero),
        position: position,
        playing: state.playing,
      ),
    );
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

  void _showToast(String message) {
    if (!mounted) {
      return;
    }
    _activeToastEntry?.remove();
    _activeToastEntry = null;

    final OverlayState overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext context) => _ToastWidget(
        message: message,
        onDismiss: () {
          if (_activeToastEntry == entry) {
            _activeToastEntry = null;
          }
          entry.remove();
        },
      ),
    );
    _activeToastEntry = entry;
    overlay.insert(entry);
  }

  // ==========================================
  // Public Getters for MusicAppStateScope
  // ==========================================
  int get selectedTab => _selectedTab;
  int get selectedQueueIndex => _selectedQueueIndex;
  List<FreeMusicSong> get playbackQueue => _playbackQueue;
  List<FreeMusicSong> get favoriteSongs => _libraryController.favoriteSongs;
  Set<String> get favoriteSongKeys => _favoriteSongKeys;
  bool get isLoadingFavorites => _libraryController.isLoadingFavorites;
  FreeMusicSong? get currentSong => _currentSong;
  Color get coverSeedColor => _coverSeedColor;
  TextEditingController get searchController => _searchController;
  List<FreeMusicSong> get searchResults => _musicSearchController.searchResults;
  bool get isSearchingMusic => _musicSearchController.isSearching;
  bool get isLoadingMoreSearchResults => _musicSearchController.isLoadingMore;
  bool get searchHasMore => _musicSearchController.searchHasMore;
  String get searchError => _musicSearchController.searchError;
  String get searchLoadMoreError => _musicSearchController.searchLoadMoreError;
  String get lastSearchQuery => _musicSearchController.lastSearchQuery;

  Future<void> retryLyricsForCurrentSong() async {
    if (_currentSong != null) {
      await _loadLyricsForSong(_currentSong!);
    }
  }

  Future<void> syncCarLifeManually() =>
      _syncCarLifePlaybackContext(showResult: true);
  FreeMusicSources? get musicSources => _musicSources;
  bool get isLoadingApiBootstrap => _isLoadingApiBootstrap;
  String get apiBootstrapError => _apiBootstrapError;
  List<String> get hotSearchKeywords => _hotSearchKeywords;
  List<FreeMusicPlaylist> get recommendedPlaylists {
    return _musicSearchController.recommendedPlaylists;
  }

  bool get isLoadingRecommendations {
    return _musicSearchController.isLoadingRecommendations;
  }

  String get recommendationError => _musicSearchController.recommendationError;
  NativePlaybackMode get playbackMode => _queueController.playbackMode;
  FreeMusicLyrics? get currentLyrics => _trackMetadataController.currentLyrics;
  bool get isLoadingLyrics => _trackMetadataController.isLoadingLyrics;
  String get lyricsError => _trackMetadataController.lyricsError;
  List<FreeMusicQuality> get currentQualities =>
      _trackMetadataController.currentQualities;
  bool get isLoadingQualities => _trackMetadataController.isLoadingQualities;
  String get qualityError => _trackMetadataController.qualityError;
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

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    final QueueReorderResult? result = _queueController.previewReorder(
      oldIndex,
      newIndex,
    );
    if (result == null) return;

    await _nativeAudioController.syncQueueFromProbe(
      PlayerProbeSnapshot(
        audioUrl: '',
        playing: _nativeAudioController.playing,
        song: result.currentSong,
        playlist: result.queue,
        currentIndex: result.nextIndex,
      ),
    );

    if (!mounted) return;
    setState(() {
      _queueController.reorder(oldIndex, newIndex);
    });
  }

  Future<void> removeQueueItem(int index) async {
    final QueueRemovalResult? result = _queueController.previewRemoveAt(index);
    if (result == null) {
      if (index >= 0 && _playbackQueue.length <= 1) {
        _showToast('队列中至少保留一首歌曲');
      }
      return;
    }

    await _nativeAudioController.syncQueueFromProbe(
      PlayerProbeSnapshot(
        audioUrl: '',
        playing: _nativeAudioController.playing,
        song: result.nextCurrentSong,
        playlist: result.queue,
        currentIndex: result.nextIndex,
      ),
    );

    if (!mounted) return;
    setState(() {
      _queueController.removeAt(index);
    });
    _showToast('已从队列移除：${result.removedSong.name}');
  }

  Future<void> skipToQueueIndex(int index) => _skipToQueueItem(index);
  Future<void> skipToQueueItem(int index) => _skipToQueueItem(index);
  Future<void> searchSongs() => _searchSongs();
  Future<void> loadMoreSearchResults() => _loadMoreSearchResults();
  Future<void> retryLoadRecommendations() => _loadRecommendations();
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
  Future<bool> skipToPreviousTrack() => _playbackController.skipToPrevious();
  Future<bool> skipToNextTrack() => _playbackController.skipToNext();
  Future<void> openCarLife() => _openCarLife();
  Future<void> syncCarLifePlaybackContext({required bool showResult}) =>
      _syncCarLifePlaybackContext(showResult: showResult);
  Future<void> refreshCarLifeStatus() => _refreshCarLifeStatus();
  Future<void> checkForUpdate() => _checkForUpdate();

  Future<void> copyDiagnostics() async {
    final String payload = _telemetry.exportJson(
      app: <String, Object?>{
        'version': '1.0.73',
        'build': 10073,
        'currentSource': _currentSong?.source,
        'queueLength': _playbackQueue.length,
        'selectedQueueIndex': _selectedQueueIndex,
        'playbackMode': playbackMode.storageValue,
        'preferredBitrate': preferredBitrate,
      },
    );
    await Clipboard.setData(ClipboardData(text: payload));
    _showToast('诊断信息已复制');
  }

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
      playbackMode: playbackMode,
      searchResults: _musicSearchController.searchResults,
      favoriteSongs: _libraryController.favoriteSongs,
      selectedTab: _selectedTab,
      isLoadingRecommendations: _musicSearchController.isLoadingRecommendations,
      isLoadingApiBootstrap: _isLoadingApiBootstrap,
      recommendationError: _musicSearchController.recommendationError,
      apiBootstrapError: _apiBootstrapError,
      child: const PortraitMusicScaffold(),
    );
  }
}

class _QualitySheetOption {
  const _QualitySheetOption({
    required this.tier,
    required this.label,
    required this.subtitle,
    required this.quality,
  });

  final String tier;
  final String label;
  final String subtitle;
  final FreeMusicQuality quality;
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

// ==========================================
// Toast Widget with Premium Aesthetics
// ==========================================
class _ToastWidget extends StatefulWidget {
  const _ToastWidget({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 40,
      left: 24,
      right: 24,
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: Colors.black.withValues(alpha: 0.65),
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
