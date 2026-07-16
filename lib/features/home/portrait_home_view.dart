import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../free_music_api.dart';
import '../../models/demo_track.dart';
import '../../theme/design_tokens.dart';
import '../../utils/formatters.dart';
import '../../shared/portrait_artwork.dart';
import '../../shared/portrait_chip.dart';
import '../../shared/portrait_circle_button.dart';

import '../../shared/portrait_message_card.dart';
import '../../shared/portrait_section_header.dart';
import '../../shared/portrait_surface.dart';
import '../../shared/staggered_animated_item.dart';
import '../../widgets/glass_card.dart';

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
                    const SizedBox(height: AppSpace.md),
                    SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _history!.length + 1,
                        itemBuilder: (BuildContext context, int index) {
                          if (index == _history!.length) {
                            return Padding(
                              padding: const EdgeInsets.only(left: AppSpace.xs),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _history!.clear();
                                  });
                                },
                                tooltip: '清空历史',
                              ),
                            );
                          }
                          final String keyword = _history![index];
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpace.sm),
                            child: GestureDetector(
                              onLongPress: () {
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
                                label: keyword,
                                onTap: () => _useHistory(keyword),
                              ),
                            ),
                          );
                        },
                      ),
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
                    PortraitSectionHeader(title: '热门搜索'),
                    const SizedBox(height: AppSpace.md),
                    _HorizontalKeywordShelf(
                      keywords: widget.hotSearchKeywords,
                      onTap: widget.onHotKeyword,
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
              duration: const Duration(milliseconds: 220),
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
                      : colors.outlineVariant.withValues(alpha: isLight ? 1 : 0.4),
                ),
              ),
              child: Text(
                option.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected ? colors.onPrimary : colors.onSurface,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
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
                children: <Widget>[
                  Positioned.fill(
                    child: PortraitArtwork(
                      visual: visual,
                      imageUrl: playlist.cover,
                      icon: Icons.queue_music_rounded,
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
              child: Text(
                greeting,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: '设置',
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        GlassCard(
          height: 48,
          radius: AppRadius.pill,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          shadows: const <BoxShadow>[],
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
                      color: colors.onSurfaceVariant.withValues(alpha: 0.72),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return GlassCard(
      radius: AppRadius.tile,
      padding: EdgeInsets.zero,
      shadows: const <BoxShadow>[],
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  color: colors.primary.withValues(alpha: 0.14),
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
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
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
    );
  }
}

class _HorizontalKeywordShelf extends StatelessWidget {
  const _HorizontalKeywordShelf({required this.keywords, required this.onTap});

  final List<String> keywords;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: keywords.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (BuildContext context, int index) {
          final String keyword = keywords[index];
          return PortraitChip(label: keyword, onTap: () => onTap(keyword));
        },
      ),
    );
  }
}

class PortraitHeroPlaylistShelf extends StatelessWidget {
  const PortraitHeroPlaylistShelf({
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
    return SizedBox(
      height: 178,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: playlists.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.md),
        itemBuilder: (BuildContext context, int index) {
          final FreeMusicPlaylist playlist = playlists[index];
          return SizedBox(
            width: 220,
            child: PortraitPlaylistHeroCard(
              playlist: playlist,
              visual: demoQueue[index % demoQueue.length],
              onTap: busy ? null : () => onSelect(playlist),
            ),
          );
        },
      ),
    );
  }
}

class PortraitPlaylistHeroCard extends StatelessWidget {
  const PortraitPlaylistHeroCard({
    super.key,
    required this.playlist,
    required this.visual,
    required this.onTap,
  });

  final FreeMusicPlaylist playlist;
  final DemoTrack visual;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: PortraitArtwork(
              visual: visual,
              imageUrl: playlist.cover,
              icon: Icons.queue_music_rounded,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    colors.scrim.withValues(alpha: 0.02),
                    colors.scrim.withValues(alpha: 0.76),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpace.md,
            right: AppSpace.md,
            bottom: AppSpace.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  playlist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColor.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (playlist.creator.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    playlist.creator,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColor.textPrimary.withValues(alpha: 0.76),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PortraitPlaylistHorizontalShelf extends StatelessWidget {
  const PortraitPlaylistHorizontalShelf({
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
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: playlists.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.md),
        itemBuilder: (BuildContext context, int index) {
          final FreeMusicPlaylist playlist = playlists[index];
          return SizedBox(
            width: 118,
            child: PortraitPlaylistCard(
              playlist: playlist,
              visual: demoQueue[index % demoQueue.length],
              onTap: busy ? null : () => onSelect(playlist),
            ),
          );
        },
      ),
    );
  }
}

class PortraitSearchHero extends StatefulWidget {
  const PortraitSearchHero({
    super.key,
    required this.controller,
    required this.onSearch,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final bool autofocus;

  @override
  State<PortraitSearchHero> createState() => _PortraitSearchHeroState();
}

class _PortraitSearchHeroState extends State<PortraitSearchHero> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        boxShadow: _isFocused
            ? <BoxShadow>[
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: GlassCard(
        radius: AppRadius.panel,
        shadows: const <BoxShadow>[],
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.panel),
            border: Border.all(
              color: _isFocused
                  ? colors.primary.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.xs,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => widget.onSearch(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: _isFocused
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    hintText: '搜索歌曲、歌手或专辑',
                    hintStyle: TextStyle(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              BounceTouchable(
                onTap: widget.onSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.lg,
                    vertical: AppSpace.sm,
                  ),
                  decoration: BoxDecoration(
                    color: _isFocused
                        ? colors.primary.withValues(alpha: 0.15)
                        : colors.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: _isFocused
                          ? colors.primary.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '搜索',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: _isFocused ? colors.primary : colors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PortraitPlaylistGrid extends StatelessWidget {
  const PortraitPlaylistGrid({
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
    final List<FreeMusicPlaylist> visible = playlists.take(6).toList();
    if (visible.isEmpty) {
      return const PortraitFallbackGrid();
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpace.md,
        mainAxisSpacing: AppSpace.md,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (BuildContext context, int index) {
        return StaggeredAnimatedItem(
          index: index,
          child: PortraitPlaylistCard(
            playlist: visible[index],
            visual: demoQueue[index % demoQueue.length],
            onTap: busy ? null : () => onSelect(visible[index]),
          ),
        );
      },
    );
  }
}

class PortraitPlaylistCard extends StatelessWidget {
  const PortraitPlaylistCard({
    super.key,
    required this.playlist,
    required this.visual,
    required this.onTap,
  });

  final FreeMusicPlaylist playlist;
  final DemoTrack visual;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: PortraitArtwork(
                visual: visual,
                imageUrl: playlist.cover,
                icon: Icons.queue_music_rounded,
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
        ],
      ),
    );
  }
}

class PortraitFallbackGrid extends StatelessWidget {
  const PortraitFallbackGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpace.md,
        mainAxisSpacing: AppSpace.md,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (BuildContext context, int index) {
        final DemoTrack track = demoQueue[index % demoQueue.length];
        return StaggeredAnimatedItem(
          index: index,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: PortraitArtwork(
                  visual: track,
                  imageUrl: '',
                  icon: Icons.album_rounded,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(track.title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        );
      },
    );
  }
}

class PortraitTimelineTile extends StatelessWidget {
  const PortraitTimelineTile({
    super.key,
    required this.song,
    required this.index,
  });

  final FreeMusicSong song;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Row(
      children: <Widget>[
        SizedBox(
          width: AppSpace.xl3,
          child: Column(
            children: <Widget>[
              Container(
                width: AppSpace.sm,
                height: AppSpace.sm,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Container(
                width: 2,
                height: AppSpace.xl3,
                color: colors.outlineVariant,
              ),
            ],
          ),
        ),
        Expanded(
          child: PortraitSurface(
            child: Row(
              children: <Widget>[
                PortraitArtwork(
                  visual: demoQueue[index % demoQueue.length],
                  imageUrl: song.cover,
                  size: 52,
                  icon: Icons.music_note_rounded,
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        song.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        song.artist.isEmpty ? song.source : song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatDuration(Duration(seconds: song.duration)),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
