import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../free_music_api.dart';
import '../../models/demo_track.dart';
import '../../theme/design_tokens.dart';
import '../../shared/portrait_artwork.dart';
import '../../shared/portrait_chip.dart';
import '../../shared/portrait_message_card.dart';
import '../../shared/portrait_section_header.dart';
import '../../shared/staggered_animated_item.dart';
import '../../shared/portrait_circle_button.dart';

class PortraitHomeView extends StatefulWidget {
  const PortraitHomeView({
    super.key,
    required this.controller,
    required this.recommendedPlaylists,
    required this.recommendationsBusy,
    required this.recommendationError,
    required this.playlistSongsBusy,
    required this.currentSong,
    required this.queueSongs,
    required this.searchResults,
    required this.favoriteSongCount,
    required this.downloadedSongCount,
    required this.hotSearchKeywords,
    required this.musicSources,
    required this.sourceBusy,
    required this.sourceError,
    required this.playlistSource,
    required this.onPlaylistSourceChanged,
    required this.onSearch,
    required this.onHotKeyword,
    required this.onSelectPlaylist,
    required this.onOpenPlayer,
    required this.onOpenLibrary,
    required this.onOpenDownloads,
    required this.onOpenSettings,
    required this.onRefresh,
    this.onRetryRecommendations,
  });

  final TextEditingController controller;
  final List<FreeMusicPlaylist> recommendedPlaylists;
  final bool recommendationsBusy;
  final String recommendationError;
  final bool playlistSongsBusy;
  final FreeMusicSong? currentSong;
  final List<FreeMusicSong> queueSongs;
  final List<FreeMusicSong> searchResults;
  final int favoriteSongCount;
  final int downloadedSongCount;
  final List<String> hotSearchKeywords;
  final FreeMusicSources? musicSources;
  final bool sourceBusy;
  final String sourceError;
  final String playlistSource;
  final ValueChanged<String> onPlaylistSourceChanged;
  final VoidCallback onSearch;
  final ValueChanged<String> onHotKeyword;
  final ValueChanged<FreeMusicPlaylist> onSelectPlaylist;
  final VoidCallback onOpenPlayer;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenDownloads;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onRefresh;
  final VoidCallback? onRetryRecommendations;

  @override
  State<PortraitHomeView> createState() => _PortraitHomeViewState();
}

class _PortraitHomeViewState extends State<PortraitHomeView> {
  List<String>? _history;

  @override
  void didUpdateWidget(covariant PortraitHomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _history ??= <String>[];
  }

  @override
  Widget build(BuildContext context) {
    _history ??= <String>[];

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.lg,
                AppSpace.xl,
                152,
              ),
              sliver: SliverList.list(
                children: <Widget>[
                  _SpotifyHomeHeader(
                    controller: widget.controller,
                    onSearch: _runSearch,
                    onOpenSettings: widget.onOpenSettings,
                  ),
                  if (_history != null && _history!.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.lg),
                    _HomeChipSection(
                      title: '最近搜索',
                      actionLabel: '清空',
                      onAction: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _history!.clear();
                        });
                      },
                      children: <Widget>[
                        for (int index = 0; index < _history!.length; index++)
                          GestureDetector(
                            onLongPress: () {
                              final String keyword = _history![index];
                              setState(() {
                                _history!.removeAt(index);
                              });
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('已删除历史: $keyword'),
                                  duration: const Duration(seconds: 4),
                                  action: SnackBarAction(
                                    label: '撤销',
                                    onPressed: () {
                                      setState(() {
                                        _history!.insert(index, keyword);
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                            child: PortraitChip(
                              label: _history![index],
                              onTap: () => _useHistory(_history![index]),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpace.lg),
                  _HomeQuickAccessGrid(
                    currentSong: widget.currentSong,
                    favoriteSongCount: widget.favoriteSongCount,
                    downloadedSongCount: widget.downloadedSongCount,
                    queueSongCount: widget.queueSongs.length,
                    onOpenPlayer: widget.onOpenPlayer,
                    onOpenLibrary: widget.onOpenLibrary,
                    onOpenDownloads: widget.onOpenDownloads,
                    onSearch: _focusSearch,
                  ),
                  if (widget.hotSearchKeywords.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.xl),
                    _HomeChipSection(
                      title: '热门搜索',
                      children: <Widget>[
                        for (final String keyword
                            in widget.hotSearchKeywords.take(8))
                          PortraitChip(
                            label: keyword,
                            onTap: () => widget.onHotKeyword(keyword),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpace.xl2),
                  PortraitSectionHeader(
                    title: '推荐歌单',
                    showLoading:
                        widget.recommendationsBusy || widget.playlistSongsBusy,
                    label:
                        widget.recommendationsBusy || widget.playlistSongsBusy
                        ? '同步中'
                        : null,
                  ),
                  const SizedBox(height: AppSpace.md),
                  _PlaylistSourceSelector(
                    selected: widget.playlistSource,
                    onSelected: widget.onPlaylistSourceChanged,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  if (widget.recommendationError.isNotEmpty &&
                      widget.recommendedPlaylists.isEmpty)
                    PortraitMessageCard(
                      icon: Icons.cloud_off_rounded,
                      title: '推荐加载失败',
                      message: widget.recommendationError,
                      action: widget.onRetryRecommendations != null
                          ? FilledButton.tonal(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                widget.onRetryRecommendations?.call();
                              },
                              child: const Text('重试'),
                            )
                          : null,
                    )
                  else if (widget.recommendedPlaylists.isEmpty &&
                      widget.recommendationsBusy)
                    const PortraitFallbackGrid()
                  else
                    PortraitPlaylistWaterfall(
                      playlists: widget.recommendedPlaylists,
                      busy: widget.playlistSongsBusy,
                      onSelect: widget.onSelectPlaylist,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _runSearch() {
    final String keyword = widget.controller.text.trim();
    if (keyword.isNotEmpty) {
      _addHistory(keyword);
    }
    widget.onSearch();
  }

  void _useHistory(String keyword) {
    widget.controller.text = keyword;
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    widget.onHotKeyword(keyword);
  }

  void _focusSearch() {
    FocusScope.of(context).unfocus();
    _runSearch();
  }

  void _addHistory(String keyword) {
    setState(() {
      _history ??= <String>[];
      _history!
        ..removeWhere((String item) => item == keyword)
        ..insert(0, keyword);
      if (_history!.length > 8) {
        _history!.removeRange(8, _history!.length);
      }
    });
  }
}

class _PlaylistSourceSelector extends StatelessWidget {
  const _PlaylistSourceSelector({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  static const List<_PlaylistSourceOption> _options = <_PlaylistSourceOption>[
    _PlaylistSourceOption(id: 'netease', label: '网易云'),
    _PlaylistSourceOption(id: 'kugou', label: '酷狗'),
    _PlaylistSourceOption(id: 'qq', label: 'QQ'),
    _PlaylistSourceOption(id: 'kuwo', label: '酷我'),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (BuildContext context, int index) {
          final _PlaylistSourceOption option = _options[index];
          final bool isSelected = option.id == selected;
          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                HapticFeedback.selectionClick();
                onSelected(option.id);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary
                    : isLight
                    ? colors.surfaceContainerHighest.withValues(alpha: 0.5)
                    : colors.surfaceContainerHighest.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isSelected
                      ? colors.primary
                      : colors.outlineVariant.withValues(
                          alpha: isLight ? 1 : 0.4,
                        ),
                ),
              ),
              child: Text(
                option.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected ? colors.onPrimary : colors.onSurface,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlaylistSourceOption {
  const _PlaylistSourceOption({required this.id, required this.label});

  final String id;
  final String label;
}

class PortraitPlaylistWaterfall extends StatelessWidget {
  const PortraitPlaylistWaterfall({
    super.key,
    required this.playlists,
    required this.busy,
    required this.onSelect,
  });

  final List<FreeMusicPlaylist> playlists;
  final bool busy;
  final ValueChanged<FreeMusicPlaylist> onSelect;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return const PortraitFallbackGrid();
    }
    final List<FreeMusicPlaylist> left = <FreeMusicPlaylist>[];
    final List<FreeMusicPlaylist> right = <FreeMusicPlaylist>[];
    for (int index = 0; index < playlists.length; index += 1) {
      (index.isEven ? left : right).add(playlists[index]);
    }
    Widget buildColumn(List<FreeMusicPlaylist> column, int columnOffset) {
      return Expanded(
        child: Column(
          children: <Widget>[
            for (int index = 0; index < column.length; index += 1)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: StaggeredAnimatedItem(
                  index: index * 2 + columnOffset,
                  child: PortraitPlaylistWaterfallCard(
                    playlist: column[index],
                    visual: demoQueue[
                        (index * 2 + columnOffset) % demoQueue.length],
                    // 交错高度营造瀑布流层次
                    tall: (index + columnOffset).isEven,
                    onTap: busy ? null : () => onSelect(column[index]),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        buildColumn(left, 0),
        const SizedBox(width: AppSpace.md),
        buildColumn(right, 1),
      ],
    );
  }
}

class PortraitPlaylistWaterfallCard extends StatelessWidget {
  const PortraitPlaylistWaterfallCard({
    super.key,
    required this.playlist,
    required this.visual,
    required this.tall,
    required this.onTap,
  });

  final FreeMusicPlaylist playlist;
  final DemoTrack visual;
  final bool tall;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: AspectRatio(
              aspectRatio: tall ? 0.78 : 1.0,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  PortraitArtwork(
                    visual: visual,
                    imageUrl: playlist.cover,
                    icon: Icons.queue_music_rounded,
                  ),
                  // Soft bottom scrim — lifts contrast for badge / future overlays
                  // without a full-card blur (Phase 2, performance-safe).
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Color(0x00000000),
                            Color(0x66000000),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (playlist.playCount > 0)
                    Positioned(
                      right: AppSpace.xs,
                      top: AppSpace.xs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.scrim.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.play_arrow_rounded,
                              size: 12,
                              color: AppColor.textPrimary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatPlayCount(playlist.playCount),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColor.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            playlist.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (playlist.creator.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              playlist.creator,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatPlayCount(int count) {
    if (count >= 100000000) {
      return '${(count / 100000000).toStringAsFixed(1)}亿';
    }
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    return '$count';
  }
}

class _SpotifyHomeHeader extends StatelessWidget {
  const _SpotifyHomeHeader({
    required this.controller,
    required this.onSearch,
    required this.onOpenSettings,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    final int hour = DateTime.now().hour;
    final String greeting = hour < 11
        ? '早上好'
        : hour < 18
        ? '下午好'
        : '晚上好';

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
                    greeting,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    '搜索、收藏与推荐歌单',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '设置',
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          decoration: BoxDecoration(
            color: isLight
                ? colors.surfaceContainerHighest.withValues(alpha: 0.55)
                : colors.surfaceContainerHighest.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: colors.outlineVariant.withValues(
                alpha: isLight ? 0.7 : 0.3,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.search_rounded, size: 22, color: colors.primary),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: '想听什么？',
                    hintStyle: TextStyle(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.68),
                    ),
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSearch();
                },
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  decoration: BoxDecoration(
                    color: isLight
                        ? colors.primaryContainer
                        : colors.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '搜索',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeChipSection extends StatelessWidget {
  const _HomeChipSection({
    required this.title,
    required this.children,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final List<Widget> children;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: onAction,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: AppSpace.xs,
                  ),
                  child: Text(
                    actionLabel!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: children,
        ),
      ],
    );
  }
}

class _HomeQuickAccessGrid extends StatelessWidget {
  const _HomeQuickAccessGrid({
    required this.currentSong,
    required this.favoriteSongCount,
    required this.downloadedSongCount,
    required this.queueSongCount,
    required this.onOpenPlayer,
    required this.onOpenLibrary,
    required this.onOpenDownloads,
    required this.onSearch,
  });

  final FreeMusicSong? currentSong;
  final int favoriteSongCount;
  final int downloadedSongCount;
  final int queueSongCount;
  final VoidCallback onOpenPlayer;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenDownloads;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final FreeMusicSong? song = currentSong;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: AppSpace.sm,
      mainAxisSpacing: AppSpace.sm,
      childAspectRatio: 3.1,
      children: <Widget>[
        _QuickAccessTile(
          icon: Icons.play_circle_fill_rounded,
          title: song == null ? '继续播放' : song.name,
          subtitle: song == null ? '打开播放器' : song.artist,
          // Phase 2: highlight now-playing with cover thumb when available.
          coverUrl: song?.cover,
          emphasize: song != null,
          onTap: onOpenPlayer,
        ),
        _QuickAccessTile(
          icon: Icons.favorite_rounded,
          title: '收藏歌曲',
          subtitle: favoriteSongCount == 0 ? '暂无收藏' : '$favoriteSongCount 首',
          onTap: onOpenLibrary,
        ),
        _QuickAccessTile(
          icon: Icons.download_done_rounded,
          title: '离线缓存',
          subtitle: downloadedSongCount == 0
              ? '管理下载'
              : '$downloadedSongCount 首',
          onTap: onOpenDownloads,
        ),
        _QuickAccessTile(
          icon: Icons.queue_music_rounded,
          title: '播放队列',
          subtitle: queueSongCount == 0 ? '从搜索开始' : '$queueSongCount 首',
          onTap: queueSongCount == 0 ? onSearch : onOpenLibrary,
        ),
      ],
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.coverUrl,
    this.emphasize = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? coverUrl;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    final bool hasCover = coverUrl != null && coverUrl!.isNotEmpty;
    return BounceTouchable(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          decoration: BoxDecoration(
            color: emphasize
                ? (isLight
                      ? colors.primaryContainer.withValues(alpha: 0.55)
                      : colors.primary.withValues(alpha: 0.12))
                : isLight
                ? colors.surfaceContainer
                : colors.surfaceContainerHighest.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(
              color: emphasize
                  ? colors.primary.withValues(alpha: isLight ? 0.35 : 0.45)
                  : colors.outlineVariant.withValues(
                      alpha: isLight ? 0.55 : 0.25,
                    ),
            ),
          ),
          child: Row(
            children: <Widget>[
              if (hasCover)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: PortraitArtwork(
                    visual: demoQueue.first,
                    imageUrl: coverUrl!,
                    size: 44,
                    icon: Icons.music_note_rounded,
                  ),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    color: isLight
                        ? colors.primaryContainer
                        : colors.primary.withValues(alpha: 0.16),
                  ),
                  child: Icon(icon, color: colors.primary, size: 22),
                ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
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

/// Static skeleton placeholders for recommendation loading.
/// No shimmer animation — keeps first paint cheap on head units (Phase 2).
class PortraitFallbackGrid extends StatelessWidget {
  const PortraitFallbackGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color bone = isLight
        ? colors.surfaceContainerHighest.withValues(alpha: 0.7)
        : colors.surfaceContainerHighest.withValues(alpha: 0.28);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: _SkeletonPlaylistColumn(bone: bone, tallFirst: true)),
        const SizedBox(width: AppSpace.md),
        Expanded(child: _SkeletonPlaylistColumn(bone: bone, tallFirst: false)),
      ],
    );
  }
}

class _SkeletonPlaylistColumn extends StatelessWidget {
  const _SkeletonPlaylistColumn({required this.bone, required this.tallFirst});

  final Color bone;
  final bool tallFirst;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int index = 0; index < 2; index += 1)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AspectRatio(
                  aspectRatio: (tallFirst ? index.isEven : index.isOdd)
                      ? 0.78
                      : 1.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: bone,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: bone,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 96,
                  decoration: BoxDecoration(
                    color: bone.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
