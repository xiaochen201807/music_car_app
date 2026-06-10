import 'package:flutter/material.dart';
import '../../free_music_api.dart';
import '../../theme/design_tokens.dart';
import '../../utils/formatters.dart';
import '../../utils/lyrics_utils.dart';
import '../../shared/portrait_message_card.dart';
import '../../widgets/luxury_loading_indicator.dart';


class LyricsSheet extends StatelessWidget {
  const LyricsSheet({
    super.key,
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.panel),
        ),
      ),
      padding: const EdgeInsets.all(AppSpace.lg),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 头部
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        artist.isEmpty ? '当前歌曲' : artist,
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
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            // 内容
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.58,
              child: LyricsContent(
                lyrics: lyrics,
                loading: loading,
                error: error,
                position: position,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LyricsContent extends StatefulWidget {
  const LyricsContent({
    super.key,
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
  State<LyricsContent> createState() => _LyricsContentState();
}

class _LyricsContentState extends State<LyricsContent> {
  static const double _lineExtent = 62;

  final ScrollController _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void didUpdateWidget(LyricsContent oldWidget) {
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    if (widget.loading) {
      return const Center(child: LuxuryLoadingIndicator());
    }
    if (widget.error.isNotEmpty) {
      return PortraitMessageCard(
        icon: Icons.subtitles_off_rounded,
        title: '歌词加载失败',
        message: widget.error,
      );
    }
    final FreeMusicLyrics? current = widget.lyrics;
    if (current == null || current.isEmpty) {
      return const PortraitMessageCard(
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
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
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
            color: active ? AppColor.fillNeutral : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(
              color: active ? AppColor.strokeHairline : Colors.transparent,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 58,
                child: Text(
                  formatDuration(line.time),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: active ? colors.primary : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontSize: 22,
                            height: 1.38,
                            fontWeight: FontWeight.w900,
                            shadows: <Shadow>[
                              Shadow(
                                color: AppColor.accentRoseEnd.withValues(alpha: 0.35),
                                offset: Offset.zero,
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                      )
                    : Text(
                        line.text,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.22),
                          fontSize: 18,
                          height: 1.38,
                          fontWeight: FontWeight.w500,
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
