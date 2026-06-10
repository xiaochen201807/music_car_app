import 'package:flutter/material.dart';
import '../../favorite_song_store.dart';
import '../../free_music_api.dart';
import '../../models/demo_track.dart';
import '../../theme/design_tokens.dart';
import '../../shared/portrait_message_card.dart';
import '../../shared/portrait_queue_tile.dart';
import '../../shared/portrait_section_header.dart';
import '../../shared/portrait_song_tile.dart';

class PortraitLibraryView extends StatelessWidget {
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
                    FilledButton.tonalIcon(
                      onPressed: favoriteSongs.isEmpty
                          ? null
                          : onPlayAllFavorites,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('播放收藏'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xl),
                PortraitSectionHeader(
                  title: '收藏',
                  label: favoritesBusy ? '加载中' : '${favoriteSongs.length} 首',
                ),
                const SizedBox(height: AppSpace.md),
                if (favoriteSongs.isEmpty)
                  const PortraitMessageCard(
                    icon: Icons.favorite_border_rounded,
                    title: '还没有收藏',
                    message: '在搜索、歌单或播放器点红心即可收藏。',
                  )
                else
                  for (int index = 0; index < favoriteSongs.length; index += 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: PortraitSongTile(
                        song: favoriteSongs[index],
                        visual: demoQueue[index % demoQueue.length],
                        favorite: favoriteSongKeys.contains(
                          favoriteSongKey(favoriteSongs[index]),
                        ),
                        onPlay: () => onPlayFavorite(index),
                        onAddToQueue: null,
                        onToggleFavorite: () =>
                            onToggleFavorite(favoriteSongs[index]),
                      ),
                    ),
                const SizedBox(height: AppSpace.xl2),
                PortraitSectionHeader(
                  title: '当前队列',
                  label: queueSongs.isEmpty ? '空' : '${queueSongs.length} 首',
                ),
                const SizedBox(height: AppSpace.md),
                if (queueSongs.isEmpty)
                  const PortraitMessageCard(
                    icon: Icons.queue_music_rounded,
                    title: '队列为空',
                    message: '播放搜索结果或歌单后，这里会显示队列。',
                  )
                else
                  for (int index = 0; index < queueSongs.length; index += 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: PortraitQueueTile(
                        song: queueSongs[index],
                        visual: demoQueue[index % demoQueue.length],
                        selected: selectedQueueIndex == index,
                        onTap: () => onSelectQueueIndex(index),
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
