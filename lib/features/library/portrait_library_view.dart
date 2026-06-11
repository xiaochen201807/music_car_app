import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/music_app_state_scope.dart';
import '../../favorite_song_store.dart';
import '../../free_music_api.dart';
import '../../models/demo_track.dart';
import '../../theme/design_tokens.dart';
import '../../shared/portrait_message_card.dart';
import '../../shared/portrait_queue_tile.dart';
import '../../shared/portrait_section_header.dart';
import '../../shared/portrait_song_tile.dart';
import '../../shared/staggered_animated_item.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/portrait_segmented_tab.dart';

class PortraitLibraryView extends StatefulWidget {
  const PortraitLibraryView({
    super.key,
    required this.favoriteSongs,
    required this.favoriteSongKeys,
    required this.favoritesBusy,
    required this.queueSongs,
    required this.selectedQueueIndex,
    required this.onPlayFavorite,
    required this.onPlayAllFavorites,
    required this.onToggleFavorite,
    required this.onSelectQueueIndex,
    required this.downloadedSongs,
    required this.downloadedSongKeys,
    required this.onPlayDownloaded,
    required this.onPlayAllDownloaded,
    required this.onDownload,
    required this.onDeleteCache,
  });

  final List<FreeMusicSong> favoriteSongs;
  final Set<String> favoriteSongKeys;
  final bool favoritesBusy;
  final List<FreeMusicSong> queueSongs;
  final int selectedQueueIndex;
  final ValueChanged<int> onPlayFavorite;
  final VoidCallback onPlayAllFavorites;
  final ValueChanged<FreeMusicSong> onToggleFavorite;
  final ValueChanged<int> onSelectQueueIndex;

  final List<FreeMusicSong> downloadedSongs;
  final Set<String> downloadedSongKeys;
  final ValueChanged<int> onPlayDownloaded;
  final VoidCallback onPlayAllDownloaded;
  final ValueChanged<FreeMusicSong> onDownload;
  final ValueChanged<FreeMusicSong> onDeleteCache;

  @override
  State<PortraitLibraryView> createState() => _PortraitLibraryViewState();
}

class _PortraitLibraryViewState extends State<PortraitLibraryView> {
  int _selectedSubTab = 0; // 0: 收藏, 1: 离线下载
  bool _isBatchMode = false;
  final Set<FreeMusicSong> _selectedSongs = <FreeMusicSong>{};

  void _toggleBatchSong(FreeMusicSong song) {
    setState(() {
      if (_selectedSongs.contains(song)) {
        _selectedSongs.remove(song);
      } else {
        _selectedSongs.add(song);
      }
    });
  }

  void _exitBatchMode() {
    setState(() {
      _isBatchMode = false;
      _selectedSongs.clear();
    });
  }

  void _handleQueueItemTap(int index, bool isSelected) {
    if (isSelected) {
      widget.onSelectQueueIndex(index);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('切换播放'),
          content: Text('是否要切换播放到队列中的《${widget.queueSongs[index].name}》？'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onSelectQueueIndex(index);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlayButton({
    required bool disabled,
    required VoidCallback? onTap,
    required String label,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return GlassPill(
      onTap: disabled
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap?.call();
            },
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      child: Center(
        widthFactor: 1.0,
        heightFactor: 1.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1.0),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 18,
                color: disabled
                    ? colors.onSurface.withValues(alpha: 0.38)
                    : colors.primary,
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: disabled
                    ? colors.onSurface.withValues(alpha: 0.38)
                    : colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchButton() {
    final bool hasItems = _selectedSubTab == 0
        ? widget.favoriteSongs.isNotEmpty
        : widget.downloadedSongs.isNotEmpty;
    if (!hasItems) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.sm),
      child: GlassPill(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _isBatchMode = !_isBatchMode;
            _selectedSongs.clear();
          });
        },
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        child: Center(
          widthFactor: 1.0,
          heightFactor: 1.0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                _isBatchMode ? Icons.close_rounded : Icons.checklist_rounded,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: AppSpace.xs),
              Text(
                _isBatchMode ? '取消' : '批量操作',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatchTile(FreeMusicSong song, int index) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isSelected = _selectedSongs.contains(song);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleBatchSong(song),
      child: Row(
        children: <Widget>[
          Icon(
            isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
            color: isSelected ? colors.primary : colors.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: IgnorePointer(
              child: PortraitSongTile(
                song: song,
                visual: demoQueue[index % demoQueue.length],
                favorite: widget.favoriteSongKeys.contains(favoriteSongKey(song)),
                downloaded: widget.downloadedSongKeys.contains('${song.source}_${song.id}'),
                onPlay: () {},
                onAddToQueue: null,
                onToggleFavorite: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final Widget mainContent = SafeArea(
      child: CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.lg,
              AppSpace.xl,
              0,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '音乐库',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _buildBatchButton(),
                    _buildPlayButton(
                      disabled: _selectedSubTab == 0
                          ? widget.favoriteSongs.isEmpty
                          : widget.downloadedSongs.isEmpty,
                      onTap: _selectedSubTab == 0
                          ? widget.onPlayAllFavorites
                          : widget.onPlayAllDownloaded,
                      label: _selectedSubTab == 0 ? '播放收藏' : '播放离线',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                Center(
                  child: PortraitSegmentedTab<int>(
                    tabs: const <PortraitSegmentTabItem<int>>[
                      PortraitSegmentTabItem<int>(
                        value: 0,
                        label: '我的收藏',
                        icon: Icons.favorite_rounded,
                      ),
                      PortraitSegmentTabItem<int>(
                        value: 1,
                        label: '离线下载',
                        icon: Icons.download_done_rounded,
                      ),
                    ],
                    selected: _selectedSubTab,
                    onSelected: (int val) {
                      setState(() {
                        _selectedSubTab = val;
                        _isBatchMode = false;
                        _selectedSongs.clear();
                      });
                    },
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                if (_selectedSubTab == 0) ...<Widget>[
                  const PortraitSectionHeader(
                    title: '收藏',
                  ),
                  const SizedBox(height: AppSpace.md),
                  if (widget.favoriteSongs.isEmpty)
                    const PortraitMessageCard(
                      icon: Icons.favorite_border_rounded,
                      title: '还没有收藏',
                      message: '在搜索、歌单或播放器点红心即可收藏。',
                    )
                  else
                    // 禁用 BackdropFilter 以降低 GPU 渲染压力
                    GlassPerformanceMode(
                      enabled: true,
                      child: SliverToBoxAdapter(
                        child: Column(
                          children: List<Widget>.generate(
                            widget.favoriteSongs.length,
                            (int index) {
                              final FreeMusicSong song = widget.favoriteSongs[index];
                              final Widget songTile = _isBatchMode
                                  ? _buildBatchTile(song, index)
                                  : PortraitSongTile(
                                      song: song,
                                      visual: demoQueue[index % demoQueue.length],
                                      favorite: widget.favoriteSongKeys.contains(
                                        favoriteSongKey(song),
                                      ),
                                      downloaded: widget.downloadedSongKeys.contains(
                                        '${song.source}_${song.id}',
                                      ),
                                      onPlay: () => widget.onPlayFavorite(index),
                                      onAddToQueue: null,
                                      onToggleFavorite: () => widget.onToggleFavorite(song),
                                      onDownload: () => widget.onDownload(song),
                                      onDeleteCache: () => widget.onDeleteCache(song),
                                    );
                              // 仅前 6 项启用入场动画
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                                child: index < 6
                                    ? StaggeredAnimatedItem(index: index, child: songTile)
                                    : songTile,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ] else ...<Widget>[
                  PortraitSectionHeader(
                    title: '离线下载',
                  ),
                  const SizedBox(height: AppSpace.md),
                  if (widget.downloadedSongs.isEmpty)
                    const PortraitMessageCard(
                      icon: Icons.download_done_rounded,
                      title: '暂无离线歌曲',
                      message: '在搜索或收藏列表中点击操作菜单可以“下载到本地”。',
                    )
                  else
                    // 禁用 BackdropFilter 以降低 GPU 渲染压力
                    GlassPerformanceMode(
                      enabled: true,
                      child: SliverToBoxAdapter(
                        child: Column(
                          children: List<Widget>.generate(
                            widget.downloadedSongs.length,
                            (int index) {
                              final FreeMusicSong song = widget.downloadedSongs[index];
                              final Widget songTile = _isBatchMode
                                  ? _buildBatchTile(song, index)
                                  : PortraitSongTile(
                                      song: song,
                                      visual: demoQueue[index % demoQueue.length],
                                      favorite: widget.favoriteSongKeys.contains(
                                        favoriteSongKey(song),
                                      ),
                                      downloaded: true,
                                      onPlay: () => widget.onPlayDownloaded(index),
                                      onAddToQueue: null,
                                      onToggleFavorite: () => widget.onToggleFavorite(song),
                                      onDeleteCache: () => widget.onDeleteCache(song),
                                    );
                              // 仅前 6 项启用入场动画
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                                child: index < 6
                                    ? StaggeredAnimatedItem(index: index, child: songTile)
                                    : songTile,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: AppSpace.xl2),
                PortraitSectionHeader(
                  title: '当前队列',
                  label: widget.queueSongs.isEmpty ? '空' : null,
                ),
                const SizedBox(height: AppSpace.md),
              ],
            ),
          ),
          if (widget.queueSongs.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                0,
                AppSpace.xl,
                140,
              ),
              sliver: SliverToBoxAdapter(
                child: const PortraitMessageCard(
                  icon: Icons.queue_music_rounded,
                  title: '队列为空',
                  message: '播放搜索结果或歌单后，这里会显示队列。',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                0,
                AppSpace.xl,
                140,
              ),
              sliver: SliverReorderableList(
                itemCount: widget.queueSongs.length,
                // ignore: deprecated_member_use
                onReorder: (int oldIdx, int newIdx) {
                  HapticFeedback.lightImpact();
                  MusicAppStateScope.of(context).reorderQueue(oldIdx, newIdx);
                },
                itemBuilder: (BuildContext context, int index) {
                  final FreeMusicSong song = widget.queueSongs[index];
                  final bool isSelected = widget.selectedQueueIndex == index;
                  return ReorderableDragStartListener(
                    key: ValueKey<String>('queue-item-${song.source}-${song.id}-$index'),
                    index: index,
                    child: Dismissible(
                      key: ValueKey<String>('dismiss-queue-item-${song.source}-${song.id}-$index'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: AppSpace.md),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.panel),
                        ),
                        child: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
                      ),
                      onDismissed: (DismissDirection direction) {
                        HapticFeedback.mediumImpact();
                        MusicAppStateScope.of(context).removeQueueItem(index);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm),
                        child: PortraitQueueTile(
                          song: song,
                          visual: demoQueue[index % demoQueue.length],
                          selected: isSelected,
                          onTap: () => _handleQueueItemTap(index, isSelected),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );

    return Stack(
      children: <Widget>[
        Positioned.fill(child: mainContent),
        if (_isBatchMode)
          Positioned(
            bottom: 140,
            left: AppSpace.xl,
            right: AppSpace.xl,
            child: GlassCard(
              radius: AppRadius.pill,
              shadows: const <BoxShadow>[],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.xs,
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      '已选 ${_selectedSongs.length} 首',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final List<FreeMusicSong> currentList = _selectedSubTab == 0
                            ? widget.favoriteSongs
                            : widget.downloadedSongs;
                        setState(() {
                          if (_selectedSongs.length == currentList.length) {
                            _selectedSongs.clear();
                          } else {
                            _selectedSongs
                              ..clear()
                              ..addAll(currentList);
                          }
                        });
                      },
                      child: Text(
                        _selectedSongs.length ==
                                (_selectedSubTab == 0
                                    ? widget.favoriteSongs.length
                                    : widget.downloadedSongs.length)
                            ? '取消全选'
                            : '全选',
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    if (_selectedSubTab == 0) ...<Widget>[
                      IconButton(
                        tooltip: '批量取消收藏',
                        icon: const Icon(Icons.favorite_rounded, color: Colors.red),
                        onPressed: _selectedSongs.isEmpty
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                for (final FreeMusicSong song in _selectedSongs) {
                                  widget.onToggleFavorite(song);
                                }
                                _exitBatchMode();
                              },
                      ),
                      IconButton(
                        tooltip: '批量下载',
                        icon: Icon(Icons.download_rounded, color: colors.primary),
                        onPressed: _selectedSongs.isEmpty
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                for (final FreeMusicSong song in _selectedSongs) {
                                  if (!widget.downloadedSongKeys.contains(
                                    '${song.source}_${song.id}',
                                  )) {
                                    widget.onDownload(song);
                                  }
                                }
                                _exitBatchMode();
                              },
                      ),
                    ] else ...<Widget>[
                      IconButton(
                        tooltip: '批量删除本地缓存',
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        onPressed: _selectedSongs.isEmpty
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                for (final FreeMusicSong song in _selectedSongs) {
                                  widget.onDeleteCache(song);
                                }
                                _exitBatchMode();
                              },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
