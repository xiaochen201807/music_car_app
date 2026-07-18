import 'package:flutter/material.dart';
import '../free_music_api.dart';
import '../main.dart';
import '../native_audio_controller.dart';
import '../services/audio_effects_controller.dart';

/// 使用 InheritedWidget 构建的全局状态共享组件。
/// 使子视图（Home, Player, Search, Library, Settings）免去层层构造传参的痛苦，
/// 直接通过 context 订阅或调起全局播控动作。
class MusicAppStateScope extends InheritedWidget {
  const MusicAppStateScope({
    super.key,
    required this.state,
    required this.currentSong,
    required this.selectedQueueIndex,
    required this.playbackQueue,
    required this.playbackMode,
    required this.searchResults,
    required this.favoriteSongs,
    required this.selectedTab,
    required this.isLoadingRecommendations,
    required this.isLoadingApiBootstrap,
    required this.recommendationError,
    required this.apiBootstrapError,
    required this.preferredBitrate,
    required this.backupMusicSourceEnabled,
    required this.audioEffectsSettings,
    required this.themeMode,
    required this.playlistSource,
    required this.recommendedPlaylists,
    required super.child,
  });

  final NativeMusicHomePageState state;
  final FreeMusicSong? currentSong;
  final int selectedQueueIndex;
  final List<FreeMusicSong> playbackQueue;
  final NativePlaybackMode playbackMode;
  final List<FreeMusicSong> searchResults;
  final List<FreeMusicSong> favoriteSongs;
  final int selectedTab;
  final bool isLoadingRecommendations;
  final bool isLoadingApiBootstrap;
  final String recommendationError;
  final String apiBootstrapError;
  final String preferredBitrate;
  final bool backupMusicSourceEnabled;
  final AudioEffectsSettings audioEffectsSettings;
  final ThemeMode themeMode;
  final String playlistSource;
  final List<FreeMusicPlaylist> recommendedPlaylists;

  /// 静态便捷获取主状态的方法。
  static NativeMusicHomePageState of(BuildContext context) {
    final MusicAppStateScope? result =
        context.dependOnInheritedWidgetOfExactType<MusicAppStateScope>();
    assert(result != null, 'No MusicAppStateScope found in context');
    return result!.state;
  }

  @override
  bool updateShouldNotify(MusicAppStateScope oldWidget) {
    return oldWidget.currentSong != currentSong ||
        oldWidget.selectedQueueIndex != selectedQueueIndex ||
        oldWidget.playbackQueue != playbackQueue ||
        oldWidget.playbackMode != playbackMode ||
        oldWidget.searchResults != searchResults ||
        oldWidget.favoriteSongs != favoriteSongs ||
        oldWidget.selectedTab != selectedTab ||
        oldWidget.isLoadingRecommendations != isLoadingRecommendations ||
        oldWidget.isLoadingApiBootstrap != isLoadingApiBootstrap ||
        oldWidget.recommendationError != recommendationError ||
        oldWidget.apiBootstrapError != apiBootstrapError ||
        oldWidget.preferredBitrate != preferredBitrate ||
        oldWidget.backupMusicSourceEnabled != backupMusicSourceEnabled ||
        oldWidget.audioEffectsSettings != audioEffectsSettings ||
        oldWidget.themeMode != themeMode ||
        // Catalog source chips + list must rebuild immediately on switch.
        oldWidget.playlistSource != playlistSource ||
        oldWidget.recommendedPlaylists != recommendedPlaylists;
  }
}
