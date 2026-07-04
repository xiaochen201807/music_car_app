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
    return _LibraryActionPill(
      icon: Icons.play_arrow_rounded,
      label: label,
      disabled: disabled,
      expanded: true,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
    );
  }

  Widget _buildBatchButton() {
    final bool hasItems = _selectedSubTab == 0
        ? widget.favoriteSongs.isNotEmpty
        : widget.downloadedSongs.isNotEmpty;
    if (!hasItems) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.sm),
      child: _LibraryActionPill(
        icon: _isBatchMode ? Icons.close_rounded : Icons.checklist_rounded,
        label: _isBatchMode ? '取消' : '批量操作',
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _isBatchMode = !_isBatchMode;
            _selectedSongs.clear();
          });
        },
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
            isSelected
                ? Icons.check_circle_rounded
                : Icons.radio_button_off_rounded,
            color: isSelected ? colors.primary : colors.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: IgnorePointer(
              child: PortraitSongTile(
                song: song,
                visual: demoQueue[index % demoQueue.length],
                favorite: widget.favoriteSongKeys.contains(
                  favoriteSongKey(song),
                ),
                downloaded: widget.downloadedSongKeys.contains(
                  '${song.source}_${song.id}',
                ),
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

    final Widget mainContent = SafeArea(
      child: CustomScrollView(
        slivers: <Widget>[
          // 顶部标题栏 + Tab 切换
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.lg,
              AppSpace.xl,
              AppSpace.xl,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                _LibraryHeaderCard(
                  favoriteCount: widget.favoriteSongs.length,
                  downloadedCount: widget.downloadedSongs.length,
                  queueCount: widget.queueSongs.length,
                  selectedQueueIndex: widget.selectedQueueIndex,
                  onPlayAll: _selectedSubTab == 0
                      ? widget.onPlayAllFavorites
                      : widget.onPlayAllDownloaded,
                  playAllDisabled: _selectedSubTab == 0
                      ? widget.favoriteSongs.isEmpty
                      : widget.downloadedSongs.isEmpty,
                  playAllLabel: _selectedSubTab == 0 ? '播放收藏' : '播放离线',
                ),
                const SizedBox(height: AppSpace.lg),
                Row(
                  children: <Widget>[
                    Expanded(
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
                    const SizedBox(width: AppSpace.sm),
                    _buildBatchButton(),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                _buildPlayButton(
                  disabled: _selectedSubTab == 0
                      ? widget.favoriteSongs.isEmpty
                      : widget.downloadedSongs.isEmpty,
                  onTap: _selectedSubTab == 0
                      ? widget.onPlayAllFavorites
                      : widget.onPlayAllDownloaded,
                  label: _selectedSubTab == 0 ? '播放全部收藏' : '播放全部离线',
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
            sliver: SliverToBoxAdapter(
              child: _LibrarySectionIntro(
                icon: _selectedSubTab == 0
                    ? Icons.favorite_rounded
                    : Icons.download_done_rounded,
                title: _selectedSubTab == 0 ? '收藏' : '离线下载',
                subtitle: _selectedSubTab == 0 ? '你标记过的常听歌曲' : '已缓存到本机的歌曲',
                count: _selectedSubTab == 0
                    ? widget.favoriteSongs.length
                    : widget.downloadedSongs.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.md)),
          if (_selectedSubTab == 0) ...<Widget>[
            if (widget.favoritesBusy && widget.favoriteSongs.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                sliver: SliverToBoxAdapter(
                  child: GlassCard(
                    radius: AppRadius.panel,
                    padding: const EdgeInsets.all(AppSpace.lg),
                    shadows: const <BoxShadow>[],
                    child: Row(
                      children: <Widget>[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: AppSpace.md),
                        Text(
                          '正在同步收藏',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (widget.favoriteSongs.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                sliver: SliverToBoxAdapter(
                  child: const PortraitMessageCard(
                    icon: Icons.favorite_border_rounded,
                    title: '还没有收藏',
                    message: '在搜索、歌单或播放器点红心即可收藏。',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                sliver: GlassPerformanceMode(
                  enabled: true,
                  child: SliverList.builder(
                    itemCount: widget.favoriteSongs.length,
                    itemBuilder: (BuildContext context, int index) {
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
                              onToggleFavorite: () =>
                                  widget.onToggleFavorite(song),
                              onDownload: () => widget.onDownload(song),
                              onDeleteCache: () => widget.onDeleteCache(song),
                            );
                      // 仅前 6 项启用入场动画
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm),
                        child: index < 6
                            ? StaggeredAnimatedItem(
                                index: index,
                                child: songTile,
                              )
                            : songTile,
                      );
                    },
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xl2)),
          ]
          // 离线下载列表（懒加载）
          else ...<Widget>[
            if (widget.downloadedSongs.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                sliver: SliverToBoxAdapter(
                  child: const PortraitMessageCard(
                    icon: Icons.download_done_rounded,
                    title: '暂无离线歌曲',
                    message: '在搜索或收藏列表中点击操作菜单可以"下载到本地"。',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                sliver: GlassPerformanceMode(
                  enabled: true,
                  child: SliverList.builder(
                    itemCount: widget.downloadedSongs.length,
                    itemBuilder: (BuildContext context, int index) {
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
                              onToggleFavorite: () =>
                                  widget.onToggleFavorite(song),
                              onDeleteCache: () => widget.onDeleteCache(song),
                            );
                      // 仅前 6 项启用入场动画
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm),
                        child: index < 6
                            ? StaggeredAnimatedItem(
                                index: index,
                                child: songTile,
                              )
                            : songTile,
                      );
                    },
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xl2)),
          ],
          // 当前队列标题
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              0,
              AppSpace.xl,
              AppSpace.md,
            ),
            sliver: SliverToBoxAdapter(
              child: PortraitSectionHeader(
                title: '当前队列',
                label: widget.queueSongs.isEmpty ? '空' : null,
              ),
            ),
          ),
          // 当前队列列表
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
                onReorderStart: (int index) => HapticFeedback.mediumImpact(),
                proxyDecorator:
                    (Widget child, int index, Animation<double> animation) =>
                        child,
                itemBuilder: (BuildContext context, int index) {
                  final FreeMusicSong song = widget.queueSongs[index];
                  final bool isSelected = widget.selectedQueueIndex == index;
                  return ReorderableDragStartListener(
                    key: ValueKey<String>(
                      'queue-item-${song.source}-${song.id}-$index',
                    ),
                    index: index,
                    child: Dismissible(
                      key: ValueKey<String>(
                        'dismiss-queue-item-${song.source}-${song.id}-$index',
                      ),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: AppSpace.md),
                        decoration: BoxDecoration(
                          color: AppColor.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.panel),
                        ),
                        child: const Icon(
                          Icons.delete_sweep_rounded,
                          color: AppColor.error,
                        ),
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
                    _LibraryActionPill(
                      icon:
                          _selectedSongs.length ==
                              (_selectedSubTab == 0
                                  ? widget.favoriteSongs.length
                                  : widget.downloadedSongs.length)
                          ? Icons.remove_done_rounded
                          : Icons.done_all_rounded,
                      label:
                          _selectedSongs.length ==
                              (_selectedSubTab == 0
                                  ? widget.favoriteSongs.length
                                  : widget.downloadedSongs.length)
                          ? '取消全选'
                          : '全选',
                      compact: true,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        final List<FreeMusicSong> currentList =
                            _selectedSubTab == 0
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
                    ),
                    const SizedBox(width: AppSpace.sm),
                    if (_selectedSubTab == 0) ...<Widget>[
                      IconButton(
                        tooltip: '批量取消收藏',
                        icon: const Icon(
                          Icons.favorite_rounded,
                          color: AppColor.error,
                        ),
                        onPressed: _selectedSongs.isEmpty
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                for (final FreeMusicSong song
                                    in _selectedSongs) {
                                  widget.onToggleFavorite(song);
                                }
                                _exitBatchMode();
                              },
                      ),
                    ],
                    IconButton(
                      tooltip: '批量下载',
                      icon: const Icon(Icons.download_rounded),
                      onPressed: _selectedSongs.isEmpty
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              for (final FreeMusicSong song in _selectedSongs) {
                                widget.onDownload(song);
                              }
                              _exitBatchMode();
                            },
                    ),
                    IconButton(
                      tooltip: '关闭',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _exitBatchMode,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LibraryActionPill extends StatelessWidget {
  const _LibraryActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabled = false,
    this.compact = false,
    this.expanded = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool disabled;
  final bool compact;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    final Color foreground = disabled
        ? colors.onSurfaceVariant
        : colors.primary;
    final double opacity = disabled
        ? AppGlass.tintAlpha + AppGlass.ribbonWhiteAlpha
        : 1;
    final Widget content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          icon,
          size: compact ? AppSpace.lg : AppSpace.xl,
          color: foreground,
        ),
        const SizedBox(width: AppSpace.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.copyWith(
              color: disabled ? colors.onSurfaceVariant : colors.onSurface,
            ),
          ),
        ),
      ],
    );
    final Widget pill = isLight
        ? Opacity(
            opacity: opacity,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: disabled ? null : onTap,
              child: Container(
                height: compact ? AppSpace.xl3 : AppSpace.xl4,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? AppSpace.sm : AppSpace.md,
                ),
                decoration: BoxDecoration(
                  color: disabled
                      ? colors.surfaceContainer
                      : colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: content,
              ),
            ),
          )
        : Opacity(
            opacity: opacity,
            child: GlassPill(
              onTap: disabled ? null : onTap,
              height: compact ? AppSpace.xl3 : AppSpace.xl4,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? AppSpace.sm : AppSpace.md,
              ),
              child: content,
            ),
          );

    if (!expanded) return pill;
    return SizedBox(width: double.infinity, child: pill);
  }
}

class _LibraryHeaderCard extends StatelessWidget {
  const _LibraryHeaderCard({
    required this.favoriteCount,
    required this.downloadedCount,
    required this.queueCount,
    required this.selectedQueueIndex,
    required this.onPlayAll,
    required this.playAllDisabled,
    required this.playAllLabel,
  });

  final int favoriteCount;
  final int downloadedCount;
  final int queueCount;
  final int selectedQueueIndex;
  final VoidCallback onPlayAll;
  final bool playAllDisabled;
  final String playAllLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
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
                      '音乐库',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      '收藏、离线和当前队列',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _LibraryActionPill(
                icon: Icons.play_arrow_rounded,
                label: playAllLabel,
                disabled: playAllDisabled,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onPlayAll();
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _LibraryMetricTile(
                  icon: Icons.favorite_rounded,
                  label: '收藏',
                  value: '$favoriteCount',
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _LibraryMetricTile(
                  icon: Icons.download_done_rounded,
                  label: '离线',
                  value: '$downloadedCount',
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _LibraryMetricTile(
                  icon: Icons.queue_music_rounded,
                  label: '队列',
                  value: queueCount == 0
                      ? '0'
                      : selectedQueueIndex >= 0
                      ? '${selectedQueueIndex + 1}/$queueCount'
                      : '$queueCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LibraryMetricTile extends StatelessWidget {
  const _LibraryMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpace.sm),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: colors.primary, size: 20),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
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

class _LibrarySectionIntro extends StatelessWidget {
  const _LibrarySectionIntro({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Row(
      children: <Widget>[
        Container(
          width: AppSpace.xl4 + AppSpace.xs,
          height: AppSpace.xl4 + AppSpace.xs,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Icon(icon, color: colors.primary, size: AppSpace.xl2),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
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
        GlassPill(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Text(
            '$count 首',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
