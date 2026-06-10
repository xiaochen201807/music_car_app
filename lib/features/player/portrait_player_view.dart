import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../free_music_api.dart';
import '../../models/demo_track.dart';
import '../../models/playback_ui_state.dart';
import '../../native_audio_controller.dart';
import '../../theme/design_tokens.dart';
import '../../utils/formatters.dart';
import '../../utils/lyrics_utils.dart';
import '../../shared/portrait_artwork.dart';
import '../../shared/portrait_circle_button.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/luxury_loading_indicator.dart';
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
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        seed.withValues(alpha: 0.40),
                        colors.surface.withValues(alpha: 0.8),
                        colors.surface,
                      ],
                      stops: const <double>[0, 0.5, 1],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: _BlurredBackgroundArtwork(
                  imageUrl: playbackState.coverUrl.isEmpty
                      ? currentSong?.cover ?? ''
                      : playbackState.coverUrl,
                  fallbackColor: seed,
                ),
              ),
              Positioned.fill(
                child: childWidget!,
              ),
            ],
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
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onPlayPause();
                    },
                    onHorizontalDragEnd: (DragEndDetails details) {
                      if (details.primaryVelocity != null) {
                        if (details.primaryVelocity! < 0) {
                          // 向左滑动 -> 上一首
                          HapticFeedback.mediumImpact();
                          onPrevious();
                        } else if (details.primaryVelocity! > 0) {
                          // 向右滑动 -> 下一首
                          HapticFeedback.mediumImpact();
                          onNext();
                        }
                      }
                    },
                    child: Hero(
                      tag: 'now-playing-artwork',
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _SpinningVinylDisc(
                          spinning: playbackState.playing,
                          imageUrl: playbackState.coverUrl.isEmpty
                              ? currentSong?.cover ?? ''
                              : playbackState.coverUrl,
                          fallbackTrack: fallbackTrack,
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
                        : (double value) {
                            HapticFeedback.lightImpact();
                            onSeek(
                              Duration(
                                milliseconds: (duration.inMilliseconds * value)
                                    .round(),
                              ),
                            );
                          },
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Row(
                    children: <Widget>[
                      Text(formatDuration(playbackState.position)),
                      const Spacer(),
                      Text(formatDuration(duration)),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),
                  PlayerLyricsView(
                    lyrics: lyrics,
                    position: playbackState.position,
                    lyricsBusy: lyricsBusy,
                    lyricsError: lyricsError,
                    onSeek: onSeek,
                  ),
                  const SizedBox(height: AppSpace.xl2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        PortraitCircleButton(
                          icon: iconForPlaybackMode(playbackMode),
                          label: labelForPlaybackMode(playbackMode),
                          onTap: onPlaybackMode,
                        ),
                        PortraitCircleButton(
                          icon: Icons.equalizer_rounded,
                          label: '音质',
                          onTap: onQuality,
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

class PortraitBottomChrome extends StatefulWidget {
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
  State<PortraitBottomChrome> createState() => _PortraitBottomChromeState();
}

class _PortraitBottomChromeState extends State<PortraitBottomChrome> {
  bool _isMinimized = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final int navigationIndex = switch (widget.selectedTab) {
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
      child: GestureDetector(
        onVerticalDragEnd: (DragEndDetails details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! > 200 && !_isMinimized) {
              setState(() {
                _isMinimized = true;
              });
            } else if (details.primaryVelocity! < -200 && _isMinimized) {
              setState(() {
                _isMinimized = false;
              });
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastOutSlowIn,
          child: GlassCard(
            radius: AppRadius.panel,
            shadows: const <BoxShadow>[],
            child: InkWell(
              onTap: _isMinimized
                  ? () {
                      setState(() {
                        _isMinimized = false;
                      });
                    }
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.panel),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 32,
                        height: 3,
                        margin: const EdgeInsets.only(top: 2, bottom: 2),
                        decoration: BoxDecoration(
                          color: colors.onSurface.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                    PortraitMiniPlayerBar(
                      currentSong: widget.currentSong,
                      fallbackTrack: widget.fallbackTrack,
                      playbackState: widget.playbackState,
                      playbackMode: widget.playbackMode,
                      coverSeedColor: widget.coverSeedColor,
                      onOpenPlayer: () {
                        HapticFeedback.lightImpact();
                        widget.onSelectTab(4);
                      },
                      onPlayPause: widget.onPlayPause,
                      onPlaybackMode: widget.onPlaybackMode,
                      onQuality: widget.onQuality,
                      onPrevious: widget.onPrevious,
                      onNext: widget.onNext,
                      transparent: true,
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                            color: colors.onSurface.withValues(alpha: 0.08),
                          ),
                          Theme(
                            data: Theme.of(context).copyWith(
                              navigationBarTheme: NavigationBarThemeData(
                                indicatorColor: Colors.transparent,
                                labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: colors.primary,
                                    );
                                  }
                                  return theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.onSurfaceVariant,
                                  );
                                }),
                                iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return IconThemeData(color: colors.primary, size: 24);
                                  }
                                  return IconThemeData(color: colors.onSurfaceVariant, size: 24);
                                }),
                              ),
                            ),
                            child: NavigationBar(
                              height: 60,
                              selectedIndex: navigationIndex,
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              onDestinationSelected: (int index) {
                                final int target = switch (index) {
                                  1 => 1,
                                  2 => 2,
                                  3 => 5,
                                  _ => 0,
                                };
                                HapticFeedback.lightImpact();
                                widget.onSelectTab(target);
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
                          ),
                        ],
                      ),
                      crossFadeState: _isMinimized
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 240),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
    this.transparent = false,
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
  final bool transparent;

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

    final Widget innerContent = InkWell(
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
            GlassPill(
              onTap: () {
                HapticFeedback.lightImpact();
                onPlayPause();
              },
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: Center(
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: Icon(
                  playbackState.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: playbackState.playing ? colors.primary : colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (transparent) {
      return innerContent;
    }

    return GlassCard(
      radius: AppRadius.panel,
      shadows: const <BoxShadow>[],
      child: innerContent,
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
  static const double _lyricLineHeight = 48.0;

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
        (offset / _lyricLineHeight).round().clamp(0, lines.length - 1);
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
      final double target = index * _lyricLineHeight;
      final double clamped = target.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
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
      top: 76.0, // Vertically center on the line height 48 inside a 200 height container
      height: 48.0,
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
        child: Center(child: LuxuryLoadingIndicator()),
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
                stops: <double>[0, 0.25, 0.75, 1],
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
                itemExtent: _lyricLineHeight,
                padding: const EdgeInsets.symmetric(vertical: 76.0),
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
                              ? theme.textTheme.titleLarge!.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                  shadows: <Shadow>[
                                    Shadow(
                                      color: AppColor.accentRoseEnd.withValues(alpha: 0.35),
                                      offset: Offset.zero,
                                      blurRadius: 14,
                                    ),
                                  ],
                                )
                              : theme.textTheme.titleMedium!.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: colors.onSurface.withValues(alpha: 0.20),
                                  fontSize: 15,
                                ),
                          child: active
                              ? ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return AppColor.accentGradient.createShader(
                                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                                    );
                                  },
                                  blendMode: BlendMode.srcIn,
                                  child: Text(
                                    line.text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : Text(
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

class _SpinningVinylDisc extends StatefulWidget {
  const _SpinningVinylDisc({
    required this.spinning,
    required this.imageUrl,
    required this.fallbackTrack,
  });

  final bool spinning;
  final String imageUrl;
  final DemoTrack fallbackTrack;

  @override
  State<_SpinningVinylDisc> createState() => _SpinningVinylDiscState();
}

class _SpinningVinylDiscState extends State<_SpinningVinylDisc>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _armCtrl;
  late final Animation<double> _armAngleAnimation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.spinning) _ctrl.repeat();

    _armCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _armAngleAnimation = Tween<double>(
      begin: -0.35,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _armCtrl,
        curve: Curves.easeOutCubic,
      ),
    );

    if (widget.spinning) {
      _armCtrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _SpinningVinylDisc old) {
    super.didUpdateWidget(old);
    if (widget.spinning != old.spinning) {
      if (widget.spinning) {
        _ctrl.repeat();
        _armCtrl.forward();
      } else {
        _ctrl.stop();
        _armCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _armCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: <Widget>[
        // 旋转的黑胶盘和封面
        RotationTransition(
          turns: _ctrl,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // 黑胶唱片主体
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF090A0E),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // 音轨细纹
              const Positioned.fill(
                child: CustomPaint(
                  painter: _VinylTracksPainter(),
                ),
              ),
              // 封面图片 (占唱片直径的 68%)
              FractionallySizedBox(
                widthFactor: 0.68,
                heightFactor: 0.68,
                child: ClipOval(
                  child: PortraitArtwork(
                    visual: widget.fallbackTrack,
                    imageUrl: widget.imageUrl,
                    icon: Icons.album_rounded,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 静态扫过的高光反射层 (固定光照反射，不随唱片转动而旋转)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _VinylRefractionPainter(),
            ),
          ),
        ),
        // 轴心银金属装饰圈
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: <Color>[
                Color(0xFF8E8E93),
                Color(0xFFD1D1D6),
                Color(0xFFE5E5EA),
                Color(0xFF8E8E93),
                Color(0xFF3A3A3C),
                Color(0xFF8E8E93),
              ],
              stops: <double>[0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF04060D),
              ),
            ),
          ),
        ),
        // 静态唱针 (悬浮于唱片右上方，在 build 阶段进行起落角度旋转)
        Positioned(
          right: 15,
          top: -10,
          width: 80,
          height: 120,
          child: AnimatedBuilder(
            animation: _armAngleAnimation,
            builder: (BuildContext context, Widget? child) {
              return Transform.rotate(
                angle: _armAngleAnimation.value,
                alignment: const Alignment(0.7, -0.8),
                child: child,
              );
            },
            child: const CustomPaint(
              painter: _ToneArmPainter(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToneArmPainter extends CustomPainter {
  const _ToneArmPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint armPaint = Paint()
      ..color = const Color(0xFFD1D1D6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final Paint jointPaint = Paint()
      ..color = const Color(0xFF48484A)
      ..style = PaintingStyle.fill;

    final Paint headPaint = Paint()
      ..color = const Color(0xFF1C1C1E)
      ..style = PaintingStyle.fill;

    final Offset pivot = Offset(size.width * 0.85, size.height * 0.15);

    // 1. 底座同心圆
    canvas.drawCircle(pivot, 10.0, jointPaint);
    canvas.drawCircle(pivot, 5.0, Paint()..color = const Color(0xFFE5E5EA));

    // 2. 针臂折线
    final Path path = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(size.width * 0.65, size.height * 0.55)
      ..lineTo(size.width * 0.25, size.height * 0.9);
    canvas.drawPath(path, armPaint);

    // 3. 针头 (带有粉红色彩装饰点缀)
    final Offset headOffset = Offset(size.width * 0.25, size.height * 0.9);
    canvas.save();
    canvas.translate(headOffset.dx, headOffset.dy);
    canvas.rotate(-math.pi / 5);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 10, height: 16),
      headPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, 3), width: 6, height: 3),
      Paint()..color = const Color(0xFFFF5C9E),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VinylTracksPainter extends CustomPainter {
  const _VinylTracksPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double maxRadius = size.width / 2;

    // 绘制 5 圈唱片音轨线
    for (double i = 0.72; i < 0.98; i += 0.05) {
      canvas.drawCircle(center, maxRadius * i, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VinylRefractionPainter extends CustomPainter {
  const _VinylRefractionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: <Color>[
          Colors.transparent,
          Colors.white.withValues(alpha: 0.10),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..blendMode = BlendMode.screen;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 高阶歌曲封面高斯模糊流体背景
class _BlurredBackgroundArtwork extends StatelessWidget {
  const _BlurredBackgroundArtwork({
    required this.imageUrl,
    required this.fallbackColor,
  });

  final String imageUrl;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final Uri? uri = Uri.tryParse(imageUrl);
    final bool canLoad =
        uri != null &&
        uri.hasAbsolutePath &&
        (uri.isScheme('http') || uri.isScheme('https'));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1500),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: KeyedSubtree(
        key: ValueKey<String>(imageUrl.isEmpty ? fallbackColor.toString() : imageUrl),
        child: SizedBox.expand(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 64, sigmaY: 64),
            child: Opacity(
              opacity: 0.16,
              child: canLoad
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: fallbackColor),
                      errorWidget: (_, _, _) => Container(color: fallbackColor),
                    )
                  : Container(
                      color: fallbackColor.withValues(alpha: 0.8),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
