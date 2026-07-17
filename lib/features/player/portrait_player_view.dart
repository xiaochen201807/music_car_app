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
import '../../shared/portrait_artwork.dart';
import '../../shared/portrait_circle_button.dart';
import '../../shared/portrait_play_button.dart';
import '../../widgets/glass_card.dart';
import 'player_lyrics_view.dart';
import 'player_seek_bar.dart';

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
    required this.animationsEnabled,
    required this.favorite,
    required this.onClose,
    required this.onToggleFavorite,
    required this.onPlayPause,
    required this.onPlaybackMode,
    required this.onQuality,
    this.playbackPositionStream,
    required this.onSeek,
    required this.onPrevious,
    required this.onNext,
    required this.onRetryLyrics,
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
  final bool animationsEnabled;
  final bool favorite;
  final VoidCallback onClose;
  final VoidCallback? onToggleFavorite;
  final VoidCallback onPlayPause;
  final VoidCallback onPlaybackMode;
  final VoidCallback onQuality;
  final Stream<PlaybackUiState>? playbackPositionStream;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onRetryLyrics;

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
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        tween: ColorTween(end: coverSeedColor),
        builder:
            (BuildContext context, Color? animatedColor, Widget? childWidget) {
              final Color seed =
                  Color.lerp(
                    animatedColor ?? coverSeedColor,
                    AppColor.bgBase,
                    0.68,
                  ) ??
                  AppColor.glowViolet;
              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: colors.surface),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            seed.withValues(alpha: 0.28),
                            AppColor.bgBase.withValues(alpha: 0.88),
                            AppColor.bgDeep,
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
Positioned.fill(child: childWidget!),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: _PlaybackPositionBuilder(
                        stream: playbackPositionStream,
                        initialState: playbackState,
                        builder: (BuildContext context, PlaybackUiState state) {
                          return PlayerSeekBar(
                            position: state.position,
                            bufferedPosition: state.bufferedPosition,
                            duration: state.duration ?? duration,
                            busy: state.isBusy,
                            onSeek: onSeek,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
        // Column (not scroll) so the lyrics band sits between transport and
        // seek bar and can vertically center empty/loading states.
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.md,
              AppSpace.xl,
              0,
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    PortraitCircleButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      label: '收起',
                      onTap: onClose,
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            '正在播放',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '左滑下一首 · 右滑上一首 · 下滑收起',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.72,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
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
                const SizedBox(height: AppSpace.md),
                // Cap vinyl height so lyrics keep a stable band above the seek bar.
                Flexible(
                  flex: 5,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GestureDetector(
                        onVerticalDragEnd: (DragEndDetails details) {
                          if (details.primaryVelocity != null &&
                              details.primaryVelocity! > 200) {
                            onClose();
                          }
                        },
                        onHorizontalDragEnd: (DragEndDetails details) {
                          final double? velocity = details.primaryVelocity;
                          if (velocity == null || velocity.abs() < 200) {
                            return;
                          }
                          HapticFeedback.mediumImpact();
                          if (velocity < 0) {
                            onNext();
                          } else {
                            onPrevious();
                          }
                        },
                        child: _VinylTouchWrapper(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            onPlayPause();
                          },
                          child: Hero(
                            tag: 'now-playing-artwork',
                            child: _SpinningVinylDisc(
                              spinning:
                                  playbackState.playing && animationsEnabled,
                              imageUrl: playbackState.coverUrl.isEmpty
                                  ? currentSong?.cover ?? ''
                                  : playbackState.coverUrl,
                              fallbackTrack: fallbackTrack,
                              transitionKey:
                                  '${currentSong?.source ?? ''}:${currentSong?.id ?? ''}:${playbackState.coverUrl}',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                _PlayerTitleBlock(title: title, artist: artist),
                const SizedBox(height: AppSpace.sm),
                _PlayerMetaRow(
                  duration: duration,
                  playbackState: playbackState,
                  qualities: qualities,
                  qualitiesBusy: qualitiesBusy,
                  qualityError: qualityError,
                ),
                if (playbackState.isBusy) ...<Widget>[
                  const SizedBox(height: AppSpace.sm),
                  _PlaybackLoadingBanner(playbackState: playbackState),
                ],
                const SizedBox(height: AppSpace.md),
                _PlayerTransportBar(
                  playing: playbackState.playing,
                  busy: playbackState.isBusy,
                  playbackMode: playbackMode,
                  onPlaybackMode: onPlaybackMode,
                  onPrevious: onPrevious,
                  onPlayPause: onPlayPause,
                  onNext: onNext,
                  onQuality: onQuality,
                ),
                // Lyrics fill remaining space and center empty/loading copy.
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpace.md,
                      bottom: 72,
                    ),
                    child: _PlaybackPositionBuilder(
                      stream: playbackPositionStream,
                      initialState: playbackState,
                      builder: (BuildContext context, PlaybackUiState state) {
                        return PlayerLyricsView(
                          lyrics: lyrics,
                          position: state.position,
                          playing: state.playing,
                          lyricsBusy: lyricsBusy,
                          lyricsError: lyricsError,
                          currentSong: currentSong,
                          onSeek: onSeek,
                          onRetry: onRetryLyrics,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerTitleBlock extends StatelessWidget {
  const _PlayerTitleBlock({required this.title, required this.artist});

  final String title;
  final String artist;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Column(
      children: <Widget>[
        MarqueeText(
          text: title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        if (artist.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpace.xs),
          Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _PlayerTransportBar extends StatelessWidget {
  const _PlayerTransportBar({
    required this.playing,
    required this.busy,
    required this.playbackMode,
    required this.onPlaybackMode,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.onQuality,
  });

  final bool playing;
  final bool busy;
  final NativePlaybackMode playbackMode;
  final VoidCallback onPlaybackMode;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onQuality;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        PortraitCircleButton(
          icon: iconForPlaybackMode(playbackMode),
          label: labelForPlaybackMode(playbackMode),
          onTap: () {
            HapticFeedback.selectionClick();
            onPlaybackMode();
          },
        ),
        PortraitCircleButton(
          icon: Icons.skip_previous_rounded,
          label: '上一首',
          onTap: () {
            HapticFeedback.mediumImpact();
            onPrevious();
          },
        ),
        PortraitPlayButton(
          playing: playing,
          onTap: busy
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onPlayPause();
                },
          size: 72,
        ),
        PortraitCircleButton(
          icon: Icons.skip_next_rounded,
          label: '下一首',
          onTap: () {
            HapticFeedback.mediumImpact();
            onNext();
          },
        ),
        PortraitCircleButton(
          icon: Icons.equalizer_rounded,
          label: '音质',
          onTap: () {
            HapticFeedback.selectionClick();
            onQuality();
          },
        ),
      ],
    );
  }
}

class _PlaybackPositionBuilder extends StatelessWidget {
  const _PlaybackPositionBuilder({
    required this.stream,
    required this.initialState,
    required this.builder,
  });

  final Stream<PlaybackUiState>? stream;
  final PlaybackUiState initialState;
  final Widget Function(BuildContext context, PlaybackUiState state) builder;

  @override
  Widget build(BuildContext context) {
    final Stream<PlaybackUiState>? effectiveStream = stream;
    if (effectiveStream == null) {
      return builder(context, initialState);
    }
    return StreamBuilder<PlaybackUiState>(
      stream: effectiveStream,
      initialData: initialState,
      builder: (BuildContext context, AsyncSnapshot<PlaybackUiState> snapshot) {
        return builder(context, snapshot.data ?? initialState);
      },
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

  bool _isLosslessQuality(FreeMusicQuality quality) {
    final String combined =
        '${quality.bitrate} ${quality.name} ${quality.format}'.toLowerCase();
    return combined.contains('flac') ||
        combined.contains('lossless') ||
        combined.contains('无损');
  }

  int _qualityBitrateValue(FreeMusicQuality quality) {
    final String value = quality.bitrate.toLowerCase();
    if (_isLosslessQuality(quality)) {
      return 1000;
    }
    return int.tryParse(RegExp(r'\d+').firstMatch(value)?.group(0) ?? '') ??
        128;
  }

  String _qualityTierLabel(FreeMusicQuality quality) {
    if (_isLosslessQuality(quality)) {
      return '无损';
    }
    final int bitrate = _qualityBitrateValue(quality);
    if (bitrate >= 192) {
      return '极高';
    }
    if (bitrate >= 128) {
      return '较高';
    }
    return '标准';
  }

  List<String> _qualityTierLabels() {
    final Set<String> labels = <String>{};
    for (final FreeMusicQuality quality in qualities) {
      labels.add(_qualityTierLabel(quality));
    }
    return <String>[
      '标准',
      '较高',
      '极高',
      '无损',
    ].where(labels.contains).toList(growable: false);
  }

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
    final List<String> qualityLabels = _qualityTierLabels();
    return Wrap(
      spacing: AppSpace.xs,
      runSpacing: AppSpace.xs,
      children: qualityLabels.map((String text) {
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

class _PlayerMetaRow extends StatelessWidget {
  const _PlayerMetaRow({
    required this.duration,
    required this.playbackState,
    required this.qualities,
    required this.qualitiesBusy,
    required this.qualityError,
  });

  final Duration duration;
  final PlaybackUiState playbackState;
  final List<FreeMusicQuality> qualities;
  final bool qualitiesBusy;
  final String qualityError;

  @override
  Widget build(BuildContext context) {
    // Flat metadata row under the title block: status, duration, qualities.
    return Row(
      children: <Widget>[
        _PlaybackStatusPill(playbackState: playbackState),
        const SizedBox(width: AppSpace.sm),
        _PlayerInfoPill(
          icon: Icons.schedule_rounded,
          label: formatDuration(duration),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: QualityChips(
            qualities: qualities,
            busy: qualitiesBusy,
            error: qualityError,
          ),
        ),
      ],
    );
  }
}

class _PlaybackStatusPill extends StatelessWidget {
  const _PlaybackStatusPill({required this.playbackState});

  final PlaybackUiState playbackState;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final IconData icon = playbackState.isBusy
        ? Icons.sync_rounded
        : playbackState.playing
        ? Icons.graphic_eq_rounded
        : Icons.pause_rounded;

    return GlassPill(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: AppSpace.xs),
          Text(
            playbackState.statusLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybackLoadingBanner extends StatelessWidget {
  const _PlaybackLoadingBanner({required this.playbackState});

  final PlaybackUiState playbackState;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return GlassCard(
      radius: AppRadius.control,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      shadows: const <BoxShadow>[],
      child: Row(
        children: <Widget>[
          SizedBox(
            width: AppSpace.lg,
            height: AppSpace.lg,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              playbackState.isLoading ? '正在解析播放地址' : '网络缓冲中，保持当前播放上下文',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerInfoPill extends StatelessWidget {
  const _PlayerInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return GlassPill(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: AppSpace.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
    // Mini player and navigation bar are both always visible. The mini player
    // sits above a persistent navigation rail so tab switching is one tap with
    // no hidden collapse/expand state.
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpace.md,
        0,
        AppSpace.md,
        AppSpace.md,
      ),
      child: GlassCard(
        key: const ValueKey<String>('portrait-bottom-chrome'),
        radius: AppRadius.panel,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
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
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                color: colors.onSurface.withValues(alpha: 0.08),
              ),
              Theme(
                data: Theme.of(context).copyWith(
                  navigationBarTheme: NavigationBarThemeData(
                    indicatorColor: Colors.transparent,
                    labelTextStyle: WidgetStateProperty.resolveWith((
                      Set<WidgetState> states,
                    ) {
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
                    iconTheme: WidgetStateProperty.resolveWith((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return IconThemeData(color: colors.primary, size: 24);
                      }
                      return IconThemeData(
                        color: colors.onSurfaceVariant,
                        size: 24,
                      );
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
                    if (widget.selectedTab == target) {
                      HapticFeedback.mediumImpact();
                    } else {
                      HapticFeedback.lightImpact();
                      widget.onSelectTab(target);
                    }
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

    final Widget innerContent = Padding(
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              key: const ValueKey<String>('portrait-mini-player-open-area'),
              behavior: HitTestBehavior.opaque,
              onTap: onOpenPlayer,
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
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          IconButton(
            tooltip: '上一首',
            onPressed: () {
              HapticFeedback.selectionClick();
              onPrevious();
            },
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          IconButton(
            tooltip: labelForPlaybackMode(playbackMode),
            onPressed: () {
              HapticFeedback.selectionClick();
              onPlaybackMode();
            },
            icon: Icon(iconForPlaybackMode(playbackMode)),
          ),
          PortraitPlayButton(
            size: 48,
            iconSize: 28,
            playing: playbackState.playing,
            onTap: () {
              HapticFeedback.lightImpact();
              onPlayPause();
            },
          ),
          IconButton(
            tooltip: '音质',
            onPressed: () {
              HapticFeedback.selectionClick();
              onQuality();
            },
            icon: const Icon(Icons.equalizer_rounded),
          ),
          IconButton(
            tooltip: '下一首',
            onPressed: () {
              HapticFeedback.selectionClick();
              onNext();
            },
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
    );

    if (transparent) {
      return innerContent;
    }

    return GlassCard(child: innerContent);
  }
}

class _SpinningVinylDisc extends StatefulWidget {
  const _SpinningVinylDisc({
    required this.spinning,
    required this.imageUrl,
    required this.fallbackTrack,
    required this.transitionKey,
  });

  final bool spinning;
  final String imageUrl;
  final DemoTrack fallbackTrack;
  final String transitionKey;

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
    ).animate(CurvedAnimation(parent: _armCtrl, curve: Curves.easeOutCubic));

    if (widget.spinning) {
      _armCtrl.value = 1.0;
    }
  }

  Timer? _debounceStopTimer;

  @override
  void didUpdateWidget(covariant _SpinningVinylDisc old) {
    super.didUpdateWidget(old);
    if (widget.spinning != old.spinning) {
      if (widget.spinning) {
        _debounceStopTimer?.cancel();
        _debounceStopTimer = null;
        if (!_ctrl.isAnimating) {
          _ctrl.repeat();
        }
        _armCtrl.forward();
      } else {
        _debounceStopTimer?.cancel();
        _debounceStopTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted && !widget.spinning) {
            _ctrl.stop();
            _armCtrl.reverse();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _debounceStopTimer?.cancel();
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
        RotationTransition(
          turns: _ctrl,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColor.vinylBase,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const Positioned.fill(
                child: CustomPaint(painter: _VinylTracksPainter()),
              ),
              FractionallySizedBox(
                widthFactor: 0.68,
                heightFactor: 0.68,
                child: ClipOval(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 460),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          final Animation<double> scale = Tween<double>(
                            begin: 0.92,
                            end: 1.0,
                          ).animate(animation);
                          final Animation<double> turn = Tween<double>(
                            begin: -0.035,
                            end: 0.0,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: scale,
                              child: RotationTransition(
                                turns: turn,
                                child: child,
                              ),
                            ),
                          );
                        },
                    child: PortraitArtwork(
                      key: ValueKey<String>(widget.transitionKey),
                      visual: widget.fallbackTrack,
                      imageUrl: widget.imageUrl,
                      icon: Icons.album_rounded,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 静态扫过的高光反射层 (固定光照反射，不随唱片转动而旋转)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _VinylRefractionPainter()),
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
                AppColor.vinylMetalMid,
                AppColor.vinylMetalLight,
                AppColor.vinylMetalHighlight,
                AppColor.vinylMetalMid,
                AppColor.vinylMetalDark,
                AppColor.vinylMetalMid,
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
                color: AppColor.bgDeep,
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
            child: const CustomPaint(painter: _ToneArmPainter()),
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
      ..color = AppColor.vinylMetalLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final Paint jointPaint = Paint()
      ..color = AppColor.vinylJoint
      ..style = PaintingStyle.fill;

    final Paint headPaint = Paint()
      ..color = AppColor.vinylHead
      ..style = PaintingStyle.fill;

    final Offset pivot = Offset(size.width * 0.85, size.height * 0.15);

    // 1. 底座同心圆
    canvas.drawCircle(pivot, 10.0, jointPaint);
    canvas.drawCircle(
      pivot,
      5.0,
      Paint()..color = AppColor.vinylMetalHighlight,
    );

    // 2. 针臂折线
    final Path path = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(size.width * 0.65, size.height * 0.55)
      ..lineTo(size.width * 0.25, size.height * 0.9);
    canvas.drawPath(path, armPaint);

    // 3. 针头 (低饱和金属色装饰点缀)
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
      Paint()..color = AppColor.accentPlatinumEnd,
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
        key: ValueKey<String>(
          imageUrl.isEmpty ? fallbackColor.toString() : imageUrl,
        ),
        child: SizedBox.expand(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Opacity(
              opacity: 0.16,
              child: canLoad
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: fallbackColor),
                      errorWidget: (_, _, _) => Container(color: fallbackColor),
                    )
                  : Container(color: fallbackColor.withValues(alpha: 0.8)),
            ),
          ),
        ),
      ),
    );
  }
}

class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.speed = 30.0,
  });

  final String text;
  final TextStyle? style;
  final double speed;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLayout());
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _stopScroll();
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkLayout());
    }
  }

  @override
  void dispose() {
    _stopScroll();
    _scrollController.dispose();
    super.dispose();
  }

  void _stopScroll() {
    _timer?.cancel();
    _timer = null;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  void _checkLayout() {
    if (!mounted || !_scrollController.hasClients) return;

    final double maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 0.0) {
      _startScroll(maxScroll);
    }
  }

  void _startScroll(double maxScroll) {
    _timer?.cancel();

    final double scrollDurationMs = (maxScroll / widget.speed) * 1000;

    void scrollLoop() {
      if (!mounted || !_scrollController.hasClients) return;

      _timer = Timer(const Duration(seconds: 2), () {
        if (!mounted || !_scrollController.hasClients) return;

        _scrollController
            .animateTo(
              maxScroll,
              duration: Duration(milliseconds: scrollDurationMs.round()),
              curve: Curves.linear,
            )
            .then((_) {
              if (!mounted || !_scrollController.hasClients) return;

              _timer = Timer(const Duration(seconds: 2), () {
                if (!mounted || !_scrollController.hasClients) return;

                _scrollController.jumpTo(0.0);
                scrollLoop();
              });
            });
      });
    }

    scrollLoop();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth;

        final TextPainter textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);

        final double textWidth = textPainter.width;

        if (textWidth <= maxWidth) {
          return Center(
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          );
        } else {
          return SizedBox(
            width: maxWidth,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Text(widget.text, style: widget.style, maxLines: 1),
            ),
          );
        }
      },
    );
  }
}

class _VinylTouchWrapper extends StatefulWidget {
  const _VinylTouchWrapper({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_VinylTouchWrapper> createState() => _VinylTouchWrapperState();
}

class _VinylTouchWrapperState extends State<_VinylTouchWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
