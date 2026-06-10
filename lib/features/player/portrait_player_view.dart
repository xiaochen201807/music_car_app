import 'package:flutter/material.dart';
import '../../free_music_api.dart';
import '../../models/demo_track.dart';
import '../../models/playback_ui_state.dart';
import '../../native_audio_controller.dart';
import '../../theme/design_tokens.dart';
import '../../utils/formatters.dart';
import '../../utils/lyrics_utils.dart';
import '../../shared/portrait_artwork.dart';
import '../../shared/portrait_circle_button.dart';
import '../../shared/portrait_play_button.dart';
import '../../shared/portrait_surface.dart';
import 'waveform_seekbar.dart';

IconData iconForPlaybackMode(NativePlaybackMode mode) {
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

String labelForPlaybackMode(NativePlaybackMode mode) {
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

class PortraitPlayerView extends StatelessWidget {
  const PortraitPlayerView({
    super.key,
    required this.currentSong,
    required this.fallbackTrack,
    required this.playbackState,
    required this.playbackMode,
    required this.coverSeedColor,
    required this.lyrics,
    required this.lyricsBusy,
    required this.lyricsError,
    required this.qualities,
    required this.qualitiesBusy,
    required this.qualityError,
    required this.favorite,
    required this.onClose,
    required this.onToggleFavorite,
    required this.onPlayPause,
    required this.onPlaybackMode,
    required this.onLyrics,
    required this.onSeek,
    required this.onPrevious,
    required this.onNext,
  });

  final FreeMusicSong? currentSong;
  final DemoTrack fallbackTrack;
  final PlaybackUiState playbackState;
  final NativePlaybackMode playbackMode;
  final Color coverSeedColor;
  final FreeMusicLyrics? lyrics;
  final bool lyricsBusy;
  final String lyricsError;
  final List<FreeMusicQuality> qualities;
  final bool qualitiesBusy;
  final String qualityError;
  final bool favorite;
  final VoidCallback onClose;
  final VoidCallback? onToggleFavorite;
  final VoidCallback onPlayPause;
  final VoidCallback onPlaybackMode;
  final VoidCallback onLyrics;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String title = playbackState.title.isEmpty
        ? currentSong?.name ?? fallbackTrack.title
        : playbackState.title;
    final String artist = playbackState.artist.isEmpty
        ? currentSong?.artist ?? fallbackTrack.artist
        : playbackState.artist;
    final Duration duration = playbackState.duration ?? fallbackTrack.duration;
    final double progress = duration == Duration.zero
        ? 0
        : playbackState.position.inMilliseconds / duration.inMilliseconds;

    // lyric calculation handled inside PlayerLyricsView

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            coverSeedColor.withValues(alpha: 0.45),
            colors.surface,
            colors.surface,
          ],
          stops: const <double>[0, 0.44, 1],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.md,
                AppSpace.xl,
                AppSpace.xl3,
              ),
              sliver: SliverList.list(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      PortraitCircleButton(
                        icon: Icons.keyboard_arrow_down_rounded,
                        label: '收起',
                        onTap: onClose,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Text(
                        '正在播放',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      PortraitCircleButton(
                        icon: favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: favorite ? '取消收藏' : '收藏',
                        selected: favorite,
                        onTap: onToggleFavorite,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl2),
                  Hero(
                    tag: 'now-playing-artwork',
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.panel),
                        child: PortraitArtwork(
                          visual: fallbackTrack,
                          imageUrl: playbackState.coverUrl.isEmpty
                              ? currentSong?.cover ?? ''
                              : playbackState.coverUrl,
                          icon: Icons.album_rounded,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl2),
                  WaveformSeekBar(
                    value: progress.clamp(0, 1).toDouble(),
                    color: colors.primary,
                    trackColor: colors.surfaceContainerHighest,
                    onChanged: duration == Duration.zero
                        ? null
                        : (double value) => onSeek(
                            Duration(
                              milliseconds: (duration.inMilliseconds * value)
                                  .round(),
                            ),
                          ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Row(
                    children: <Widget>[
                      Text(formatDuration(playbackState.position)),
                      const Spacer(),
                      Text(formatDuration(duration)),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      PortraitCircleButton(
                        icon: iconForPlaybackMode(playbackMode),
                        label: labelForPlaybackMode(playbackMode),
                        onTap: onPlaybackMode,
                      ),
                      PortraitCircleButton(
                        icon: Icons.skip_previous_rounded,
                        label: '上一曲',
                        large: true,
                        onTap: onPrevious,
                      ),
                      PortraitPlayButton(
                        playing: playbackState.playing,
                        onTap: onPlayPause,
                      ),
                      PortraitCircleButton(
                        icon: Icons.skip_next_rounded,
                        label: '下一曲',
                        large: true,
                        onTap: onNext,
                      ),
                      PortraitCircleButton(
                        icon: Icons.lyrics_rounded,
                        label: '歌词',
                        onTap: onLyrics,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl2),
                  PortraitSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        PlayerLyricsView(
                          lyrics: lyrics,
                          position: playbackState.position,
                          lyricsBusy: lyricsBusy,
                          lyricsError: lyricsError,
                        ),
                        const SizedBox(height: AppSpace.md),
                        QualityChips(
                          qualities: qualities,
                          busy: qualitiesBusy,
                          error: qualityError,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QualityChips extends StatelessWidget {
  const QualityChips({
    super.key,
    required this.qualities,
    required this.busy,
    required this.error,
  });

  final List<FreeMusicQuality> qualities;
  final bool busy;
  final String error;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    if (busy) {
      return Text('音质加载中', style: theme.textTheme.bodySmall);
    }
    if (error.isNotEmpty) {
      return Text('音质可重试: $error', style: theme.textTheme.bodySmall);
    }
    if (qualities.isEmpty) {
      return Text('等待品质信息', style: theme.textTheme.bodySmall);
    }
    return Wrap(
      spacing: AppSpace.xs,
      runSpacing: AppSpace.xs,
      children: qualities.take(4).map((FreeMusicQuality quality) {
        final String text =
            quality.name.isNotEmpty ? quality.name : quality.bitrate;
        return Card(
          margin: EdgeInsets.zero,
          color: colors.surfaceContainerHighest.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: AppSpace.xs,
            ),
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class PortraitBottomChrome extends StatelessWidget {
  const PortraitBottomChrome({
    super.key,
    required this.selectedTab,
    required this.currentSong,
    required this.fallbackTrack,
    required this.playbackState,
    required this.playbackMode,
    required this.coverSeedColor,
    required this.lyricsAvailable,
    required this.lyricsBusy,
    required this.onSelectTab,
    required this.onPlayPause,
    required this.onPlaybackMode,
    required this.onLyrics,
    required this.onPrevious,
    required this.onNext,
  });

  final int selectedTab;
  final FreeMusicSong? currentSong;
  final DemoTrack fallbackTrack;
  final PlaybackUiState playbackState;
  final NativePlaybackMode playbackMode;
  final Color coverSeedColor;
  final bool lyricsAvailable;
  final bool lyricsBusy;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onPlayPause;
  final VoidCallback onPlaybackMode;
  final VoidCallback onLyrics;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int navigationIndex = switch (selectedTab) {
      1 => 1,
      2 || 3 => 2,
      4 => 3,
      _ => 0,
    };
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpace.md,
        0,
        AppSpace.md,
        AppSpace.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PortraitMiniPlayerBar(
            currentSong: currentSong,
            fallbackTrack: fallbackTrack,
            playbackState: playbackState,
            playbackMode: playbackMode,
            coverSeedColor: coverSeedColor,
            lyricsAvailable: lyricsAvailable,
            lyricsBusy: lyricsBusy,
            onOpenPlayer: () => onSelectTab(4),
            onPlayPause: onPlayPause,
            onPlaybackMode: onPlaybackMode,
            onLyrics: onLyrics,
            onPrevious: onPrevious,
            onNext: onNext,
          ),
          const SizedBox(height: AppSpace.sm),
          NavigationBar(
            selectedIndex: navigationIndex,
            backgroundColor: colors.surfaceContainerHighest.withValues(
              alpha: 0.92,
            ),
            elevation: 0,
            onDestinationSelected: (int index) {
              final int target = switch (index) {
                1 => 1,
                2 => 2,
                3 => 4,
                _ => 0,
              };
              onSelectTab(target);
            },
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.home_rounded),
                label: '首页',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                label: '搜索',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_rounded),
                label: '音乐库',
              ),
              NavigationDestination(
                icon: Icon(Icons.graphic_eq_rounded),
                label: '播放',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PortraitMiniPlayerBar extends StatelessWidget {
  const PortraitMiniPlayerBar({
    super.key,
    required this.currentSong,
    required this.fallbackTrack,
    required this.playbackState,
    required this.playbackMode,
    required this.coverSeedColor,
    required this.lyricsAvailable,
    required this.lyricsBusy,
    required this.onOpenPlayer,
    required this.onPlayPause,
    required this.onPlaybackMode,
    required this.onLyrics,
    required this.onPrevious,
    required this.onNext,
  });

  final FreeMusicSong? currentSong;
  final DemoTrack fallbackTrack;
  final PlaybackUiState playbackState;
  final NativePlaybackMode playbackMode;
  final Color coverSeedColor;
  final bool lyricsAvailable;
  final bool lyricsBusy;
  final VoidCallback onOpenPlayer;
  final VoidCallback onPlayPause;
  final VoidCallback onPlaybackMode;
  final VoidCallback onLyrics;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String title = playbackState.title.isEmpty
        ? currentSong?.name ?? fallbackTrack.title
        : playbackState.title;
    final String artist = playbackState.artist.isEmpty
        ? currentSong?.artist ?? fallbackTrack.artist
        : playbackState.artist;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(AppRadius.panel),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        onTap: onOpenPlayer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Row(
            children: <Widget>[
              Hero(
                tag: 'now-playing-artwork',
                child: PortraitArtwork(
                  visual: fallbackTrack,
                  imageUrl: playbackState.coverUrl.isEmpty
                      ? currentSong?.cover ?? ''
                      : playbackState.coverUrl,
                  size: 52,
                  icon: Icons.album_rounded,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: labelForPlaybackMode(playbackMode),
                onPressed: onPlaybackMode,
                icon: Icon(iconForPlaybackMode(playbackMode)),
              ),
              IconButton(
                tooltip: lyricsAvailable || lyricsBusy ? '歌词' : '歌词',
                onPressed: onLyrics,
                icon: const Icon(Icons.lyrics_rounded),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: coverSeedColor),
                onPressed: onPlayPause,
                icon: Icon(
                  playbackState.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerLyricsView extends StatefulWidget {
  const PlayerLyricsView({
    super.key,
    required this.lyrics,
    required this.position,
    required this.lyricsBusy,
    required this.lyricsError,
  });

  final FreeMusicLyrics? lyrics;
  final Duration position;
  final bool lyricsBusy;
  final String lyricsError;

  @override
  State<PlayerLyricsView> createState() => _PlayerLyricsViewState();
}

class _PlayerLyricsViewState extends State<PlayerLyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _lastIndex = -1;

  @override
  void didUpdateWidget(PlayerLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final List<FreeMusicLyricLine> lines = widget.lyrics?.lines ?? const [];
    final int activeIndex = activeLyricLineIndex(lines, widget.position);
    if (activeIndex != _lastIndex && activeIndex >= 0) {
      _lastIndex = activeIndex;
      _scrollToIndex(activeIndex);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      const double lineExtent = 32.0;
      final double target = (index * lineExtent) - 44.0;
      final double clamped = target.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    if (widget.lyricsBusy) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.lyricsError.isNotEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            '歌词加载失败',
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.error),
          ),
        ),
      );
    }
    final List<FreeMusicLyricLine> lines = widget.lyrics?.lines ?? const [];
    if (lines.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            widget.lyrics?.raw.isNotEmpty == true ? widget.lyrics!.raw : '等待歌词同步',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final int activeIndex = activeLyricLineIndex(lines, widget.position);

    return SizedBox(
      height: 120,
      child: ShaderMask(
        shaderCallback: (Rect rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: <double>[0, 0.22, 0.78, 1],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: lines.length,
          itemExtent: 32,
          padding: const EdgeInsets.symmetric(vertical: 44),
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (BuildContext context, int index) {
            final bool active = index == activeIndex;
            return Align(
              alignment: Alignment.center,
              child: Text(
                lines[index].text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  fontSize: active ? 18 : 16,
                  color: active
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.38),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
