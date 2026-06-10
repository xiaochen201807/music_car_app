import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';

import '../../app/music_app_state_scope.dart';
import '../../favorite_song_store.dart';
import '../../models/demo_track.dart';
import '../../models/playback_ui_state.dart';
import '../../widgets/sparkling_stars.dart';
import '../home/portrait_home_view.dart';
import '../search/portrait_search_view.dart';
import '../library/portrait_library_view.dart';
import '../player/portrait_player_view.dart';
import '../settings/portrait_settings_view.dart';
import '../../main.dart';

/// 竖屏模式下的主音乐 Shell。
/// 通过 [MusicAppStateScope] 自动获取全局状态与操作方法，内部自包含播放状态监听，
/// 无需任何构造参数，消除参数膨胀问题。
class PortraitMusicScaffold extends StatefulWidget {
  const PortraitMusicScaffold({super.key});

  @override
  State<PortraitMusicScaffold> createState() => _PortraitMusicScaffoldState();
}

class _PortraitMusicScaffoldState extends State<PortraitMusicScaffold> {
  static const List<int> _regularTabs = <int>[0, 1, 2, 5];

  PageController? _pageController;
  bool _isAnimatingToPage = false;
  int _lastRegularTab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final NativeMusicHomePageState appState = MusicAppStateScope.of(context);
    final int selectedTab = appState.selectedTab;
    if (_isRegularTab(selectedTab)) {
      _lastRegularTab = selectedTab;
    }
    _pageController ??= PageController(
      initialPage: _pageIndexForTab(_regularTabFor(selectedTab)),
    );
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NativeMusicHomePageState appState = MusicAppStateScope.of(context);

    // 内部直接订阅 audioHandler 上的流，包装出 PlaybackUiState
    return StreamBuilder<PlaybackState>(
      stream: appState.widget.audioHandler?.playbackState,
      initialData: appState.widget.audioHandler?.playbackState.valueOrNull,
      builder: (BuildContext context, AsyncSnapshot<PlaybackState> snapshot) {
        return StreamBuilder<MediaItem?>(
          stream: appState.widget.audioHandler?.mediaItem,
          initialData: appState.widget.audioHandler?.mediaItem.valueOrNull,
          builder:
              (BuildContext context, AsyncSnapshot<MediaItem?> itemSnapshot) {
                final PlaybackUiState playbackState =
                    PlaybackUiState.fromAudioService(
                      snapshot.data,
                      itemSnapshot.data,
                    );
                return _buildScaffold(context, appState, playbackState);
              },
        );
      },
    );
  }

  static bool _isRegularTab(int tab) => _regularTabs.contains(tab);

  static int _regularTabFor(int tab) {
    return _isRegularTab(tab) ? tab : 0;
  }

  static int _pageIndexForTab(int tab) {
    final int index = _regularTabs.indexOf(tab);
    return index < 0 ? 0 : index;
  }

  static int _tabForPageIndex(int index) {
    if (index < 0 || index >= _regularTabs.length) {
      return _regularTabs.first;
    }
    return _regularTabs[index];
  }

  void _syncPageController(int selectedTab) {
    if (!_isRegularTab(selectedTab)) {
      return;
    }
    _lastRegularTab = selectedTab;
    if (_isAnimatingToPage) {
      return;
    }
    final PageController? controller = _pageController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    final int targetPage = _pageIndexForTab(selectedTab);
    final int? currentPage = controller.page?.round();
    if (currentPage == targetPage) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _pageController == null || !_pageController!.hasClients) {
        return;
      }
      final int? updatedPage = _pageController!.page?.round();
      if (updatedPage == targetPage) {
        return;
      }
      _isAnimatingToPage = true;
      try {
        await _pageController!.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } finally {
        _isAnimatingToPage = false;
      }
    });
  }

  void _onPageChanged(NativeMusicHomePageState appState, int pageIndex) {
    final int targetTab = _tabForPageIndex(pageIndex);
    _lastRegularTab = targetTab;
    if (_isAnimatingToPage || appState.selectedTab == targetTab) {
      return;
    }
    appState.selectTab(targetTab);
  }

  Widget _buildScaffold(
    BuildContext context,
    NativeMusicHomePageState appState,
    PlaybackUiState playbackState,
  ) {
    final ThemeData baseTheme = Theme.of(context);
    final ColorScheme dynamicScheme = ColorScheme.fromSeed(
      seedColor: appState.coverSeedColor,
      brightness: baseTheme.brightness,
    );
    final ThemeData theme = baseTheme.copyWith(colorScheme: dynamicScheme);

    _syncPageController(appState.selectedTab);

    // 搜索回调包装，如果当前不在搜索页则切过去
    void runSearchFromHome() {
      if (appState.selectedTab != 1) {
        appState.selectTab(1);
      }
      appState.searchSongs();
    }

    final Widget playerOverlay = _buildPlayerOverlay(appState, playbackState);
    final bool playerOpen = appState.selectedTab == 4;

    return Theme(
      data: theme,
      child: PortraitDynamicBackground(
        seedColor: appState.coverSeedColor,
        child: Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: Stack(
            children: <Widget>[
              IgnorePointer(
                ignoring: playerOpen,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (int index) => _onPageChanged(appState, index),
                  children: <Widget>[
                    _KeepAlivePage(
                      key: const PageStorageKey<String>('portrait-home-page'),
                      child: _buildHomeView(appState, runSearchFromHome),
                    ),
                    _KeepAlivePage(
                      key: const PageStorageKey<String>('portrait-search-page'),
                      child: _buildSearchView(appState),
                    ),
                    _KeepAlivePage(
                      key: const PageStorageKey<String>(
                        'portrait-library-page',
                      ),
                      child: _buildLibraryView(appState),
                    ),
                    _KeepAlivePage(
                      key: const PageStorageKey<String>(
                        'portrait-settings-page',
                      ),
                      child: _buildSettingsView(appState),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        final Animation<Offset> slide =
                            Tween<Offset>(
                              begin: const Offset(0.0, 1.0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            );
                        return SlideTransition(
                          position: slide,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                  child: playerOpen
                      ? KeyedSubtree(
                          key: const ValueKey<String>(
                            'portrait-player-overlay',
                          ),
                          child: playerOverlay,
                        )
                      : const SizedBox.shrink(
                          key: ValueKey<String>('portrait-player-closed'),
                        ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: appState.selectedTab == 4
              ? null
              : PortraitBottomChrome(
                  selectedTab: appState.selectedTab,
                  currentSong: appState.currentSong,
                  fallbackTrack:
                      demoQueue[appState.selectedQueueIndex % demoQueue.length],
                  playbackState: playbackState,
                  playbackMode: appState.playbackMode,
                  coverSeedColor: appState.coverSeedColor,
                  onSelectTab: (int index) => appState.selectTab(index),
                  onPlayPause: () =>
                      appState.togglePlayback(playbackState.playing),
                  onPlaybackMode: () => appState.cyclePlaybackMode(),
                  onQuality: () => appState.showQualitySheet(),
                  onPrevious: () => appState.skipToPreviousTrack(),
                  onNext: () => appState.skipToNextTrack(),
                ),
        ),
      ),
    );
  }

  Widget _buildHomeView(
    NativeMusicHomePageState appState,
    VoidCallback runSearchFromHome,
  ) {
    return PortraitHomeView(
      controller: appState.searchController,
      recommendedPlaylists: appState.recommendedPlaylists,
      recommendationsBusy: appState.isLoadingRecommendations,
      recommendationError: appState.recommendationError,
      playlistSongsBusy: false,
      queueSongs: appState.playbackQueue,
      searchResults: appState.searchResults,
      favoriteSongs: appState.favoriteSongs,
      hotSearchKeywords: appState.hotSearchKeywords,
      musicSources: appState.musicSources,
      sourceBusy: appState.isLoadingApiBootstrap,
      sourceError: appState.apiBootstrapError,
      carLifeStatus: appState.carLifeStatus,
      onSearch: runSearchFromHome,
      onHotKeyword: (String keyword) {
        appState.searchController.text = keyword;
        runSearchFromHome();
      },
      onSelectPlaylist: appState.openPlaylistDetails,
      onOpenFavorites: () => appState.selectTab(2),
      onOpenDownloads: () => appState.selectTab(5),
    );
  }

  Widget _buildSearchView(NativeMusicHomePageState appState) {
    return PortraitSearchView(
      controller: appState.searchController,
      songs: appState.searchResults,
      busy: appState.isSearchingMusic,
      loadMoreBusy: appState.isLoadingMoreSearchResults,
      canLoadMore: appState.searchHasMore,
      error: appState.searchError,
      loadMoreError: appState.searchLoadMoreError,
      query: appState.lastSearchQuery,
      hotSearchKeywords: appState.hotSearchKeywords,
      favoriteSongKeys: appState.favoriteSongKeys,
      downloadedSongKeys: appState.downloadedSongKeys,
      onSearch: appState.searchSongs,
      onHotKeyword: (String keyword) {
        appState.searchController.text = keyword;
        appState.searchSongs();
      },
      onLoadMore: appState.loadMoreSearchResults,
      onPlay: appState.playSearchResult,
      onAddToQueue: appState.addSearchResultToQueue,
      onToggleFavorite: appState.toggleFavoriteSong,
      onDownload: appState.downloadSong,
    );
  }

  Widget _buildLibraryView(NativeMusicHomePageState appState) {
    return PortraitLibraryView(
      favoriteSongs: appState.favoriteSongs,
      favoriteSongKeys: appState.favoriteSongKeys,
      favoritesBusy: appState.isLoadingFavorites,
      queueSongs: appState.playbackQueue,
      selectedQueueIndex: appState.selectedQueueIndex,
      onPlayFavorite: appState.playFavoriteSong,
      onPlayAllFavorites: appState.playAllFavorites,
      onToggleFavorite: appState.toggleFavoriteSong,
      onSelectQueueIndex: appState.skipToQueueItem,
      downloadedSongs: appState.downloadedSongs,
      downloadedSongKeys: appState.downloadedSongKeys,
      onPlayDownloaded: appState.playDownloadedSong,
      onPlayAllDownloaded: appState.playAllDownloadedSongs,
      onDownload: appState.downloadSong,
      onDeleteCache: appState.deleteSongCache,
    );
  }

  Widget _buildSettingsView(NativeMusicHomePageState appState) {
    return PortraitSettingsView(
      themeMode: appState.widget.themeMode,
      preferredBitrate: appState.preferredBitrate,
      carLifeStatus: appState.carLifeStatus,
      carLifeBusy: appState.isCheckingCarLife || appState.isSyncingCarLife,
      updateBusy: appState.isCheckingUpdate || appState.isInstallingUpdate,
      onThemeModeChanged:
          appState.widget.onThemeModeChanged ?? (ThemeMode mode) {},
      onPreferredBitrateChanged: (String bitrate) =>
          appState.setPreferredBitrate(bitrate),
      onOpenCarLife: appState.openCarLife,
      onSyncCarLife: () =>
          appState.syncCarLifePlaybackContext(showResult: true),
      onRefreshCarLife: appState.refreshCarLifeStatus,
      onCheckUpdate: () => appState.checkForUpdate(),
      onOpenDownloads: () => appState.openDownloads(),
    );
  }

  Widget _buildPlayerOverlay(
    NativeMusicHomePageState appState,
    PlaybackUiState playbackState,
  ) {
    return PortraitPlayerView(
      currentSong: appState.currentSong,
      fallbackTrack: demoQueue[appState.selectedQueueIndex % demoQueue.length],
      playbackState: playbackState,
      playbackMode: appState.playbackMode,
      coverSeedColor: appState.coverSeedColor,
      lyrics: appState.currentLyrics,
      lyricsBusy: appState.isLoadingLyrics,
      lyricsError: appState.lyricsError,
      qualities: appState.currentQualities,
      qualitiesBusy: appState.isLoadingQualities,
      qualityError: appState.qualityError,
      favorite:
          appState.currentSong != null &&
          appState.favoriteSongKeys.contains(
            favoriteSongKey(appState.currentSong!),
          ),
      onClose: () => appState.selectTab(_lastRegularTab),
      onToggleFavorite: appState.currentSong == null
          ? null
          : () => appState.toggleFavoriteSong(appState.currentSong!),
      onPlayPause: () => appState.togglePlayback(playbackState.playing),
      onPlaybackMode: () => appState.cyclePlaybackMode(),
      onQuality: () => appState.showQualitySheet(),
      onSeek: (Duration position) => appState.seekPlayback(position),
      onPrevious: () => appState.skipToPreviousTrack(),
      onNext: () => appState.skipToNextTrack(),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({super.key, required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
