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
import '../home/portrait_home_view.dart'; // 共享已有的 PortraitSearchHero

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
    return SafeArea(
      child: CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.lg,
              AppSpace.xl,
              140,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                Text(
                  '搜索',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                PortraitSearchHero(
                  controller: widget.controller,
                  onSearch: _runSearch,
                ),
                if (_searchHistory.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.md),
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
                  )
                else
                  for (int index = 0; index < widget.songs.length; index += 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: StaggeredAnimatedItem(
                        index: index,
                        child: PortraitSongTile(
                          song: widget.songs[index],
                          visual: demoQueue[index % demoQueue.length],
                          favorite: widget.favoriteSongKeys.contains(
                            favoriteSongKey(widget.songs[index]),
                          ),
                          downloaded: widget.downloadedSongKeys.contains(
                            '${widget.songs[index].source}_${widget.songs[index].id}',
                          ),
                          onPlay: () => widget.onPlay(index),
                          onAddToQueue: () => widget.onAddToQueue(index),
                          onToggleFavorite: () =>
                              widget.onToggleFavorite(widget.songs[index]),
                          onDownload: () =>
                              widget.onDownload(widget.songs[index]),
                        ),
                      ),
                    ),
                if (widget.query.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpace.md),
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
                                              widget
                                                  .loadMoreError
                                                  .isNotEmpty) &&
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
                                              widget
                                                  .loadMoreError
                                                  .isNotEmpty) &&
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
