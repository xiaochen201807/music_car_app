import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../favorite_song_store.dart';
import '../../free_music_api.dart';
import '../../models/demo_track.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/luxury_loading_indicator.dart';
import '../../shared/portrait_chip.dart';
import '../../shared/portrait_message_card.dart';
import '../../shared/portrait_song_tile.dart';
import '../../shared/staggered_animated_item.dart';

class PortraitSearchView extends StatefulWidget {
  const PortraitSearchView({
    super.key,
    required this.controller,
    required this.songs,
    required this.busy,
    required this.loadMoreBusy,
    required this.canLoadMore,
    required this.error,
    required this.loadMoreError,
    required this.query,
    required this.favoriteSongKeys,
    required this.downloadedSongKeys,
    required this.onSearch,
    required this.onLoadMore,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onToggleFavorite,
    required this.onDownload,
  });

  final TextEditingController controller;
  final List<FreeMusicSong> songs;
  final bool busy;
  final bool loadMoreBusy;
  final bool canLoadMore;
  final String error;
  final String loadMoreError;
  final String query;
  final Set<String> favoriteSongKeys;
  final Set<String> downloadedSongKeys;
  final VoidCallback onSearch;
  final VoidCallback onLoadMore;
  final ValueChanged<int> onPlay;
  final ValueChanged<int> onAddToQueue;
  final ValueChanged<FreeMusicSong> onToggleFavorite;
  final ValueChanged<FreeMusicSong> onDownload;

  @override
  State<PortraitSearchView> createState() => _PortraitSearchViewState();
}

class _SearchHistoryBar extends StatelessWidget {
  const _SearchHistoryBar({
    required this.history,
    required this.onUse,
    required this.onClear,
  });

  final List<String> history;
  final ValueChanged<String> onUse;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: history.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (BuildContext context, int index) {
          if (index == history.length) {
            return Tooltip(
              message: '清空历史',
              child: GlassPill(
                onTap: onClear,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                child: Center(
                  widthFactor: 1.0,
                  heightFactor: 1.0,
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: colors.onSurface.withValues(alpha: 0.76),
                  ),
                ),
              ),
            );
          }

          final String keyword = history[index];
          return PortraitChip(label: keyword, onTap: () => onUse(keyword));
        },
      ),
    );
  }
}

class _PortraitSearchViewState extends State<PortraitSearchView> {
  final List<String> _searchHistory = <String>[];

  void _runSearch() {
    final String keyword = widget.controller.text.trim();
    if (keyword.isNotEmpty) {
      _addHistory(keyword);
    }
    widget.onSearch();
  }

  void _useHistory(String keyword) {
    HapticFeedback.selectionClick();
    widget.controller.text = keyword;
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    widget.onSearch();
  }

  void _addHistory(String keyword) {
    setState(() {
      _searchHistory
        ..removeWhere((String item) => item == keyword)
        ..insert(0, keyword);
      if (_searchHistory.length > 8) {
        _searchHistory.removeRange(8, _searchHistory.length);
      }
    });
  }

  void _clearHistory() {
    setState(_searchHistory.clear);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool showList = widget.songs.isNotEmpty && !widget.busy;
    final double topSliverBottomPadding = showList ? AppSpace.md : 140.0;

    return SafeArea(
      child: CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.lg,
              AppSpace.xl,
              topSliverBottomPadding,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                _SearchPageHeader(
                  controller: widget.controller,
                  onSearch: _runSearch,
                  resultCount: widget.songs.length,
                  query: widget.query,
                  busy: widget.busy || widget.loadMoreBusy,
                ),
                if (_searchHistory.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.lg),
                  _SearchShelfTitle(
                    title: '最近搜索',
                    actionLabel: '清空',
                    onAction: _clearHistory,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  _SearchHistoryBar(
                    history: _searchHistory,
                    onUse: _useHistory,
                    onClear: _clearHistory,
                  ),
                ],
                const SizedBox(height: AppSpace.xl),
                if (widget.busy && widget.songs.isEmpty)
                  Center(child: LuxuryLoadingIndicator())
                else if (widget.error.isNotEmpty)
                  PortraitMessageCard(
                    icon: Icons.cloud_off_rounded,
                    title: '搜索失败',
                    message: widget.error,
                  )
                else if (widget.query.isEmpty)
                  const PortraitMessageCard(
                    icon: Icons.travel_explore_rounded,
                    title: '探索在线曲库',
                    message: '输入歌名、歌手或专辑，结果会沿用现有 FreeMusic API。',
                  )
                else if (widget.songs.isEmpty)
                  const PortraitMessageCard(
                    icon: Icons.music_off_rounded,
                    title: '没有结果',
                    message: '换一个关键词再试。',
                  ),
              ],
            ),
          ),
          if (showList)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              sliver: SliverList.list(
                children: <Widget>[
                  _SearchShelfTitle(
                    title: widget.query.isEmpty ? '搜索结果' : '“${widget.query}”',
                    actionLabel: '${widget.songs.length} 首',
                  ),
                  const SizedBox(height: AppSpace.sm),
                  GlassPerformanceMode(
                    enabled: true,
                    child: Column(
                      children: <Widget>[
                        for (
                          int index = 0;
                          index < widget.songs.length;
                          index += 1
                        )
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.sm),
                            child: index < 6
                                ? StaggeredAnimatedItem(
                                    index: index,
                                    child: _buildSongTile(index),
                                  )
                                : _buildSongTile(index),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (widget.query.isNotEmpty &&
              widget.songs.isNotEmpty &&
              !widget.busy)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.md,
                AppSpace.xl,
                140,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: GlassPill(
                    onTap:
                        (widget.canLoadMore ||
                                widget.loadMoreError.isNotEmpty) &&
                            !widget.busy &&
                            !widget.loadMoreBusy
                        ? () {
                            HapticFeedback.lightImpact();
                            widget.onLoadMore();
                          }
                        : null,
                    height: 38,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.xl,
                    ),
                    child: Center(
                      widthFactor: 1.0,
                      heightFactor: 1.0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (widget.loadMoreBusy)
                            LuxuryLoadingIndicator(size: 14)
                          else
                            Icon(
                              Icons.expand_more_rounded,
                              size: 18,
                              color:
                                  (widget.canLoadMore ||
                                          widget.loadMoreError.isNotEmpty) &&
                                      !widget.busy &&
                                      !widget.loadMoreBusy
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.38,
                                    ),
                            ),
                          const SizedBox(width: AppSpace.xs),
                          Text(
                            widget.loadMoreBusy
                                ? '加载中'
                                : widget.loadMoreError.isNotEmpty
                                ? '重试加载'
                                : widget.canLoadMore
                                ? '加载更多'
                                : '已加载全部',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color:
                                  (widget.canLoadMore ||
                                          widget.loadMoreError.isNotEmpty) &&
                                      !widget.busy &&
                                      !widget.loadMoreBusy
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.38,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSongTile(int index) {
    final FreeMusicSong song = widget.songs[index];
    return PortraitSongTile(
      song: song,
      visual: demoQueue[index % demoQueue.length],
      favorite: widget.favoriteSongKeys.contains(favoriteSongKey(song)),
      downloaded: widget.downloadedSongKeys.contains(
        '${song.source}_${song.id}',
      ),
      onPlay: () => widget.onPlay(index),
      onAddToQueue: () => widget.onAddToQueue(index),
      onToggleFavorite: () => widget.onToggleFavorite(song),
      onDownload: () => widget.onDownload(song),
    );
  }
}

class _SearchPageHeader extends StatelessWidget {
  const _SearchPageHeader({
    required this.controller,
    required this.onSearch,
    required this.resultCount,
    required this.query,
    required this.busy,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final int resultCount;
  final String query;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    final String subtitle = query.isEmpty
        ? '搜索歌曲、歌手、专辑'
        : busy
        ? '正在同步曲库'
        : '找到 $resultCount 首结果';

    return GlassCard(
      radius: AppRadius.panel,
      padding: const EdgeInsets.all(AppSpace.lg),
      shadows: const <BoxShadow>[],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '搜索',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                LuxuryLoadingIndicator(size: 20)
              else
                Icon(Icons.travel_explore_rounded, color: colors.primary),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            decoration: BoxDecoration(
              color: isLight
                  ? AppColor.paperBase
                  : AppColor.glassTint.withValues(alpha: AppGlass.tintAlpha),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Center(
              child: Row(
                children: <Widget>[
                  Icon(Icons.search_rounded, size: 22, color: colors.primary),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
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
                          color: colors.onSurfaceVariant.withValues(
                            alpha: 0.68,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  if (isLight)
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      onTap: onSearch,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.md,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: colors.primary,
                            ),
                            const SizedBox(width: AppSpace.xs),
                            Text(
                              '搜索',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    GlassPill(
                      onTap: onSearch,
                      height: 36,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: AppSpace.xs),
                          Text(
                            '搜索',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
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

class _SearchShelfTitle extends StatelessWidget {
  const _SearchShelfTitle({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (actionLabel != null)
          Opacity(
            opacity: onAction == null
                ? AppGlass.tintAlpha + AppGlass.ribbonWhiteAlpha
                : 1,
            child: GlassPill(
              onTap: onAction,
              height: AppSpace.xl3,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
              child: Text(
                actionLabel!,
                style: AppType.caption.copyWith(
                  color: onAction == null
                      ? colors.onSurfaceVariant
                      : colors.onSurface,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
