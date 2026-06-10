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
class PortraitMusicScaffold extends StatelessWidget {
  const PortraitMusicScaffold({super.key});

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
          builder: (BuildContext context, AsyncSnapshot<MediaItem?> itemSnapshot) {
            final PlaybackUiState playbackState = PlaybackUiState.fromAudioService(
              snapshot.data,
              itemSnapshot.data,
            );
            return _buildScaffold(context, appState, playbackState);
          },
        );
      },
    );
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

    // 搜索回调包装，如果当前不在搜索页则切过去
    void runSearchFromHome() {
      if (appState.selectedTab != 1) {
        appState.selectTab(1);
      }
      appState.searchSongs();
    }

    // Tab 页面切换映射
    final Widget page = switch (appState.selectedTab) {
      1 => PortraitSearchView(
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
        ),
      2 => PortraitLibraryView(
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
        ),
      4 => PortraitPlayerView(
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
          favorite: appState.currentSong != null &&
              appState.favoriteSongKeys.contains(favoriteSongKey(appState.currentSong!)),
          onClose: () => appState.selectTab(0),
          onToggleFavorite: appState.currentSong == null
              ? null
              : () => appState.toggleFavoriteSong(appState.currentSong!),
          onPlayPause: () => appState.togglePlayback(playbackState.playing),
          onPlaybackMode: () => appState.cyclePlaybackMode(),
          onQuality: () => appState.showQualitySheet(),
          onSeek: (Duration pos) => appState.seekPlayback(pos),
          onPrevious: () => appState.skipToPreviousTrack(),
          onNext: () => appState.skipToNextTrack(),
        ),
      5 => PortraitSettingsView(
          themeMode: appState.widget.themeMode,
          preferredBitrate: appState.preferredBitrate,
          carLifeStatus: appState.carLifeStatus,
          carLifeBusy: appState.isCheckingCarLife || appState.isSyncingCarLife,
          updateBusy: appState.isCheckingUpdate || appState.isInstallingUpdate,
          onThemeModeChanged:
              appState.widget.onThemeModeChanged ?? (ThemeMode mode) {},
          onPreferredBitrateChanged: (String br) =>
              appState.setPreferredBitrate(br),
          onOpenCarLife: appState.openCarLife,
          onSyncCarLife: () =>
              appState.syncCarLifePlaybackContext(showResult: true),
          onRefreshCarLife: appState.refreshCarLifeStatus,
          onCheckUpdate: () => appState.checkForUpdate(),
          onOpenDownloads: () => appState.openDownloads(),
        ),
      _ => PortraitHomeView(
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
        ),
    };

    return Theme(
      data: theme,
      child: PortraitDynamicBackground(
        seedColor: appState.coverSeedColor,
        child: Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              final Animation<Offset> slide = Tween<Offset>(
                begin: const Offset(0.03, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: slide,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(key: ValueKey<int>(appState.selectedTab), child: page),
          ),
          bottomNavigationBar: appState.selectedTab == 4
              ? null
              : PortraitBottomChrome(
                  selectedTab: appState.selectedTab,
                  currentSong: appState.currentSong,
                  fallbackTrack: demoQueue[appState.selectedQueueIndex % demoQueue.length],
                  playbackState: playbackState,
                  playbackMode: appState.playbackMode,
                  coverSeedColor: appState.coverSeedColor,
                  onSelectTab: (int index) => appState.selectTab(index),
                  onPlayPause: () => appState.togglePlayback(playbackState.playing),
                  onPlaybackMode: () => appState.cyclePlaybackMode(),
                  onQuality: () => appState.showQualitySheet(),
                  onPrevious: () => appState.skipToPreviousTrack(),
                  onNext: () => appState.skipToNextTrack(),
                ),
        ),
      ),
    );
  }
}
