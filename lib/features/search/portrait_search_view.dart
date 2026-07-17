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
    this.hotKeywords = const <String>[],
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
  final List<String> hotKeywords;

  @override
  State<PortraitSearchView> createState() => _PortraitSearchViewState();
}

class _PortraitSearchViewState extends State<PortraitSearchView> {
  final List<String> _searchHistory = <String>[];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    widget.controller.addListener(_handleQueryTextChanged);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    widget.controller.removeListener(_handleQueryTextChanged);
    super.dispose();
  }

  void _handleQueryTextChanged() {
    // Rebuild so the clear button appears/disappears with the field text.
    if (mounted) {
      setState(() {});
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (widget.busy ||
        widget.loadMoreBusy ||
        !widget.canLoadMore ||
        widget.songs.isEmpty) {
      return;
    }
    final ScrollPosition position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      widget.onLoadMore();
    }
  }

  void _runSearch() {
    final String keyword = widget.controller.text.trim();
    if (keyword.isNotEmpty) {
      _addHistory(keyword);
    }
    HapticFeedback.lightImpact();
    widget.onSearch();
  }

  void _useKeyword(String keyword) {
    HapticFeedback.selectionClick();
    widget.controller.text = keyword;
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    _addHistory(keyword);
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
    HapticFeedback.lightImpact();
    setState(_searchHistory.clear);
  }

  void _clearInput() {
    HapticFeedback.selectionClick();
    widget.controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bool showList = widget.songs.isNotEmpty;
    final bool showEmptyState =
        !widget.busy &&
        widget.error.isEmpty &&
        widget.songs.isEmpty &&
        widget.query.isEmpty;
    final bool showNoResults =
        !widget.busy &&
        widget.error.isEmpty &&
        widget.songs.isEmpty &&
        widget.query.isNotEmpty;

    return SafeArea(
      child: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          // Header + input + chips
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.lg,
              AppSpace.xl,
              AppSpace.md,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                _SearchHeader(
                  resultCount: widget.songs.length,
                  query: widget.query,
                  busy: widget.busy || widget.loadMoreBusy,
                ),
                const SizedBox(height: AppSpace.lg),
                _SearchInputBar(
                  controller: widget.controller,
                  busy: widget.busy,
                  onSearch: _runSearch,
                  onClear: widget.controller.text.isEmpty ? null : _clearInput,
                ),
                if (_searchHistory.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpace.lg),
                  _SearchChipSection(
                    title: '最近搜索',
                    actionLabel: '清空',
                    onAction: _clearHistory,
                    actionTooltip: '清空历史',
                    children: <Widget>[
                      for (final String keyword in _searchHistory)
                        PortraitChip(
                          label: keyword,
                          onTap: () => _useKeyword(keyword),
                        ),
                    ],
                  ),
                ] else if (showEmptyState && widget.hotKeywords.isNotEmpty) ...<
                  Widget
                >[
                  const SizedBox(height: AppSpace.lg),
                  _SearchChipSection(
                    title: '热门搜索',
                    children: <Widget>[
                      for (final String keyword in widget.hotKeywords.take(8))
                        PortraitChip(
                          label: keyword,
                          onTap: () => _useKeyword(keyword),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Status / empty / error
          if (widget.busy && widget.songs.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.md,
                AppSpace.xl,
                152,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpace.xl2),
                    child: LuxuryLoadingIndicator(),
                  ),
                ),
              ),
            )
          else if (widget.error.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.md,
                AppSpace.xl,
                152,
              ),
              sliver: SliverToBoxAdapter(
                child: PortraitMessageCard(
                  icon: Icons.cloud_off_rounded,
                  title: '搜索失败',
                  message: widget.error,
                ),
              ),
            )
          else if (showEmptyState)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.md,
                AppSpace.xl,
                152,
              ),
              sliver: SliverToBoxAdapter(
                child: PortraitMessageCard(
                  icon: Icons.travel_explore_rounded,
                  title: '探索在线曲库',
                  message: '输入歌名、歌手或专辑，或点上方热词一键搜索。',
                ),
              ),
            )
          else if (showNoResults)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.md,
                AppSpace.xl,
                152,
              ),
              sliver: SliverToBoxAdapter(
                child: PortraitMessageCard(
                  icon: Icons.music_off_rounded,
                  title: '没有结果',
                  message: '换一个关键词再试。',
                ),
              ),
            ),

          // Results toolbar + list
          if (showList) ...<Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.sm,
                AppSpace.xl,
                AppSpace.md,
              ),
              sliver: SliverToBoxAdapter(
                child: _SearchResultsToolbar(
                  query: widget.query,
                  count: widget.songs.length,
                  busy: widget.busy,
                  onPlayFirst: () {
                    HapticFeedback.lightImpact();
                    widget.onPlay(0);
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              sliver: GlassPerformanceMode(
                enabled: true,
                child: SliverList.builder(
                  itemCount: widget.songs.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Widget tile = _buildSongTile(index);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: index < 6
                          ? StaggeredAnimatedItem(index: index, child: tile)
                          : tile,
                    );
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.md,
                AppSpace.xl,
                152,
              ),
              sliver: SliverToBoxAdapter(
                child: _LoadMoreFooter(
                  canLoadMore: widget.canLoadMore,
                  loadMoreBusy: widget.loadMoreBusy,
                  loadMoreError: widget.loadMoreError,
                  busy: widget.busy,
                  onLoadMore: () {
                    HapticFeedback.lightImpact();
                    widget.onLoadMore();
                  },
                ),
              ),
            ),
          ],
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

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.resultCount,
    required this.query,
    required this.busy,
  });

  final int resultCount;
  final String query;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String subtitle = query.isEmpty
        ? '搜索歌曲、歌手、专辑'
        : busy
        ? '正在同步曲库'
        : '找到 $resultCount 首结果';

    return Row(
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
    );
  }
}

class _SearchInputBar extends StatelessWidget {
  const _SearchInputBar({
    required this.controller,
    required this.busy,
    required this.onSearch,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSearch;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      decoration: BoxDecoration(
        color: isLight
            ? colors.surfaceContainerHighest.withValues(alpha: 0.55)
            : colors.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: isLight ? 0.7 : 0.3),
        ),
      ),
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
                  color: colors.onSurfaceVariant.withValues(alpha: 0.68),
                ),
              ),
            ),
          ),
          if (onClear != null) ...<Widget>[
            IconButton(
              tooltip: '清空',
              visualDensity: VisualDensity.compact,
              onPressed: onClear,
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(width: AppSpace.xs),
          _SearchActionButton(busy: busy, onSearch: onSearch),
        ],
      ),
    );
  }
}

class _SearchActionButton extends StatelessWidget {
  const _SearchActionButton({required this.busy, required this.onSearch});

  final bool busy;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    final Widget label = busy
        ? LuxuryLoadingIndicator(size: 14)
        : Row(
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
          );

    if (isLight) {
      return InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: busy ? null : onSearch,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          alignment: Alignment.center,
          child: label,
        ),
      );
    }

    return GlassPill(
      onTap: busy ? null : onSearch,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      child: label,
    );
  }
}

class _SearchChipSection extends StatelessWidget {
  const _SearchChipSection({
    required this.title,
    required this.children,
    this.actionLabel,
    this.onAction,
    this.actionTooltip,
  });

  final String title;
  final List<Widget> children;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? actionTooltip;

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
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              Tooltip(
                message: actionTooltip ?? actionLabel!,
                child: InkWell(
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

class _SearchResultsToolbar extends StatelessWidget {
  const _SearchResultsToolbar({
    required this.query,
    required this.count,
    required this.busy,
    required this.onPlayFirst,
  });

  final String query;
  final int count;
  final bool busy;
  final VoidCallback onPlayFirst;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String title = query.isEmpty ? '搜索结果' : '“$query”';

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                busy ? '更新中 · $count 首' : '$count 首',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _SearchPlayAllPill(onTap: onPlayFirst),
      ],
    );
  }
}

class _SearchPlayAllPill extends StatelessWidget {
  const _SearchPlayAllPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.play_arrow_rounded, size: 20, color: colors.primary),
        const SizedBox(width: AppSpace.xs),
        Text(
          '播放',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );

    if (isLight) {
      return InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          height: AppSpace.xl4,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: content,
        ),
      );
    }

    return GlassPill(
      onTap: onTap,
      height: AppSpace.xl4,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      child: content,
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({
    required this.canLoadMore,
    required this.loadMoreBusy,
    required this.loadMoreError,
    required this.busy,
    required this.onLoadMore,
  });

  final bool canLoadMore;
  final bool loadMoreBusy;
  final String loadMoreError;
  final bool busy;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool actionable =
        (canLoadMore || loadMoreError.isNotEmpty) && !busy && !loadMoreBusy;
    final String label = loadMoreBusy
        ? '加载中'
        : loadMoreError.isNotEmpty
        ? '重试加载'
        : canLoadMore
        ? '加载更多'
        : '已加载全部';

    return Center(
      child: GlassPill(
        onTap: actionable ? onLoadMore : null,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (loadMoreBusy)
              LuxuryLoadingIndicator(size: 14)
            else
              Icon(
                loadMoreError.isNotEmpty
                    ? Icons.refresh_rounded
                    : canLoadMore
                    ? Icons.expand_more_rounded
                    : Icons.check_rounded,
                size: 18,
                color: actionable
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.38),
              ),
            const SizedBox(width: AppSpace.xs),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: actionable
                    ? colors.onSurface
                    : colors.onSurface.withValues(alpha: 0.38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
