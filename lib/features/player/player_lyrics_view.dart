import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../free_music_api.dart';
import '../../services/lyric_offset_store.dart';
import '../../theme/design_tokens.dart';
import '../../utils/formatters.dart';
import '../../utils/lyrics_utils.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/luxury_loading_indicator.dart';
import '../../widgets/lyric_offset_adjuster.dart';

class PlayerLyricsView extends StatefulWidget {
  const PlayerLyricsView({
    super.key,
    required this.lyrics,
    required this.position,
    required this.playing,
    required this.lyricsBusy,
    required this.lyricsError,
    required this.currentSong,
    this.onSeek,
    this.onRetry,
  });

  final FreeMusicLyrics? lyrics;
  final Duration position;
  final bool playing;
  final bool lyricsBusy;
  final String lyricsError;
  final FreeMusicSong? currentSong;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onRetry;

  @override
  State<PlayerLyricsView> createState() => _PlayerLyricsViewState();
}

class _PlayerLyricsViewState extends State<PlayerLyricsView>
    with SingleTickerProviderStateMixin {
  static const double _lyricLineHeight = 48.0;

  final ScrollController _scrollController = ScrollController();
  int _lastIndex = -1;
  bool _isUserScrolling = false;
  bool _lyricsScrollLocked = false;
  int _centerIndex = 0;
  Timer? _userScrollTimer;
  Duration _offset = Duration.zero;

  late Duration _currentPosition;
  Ticker? _ticker;
  DateTime? _lastTickTime;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _currentPosition = widget.position;
    _updateTicker();
    _loadOffset();
  }

  Future<void> _loadOffset() async {
    if (widget.currentSong == null) return;
    final LyricOffsetStore store = LyricOffsetStore();
    final Duration offset = await store.getOffset(widget.currentSong!);
    if (mounted) {
      setState(() {
        _offset = offset;
      });
    }
  }

  void _showOffsetAdjuster() {
    if (widget.currentSong == null) return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => LyricOffsetAdjuster(
        song: widget.currentSong!,
        currentOffset: _offset,
        onOffsetChanged: (Duration offset) {
          setState(() {
            _offset = offset;
          });
        },
      ),
    );
  }

  bool _sameSong(FreeMusicSong? a, FreeMusicSong? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a == null || b == null) {
      return false;
    }
    return a.source == b.source && a.id == b.id;
  }

  @override
  void didUpdateWidget(PlayerLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool songChanged = !_sameSong(widget.currentSong, oldWidget.currentSong);
    final bool lyricsChanged = !identical(widget.lyrics, oldWidget.lyrics);

    // On track switch, drop the previous song's scroll position / local offset
    // so the ticker does not keep highlighting against the wrong lyrics.
    if (songChanged) {
      _userScrollTimer?.cancel();
      _isUserScrolling = false;
      _lyricsScrollLocked = false;
      _lastIndex = -1;
      _centerIndex = 0;
      _offset = Duration.zero;
      _currentPosition = widget.position;
      _updateTicker();
      unawaited(_loadOffset());
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    } else if (widget.position != oldWidget.position ||
        widget.playing != oldWidget.playing) {
      _currentPosition = widget.position;
      _updateTicker();
    }

    if (songChanged || lyricsChanged) {
      _lastIndex = -1;
    }

    final List<FreeMusicLyricLine> lines = widget.lyrics?.lines ?? const [];
    final int activeIndex = activeLyricLineIndex(
      lines,
      _currentPosition + _offset,
      lead: lyricHighlightLead,
    );
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
    _ticker?.stop();
    _ticker?.dispose();
    super.dispose();
  }

  void _updateTicker() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _lastTickTime = null;

    if (widget.playing) {
      _lastTickTime = DateTime.now();
      _ticker = createTicker((Duration elapsed) {
        if (!mounted) return;
        final DateTime now = DateTime.now();
        final Duration delta = _lastTickTime != null
            ? now.difference(_lastTickTime!)
            : Duration.zero;
        _lastTickTime = now;

        setState(() {
          _currentPosition += delta;
        });

        final List<FreeMusicLyricLine> lines = widget.lyrics?.lines ?? const [];
        final int activeIndex = activeLyricLineIndex(
          lines,
          _currentPosition + _offset,
          lead: lyricHighlightLead,
        );
        if (activeIndex != _lastIndex && activeIndex >= 0) {
          _lastIndex = activeIndex;
          if (!_isUserScrolling) {
            _scrollToIndex(activeIndex);
          }
        }
      });
      _ticker!.start();
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final double offset = _scrollController.offset;
    final List<FreeMusicLyricLine> lines = widget.lyrics?.lines ?? const [];
    if (lines.isEmpty) return;
    final int calculatedIndex = (offset / _lyricLineHeight).round().clamp(
      0,
      lines.length - 1,
    );
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

  void _resumeAutoScroll() {
    if (!mounted) {
      return;
    }
    _userScrollTimer?.cancel();
    setState(() {
      _isUserScrolling = false;
      _lyricsScrollLocked = false;
    });
    final List<FreeMusicLyricLine> lines = widget.lyrics?.lines ?? const [];
    final int activeIndex = activeLyricLineIndex(
      lines,
      _currentPosition + _offset,
      lead: lyricHighlightLead,
    );
    if (activeIndex >= 0) {
      _scrollToIndex(activeIndex);
    }
  }

  Widget _buildSeekOverlay(FreeMusicLyricLine line) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Positioned(
      left: 0,
      right: 0,
      top: 76.0,
      height: _lyricLineHeight,
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
                  _currentPosition = line.time;
                  _isUserScrolling = false;
                  _lyricsScrollLocked = false;
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
                      const SizedBox(width: AppSpace.xs),
                      Text(
                        '从此处播放 ${formatDuration(line.time)}',
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
      return const Center(child: LuxuryLoadingIndicator());
    }
    if (widget.lyricsError.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '歌词加载失败',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.error,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            TextButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('重试'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              ),
            ),
          ],
        ),
      );
    }
    final List<FreeMusicLyricLine> lines = widget.lyrics?.lines ?? const [];
    if (lines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
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

    final int activeIndex = activeLyricLineIndex(
      lines,
      _currentPosition + _offset,
      lead: lyricHighlightLead,
    );

    return GestureDetector(
      onLongPress: _showOffsetAdjuster,
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
                        _lyricsScrollLocked = true;
                      });
                      _userScrollTimer?.cancel();
                    }
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: lines.length,
                  itemExtent: _lyricLineHeight,
                  padding: const EdgeInsets.symmetric(vertical: 48.0),
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
                            _currentPosition = line.time;
                            _isUserScrolling = false;
                            _lyricsScrollLocked = false;
                          });
                        },
                        child: Align(
                          alignment: Alignment.center,
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: active
                                ? theme.textTheme.titleLarge!.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    shadows: <Shadow>[
                                      Shadow(
                                        color: AppColor.accentRoseEnd
                                            .withValues(alpha: 0.35),
                                        offset: Offset.zero,
                                        blurRadius: 14,
                                      ),
                                    ],
                                  )
                                : theme.textTheme.titleMedium!.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: colors.onSurface.withValues(
                                      alpha: 0.20,
                                    ),
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
            if (_isUserScrolling &&
                lines.isNotEmpty &&
                _centerIndex >= 0 &&
                _centerIndex < lines.length)
              _buildSeekOverlay(lines[_centerIndex]),
            if (_lyricsScrollLocked)
              Positioned(
                right: AppSpace.sm,
                top: AppSpace.sm,
                child: GlassPill(
                  onTap: _resumeAutoScroll,
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.lock_clock_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: AppSpace.xs),
                      Text(
                        '恢复同步',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
      ),
    );
  }
}
