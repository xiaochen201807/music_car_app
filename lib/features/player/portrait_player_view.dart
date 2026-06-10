import 'dart:async';
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
import '../../widgets/glass_card.dart';
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
    required this.onQuality,
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
  final VoidCallback onQuality;
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

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollUpdateNotification) {
          if (notification.metrics.pixels <= 0 &&
              notification.scrollDelta != null &&
              notification.scrollDelta! < -8) {
            onClose();
            return true;
          }
        }
        return false;
      },
      child: TweenAnimationBuilder<Color?>(
        duration: const Duration(milliseconds: 1500),
        curve: Curves.easeInOut,
        tween: ColorTween(end: coverSeedColor),
        builder:
            (BuildContext context, Color? animatedColor, Widget? childWidget) {
          final Color seed = animatedColor ?? coverSeedColor;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  seed.withValues(alpha: 0.45),
                  colors.surface,
                  colors.surface,
                ],
                stops: const <double>[0, 0.44, 1],
              ),
            ),
            child: childWidget,
          );
        },
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
                  const SizedBox(height: AppSpace.lg),
                  GestureDetector(
                    onVerticalDragEnd: (DragEndDetails details) {
                      if (details.primaryVelocity != null &&
                          details.primaryVelocity! > 200) {
                        onClose();
                      }
                    },
                    child: Hero(
                      tag: 'now-playing-artwork',
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.panel),
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              _SpinningArtwork(
                                spinning: playbackState.playing,
                                child: PortraitArtwork(
                                  visual: fallbackTrack,
                                  imageUrl: playbackState.coverUrl.isEmpty
                                      ? currentSong?.cover ?? ''
                                      : playbackState.coverUrl,
                                  icon: Icons.album_rounded,
                                ),
                              ),
                              Container(
                                width: AppSpace.xl4 * 1.5,
                                height: AppSpace.xl4 * 1.5,
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: AppColor.scrimStrong.withValues(alpha: 0.07),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
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
                  const SizedBox(height: AppSpace.xs),
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
                  const SizedBox(height: AppSpace.lg),
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
                        icon: Icons.equalizer_rounded,
                        label: '音质',
                        onTap: onQuality,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  PortraitSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        PlayerLyricsView(
                          lyrics: lyrics,
                          position: playbackState.position,
                          lyricsBusy: lyricsBusy,
                          lyricsError: lyricsError,
                          onSeek: onSeek,
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
        return GlassCard(
          radius: AppRadius.control,
          shadows: const <BoxShadow>[],
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
    required this.onSelectTab,
    required this.onPlayPause,
    required this.onPlaybackMode,
    required this.onQuality,
    required this.onPrevious,
    required this.onNext,
  });

  final int selectedTab;
  final FreeMusicSong? currentSong;
  final DemoTrack fallbackTrack;
  final PlaybackUiState playbackState;
  final NativePlaybackMode playbackMode;
  final Color coverSeedColor;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onPlayPause;
  final VoidCallback onPlaybackMode;
  final VoidCallback onQuality;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int navigationIndex = switch (selectedTab) {
      1 => 1,
      2 || 3 => 2,
      5 => 3,
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
            onOpenPlayer: () => onSelectTab(4),
            onPlayPause: onPlayPause,
            onPlaybackMode: onPlaybackMode,
            onQuality: onQuality,
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
                3 => 5,
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
                icon: Icon(Icons.settings_rounded),
                label: '设置',
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
    required this.onOpenPlayer,
    required this.onPlayPause,
    required this.onPlaybackMode,
    required this.onQuality,
    required this.onPrevious,
    required this.onNext,
  });

  final FreeMusicSong? currentSong;
  final DemoTrack fallbackTrack;
  final PlaybackUiState playbackState;
  final NativePlaybackMode playbackMode;
  final Color coverSeedColor;
  final VoidCallback onOpenPlayer;
  final VoidCallback onPlayPause;
  final VoidCallback onPlaybackMode;
  final VoidCallback onQuality;
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
    return GlassCard(
      radius: AppRadius.panel,
      shadows: const <BoxShadow>[],
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
                tooltip: '音质',
                onPressed: onQuality,
                icon: const Icon(Icons.equalizer_rounded),
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
    this.onSeek,
  });

  final FreeMusicLyrics? lyrics;
  final Duration position;
  final bool lyricsBusy;
  final String lyricsError;
  final ValueChanged<Duration>? onSeek;

  @override
  State<PlayerLyricsView> createState() => _PlayerLyricsViewState();
}

class _PlayerLyricsViewState extends State<PlayerLyricsView> {
  final ScrollController _scrollController = ScrollController();
  int _lastIndex = -1;
  bool _isUserScrolling = false;
  int _centerIndex = 0;
  Timer? _userScrollTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(PlayerLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final List<FreeMusicLyricLine> lines = widget.lyrics?.lines ?? const [];
    final int activeIndex = activeLyricLineIndex(lines, widget.position);
    if (activeIndex != _lastIndex && activeIndex >= 0) {
      _lastIndex = activeIndex;
      if (!_isUserScrolling) {
        _scrollToIndex(activeIndex);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _userScrollTimer?.cancel();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final double offset = _scrollController.offset;
    final List<FreeMusicLyricLine> lines = widget.lyrics?.lines ?? const [];
    if (lines.isEmpty) return;
    final int calculatedIndex =
        (offset / 32.0).round().clamp(0, lines.length - 1);
    if (calculatedIndex != _centerIndex) {
      setState(() {
        _centerIndex = calculatedIndex;
      });
    }
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

  void _startRestoreAutoScrollTimer() {
    _userScrollTimer?.cancel();
    _userScrollTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isUserScrolling = false;
        });
        final List<FreeMusicLyricLine> lines = widget.lyrics?.lines ?? const [];
        final int activeIndex = activeLyricLineIndex(lines, widget.position);
        if (activeIndex >= 0) {
          _scrollToIndex(activeIndex);
        }
      }
    });
  }

  Widget _buildSeekOverlay(FreeMusicLyricLine line) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Positioned(
      left: 0,
      right: 0,
      top: 60 - 16, // Vertically center on the line height 32
      height: 32,
      child: IgnorePointer(
        ignoring: false,
        child: Row(
          children: <Widget>[
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Container(
                height: 1,
                color: colors.primary.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            GestureDetector(
              onTap: () {
                widget.onSeek?.call(line.time);
                setState(() {
                  _isUserScrolling = false;
                });
              },
              child: GlassCard(
                radius: AppRadius.control,
                shadows: const <BoxShadow>[],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: AppSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 14,
                      color: colors.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatDuration(line.time),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Container(
                height: 1,
                color: colors.primary.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(width: AppSpace.md),
          ],
        ),
      ),
    );
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
            widget.lyrics?.raw.isNotEmpty == true
                ? widget.lyrics!.raw
                : '等待歌词同步',
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
      height: 200,
      child: Stack(
        children: <Widget>[
          ShaderMask(
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
                stops: <double>[0, 0.15, 0.85, 1],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (notification is ScrollStartNotification) {
                  if (notification.dragDetails != null) {
                    setState(() {
                      _isUserScrolling = true;
                    });
                    _userScrollTimer?.cancel();
                  }
                } else if (notification is ScrollEndNotification) {
                  _startRestoreAutoScrollTimer();
                }
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                itemCount: lines.length,
                itemExtent: 40,
                padding: const EdgeInsets.symmetric(vertical: 80),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemBuilder: (BuildContext context, int index) {
                  final bool active = index == activeIndex;
                  final FreeMusicLyricLine line = lines[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        widget.onSeek?.call(line.time);
                        setState(() {
                          _isUserScrolling = false;
                        });
                      },
                      child: Align(
                        alignment: Alignment.center,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: active
                              ? theme.textTheme.headlineSmall!.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: colors.primary,
                                  letterSpacing: -0.3,
                                )
                              : theme.textTheme.titleMedium!.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface.withValues(alpha: 0.45),
                                  fontSize: 15,
                                ),
                          child: Text(
                            line.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 200 / 2 - AppSpace.xl,
            height: AppSpace.xl4,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    colors.primary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  stops: const <double>[0.5, 1],
                ),
              ),
            ),
          ),
          if (_isUserScrolling &&
              lines.isNotEmpty &&
              _centerIndex >= 0 &&
              _centerIndex < lines.length)
            _buildSeekOverlay(lines[_centerIndex]),
        ],
      ),
    );
  }
}

/// 封面持续旋转组件：播放时匀速转动，暂停时停止。
class _SpinningArtwork extends StatefulWidget {
  const _SpinningArtwork({required this.spinning, required this.child});

  final bool spinning;
  final Widget child;

  @override
  State<_SpinningArtwork> createState() => _SpinningArtworkState();
}

class _SpinningArtworkState extends State<_SpinningArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.spinning) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _SpinningArtwork old) {
    super.didUpdateWidget(old);
    if (widget.spinning != old.spinning) {
      widget.spinning ? _ctrl.repeat() : _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _ctrl, child: widget.child);
  }
}
