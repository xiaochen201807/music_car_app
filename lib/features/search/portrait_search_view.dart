import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../favorite_song_store.dart';
import '../../free_music_api.dart';
import '../../models/demo_track.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/glass_card.dart';
import '../../shared/portrait_chip.dart';
import '../../shared/portrait_message_card.dart';
import '../../shared/portrait_song_tile.dart';
import '../../shared/staggered_animated_item.dart';
import '../home/portrait_home_view.dart'; // 共享已有的 PortraitSearchHero

class PortraitSearchView extends StatelessWidget {
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
    required this.hotSearchKeywords,
    required this.favoriteSongKeys,
    required this.downloadedSongKeys,
    required this.onSearch,
    required this.onHotKeyword,
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
  final List<String> hotSearchKeywords;
  final Set<String> favoriteSongKeys;
  final Set<String> downloadedSongKeys;
  final VoidCallback onSearch;
  final ValueChanged<String> onHotKeyword;
  final VoidCallback onLoadMore;
  final ValueChanged<int> onPlay;
  final ValueChanged<int> onAddToQueue;
  final ValueChanged<FreeMusicSong> onToggleFavorite;
  final ValueChanged<FreeMusicSong> onDownload;

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
                PortraitSearchHero(controller: controller, onSearch: onSearch),
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: <Widget>[
                    for (final String keyword in hotSearchKeywords.take(8))
                      PortraitChip(
                        label: keyword,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onHotKeyword(keyword);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.xl),
                if (busy && songs.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else if (error.isNotEmpty)
                  PortraitMessageCard(
                    icon: Icons.cloud_off_rounded,
                    title: '搜索失败',
                    message: error,
                  )
                else if (query.isEmpty)
                  const PortraitMessageCard(
                    icon: Icons.travel_explore_rounded,
                    title: '探索在线曲库',
                    message: '输入歌名、歌手或专辑，结果会沿用现有 FreeMusic API。',
                  )
                else if (songs.isEmpty)
                  const PortraitMessageCard(
                    icon: Icons.music_off_rounded,
                    title: '没有结果',
                    message: '换一个关键词再试。',
                  )
                else
                  for (int index = 0; index < songs.length; index += 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: StaggeredAnimatedItem(
                        index: index,
                        child: PortraitSongTile(
                          song: songs[index],
                          visual: demoQueue[index % demoQueue.length],
                          favorite: favoriteSongKeys.contains(
                            favoriteSongKey(songs[index]),
                          ),
                          downloaded: downloadedSongKeys.contains(
                            '${songs[index].source}_${songs[index].id}',
                          ),
                          onPlay: () => onPlay(index),
                          onAddToQueue: () => onAddToQueue(index),
                          onToggleFavorite: () =>
                              onToggleFavorite(songs[index]),
                          onDownload: () => onDownload(songs[index]),
                        ),
                      ),
                    ),
                if (query.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpace.md),
                      child: GlassPill(
                        onTap: (canLoadMore || loadMoreError.isNotEmpty) &&
                                !busy &&
                                !loadMoreBusy
                            ? () {
                                HapticFeedback.lightImpact();
                                onLoadMore();
                              }
                            : null,
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                        child: Center(
                          widthFactor: 1.0,
                          heightFactor: 1.0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (loadMoreBusy)
                                SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.primary,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.expand_more_rounded,
                                  size: 18,
                                  color: (canLoadMore || loadMoreError.isNotEmpty) &&
                                          !busy &&
                                          !loadMoreBusy
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                                ),
                              const SizedBox(width: AppSpace.xs),
                              Text(
                                loadMoreBusy
                                    ? '加载中'
                                    : loadMoreError.isNotEmpty
                                        ? '重试加载'
                                        : canLoadMore
                                            ? '加载更多'
                                            : '已加载全部',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: (canLoadMore || loadMoreError.isNotEmpty) &&
                                          !busy &&
                                          !loadMoreBusy
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.38),
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
