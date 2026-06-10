import 'package:flutter/material.dart';
import '../../favorite_song_store.dart';
import '../../free_music_api.dart';
import '../../models/demo_track.dart';
import '../../theme/design_tokens.dart';
import '../../shared/portrait_message_card.dart';
import '../../shared/portrait_queue_tile.dart';
import '../../shared/portrait_section_header.dart';
import '../../shared/portrait_song_tile.dart';

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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
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
                    if (_selectedSubTab == 0)
                      FilledButton.tonalIcon(
                        onPressed: widget.favoriteSongs.isEmpty
                            ? null
                            : widget.onPlayAllFavorites,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('播放收藏'),
                      )
                    else
                      FilledButton.tonalIcon(
                        onPressed: widget.downloadedSongs.isEmpty
                            ? null
                            : widget.onPlayAllDownloaded,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('播放离线'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                Center(
                  child: SegmentedButton<int>(
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: colors.primaryContainer,
                      selectedForegroundColor: colors.onPrimaryContainer,
                    ),
                    segments: const <ButtonSegment<int>>[
                      ButtonSegment<int>(
                        value: 0,
                        label: Text('我的收藏'),
                        icon: Icon(Icons.favorite_rounded),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        label: Text('离线下载'),
                        icon: Icon(Icons.download_done_rounded),
                      ),
                    ],
                    selected: <int>{_selectedSubTab},
                    onSelectionChanged: (Set<int> newSelection) {
                      setState(() {
                        _selectedSubTab = newSelection.first;
                      });
                    },
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                if (_selectedSubTab == 0) ...<Widget>[
                  PortraitSectionHeader(
                    title: '收藏',
                    label: widget.favoritesBusy
                        ? '加载中'
                        : '${widget.favoriteSongs.length} 首',
                  ),
                  const SizedBox(height: AppSpace.md),
                  if (widget.favoriteSongs.isEmpty)
                    const PortraitMessageCard(
                      icon: Icons.favorite_border_rounded,
                      title: '还没有收藏',
                      message: '在搜索、歌单或播放器点红心即可收藏。',
                    )
                  else
                    for (int index = 0;
                        index < widget.favoriteSongs.length;
                        index += 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm),
                        child: PortraitSongTile(
                          song: widget.favoriteSongs[index],
                          visual: demoQueue[index % demoQueue.length],
                          favorite: widget.favoriteSongKeys.contains(
                            favoriteSongKey(widget.favoriteSongs[index]),
                          ),
                          downloaded: widget.downloadedSongKeys.contains(
                            '${widget.favoriteSongs[index].source}_${widget.favoriteSongs[index].id}',
                          ),
                          onPlay: () => widget.onPlayFavorite(index),
                          onAddToQueue: null,
                          onToggleFavorite: () => widget.onToggleFavorite(
                              widget.favoriteSongs[index]),
                          onDownload: () =>
                              widget.onDownload(widget.favoriteSongs[index]),
                          onDeleteCache: () =>
                              widget.onDeleteCache(widget.favoriteSongs[index]),
                        ),
                      ),
                ] else ...<Widget>[
                  PortraitSectionHeader(
                    title: '离线下载',
                    label: '${widget.downloadedSongs.length} 首',
                  ),
                  const SizedBox(height: AppSpace.md),
                  if (widget.downloadedSongs.isEmpty)
                    const PortraitMessageCard(
                      icon: Icons.download_done_rounded,
                      title: '暂无离线歌曲',
                      message: '在搜索或收藏列表中点击操作菜单可以“下载到本地”。',
                    )
                  else
                    for (int index = 0;
                        index < widget.downloadedSongs.length;
                        index += 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.sm),
                        child: PortraitSongTile(
                          song: widget.downloadedSongs[index],
                          visual: demoQueue[index % demoQueue.length],
                          favorite: widget.favoriteSongKeys.contains(
                            favoriteSongKey(widget.downloadedSongs[index]),
                          ),
                          downloaded: true,
                          onPlay: () => widget.onPlayDownloaded(index),
                          onAddToQueue: null,
                          onToggleFavorite: () => widget.onToggleFavorite(
                              widget.downloadedSongs[index]),
                          onDeleteCache: () => widget.onDeleteCache(
                              widget.downloadedSongs[index]),
                        ),
                      ),
                ],
                const SizedBox(height: AppSpace.xl2),
                PortraitSectionHeader(
                  title: '当前队列',
                  label: widget.queueSongs.isEmpty
                      ? '空'
                      : '${widget.queueSongs.length} 首',
                ),
                const SizedBox(height: AppSpace.md),
                if (widget.queueSongs.isEmpty)
                  const PortraitMessageCard(
                    icon: Icons.queue_music_rounded,
                    title: '队列为空',
                    message: '播放搜索结果或歌单后，这里会显示队列。',
                  )
                else
                  for (int index = 0;
                      index < widget.queueSongs.length;
                      index += 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: PortraitQueueTile(
                        song: widget.queueSongs[index],
                        visual: demoQueue[index % demoQueue.length],
                        selected: widget.selectedQueueIndex == index,
                        onTap: () => widget.onSelectQueueIndex(index),
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
