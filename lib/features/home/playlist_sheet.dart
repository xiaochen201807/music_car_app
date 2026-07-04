import 'package:flutter/material.dart';
import '../../favorite_song_store.dart';
import '../../free_music_api.dart';
import '../../models/demo_track.dart';
import '../../theme/design_tokens.dart';
import '../../utils/formatters.dart';
import '../../shared/portrait_artwork.dart';
import '../../shared/portrait_surface.dart';
import '../../widgets/glass_card.dart';

class PlaylistSheet extends StatelessWidget {
  const PlaylistSheet({
    super.key,
    required this.playlist,
    required this.songs,
    required this.total,
    required this.busy,
    required this.error,
    required this.favoriteSongKeys,
    required this.canLoadMore,
    required this.onPlay,
    required this.onToggleFavorite,
    required this.onLoadMore,
  });

  final FreeMusicPlaylist? playlist;
  final List<FreeMusicSong> songs;
  final int total;
  final bool busy;
  final String error;
  final Set<String> favoriteSongKeys;
  final bool canLoadMore;
  final ValueChanged<int> onPlay;
  final ValueChanged<FreeMusicSong> onToggleFavorite;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final FreeMusicPlaylist? current = playlist;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.panel),
        ),
      ),
      padding: const EdgeInsets.all(AppSpace.lg),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 头部信息
            Row(
              children: <Widget>[
                PortraitArtwork(
                  visual: demoQueue.first,
                  imageUrl: current?.cover ?? '',
                  size: 62,
                  icon: Icons.queue_music_rounded,
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        current?.name ?? '推荐歌单',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        <String>[
                          if ((current?.creator ?? '').isNotEmpty)
                            current!.creator,
                          current?.source ?? '',
                          '${songs.length}/${total == 0 ? '?' : total} 首',
                        ].where((String val) => val.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (songs.isNotEmpty) ...<Widget>[
                  const SizedBox(width: AppSpace.sm),
                  GlassPill(
                    onTap: busy
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            onPlay(0);
                          },
                    height: AppSpace.xl4,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.play_arrow_rounded,
                          size: AppSpace.xl,
                          color: colors.primary,
                        ),
                        const SizedBox(width: AppSpace.xs),
                        Text(
                          '播放',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(width: AppSpace.xs),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            // 歌曲列表区域
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.62,
              child: songs.isEmpty && busy
                  ? const Center(child: CircularProgressIndicator())
                  : songs.isEmpty && error.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.queue_music_rounded,
                            color: colors.onSurfaceVariant,
                            size: 48,
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text('歌单加载失败', style: theme.textTheme.titleSmall),
                          Text(error, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: songs.length + 1,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpace.sm),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == songs.length) {
                          return Center(
                            child: TextButton.icon(
                              onPressed: canLoadMore && !busy
                                  ? onLoadMore
                                  : null,
                              icon: busy
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.expand_more_rounded),
                              label: Text(
                                busy
                                    ? '加载中'
                                    : canLoadMore
                                    ? '加载更多'
                                    : '已加载全部',
                              ),
                            ),
                          );
                        }
                        return PlaylistSongRow(
                          song: songs[index],
                          visual: demoQueue[index % demoQueue.length],
                          index: index,
                          favorite: favoriteSongKeys.contains(
                            favoriteSongKey(songs[index]),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            onPlay(index);
                          },
                          onToggleFavorite: () =>
                              onToggleFavorite(songs[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlaylistSongRow extends StatelessWidget {
  const PlaylistSongRow({
    super.key,
    required this.song,
    required this.visual,
    required this.index,
    required this.favorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final FreeMusicSong song;
  final DemoTrack visual;
  final int index;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: PortraitSurface(
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            PortraitArtwork(
              visual: visual,
              imageUrl: song.cover,
              size: 48,
              icon: Icons.album_rounded,
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
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    <String>[
                      song.artist,
                      if (song.album.isNotEmpty) song.album,
                    ].where((String val) => val.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: favorite ? '取消收藏' : '收藏',
              onPressed: onToggleFavorite,
              icon: Icon(
                favorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: favorite ? colors.primary : colors.onSurfaceVariant,
              ),
            ),
            Text(
              formatDuration(Duration(seconds: song.duration)),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
