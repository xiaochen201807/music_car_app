import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/music_app_state_scope.dart';
import '../../favorite_song_store.dart';
import '../../free_music_api.dart';
import '../../models/demo_track.dart';
import '../../theme/design_tokens.dart';
import '../../shared/portrait_message_card.dart';
import '../../shared/portrait_queue_tile.dart';
import '../../shared/portrait_song_tile.dart';
import '../../shared/staggered_animated_item.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/portrait_segmented_tab.dart';

/// Library sub-tabs: favorites, offline cache, and the live playback queue.
enum _LibraryTab { favorites, offline, queue }

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
  _LibraryTab _selectedTab = _LibraryTab.favorites;
  bool _isBatchMode = false;
  // Identity keys (`source:id`) — FreeMusicSong has no ==, so object identity
  // would break selection after list rebuilds.
  final Set<String> _selectedSongKeys = <String>{};

  static String _songKey(FreeMusicSong song) => '${song.source}:${song.id}';

  List<FreeMusicSong> get _activeSongList {
    switch (_selectedTab) {
      case _LibraryTab.favorites:
        return widget.favoriteSongs;
      case _LibraryTab.offline:
        return widget.downloadedSongs;
      case _LibraryTab.queue:
        return const <FreeMusicSong>[];
    }
  }

  void _selectTab(_LibraryTab tab) {
    if (_selectedTab == tab) {
      return;
    }
    setState(() {
      _selectedTab = tab;
      _isBatchMode = false;
      _selectedSongKeys.clear();
    });
  }

  void _toggleBatchSong(FreeMusicSong song) {
    final String key = _songKey(song);
    setState(() {
      if (_selectedSongKeys.contains(key)) {
        _selectedSongKeys.remove(key);
      } else {
        _selectedSongKeys.add(key);
      }
    });
  }

  void _exitBatchMode() {
    setState(() {
      _isBatchMode = false;
      _selectedSongKeys.clear();
    });
  }

  void _toggleBatchMode() {
    setState(() {
      _isBatchMode = !_isBatchMode;
      _selectedSongKeys.clear();
    });
  }

  List<FreeMusicSong> get _selectedSongs {
    return _activeSongList
        .where((FreeMusicSong song) => _selectedSongKeys.contains(_songKey(song)))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool supportsBatch = _selectedTab != _LibraryTab.queue &&
        _activeSongList.isNotEmpty;

    final Widget mainContent = SafeArea(
      child: CustomScrollView(
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.lg,
              AppSpace.xl,
              AppSpace.md,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                _LibraryHeader(
                  favoriteCount: widget.favoriteSongs.length,
                  downloadedCount: widget.downloadedSongs.length,
                  queueCount: widget.queueSongs.length,
                  selectedQueueIndex: widget.selectedQueueIndex,
                  selectedTab: _selectedTab,
                  onSelectTab: _selectTab,
                ),
                const SizedBox(height: AppSpace.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: PortraitSegmentedTab<_LibraryTab>(
                        expands: true,
                        tabs: const <PortraitSegmentTabItem<_LibraryTab>>[
                          PortraitSegmentTabItem<_LibraryTab>(
                            value: _LibraryTab.favorites,
                            label: '收藏',
                            icon: Icons.favorite_rounded,
                          ),
                          PortraitSegmentTabItem<_LibraryTab>(
                            value: _LibraryTab.offline,
                            label: '离线',
                            icon: Icons.download_done_rounded,
                          ),
                          PortraitSegmentTabItem<_LibraryTab>(
                            value: _LibraryTab.queue,
                            label: '队列',
                            icon: Icons.queue_music_rounded,
                          ),
                        ],
                        selected: _selectedTab,
                        onSelected: _selectTab,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                _LibraryToolbar(
                  tab: _selectedTab,
                  itemCount: _selectedTab == _LibraryTab.queue
                      ? widget.queueSongs.length
                      : _activeSongList.length,
                  busy: _selectedTab == _LibraryTab.favorites &&
                      widget.favoritesBusy,
                  supportsBatch: supportsBatch,
                  isBatchMode: _isBatchMode,
                  playAllLabel: switch (_selectedTab) {
                    _LibraryTab.favorites => '播放全部',
                    _LibraryTab.offline => '播放全部',
                    _LibraryTab.queue => '回到当前',
                  },
                  playAllEnabled: switch (_selectedTab) {
                    _LibraryTab.favorites => widget.favoriteSongs.isNotEmpty,
                    _LibraryTab.offline => widget.downloadedSongs.isNotEmpty,
                    _LibraryTab.queue =>
                      widget.queueSongs.isNotEmpty &&
                          widget.selectedQueueIndex >= 0,
                  },
                  onPlayAll: () {
                    HapticFeedback.lightImpact();
                    switch (_selectedTab) {
                      case _LibraryTab.favorites:
                        widget.onPlayAllFavorites();
                      case _LibraryTab.offline:
                        widget.onPlayAllDownloaded();
                      case _LibraryTab.queue:
                        if (widget.selectedQueueIndex >= 0) {
                          widget.onSelectQueueIndex(widget.selectedQueueIndex);
                        }
                    }
                  },
                  onToggleBatch: supportsBatch
                      ? () {
                          HapticFeedback.lightImpact();
                          _toggleBatchMode();
                        }
                      : null,
                ),
              ],
            ),
          ),
          ..._buildTabBody(theme),
        ],
      ),
    );

    return Stack(
      children: <Widget>[
        Positioned.fill(child: mainContent),
        if (_isBatchMode && supportsBatch) _buildBatchBar(theme),
      ],
    );
  }

  List<Widget> _buildTabBody(ThemeData theme) {
    switch (_selectedTab) {
      case _LibraryTab.favorites:
        return _buildSongListSlivers(
          songs: widget.favoriteSongs,
          emptyIcon: Icons.favorite_border_rounded,
          emptyTitle: '还没有收藏',
          emptyMessage: '在搜索、歌单或播放器点红心即可收藏。',
          loading: widget.favoritesBusy && widget.favoriteSongs.isEmpty,
          loadingLabel: '正在同步收藏',
          onPlayAt: widget.onPlayFavorite,
        );
      case _LibraryTab.offline:
        return _buildSongListSlivers(
          songs: widget.downloadedSongs,
          emptyIcon: Icons.download_done_rounded,
          emptyTitle: '暂无离线歌曲',
          emptyMessage: '在搜索或收藏列表中打开操作菜单，即可下载到本地。',
          loading: false,
          loadingLabel: '',
          onPlayAt: widget.onPlayDownloaded,
          forceDownloaded: true,
        );
      case _LibraryTab.queue:
        return _buildQueueSlivers();
    }
  }

  List<Widget> _buildSongListSlivers({
    required List<FreeMusicSong> songs,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptyMessage,
    required bool loading,
    required String loadingLabel,
    required ValueChanged<int> onPlayAt,
    bool forceDownloaded = false,
  }) {
    if (loading) {
      return <Widget>[
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
                    loadingLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 152)),
      ];
    }

    if (songs.isEmpty) {
      return <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            0,
            AppSpace.xl,
            152,
          ),
          sliver: SliverToBoxAdapter(
            child: PortraitMessageCard(
              icon: emptyIcon,
              title: emptyTitle,
              message: emptyMessage,
            ),
          ),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          0,
          AppSpace.xl,
          152,
        ),
        sliver: GlassPerformanceMode(
          enabled: true,
          child: SliverList.builder(
            itemCount: songs.length,
            itemBuilder: (BuildContext context, int index) {
              final FreeMusicSong song = songs[index];
              final Widget songTile = _isBatchMode
                  ? _buildBatchTile(song, index, forceDownloaded: forceDownloaded)
                  : PortraitSongTile(
                      song: song,
                      visual: demoQueue[index % demoQueue.length],
                      favorite: widget.favoriteSongKeys.contains(
                        favoriteSongKey(song),
                      ),
                      downloaded: forceDownloaded ||
                          widget.downloadedSongKeys.contains(
                            '${song.source}_${song.id}',
                          ),
                      onPlay: () => onPlayAt(index),
                      onAddToQueue: null,
                      onToggleFavorite: () => widget.onToggleFavorite(song),
                      onDownload: forceDownloaded
                          ? null
                          : () => widget.onDownload(song),
                      onDeleteCache: () => widget.onDeleteCache(song),
                    );
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
    ];
  }

  List<Widget> _buildQueueSlivers() {
    if (widget.queueSongs.isEmpty) {
      return <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            0,
            AppSpace.xl,
            152,
          ),
          sliver: const SliverToBoxAdapter(
            child: PortraitMessageCard(
              icon: Icons.queue_music_rounded,
              title: '队列为空',
              message: '播放搜索结果或歌单后，这里会显示当前队列。',
            ),
          ),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          0,
          AppSpace.xl,
          AppSpace.sm,
        ),
        sliver: SliverToBoxAdapter(
          child: Text(
            '长按拖动排序 · 左滑移除 · 点选立即播放',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          0,
          AppSpace.xl,
          152,
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
              (Widget child, int index, Animation<double> animation) => child,
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
                    // Immediate skip — no confirm dialog.
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onSelectQueueIndex(index);
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildBatchTile(
    FreeMusicSong song,
    int index, {
    required bool forceDownloaded,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isSelected = _selectedSongKeys.contains(_songKey(song));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        onTap: () => _toggleBatchSong(song),
        child: Row(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 28,
              alignment: Alignment.center,
              child: Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected ? colors.primary : colors.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: IgnorePointer(
                child: PortraitSongTile(
                  song: song,
                  visual: demoQueue[index % demoQueue.length],
                  favorite: widget.favoriteSongKeys.contains(
                    favoriteSongKey(song),
                  ),
                  downloaded: forceDownloaded ||
                      widget.downloadedSongKeys.contains(
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
      ),
    );
  }

  Widget _buildBatchBar(ThemeData theme) {
    final List<FreeMusicSong> currentList = _activeSongList;
    final bool allSelected = currentList.isNotEmpty &&
        _selectedSongKeys.length == currentList.length;
    return Positioned(
      bottom: 168,
      left: AppSpace.xl,
      right: AppSpace.xl,
      child: GlassCard(
        radius: AppRadius.pill,
        shadows: const <BoxShadow>[],
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.xs,
          ),
          child: Row(
            children: <Widget>[
              Text(
                '已选 ${_selectedSongKeys.length} 首',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _LibraryActionPill(
                icon: allSelected
                    ? Icons.remove_done_rounded
                    : Icons.done_all_rounded,
                label: allSelected ? '取消全选' : '全选',
                compact: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (allSelected) {
                      _selectedSongKeys.clear();
                    } else {
                      _selectedSongKeys
                        ..clear()
                        ..addAll(currentList.map(_songKey));
                    }
                  });
                },
              ),
              const SizedBox(width: AppSpace.sm),
              if (_selectedTab == _LibraryTab.favorites)
                IconButton(
                  tooltip: '批量取消收藏',
                  icon: const Icon(
                    Icons.favorite_rounded,
                    color: AppColor.error,
                  ),
                  onPressed: _selectedSongKeys.isEmpty
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          for (final FreeMusicSong song in _selectedSongs) {
                            widget.onToggleFavorite(song);
                          }
                          _exitBatchMode();
                        },
                ),
              if (_selectedTab == _LibraryTab.offline)
                IconButton(
                  tooltip: '批量删除缓存',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: _selectedSongKeys.isEmpty
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          for (final FreeMusicSong song in _selectedSongs) {
                            widget.onDeleteCache(song);
                          }
                          _exitBatchMode();
                        },
                )
              else
                IconButton(
                  tooltip: '批量下载',
                  icon: const Icon(Icons.download_rounded),
                  onPressed: _selectedSongKeys.isEmpty
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
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.favoriteCount,
    required this.downloadedCount,
    required this.queueCount,
    required this.selectedQueueIndex,
    required this.selectedTab,
    required this.onSelectTab,
  });

  final int favoriteCount;
  final int downloadedCount;
  final int queueCount;
  final int selectedQueueIndex;
  final _LibraryTab selectedTab;
  final ValueChanged<_LibraryTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Column(
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
          '收藏、离线缓存与当前播放队列',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: _LibraryMetricTile(
                icon: Icons.favorite_rounded,
                label: '收藏',
                value: '$favoriteCount',
                selected: selectedTab == _LibraryTab.favorites,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelectTab(_LibraryTab.favorites);
                },
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: _LibraryMetricTile(
                icon: Icons.download_done_rounded,
                label: '离线',
                value: '$downloadedCount',
                selected: selectedTab == _LibraryTab.offline,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelectTab(_LibraryTab.offline);
                },
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
                selected: selectedTab == _LibraryTab.queue,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelectTab(_LibraryTab.queue);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LibraryToolbar extends StatelessWidget {
  const _LibraryToolbar({
    required this.tab,
    required this.itemCount,
    required this.busy,
    required this.supportsBatch,
    required this.isBatchMode,
    required this.playAllLabel,
    required this.playAllEnabled,
    required this.onPlayAll,
    required this.onToggleBatch,
  });

  final _LibraryTab tab;
  final int itemCount;
  final bool busy;
  final bool supportsBatch;
  final bool isBatchMode;
  final String playAllLabel;
  final bool playAllEnabled;
  final VoidCallback onPlayAll;
  final VoidCallback? onToggleBatch;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String countLabel = switch (tab) {
      _LibraryTab.favorites => busy && itemCount == 0 ? '同步中' : '$itemCount 首',
      _LibraryTab.offline => '$itemCount 首',
      _LibraryTab.queue => itemCount == 0 ? '空' : '$itemCount 首',
    };

    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.xs,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(
              alpha: theme.brightness == Brightness.light ? 0.55 : 0.22,
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            countLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Spacer(),
        if (supportsBatch)
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.sm),
            child: _LibraryActionPill(
              icon: isBatchMode ? Icons.close_rounded : Icons.checklist_rounded,
              label: isBatchMode ? '取消' : '批量',
              compact: true,
              onTap: onToggleBatch,
            ),
          ),
        _LibraryActionPill(
          icon: Icons.play_arrow_rounded,
          label: playAllLabel,
          disabled: !playAllEnabled,
          onTap: playAllEnabled ? onPlayAll : null,
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
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool disabled;
  final bool compact;

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
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          icon,
          size: compact ? AppSpace.lg : AppSpace.xl,
          color: foreground,
        ),
        const SizedBox(width: AppSpace.xs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.caption.copyWith(
            color: disabled ? colors.onSurfaceVariant : colors.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );

    if (isLight) {
      return Opacity(
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
      );
    }

    return Opacity(
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
  }
}

class _LibraryMetricTile extends StatelessWidget {
  const _LibraryMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.sm,
            vertical: AppSpace.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? (isLight
                      ? colors.primaryContainer
                      : colors.primary.withValues(alpha: 0.16))
                : colors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.55)
                  : colors.outlineVariant.withValues(alpha: isLight ? 0.5 : 0.25),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                color: selected ? colors.primary : colors.onSurfaceVariant,
                size: 20,
              ),
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
                        fontWeight: FontWeight.w800,
                        color: selected ? colors.primary : colors.onSurface,
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
        ),
      ),
    );
  }
}
