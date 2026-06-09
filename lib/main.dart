import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'free_music_api.dart';
import 'music_audio_handler.dart';
import 'models/app_update_info.dart';
import 'native_audio_controller.dart';
import 'services/app_installer_service.dart';
import 'services/carlife_service.dart';
import 'services/update_check_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await WakelockPlus.enable();

  final MusicAudioHandler audioHandler = await initMusicAudioHandler();

  runApp(MusicCarApp(audioHandler: audioHandler));
}

class MusicCarApp extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '车载音乐',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'sans',
        colorScheme: const ColorScheme.dark(
          primary: _AppColors.primary,
          secondary: _AppColors.accent,
          surface: _AppColors.surface,
          error: _AppColors.error,
        ),
        scaffoldBackgroundColor: _AppColors.background,
        splashFactory: NoSplash.splashFactory,
        useMaterial3: true,
      ),
      home:
          homeOverride ??
          NativeMusicHomePage(
            audioHandler: audioHandler,
            autoCheckForUpdates: autoCheckForUpdates,
          ),
    );
  }
}

class NativeMusicHomePage extends StatefulWidget {
  const NativeMusicHomePage({
    super.key,
    this.audioHandler,
    this.autoCheckForUpdates = true,
  });

  final MusicAudioHandler? audioHandler;
  final bool autoCheckForUpdates;

  @override
  State<NativeMusicHomePage> createState() => _NativeMusicHomePageState();
}

class _NativeMusicHomePageState extends State<NativeMusicHomePage>
    with WidgetsBindingObserver {
  late final NativeAudioController _nativeAudioController;
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
  bool _isLoadingPlaylistSongs = false;
  bool _isLoadingLyrics = false;
  bool _isLoadingApiBootstrap = false;
  bool _isLoadingQualities = false;
  bool _syncingSessionPlaybackMode = false;
  int _searchRequestId = 0;
  String _searchError = '';
  String _searchLoadMoreError = '';
  String _recommendationError = '';
  String _playlistError = '';
  String _lyricsError = '';
  String _apiBootstrapError = '';
  String _qualityError = '';
  String _lastSearchQuery = '';
  FreeMusicSources? _musicSources;
  FreeMusicLyrics? _currentLyrics;
  List<String> _hotSearchKeywords = const <String>[];
  List<FreeMusicQuality> _currentQualities = const <FreeMusicQuality>[];
  FreeMusicSong? _currentSong;
  FreeMusicPlaylist? _activePlaylist;
  int _playlistTotal = 0;
  int _playlistOffset = 0;
  int _searchPage = 0;
  bool _searchHasMore = false;
  List<FreeMusicSong> _searchResults = const <FreeMusicSong>[];
  List<FreeMusicPlaylist> _recommendedPlaylists = const <FreeMusicPlaylist>[];
  List<FreeMusicSong> _playlistSongs = const <FreeMusicSong>[];
  List<FreeMusicSong> _playbackQueue = const <FreeMusicSong>[];
  NativePlaybackMode _playbackMode = NativePlaybackMode.sequential;
  int _selectedTab = 0;
  int _selectedQueueIndex = 0;

  @override
  void initState() {
    super.initState();
    _nativeAudioController = NativeAudioController(player: widget.audioHandler);
    widget.audioHandler?.onPlayTrack = _resumeNativePlayback;
    widget.audioHandler?.onSkipToNextTrack = _skipToNextTrack;
    widget.audioHandler?.onSkipToPreviousTrack = _skipToPreviousTrack;
    widget.audioHandler?.onSkipToQueueItem = _skipToQueueItem;
    widget.audioHandler?.onSetRepeatMode = _setRepeatModeFromSession;
    widget.audioHandler?.onSetShuffleMode = _setShuffleModeFromSession;
    _carLifeService.setControlHandler(_handleCarLifeControl);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadApiBootstrap());
      unawaited(_loadRecommendations());
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
          .fetchRecommendations(sources: _activeSourceIds);
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

  Future<void> _playRecommendedPlaylist(FreeMusicPlaylist playlist) async {
    if (_isLoadingPlaylistSongs) {
      return;
    }
    setState(() {
      _activePlaylist = playlist;
      _playlistSongs = const <FreeMusicSong>[];
      _playlistTotal = 0;
      _playlistOffset = 0;
    });
    await _loadPlaylistSongs(reset: true);
    if (mounted && _playlistSongs.isNotEmpty) {
      _showPlaylistSheet();
    }
  }

  Future<void> _loadPlaylistSongs({required bool reset}) async {
    final FreeMusicPlaylist? playlist = _activePlaylist;
    if (playlist == null || _isLoadingPlaylistSongs) {
      return;
    }
    final int offset = reset ? 0 : _playlistOffset;
    setState(() {
      _isLoadingPlaylistSongs = true;
      _playlistError = '';
    });
    try {
      final FreeMusicPlaylistPage page = await _freeMusicApi.fetchPlaylistSongs(
        playlist,
        offset: offset,
        size: 30,
      );
      if (!mounted) {
        return;
      }
      final List<FreeMusicSong> nextSongs = reset
          ? page.songs
          : <FreeMusicSong>[..._playlistSongs, ...page.songs];
      if (page.songs.isEmpty) {
        setState(() {
          _isLoadingPlaylistSongs = false;
          _playlistError = reset ? '歌单暂无可播放歌曲' : '没有更多歌曲';
        });
        return;
      }
      setState(() {
        _playlistSongs = List<FreeMusicSong>.unmodifiable(nextSongs);
        _playlistTotal = page.total;
        _playlistOffset = nextSongs.length;
        _isLoadingPlaylistSongs = false;
      });
    } on FreeMusicApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playlistError = error.message;
        _isLoadingPlaylistSongs = false;
      });
      _showSnack(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playlistError = '歌单加载失败：$error';
        _isLoadingPlaylistSongs = false;
      });
      _showSnack('歌单加载失败：$error');
    }
  }

  Future<void> _playPlaylistSong(int index) async {
    if (index < 0 || index >= _playlistSongs.length) {
      return;
    }
    await _playSongQueue(_playlistSongs, index);
    if (!mounted) {
      return;
    }
    setState(() {
      _searchResults = _playlistSongs;
    });
  }

  void _showPlaylistSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter sheetSetState) {
            return _PlaylistSheet(
              playlist: _activePlaylist,
              songs: _playlistSongs,
              total: _playlistTotal,
              busy: _isLoadingPlaylistSongs,
              error: _playlistError,
              canLoadMore:
                  _playlistTotal == 0 || _playlistSongs.length < _playlistTotal,
              onPlay: (int index) {
                unawaited(_playPlaylistSong(index));
              },
              onLoadMore: () {
                unawaited(() async {
                  final Future<void> loadFuture = _loadPlaylistSongs(
                    reset: false,
                  );
                  sheetSetState(() {});
                  await loadFuture;
                  if (mounted) {
                    sheetSetState(() {});
                  }
                }());
              },
            );
          },
        );
      },
    );
  }

  Future<void> _playSearchResult(int index) async {
    if (index < 0 || index >= _searchResults.length) {
      return;
    }
    await _playSongQueue(_searchResults, index);
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
      return;
    }
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
    } on FreeMusicApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lyricsError = error.message;
        _isLoadingLyrics = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lyricsError = '歌词加载失败：$error';
        _isLoadingLyrics = false;
      });
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

  void _showLyricsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final MusicAudioHandler? handler = widget.audioHandler;
        if (handler == null) {
          return _LyricsSheet(
            songTitle: _currentSong?.name ?? '',
            artist: _currentSong?.artist ?? '',
            lyrics: _currentLyrics,
            loading: _isLoadingLyrics,
            error: _lyricsError,
            position: Duration.zero,
          );
        }
        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          initialData: handler.playbackState.valueOrNull,
          builder:
              (BuildContext context, AsyncSnapshot<PlaybackState> snapshot) {
                return _LyricsSheet(
                  songTitle: _currentSong?.name ?? '',
                  artist: _currentSong?.artist ?? '',
                  lyrics: _currentLyrics,
                  loading: _isLoadingLyrics,
                  error: _lyricsError,
                  position: snapshot.data?.position ?? Duration.zero,
                );
              },
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
            final _DemoTrack currentTrack =
                _demoQueue[_selectedQueueIndex % _demoQueue.length];
            return _NativeMusicScaffold(
              selectedTab: _selectedTab,
              selectedQueueIndex: _selectedQueueIndex,
              queueSongs: _playbackQueue,
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
              recommendationError: _playlistError.isEmpty
                  ? _recommendationError
                  : _playlistError,
              playlistSongsBusy: _isLoadingPlaylistSongs,
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
              onSelectPlaylist: (FreeMusicPlaylist playlist) {
                unawaited(_playRecommendedPlaylist(playlist));
              },
              onPlayPause: () => _togglePlayback(playbackState.playing),
              onPlaybackMode: () {
                unawaited(_cyclePlaybackMode());
              },
              onLyrics: _showLyricsSheet,
              onPrevious: _skipToPreviousTrack,
              onNext: _skipToNextTrack,
              onOpenCarLife: _openCarLife,
              onSyncCarLife: () {
                unawaited(_syncCarLifePlaybackContext(showResult: true));
              },
              onRefreshCarLife: _refreshCarLifeStatus,
              onCheckUpdate: _checkForUpdate,
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

class PlaybackUiState {
  const PlaybackUiState({
    this.playing = false,
    this.title = '',
    this.artist = '',
    this.coverUrl = '',
    this.position = Duration.zero,
    this.duration,
  });

  factory PlaybackUiState.fromAudioService(
    PlaybackState? state,
    MediaItem? item,
  ) {
    return PlaybackUiState(
      playing: state?.playing ?? false,
      title: item?.title ?? '',
      artist: item?.artist ?? '',
      coverUrl: item?.artUri?.toString() ?? '',
      position: state?.position ?? Duration.zero,
      duration: item?.duration,
    );
  }

  final bool playing;
  final String title;
  final String artist;
  final String coverUrl;
  final Duration position;
  final Duration? duration;
}

class _NativeMusicScaffold extends StatelessWidget {
  const _NativeMusicScaffold({
    required this.selectedTab,
    required this.selectedQueueIndex,
    required this.queueSongs,
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
    required this.onSelectPlaylist,
    required this.onPlayPause,
    required this.onPlaybackMode,
    required this.onLyrics,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenCarLife,
    required this.onSyncCarLife,
    required this.onRefreshCarLife,
    required this.onCheckUpdate,
  });

  final int selectedTab;
  final int selectedQueueIndex;
  final List<FreeMusicSong> queueSongs;
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
  final _DemoTrack currentTrack;
  final CarLifeStatus carLifeStatus;
  final bool updateBusy;
  final bool carLifeBusy;
  final ValueChanged<int> onSelectTab;
  final ValueChanged<int> onSelectQueueIndex;
  final VoidCallback onSearch;
  final VoidCallback onLoadMoreSearchResults;
  final ValueChanged<int> onPlaySearchResult;
  final ValueChanged<FreeMusicPlaylist> onSelectPlaylist;
  final VoidCallback onPlayPause;
  final VoidCallback onPlaybackMode;
  final VoidCallback onLyrics;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onOpenCarLife;
  final VoidCallback onSyncCarLife;
  final VoidCallback onRefreshCarLife;
  final VoidCallback onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    void runSearchFromCurrentSurface() {
      if (selectedTab != 1) {
        onSelectTab(1);
      }
      onSearch();
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _AtmosphereBackground(track: currentTrack),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool showNowPlayingPanel =
                constraints.maxWidth >= 980 &&
                selectedTab != 2 &&
                selectedTab != 3;
            final Widget centerPanel = switch (selectedTab) {
              2 => _QueuePanel(
                selectedIndex: selectedQueueIndex,
                songs: queueSongs,
                onSelect: onSelectQueueIndex,
              ),
              3 => _NowPlayingFullScreenPanel(
                track: currentTrack,
                playbackState: playbackState,
                playbackMode: playbackMode,
                lyrics: lyrics,
                lyricsAvailable: lyricsAvailable,
                lyricsBusy: lyricsBusy,
                lyricsError: lyricsError,
                qualities: qualities,
                qualitiesBusy: qualitiesBusy,
                qualityError: qualityError,
                onPlayPause: onPlayPause,
                onPlaybackMode: onPlaybackMode,
                onLyrics: onLyrics,
                onPrevious: onPrevious,
                onNext: onNext,
              ),
              4 => _SettingsPanel(
                carLifeStatus: carLifeStatus,
                carLifeBusy: carLifeBusy,
                updateBusy: updateBusy,
                onOpenCarLife: onOpenCarLife,
                onSyncCarLife: onSyncCarLife,
                onRefreshCarLife: onRefreshCarLife,
                onCheckUpdate: onCheckUpdate,
              ),
              _ => _HomePanel(
                selectedTab: selectedTab,
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
                carLifeStatus: carLifeStatus,
                carLifeBusy: carLifeBusy,
                onSearch: runSearchFromCurrentSurface,
                onLoadMoreSearchResults: onLoadMoreSearchResults,
                onPlaySearchResult: onPlaySearchResult,
                onSelectPlaylist: onSelectPlaylist,
                onOpenCarLife: onOpenCarLife,
                onSyncCarLife: onSyncCarLife,
                onRefreshCarLife: onRefreshCarLife,
              ),
            };
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          _SideNavigationRail(
                            compact: constraints.maxHeight < 620,
                            selectedIndex: selectedTab,
                            updateBusy: updateBusy,
                            onSelect: onSelectTab,
                            onCheckUpdate: onCheckUpdate,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: showNowPlayingPanel ? 7 : 10,
                            child: centerPanel,
                          ),
                          if (showNowPlayingPanel) ...<Widget>[
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 5,
                              child: _NowPlayingPanel(
                                track: currentTrack,
                                playbackState: playbackState,
                                playbackMode: playbackMode,
                                onPlayPause: onPlayPause,
                                onPlaybackMode: onPlaybackMode,
                                onPrevious: onPrevious,
                                onNext: onNext,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MiniPlayerBar(
                      track: currentTrack,
                      playbackState: playbackState,
                      playbackMode: playbackMode,
                      lyricsAvailable: lyricsAvailable,
                      lyricsBusy: lyricsBusy,
                      onPlayPause: onPlayPause,
                      onPlaybackMode: onPlaybackMode,
                      onLyrics: onLyrics,
                      onPrevious: onPrevious,
                      onNext: onNext,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AtmosphereBackground extends StatelessWidget {
  const _AtmosphereBackground({required this.track});

  final _DemoTrack track;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.62, -0.74),
          radius: 1.35,
          colors: <Color>[
            track.color.withValues(alpha: 0.58),
            _AppColors.background,
            const Color(0xFF02040A),
          ],
          stops: const <double>[0, 0.52, 1],
        ),
      ),
      child: CustomPaint(painter: _NoiseRibbonPainter(track.color)),
    );
  }
}

class _NoiseRibbonPainter extends CustomPainter {
  const _NoiseRibbonPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.10),
          color.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);

    final Path path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.12)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.04,
        size.width * 0.50,
        size.height * 0.44,
        size.width * 0.78,
        size.height * 0.20,
      )
      ..cubicTo(
        size.width * 1.05,
        size.height * -0.02,
        size.width * 1.08,
        size.height * 0.52,
        size.width * 0.74,
        size.height * 0.64,
      )
      ..cubicTo(
        size.width * 0.42,
        size.height * 0.76,
        size.width * 0.22,
        size.height * 0.44,
        size.width * 0.06,
        size.height * 0.58,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_NoiseRibbonPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SideNavigationRail extends StatelessWidget {
  const _SideNavigationRail({
    required this.compact,
    required this.selectedIndex,
    required this.updateBusy,
    required this.onSelect,
    required this.onCheckUpdate,
  });

  final bool compact;
  final int selectedIndex;
  final bool updateBusy;
  final ValueChanged<int> onSelect;
  final VoidCallback onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      width: compact ? 92 : 104,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 10 : 14,
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: compact ? 48 : 58,
            height: compact ? 48 : 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 18 : 22),
              gradient: const LinearGradient(
                colors: <Color>[_AppColors.primary, _AppColors.accent],
              ),
            ),
            child: Icon(Icons.music_note_rounded, size: compact ? 28 : 34),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            '车载音乐',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _AppColors.textPrimary,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          for (int index = 0; index < _navItems.length; index += 1)
            _RailButton(
              item: _navItems[index],
              compact: compact,
              selected: selectedIndex == index,
              onTap: () => onSelect(index),
            ),
          const Spacer(),
          _RailIconButton(
            icon: Icons.system_update_rounded,
            label: '更新',
            enabled: !updateBusy,
            onTap: onCheckUpdate,
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.compact,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 6 : 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: compact ? 64 : 74,
          padding: EdgeInsets.symmetric(vertical: compact ? 7 : 10),
          decoration: BoxDecoration(
            color: selected
                ? _AppColors.primary.withValues(alpha: 0.24)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.20)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            children: <Widget>[
              Icon(
                item.icon,
                color: selected ? Colors.white : _AppColors.textMuted,
                size: compact ? 22 : 26,
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                item.label,
                style: TextStyle(
                  color: selected ? Colors.white : _AppColors.textMuted,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailIconButton extends StatelessWidget {
  const _RailIconButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = enabled
        ? _AppColors.textMuted
        : const Color(0x66FFFFFF);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: <Widget>[
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePanel extends StatelessWidget {
  const _HomePanel({
    required this.selectedTab,
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
    required this.carLifeStatus,
    required this.carLifeBusy,
    required this.onSearch,
    required this.onLoadMoreSearchResults,
    required this.onPlaySearchResult,
    required this.onSelectPlaylist,
    required this.onOpenCarLife,
    required this.onSyncCarLife,
    required this.onRefreshCarLife,
  });

  final int selectedTab;
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
  final CarLifeStatus carLifeStatus;
  final bool carLifeBusy;
  final VoidCallback onSearch;
  final VoidCallback onLoadMoreSearchResults;
  final ValueChanged<int> onPlaySearchResult;
  final ValueChanged<FreeMusicPlaylist> onSelectPlaylist;
  final VoidCallback onOpenCarLife;
  final VoidCallback onSyncCarLife;
  final VoidCallback onRefreshCarLife;

  @override
  Widget build(BuildContext context) {
    final _NavItem activeItem = _navItems[selectedTab];
    final bool searchMode = selectedTab == 1;
    void searchKeyword(String keyword) {
      searchController.text = keyword;
      onSearch();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    activeItem.label,
                    style: TextStyle(
                      color: _AppColors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    searchMode
                        ? '输入歌名、歌手或专辑，结果直接进入原生队列。'
                        : '在线曲库 · 推荐歌单 · 横屏车机布局',
                    style: const TextStyle(
                      color: _AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (!searchMode) _SearchPill(onTap: onSearch, compact: false),
          ],
        ),
        const SizedBox(height: 18),
        if (searchMode)
          Expanded(
            child: _SearchPanel(
              controller: searchController,
              songs: searchResults,
              busy: searchBusy,
              loadMoreBusy: searchMoreBusy,
              canLoadMore: searchCanLoadMore,
              error: searchError,
              loadMoreError: searchLoadMoreError,
              query: lastSearchQuery,
              hotSearchKeywords: hotSearchKeywords,
              onSearch: onSearch,
              onHotKeyword: searchKeyword,
              onLoadMore: onLoadMoreSearchResults,
              onPlay: onPlaySearchResult,
            ),
          )
        else
          Expanded(
            child: _HomeDiscoveryPanel(
              controller: searchController,
              recommendedPlaylists: recommendedPlaylists,
              recommendationsBusy: recommendationsBusy,
              recommendationError: recommendationError,
              playlistSongsBusy: playlistSongsBusy,
              musicSources: musicSources,
              sourceBusy: sourceBusy,
              sourceError: sourceError,
              hotSearchKeywords: hotSearchKeywords,
              carLifeStatus: carLifeStatus,
              onSearch: onSearch,
              onHotKeyword: searchKeyword,
              onSelectPlaylist: onSelectPlaylist,
            ),
          ),
      ],
    );
  }
}

class _HomeDiscoveryPanel extends StatelessWidget {
  const _HomeDiscoveryPanel({
    required this.controller,
    required this.recommendedPlaylists,
    required this.recommendationsBusy,
    required this.recommendationError,
    required this.playlistSongsBusy,
    required this.musicSources,
    required this.sourceBusy,
    required this.sourceError,
    required this.hotSearchKeywords,
    required this.carLifeStatus,
    required this.onSearch,
    required this.onHotKeyword,
    required this.onSelectPlaylist,
  });

  final TextEditingController controller;
  final List<FreeMusicPlaylist> recommendedPlaylists;
  final bool recommendationsBusy;
  final String recommendationError;
  final bool playlistSongsBusy;
  final FreeMusicSources? musicSources;
  final bool sourceBusy;
  final String sourceError;
  final List<String> hotSearchKeywords;
  final CarLifeStatus carLifeStatus;
  final VoidCallback onSearch;
  final ValueChanged<String> onHotKeyword;
  final ValueChanged<FreeMusicPlaylist> onSelectPlaylist;

  @override
  Widget build(BuildContext context) {
    final List<FreeMusicPlaylist> featured = recommendedPlaylists
        .take(8)
        .toList(growable: false);
    final List<String> activeSources =
        musicSources?.activeSources ?? const <String>[];
    return _GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '在线曲库',
                  style: TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (recommendationsBusy || playlistSongsBusy)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                _ChipLabel(text: '${recommendedPlaylists.length} 个推荐源'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                  style: const TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: InputDecoration(
                    hintText: '搜索音乐',
                    hintStyle: const TextStyle(
                      color: _AppColors.textMuted,
                      fontWeight: FontWeight.w800,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.09),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.manage_search_rounded),
                label: const Text('搜索'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (sourceBusy)
                const _ChipLabel(text: '来源加载中')
              else if (sourceError.isNotEmpty)
                const _ChipLabel(text: '来源可重试')
              else
                for (final String source in activeSources.take(4))
                  _ChipLabel(text: musicSources?.labelFor(source) ?? source),
              for (final String keyword in hotSearchKeywords.take(4))
                _ActionChipLabel(
                  text: keyword,
                  onTap: () => onHotKeyword(keyword),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '为你推荐',
                  style: TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (recommendationError.isNotEmpty)
                _ChipLabel(text: '推荐加载失败')
              else
                const _ChipLabel(text: '横向浏览'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: recommendationError.isNotEmpty && featured.isEmpty
                ? _InlineMessage(text: recommendationError)
                : featured.isEmpty
                ? const _FallbackRecommendationRail()
                : _PlaylistCardRail(
                    playlists: featured,
                    busy: playlistSongsBusy,
                    onSelect: onSelectPlaylist,
                  ),
          ),
          const SizedBox(height: 14),
          _HomeReadinessStrip(
            recommendationsBusy: recommendationsBusy,
            recommendationError: recommendationError,
            carLifeStatus: carLifeStatus,
          ),
        ],
      ),
    );
  }
}

class _PlaylistCardRail extends StatelessWidget {
  const _PlaylistCardRail({
    required this.playlists,
    required this.busy,
    required this.onSelect,
  });

  final List<FreeMusicPlaylist> playlists;
  final bool busy;
  final ValueChanged<FreeMusicPlaylist> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: playlists.length,
      separatorBuilder: (_, _) => const SizedBox(width: 14),
      itemBuilder: (BuildContext context, int index) {
        final FreeMusicPlaylist playlist = playlists[index];
        return _FeaturedPlaylistCard(
          playlist: playlist,
          visual: _demoQueue[index % _demoQueue.length],
          onTap: busy ? null : () => onSelect(playlist),
        );
      },
    );
  }
}

class _FeaturedPlaylistCard extends StatelessWidget {
  const _FeaturedPlaylistCard({
    required this.playlist,
    required this.visual,
    required this.onTap,
  });

  final FreeMusicPlaylist playlist;
  final _DemoTrack visual;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        width: 188,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _ArtworkView(
                track: visual,
                imageUrl: playlist.cover,
                size: 164,
                radius: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              <String>[
                if (playlist.creator.isNotEmpty) playlist.creator,
                playlist.source,
                if (playlist.trackCount > 0)
                  '${_formatCount(playlist.trackCount)}首',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackRecommendationRail extends StatelessWidget {
  const _FallbackRecommendationRail();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _recentTracks.length,
      separatorBuilder: (_, _) => const SizedBox(width: 14),
      itemBuilder: (BuildContext context, int index) {
        final _DemoTrack track = _recentTracks[index];
        return Container(
          width: 188,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _ArtworkTile(track: track, size: 164, radius: 18),
              ),
              const SizedBox(height: 10),
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeReadinessStrip extends StatelessWidget {
  const _HomeReadinessStrip({
    required this.recommendationsBusy,
    required this.recommendationError,
    required this.carLifeStatus,
  });

  final bool recommendationsBusy;
  final String recommendationError;
  final CarLifeStatus carLifeStatus;

  @override
  Widget build(BuildContext context) {
    final String apiText = recommendationsBusy
        ? 'API 加载中'
        : recommendationError.isEmpty
        ? 'API 已接入'
        : 'API 可重试';
    final String carLifeText = carLifeStatus.reason == 'unchecked'
        ? 'CarLife 待检测'
        : 'CarLife ${carLifeStatus.displayText}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.cloud_done_rounded,
            color: _AppColors.textSecondary,
            size: 19,
          ),
          const SizedBox(width: 8),
          Text(
            apiText,
            style: const TextStyle(
              color: _AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 14),
          const Icon(
            Icons.directions_car_filled_rounded,
            color: _AppColors.textMuted,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              carLifeText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarLifeCard extends StatelessWidget {
  const _CarLifeCard({
    required this.status,
    required this.busy,
    required this.onOpen,
    required this.onSync,
    required this.onRefresh,
  });

  final CarLifeStatus status;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onSync;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      height: 188,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _AppColors.carlife.withValues(alpha: 0.24),
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  color: _AppColors.carlife,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '百度 CarLife',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            status.displayText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status.sdkLinked ? '可同步模板和控制。' : '可缓存当前队列，等待 SDK 接入。',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _AppColors.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: _AppColors.carlife,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(status.launchable ? '打开' : '安装'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '同步当前播放',
                onPressed: busy ? null : onSync,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                color: _AppColors.textSecondary,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '刷新状态',
                onPressed: busy ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                color: _AppColors.textSecondary,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.carLifeStatus,
    required this.carLifeBusy,
    required this.updateBusy,
    required this.onOpenCarLife,
    required this.onSyncCarLife,
    required this.onRefreshCarLife,
    required this.onCheckUpdate,
  });

  final CarLifeStatus carLifeStatus;
  final bool carLifeBusy;
  final bool updateBusy;
  final VoidCallback onOpenCarLife;
  final VoidCallback onSyncCarLife;
  final VoidCallback onRefreshCarLife;
  final VoidCallback onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '设置',
          style: TextStyle(
            color: _AppColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '系统能力入口集中在这里，首页只保留播放和曲库任务。',
          style: TextStyle(
            color: _AppColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _GlassCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '车机集成',
                  style: TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 300,
                  child: _CarLifeCard(
                    status: carLifeStatus,
                    busy: carLifeBusy,
                    onOpen: onOpenCarLife,
                    onSync: onSyncCarLife,
                    onRefresh: onRefreshCarLife,
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(color: Color(0x22FFFFFF)),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: _AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '应用更新',
                            style: TextStyle(
                              color: _AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '保持远程构建路径，车机端只负责检查和安装发布产物。',
                            style: TextStyle(
                              color: _AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: updateBusy ? null : onCheckUpdate,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(updateBusy ? '检查中' : '检查更新'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onTap, required this.compact});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: _GlassCard(
        width: compact ? 178 : 250,
        height: 56,
        borderRadius: 28,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: const Row(
          children: <Widget>[
            Icon(Icons.search_rounded, color: _AppColors.textSecondary),
            SizedBox(width: 10),
            Text(
              '搜索音乐',
              style: TextStyle(
                color: _AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.songs,
    required this.busy,
    required this.loadMoreBusy,
    required this.canLoadMore,
    required this.error,
    required this.loadMoreError,
    required this.query,
    required this.hotSearchKeywords,
    required this.onSearch,
    required this.onHotKeyword,
    required this.onLoadMore,
    required this.onPlay,
  });

  final TextEditingController controller;
  final List<FreeMusicSong> songs;
  final bool busy;
  final bool loadMoreBusy;
  final bool canLoadMore;
  final String error;
  final String loadMoreError;
  final String query;
  final List<String> hotSearchKeywords;
  final VoidCallback onSearch;
  final ValueChanged<String> onHotKeyword;
  final VoidCallback onLoadMore;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                  style: const TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: '输入歌名、歌手或专辑',
                    hintStyle: const TextStyle(color: _AppColors.textMuted),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: busy ? null : onSearch,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.manage_search_rounded),
                label: Text(busy ? '搜索中' : '搜索'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              const Text(
                '在线曲库',
                style: TextStyle(
                  color: _AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              _ChipLabel(text: query.isEmpty ? 'FreeMusic' : query),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _SearchResultsBody(
              songs: songs,
              busy: busy,
              loadMoreBusy: loadMoreBusy,
              canLoadMore: canLoadMore,
              error: error,
              loadMoreError: loadMoreError,
              query: query,
              hotSearchKeywords: hotSearchKeywords,
              onLoadMore: onLoadMore,
              onHotKeyword: onHotKeyword,
              onPlay: onPlay,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsBody extends StatelessWidget {
  const _SearchResultsBody({
    required this.songs,
    required this.busy,
    required this.loadMoreBusy,
    required this.canLoadMore,
    required this.error,
    required this.loadMoreError,
    required this.query,
    required this.hotSearchKeywords,
    required this.onLoadMore,
    required this.onHotKeyword,
    required this.onPlay,
  });

  final List<FreeMusicSong> songs;
  final bool busy;
  final bool loadMoreBusy;
  final bool canLoadMore;
  final String error;
  final String loadMoreError;
  final String query;
  final List<String> hotSearchKeywords;
  final VoidCallback onLoadMore;
  final ValueChanged<String> onHotKeyword;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context) {
    if (busy && songs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error.isNotEmpty) {
      return _SearchMessage(
        icon: Icons.cloud_off_rounded,
        title: '搜索失败',
        message: error,
      );
    }
    if (query.isEmpty) {
      return _SearchLandingState(
        hotSearchKeywords: hotSearchKeywords,
        onHotKeyword: onHotKeyword,
      );
    }
    if (songs.isEmpty) {
      return const _SearchMessage(
        icon: Icons.music_off_rounded,
        title: '没有结果',
        message: '换一个关键词再试。',
      );
    }
    return ListView.separated(
      itemCount: songs.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        if (index == songs.length) {
          return _LoadMoreButton(
            busy: loadMoreBusy,
            enabled:
                (canLoadMore || loadMoreError.isNotEmpty) &&
                !busy &&
                !loadMoreBusy,
            error: loadMoreError,
            onTap: onLoadMore,
          );
        }
        final FreeMusicSong song = songs[index];
        return _SongResultTile(song: song, index: index, onPlay: onPlay);
      },
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: _AppColors.textMuted, size: 54),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: _AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 420,
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _AppColors.textSecondary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchLandingState extends StatelessWidget {
  const _SearchLandingState({
    required this.hotSearchKeywords,
    required this.onHotKeyword,
  });

  final List<String> hotSearchKeywords;
  final ValueChanged<String> onHotKeyword;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.travel_explore_rounded,
            color: _AppColors.textMuted,
            size: 54,
          ),
          const SizedBox(height: 12),
          const Text(
            '搜索真实歌曲',
            style: TextStyle(
              color: _AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 420,
            child: Text(
              '结果会直接进入原生播放队列，媒体键和 CarLife 控制可复用同一队列。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _AppColors.textSecondary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
          if (hotSearchKeywords.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String keyword in hotSearchKeywords.take(8))
                  _ActionChipLabel(
                    text: keyword,
                    onTap: () => onHotKeyword(keyword),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SongResultTile extends StatelessWidget {
  const _SongResultTile({
    required this.song,
    required this.index,
    required this.onPlay,
  });

  final FreeMusicSong song;
  final int index;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context) {
    final _DemoTrack visual = _demoQueue[index % _demoQueue.length];
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onPlay(index),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: <Widget>[
            _ArtworkView(
              track: visual,
              imageUrl: song.cover,
              size: 54,
              radius: 16,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    song.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    <String>[
                      song.artist,
                      if (song.album.isNotEmpty) song.album,
                      song.source,
                    ].where((String value) => value.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatDuration(Duration(seconds: song.duration)),
              style: const TextStyle(
                color: _AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.play_circle_fill_rounded,
              color: _AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistSheet extends StatelessWidget {
  const _PlaylistSheet({
    required this.playlist,
    required this.songs,
    required this.total,
    required this.busy,
    required this.error,
    required this.canLoadMore,
    required this.onPlay,
    required this.onLoadMore,
  });

  final FreeMusicPlaylist? playlist;
  final List<FreeMusicSong> songs;
  final int total;
  final bool busy;
  final String error;
  final bool canLoadMore;
  final ValueChanged<int> onPlay;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final FreeMusicPlaylist? current = playlist;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _GlassCard(
          height: MediaQuery.sizeOf(context).height * 0.82,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _ArtworkView(
                    track: _demoQueue.first,
                    imageUrl: current?.cover ?? '',
                    size: 62,
                    radius: 18,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          current?.name ?? '推荐歌单',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _AppColors.textPrimary,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          <String>[
                                if ((current?.creator ?? '').isNotEmpty)
                                  current!.creator,
                                current?.source ?? '',
                                '${songs.length}/${total == 0 ? '?' : total} 首',
                              ]
                              .where((String value) => value.isNotEmpty)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: _AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: songs.isEmpty && busy
                    ? const Center(child: CircularProgressIndicator())
                    : songs.isEmpty && error.isNotEmpty
                    ? _SearchMessage(
                        icon: Icons.queue_music_rounded,
                        title: '歌单加载失败',
                        message: error,
                      )
                    : ListView.separated(
                        itemCount: songs.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          if (index == songs.length) {
                            return _LoadMoreButton(
                              busy: busy,
                              enabled: canLoadMore && !busy,
                              error: error,
                              onTap: onLoadMore,
                            );
                          }
                          return _PlaylistSongRow(
                            song: songs[index],
                            visual: _demoQueue[index % _demoQueue.length],
                            index: index,
                            onTap: () => onPlay(index),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistSongRow extends StatelessWidget {
  const _PlaylistSongRow({
    required this.song,
    required this.visual,
    required this.index,
    required this.onTap,
  });

  final FreeMusicSong song;
  final _DemoTrack visual;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ArtworkView(
              track: visual,
              imageUrl: song.cover,
              size: 48,
              radius: 14,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    song.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    <String>[
                      song.artist,
                      if (song.album.isNotEmpty) song.album,
                    ].where((String value) => value.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatDuration(Duration(seconds: song.duration)),
              style: const TextStyle(
                color: _AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({
    required this.busy,
    required this.enabled,
    required this.error,
    required this.onTap,
  });

  final bool busy;
  final bool enabled;
  final String error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: enabled ? onTap : null,
        icon: busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(error.isEmpty ? Icons.expand_more_rounded : Icons.refresh),
        label: Text(
          busy
              ? '加载中'
              : error.isNotEmpty
              ? '重试加载'
              : enabled
              ? '加载更多'
              : '已加载全部',
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _AppColors.textSecondary,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }
}

class _NowPlayingPanel extends StatelessWidget {
  const _NowPlayingPanel({
    required this.track,
    required this.playbackState,
    required this.playbackMode,
    required this.onPlayPause,
    required this.onPlaybackMode,
    required this.onPrevious,
    required this.onNext,
  });

  final _DemoTrack track;
  final PlaybackUiState playbackState;
  final NativePlaybackMode playbackMode;
  final VoidCallback onPlayPause;
  final VoidCallback onPlaybackMode;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final String title = playbackState.title.isEmpty
        ? track.title
        : playbackState.title;
    final String artist = playbackState.artist.isEmpty
        ? track.artist
        : playbackState.artist;
    final Duration duration = playbackState.duration ?? track.duration;
    final double progress = duration == Duration.zero
        ? 0
        : (playbackState.position.inMilliseconds / duration.inMilliseconds)
              .clamp(0, 1)
              .toDouble();

    return _GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '正在播放',
            style: TextStyle(
              color: _AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: _ArtworkView(
                track: track,
                imageUrl: playbackState.coverUrl,
                size: 220,
                radius: 48,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(track.color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _formatDuration(playbackState.position),
                style: const TextStyle(color: _AppColors.textMuted),
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(color: _AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _TransportButton(
                icon: _iconForPlaybackMode(playbackMode),
                label: _labelForPlaybackMode(playbackMode),
                onTap: onPlaybackMode,
              ),
              const SizedBox(width: 18),
              _TransportButton(
                icon: Icons.skip_previous_rounded,
                label: '上一曲',
                onTap: onPrevious,
              ),
              const SizedBox(width: 18),
              _TransportButton(
                icon: playbackState.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                label: playbackState.playing ? '暂停' : '播放',
                primary: true,
                onTap: onPlayPause,
              ),
              const SizedBox(width: 18),
              _TransportButton(
                icon: Icons.skip_next_rounded,
                label: '下一曲',
                onTap: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NowPlayingFullScreenPanel extends StatelessWidget {
  const _NowPlayingFullScreenPanel({
    required this.track,
    required this.playbackState,
    required this.playbackMode,
    required this.lyrics,
    required this.lyricsAvailable,
    required this.lyricsBusy,
    required this.lyricsError,
    required this.qualities,
    required this.qualitiesBusy,
    required this.qualityError,
    required this.onPlayPause,
    required this.onPlaybackMode,
    required this.onLyrics,
    required this.onPrevious,
    required this.onNext,
  });

  final _DemoTrack track;
  final PlaybackUiState playbackState;
  final NativePlaybackMode playbackMode;
  final FreeMusicLyrics? lyrics;
  final bool lyricsAvailable;
  final bool lyricsBusy;
  final String lyricsError;
  final List<FreeMusicQuality> qualities;
  final bool qualitiesBusy;
  final String qualityError;
  final VoidCallback onPlayPause;
  final VoidCallback onPlaybackMode;
  final VoidCallback onLyrics;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final String title = playbackState.title.isEmpty
        ? track.title
        : playbackState.title;
    final String artist = playbackState.artist.isEmpty
        ? track.artist
        : playbackState.artist;
    final Duration duration = playbackState.duration ?? track.duration;
    final double progress = duration == Duration.zero
        ? 0
        : (playbackState.position.inMilliseconds / duration.inMilliseconds)
              .clamp(0, 1)
              .toDouble();
    final List<FreeMusicLyricLine> lyricLines =
        lyrics?.lines ?? const <FreeMusicLyricLine>[];
    final int activeLineIndex = activeLyricLineIndex(
      lyricLines,
      playbackState.position,
    );
    final String activeLyric = activeLineIndex < 0
        ? ''
        : lyricLines[activeLineIndex].text;
    final String nextLyric =
        activeLineIndex + 1 >= 0 && activeLineIndex + 1 < lyricLines.length
        ? lyricLines[activeLineIndex + 1].text
        : '';

    return _GlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _CircleIconButton(
                icon: Icons.keyboard_arrow_down_rounded,
                label: '收起',
                onTap: () {},
              ),
              const Spacer(),
              _LyricsButton(
                available: lyricsAvailable,
                busy: lyricsBusy,
                onTap: onLyrics,
              ),
            ],
          ),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: Center(
                    child: _ArtworkView(
                      track: track,
                      imageUrl: playbackState.coverUrl,
                      size: 320,
                      radius: 34,
                    ),
                  ),
                ),
                const SizedBox(width: 34),
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _AppColors.textPrimary,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _AppColors.textSecondary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _QualityChips(
                        qualities: qualities,
                        busy: qualitiesBusy,
                        error: qualityError,
                      ),
                      const SizedBox(height: 26),
                      Text(
                        lyricsBusy
                            ? '歌词加载中...'
                            : lyricsError.isNotEmpty
                            ? '歌词加载失败'
                            : activeLyric.isEmpty
                            ? '暂无当前歌词'
                            : activeLyric,
                        style: TextStyle(
                          color: _AppColors.textPrimary.withValues(alpha: 0.88),
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        nextLyric.isEmpty ? '播放搜索结果后会自动同步歌词' : nextLyric,
                        style: TextStyle(
                          color: _AppColors.textSecondary.withValues(
                            alpha: 0.64,
                          ),
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 30),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          value: progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            track.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            _formatDuration(playbackState.position),
                            style: const TextStyle(
                              color: _AppColors.textMuted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(
                              color: _AppColors.textMuted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _TransportButton(
                icon: _iconForPlaybackMode(playbackMode),
                label: _labelForPlaybackMode(playbackMode),
                onTap: onPlaybackMode,
              ),
              const SizedBox(width: 34),
              _TransportButton(
                icon: Icons.skip_previous_rounded,
                label: '上一曲',
                onTap: onPrevious,
              ),
              const SizedBox(width: 34),
              _TransportButton(
                icon: playbackState.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                label: playbackState.playing ? '暂停' : '播放',
                primary: true,
                onTap: onPlayPause,
              ),
              const SizedBox(width: 34),
              _TransportButton(
                icon: Icons.skip_next_rounded,
                label: '下一曲',
                onTap: onNext,
              ),
              const SizedBox(width: 34),
              _TransportButton(
                icon: Icons.repeat_rounded,
                label: '循环',
                onTap: onPlaybackMode,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QualityChips extends StatelessWidget {
  const _QualityChips({
    required this.qualities,
    required this.busy,
    required this.error,
  });

  final List<FreeMusicQuality> qualities;
  final bool busy;
  final String error;

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips;
    if (busy) {
      chips = const <Widget>[_ChipLabel(text: '音质加载中')];
    } else if (error.isNotEmpty) {
      chips = const <Widget>[_ChipLabel(text: '音质可重试')];
    } else if (qualities.isEmpty) {
      chips = const <Widget>[_ChipLabel(text: '等待品质信息')];
    } else {
      chips = qualities
          .take(4)
          .map((FreeMusicQuality quality) {
            final String text = quality.name.isNotEmpty
                ? quality.name
                : quality.bitrate;
            return _ChipLabel(text: text);
          })
          .toList(growable: false);
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel({
    required this.selectedIndex,
    required this.songs,
    required this.onSelect,
  });

  final int selectedIndex;
  final List<FreeMusicSong> songs;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '播放队列',
                  style: TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
              ),
              _QueueHeaderAction(label: '清空', onTap: () {}),
              const SizedBox(width: 10),
              _QueueHeaderAction(label: '编辑', onTap: () {}),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            songs.isEmpty ? '搜索并播放歌曲后，这里会显示真实原生队列。' : '来自在线搜索结果，可直接切换任意歌曲。',
            style: TextStyle(
              color: _AppColors.textSecondary,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: songs.isEmpty
                ? _DemoQueueList(
                    selectedIndex: selectedIndex,
                    onSelect: onSelect,
                  )
                : _SongQueueList(
                    songs: songs,
                    selectedIndex: selectedIndex,
                    onSelect: onSelect,
                  ),
          ),
        ],
      ),
    );
  }
}

class _DemoQueueList extends StatelessWidget {
  const _DemoQueueList({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: _demoQueue.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final _DemoTrack track = _demoQueue[index];
        final bool selected = selectedIndex == index;
        return _QueueTile(
          number: index + 1,
          title: track.title,
          subtitle: track.artist,
          visual: track,
          selected: selected,
          onTap: () => onSelect(index),
        );
      },
    );
  }
}

class _SongQueueList extends StatelessWidget {
  const _SongQueueList({
    required this.songs,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<FreeMusicSong> songs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: songs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (BuildContext context, int index) {
        final FreeMusicSong song = songs[index];
        return _QueueTile(
          number: index + 1,
          title: song.name,
          subtitle: song.artist.isEmpty
              ? song.source
              : '${song.artist} · ${song.source}',
          imageUrl: song.cover,
          visual: _demoQueue[index % _demoQueue.length],
          selected: selectedIndex == index,
          onTap: () => onSelect(index),
        );
      },
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.visual,
    this.imageUrl = '',
    required this.selected,
    required this.onTap,
  });

  final int number;
  final String title;
  final String subtitle;
  final _DemoTrack visual;
  final String imageUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _AppColors.primary.withValues(alpha: 0.13)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? visual.color.withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              child: Text(
                '$number',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? _AppColors.textPrimary
                      : _AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _ArtworkView(
              track: visual,
              imageUrl: imageUrl,
              size: 48,
              radius: 15,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? _AppColors.textPrimary
                          : _AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.graphic_eq_rounded,
                color: _AppColors.primary,
                size: 22,
              ),
            const SizedBox(width: 12),
            const Icon(
              Icons.menu_rounded,
              color: _AppColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueHeaderAction extends StatelessWidget {
  const _QueueHeaderAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  const _MiniPlayerBar({
    required this.track,
    required this.playbackState,
    required this.playbackMode,
    required this.lyricsAvailable,
    required this.lyricsBusy,
    required this.onPlayPause,
    required this.onPlaybackMode,
    required this.onLyrics,
    required this.onPrevious,
    required this.onNext,
  });

  final _DemoTrack track;
  final PlaybackUiState playbackState;
  final NativePlaybackMode playbackMode;
  final bool lyricsAvailable;
  final bool lyricsBusy;
  final VoidCallback onPlayPause;
  final VoidCallback onPlaybackMode;
  final VoidCallback onLyrics;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final String title = playbackState.title.isEmpty
        ? track.title
        : playbackState.title;
    final String artist = playbackState.artist.isEmpty
        ? track.artist
        : playbackState.artist;
    final Duration duration = playbackState.duration ?? track.duration;
    final double progress = duration == Duration.zero
        ? 0
        : (playbackState.position.inMilliseconds / duration.inMilliseconds)
              .clamp(0, 1)
              .toDouble();
    return _GlassCard(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          _ArtworkView(
            track: track,
            imageUrl: playbackState.coverUrl,
            size: 50,
            radius: 14,
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 210,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: <Widget>[
                Text(
                  _formatDuration(playbackState.position),
                  style: const TextStyle(
                    color: _AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(track.color),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(
                    color: _AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _MiniTransportButton(
            icon: Icons.skip_previous_rounded,
            onTap: onPrevious,
          ),
          _MiniTransportButton(
            icon: playbackState.playing
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            primary: true,
            onTap: onPlayPause,
          ),
          _MiniTransportButton(icon: Icons.skip_next_rounded, onTap: onNext),
          const SizedBox(width: 8),
          _ModePill(mode: playbackMode, onTap: onPlaybackMode),
          const SizedBox(width: 8),
          _LyricsButton(
            available: lyricsAvailable,
            busy: lyricsBusy,
            onTap: onLyrics,
          ),
        ],
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(primary ? 34 : 28),
        onTap: onTap,
        child: Container(
          width: primary ? 76 : 62,
          height: primary ? 76 : 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: primary
                ? const LinearGradient(
                    colors: <Color>[_AppColors.primary, _AppColors.accent],
                  )
                : null,
            color: primary ? null : Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: primary
                ? <BoxShadow>[
                    BoxShadow(
                      color: _AppColors.primary.withValues(alpha: 0.32),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, size: primary ? 42 : 34, color: Colors.white),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: _AppColors.textPrimary, size: 30),
        ),
      ),
    );
  }
}

class _MiniTransportButton extends StatelessWidget {
  const _MiniTransportButton({
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: primary ? 34 : 30),
        color: Colors.white,
        style: IconButton.styleFrom(
          fixedSize: Size.square(primary ? 58 : 50),
          backgroundColor: primary
              ? _AppColors.primary
              : Colors.white.withValues(alpha: 0.08),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.mode, required this.onTap});

  final NativePlaybackMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _labelForPlaybackMode(mode),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                _iconForPlaybackMode(mode),
                color: _AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                _labelForPlaybackMode(mode),
                style: const TextStyle(
                  color: _AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LyricsButton extends StatelessWidget {
  const _LyricsButton({
    required this.available,
    required this.busy,
    required this.onTap,
  });

  final bool available;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: available
              ? _AppColors.primary.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: available
                ? _AppColors.primary.withValues(alpha: 0.36)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          children: <Widget>[
            if (busy)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.subtitles_rounded,
                color: available
                    ? _AppColors.primary
                    : _AppColors.textSecondary,
                size: 18,
              ),
            const SizedBox(width: 6),
            Text(
              '歌词',
              style: TextStyle(
                color: available
                    ? _AppColors.textPrimary
                    : _AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LyricsSheet extends StatelessWidget {
  const _LyricsSheet({
    required this.songTitle,
    required this.artist,
    required this.lyrics,
    required this.loading,
    required this.error,
    required this.position,
  });

  final String songTitle;
  final String artist;
  final FreeMusicLyrics? lyrics;
  final bool loading;
  final String error;
  final Duration position;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _GlassCard(
          height: MediaQuery.sizeOf(context).height * 0.78,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          songTitle.isEmpty ? '歌词' : songTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _AppColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          artist.isEmpty ? '当前歌曲' : artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: _AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _LyricsContent(
                  lyrics: lyrics,
                  loading: loading,
                  error: error,
                  position: position,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LyricsContent extends StatefulWidget {
  const _LyricsContent({
    required this.lyrics,
    required this.loading,
    required this.error,
    required this.position,
  });

  final FreeMusicLyrics? lyrics;
  final bool loading;
  final String error;
  final Duration position;

  @override
  State<_LyricsContent> createState() => _LyricsContentState();
}

class _LyricsContentState extends State<_LyricsContent> {
  static const double _lineExtent = 62;

  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void didUpdateWidget(_LyricsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final List<FreeMusicLyricLine> lines = widget.lyrics?.lines ?? const [];
    final int activeIndex = activeLyricLineIndex(lines, widget.position);
    if (activeIndex != _lastActiveIndex) {
      _lastActiveIndex = activeIndex;
      _scrollActiveLineIntoView(activeIndex);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollActiveLineIntoView(int index) {
    if (index < 0 || !_scrollController.hasClients) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final ScrollPosition scrollPosition = _scrollController.position;
      final double viewport = scrollPosition.viewportDimension;
      final double target = (index * _lineExtent) - (viewport * 0.38);
      final double clamped = target.clamp(
        scrollPosition.minScrollExtent,
        scrollPosition.maxScrollExtent,
      );
      if ((scrollPosition.pixels - clamped).abs() < 8) {
        return;
      }
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.error.isNotEmpty) {
      return _SearchMessage(
        icon: Icons.subtitles_off_rounded,
        title: '歌词加载失败',
        message: widget.error,
      );
    }
    final FreeMusicLyrics? current = widget.lyrics;
    if (current == null || current.isEmpty) {
      return const _SearchMessage(
        icon: Icons.subtitles_off_rounded,
        title: '暂无歌词',
        message: '播放搜索结果后会自动加载歌词。',
      );
    }
    final List<FreeMusicLyricLine> lines = current.lines;
    if (lines.isEmpty) {
      return SingleChildScrollView(
        child: Text(
          current.raw,
          style: const TextStyle(
            color: _AppColors.textSecondary,
            fontSize: 18,
            height: 1.7,
          ),
        ),
      );
    }
    final int activeIndex = activeLyricLineIndex(lines, widget.position);
    if (_lastActiveIndex != activeIndex) {
      _lastActiveIndex = activeIndex;
      _scrollActiveLineIntoView(activeIndex);
    }
    return ListView.separated(
      controller: _scrollController,
      itemCount: lines.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final FreeMusicLyricLine line = lines[index];
        final bool active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: active ? 12 : 0,
            vertical: active ? 8 : 0,
          ),
          decoration: BoxDecoration(
            color: active
                ? _AppColors.accent.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active
                  ? _AppColors.accent.withValues(alpha: 0.28)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 58,
                child: Text(
                  _formatDuration(line.time),
                  style: TextStyle(
                    color: active ? _AppColors.accent : _AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  line.text,
                  style: TextStyle(
                    color: active
                        ? _AppColors.textPrimary
                        : _AppColors.textSecondary,
                    fontSize: active ? 22 : 20,
                    height: 1.38,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

@visibleForTesting
int activeLyricLineIndex(List<FreeMusicLyricLine> lines, Duration position) {
  if (lines.isEmpty || position < lines.first.time) {
    return -1;
  }
  int low = 0;
  int high = lines.length - 1;
  while (low <= high) {
    final int mid = low + ((high - low) >> 1);
    if (lines[mid].time <= position) {
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return math.max(0, high);
}

class _ArtworkTile extends StatelessWidget {
  const _ArtworkTile({
    required this.track,
    required this.size,
    required this.radius,
  });

  final _DemoTrack track;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[track.color, track.color.withBlue(230), Colors.black],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: track.color.withValues(alpha: 0.24),
            blurRadius: size * 0.16,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -size * 0.12,
            top: -size * 0.08,
            child: Container(
              width: size * 0.70,
              height: size * 0.70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Center(
            child: Text(
              track.mark,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtworkView extends StatelessWidget {
  const _ArtworkView({
    required this.track,
    required this.imageUrl,
    required this.size,
    required this.radius,
  });

  final _DemoTrack track;
  final String imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Uri? uri = Uri.tryParse(imageUrl);
    final bool canLoadImage = uri != null && uri.hasAbsolutePath;
    if (!canLoadImage || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return _ArtworkTile(track: track, size: size, radius: radius);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: track.color.withValues(alpha: 0.24),
              blurRadius: size * 0.16,
              offset: Offset(0, size * 0.06),
            ),
          ],
        ),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            return _ArtworkTile(track: track, size: size, radius: radius);
          },
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
    this.borderRadius = 30,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: _AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActionChipLabel extends StatelessWidget {
  const _ActionChipLabel({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _AppColors.primary.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _AppColors.primary.withValues(alpha: 0.24)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: _AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AppColors {
  const _AppColors._();

  static const Color background = Color(0xFF07101C);
  static const Color surface = Color(0xCC151824);
  static const Color primary = Color(0xFFFF5C93);
  static const Color accent = Color(0xFFFFB86B);
  static const Color carlife = Color(0xFF2D7DFF);
  static const Color error = Color(0xFFFF5A5F);
  static const Color textPrimary = Color(0xFFF7F8FA);
  static const Color textSecondary = Color(0xFFAEB4C1);
  static const Color textMuted = Color(0xFF747D8C);
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _DemoTrack {
  const _DemoTrack({
    required this.title,
    required this.artist,
    required this.duration,
    required this.color,
    required this.mark,
  });

  final String title;
  final String artist;
  final Duration duration;
  final Color color;
  final String mark;

  String get durationText => _formatDuration(duration);
}

const List<_NavItem> _navItems = <_NavItem>[
  _NavItem(icon: Icons.home_rounded, label: '推荐'),
  _NavItem(icon: Icons.search_rounded, label: '搜索'),
  _NavItem(icon: Icons.queue_music_rounded, label: '播放队列'),
  _NavItem(icon: Icons.equalizer_rounded, label: '正在播放'),
  _NavItem(icon: Icons.settings_rounded, label: '设置'),
];

const List<_DemoTrack> _demoQueue = <_DemoTrack>[
  _DemoTrack(
    title: 'Highway Morning',
    artist: 'Native Radio',
    duration: Duration(minutes: 3, seconds: 42),
    color: Color(0xFFFF5C93),
    mark: 'H',
  ),
  _DemoTrack(
    title: 'City Lights',
    artist: 'Drive Session',
    duration: Duration(minutes: 4, seconds: 8),
    color: Color(0xFF36C8FF),
    mark: 'C',
  ),
  _DemoTrack(
    title: 'Ocean Avenue',
    artist: 'Glass FM',
    duration: Duration(minutes: 3, seconds: 25),
    color: Color(0xFF65E4A3),
    mark: 'O',
  ),
  _DemoTrack(
    title: 'Late Night Loop',
    artist: 'CarPlay Mix',
    duration: Duration(minutes: 5, seconds: 1),
    color: Color(0xFFFFB86B),
    mark: 'L',
  ),
  _DemoTrack(
    title: 'Silent Dashboard',
    artist: 'iMusic Lab',
    duration: Duration(minutes: 2, seconds: 57),
    color: Color(0xFF9A7CFF),
    mark: 'S',
  ),
];

const List<_DemoTrack> _recentTracks = <_DemoTrack>[
  _DemoTrack(
    title: 'Morning Pulse',
    artist: 'Daily Drive',
    duration: Duration(minutes: 3, seconds: 9),
    color: Color(0xFF36C8FF),
    mark: 'M',
  ),
  _DemoTrack(
    title: 'Warm Start',
    artist: 'Engine Room',
    duration: Duration(minutes: 4, seconds: 12),
    color: Color(0xFFFFB86B),
    mark: 'W',
  ),
  _DemoTrack(
    title: 'Signal Green',
    artist: 'Route 88',
    duration: Duration(minutes: 3, seconds: 33),
    color: Color(0xFF65E4A3),
    mark: 'G',
  ),
];

String _formatDuration(Duration duration) {
  final int minutes = duration.inMinutes;
  final int seconds = duration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _formatCount(int value) {
  if (value >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(1)}亿';
  }
  if (value >= 10000) {
    return '${(value / 10000).toStringAsFixed(1)}万';
  }
  return '$value';
}

IconData _iconForPlaybackMode(NativePlaybackMode mode) {
  switch (mode) {
    case NativePlaybackMode.sequential:
      return Icons.trending_flat_rounded;
    case NativePlaybackMode.repeatAll:
      return Icons.repeat_rounded;
    case NativePlaybackMode.repeatOne:
      return Icons.repeat_one_rounded;
    case NativePlaybackMode.shuffle:
      return Icons.shuffle_rounded;
  }
}

String _labelForPlaybackMode(NativePlaybackMode mode) {
  switch (mode) {
    case NativePlaybackMode.sequential:
      return '顺序';
    case NativePlaybackMode.repeatAll:
      return '列表循环';
    case NativePlaybackMode.repeatOne:
      return '单曲循环';
    case NativePlaybackMode.shuffle:
      return '随机';
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
