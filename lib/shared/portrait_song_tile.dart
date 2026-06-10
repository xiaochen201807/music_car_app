import 'package:flutter/material.dart';
import '../free_music_api.dart';
import '../models/demo_track.dart';
import '../theme/design_tokens.dart';
import 'portrait_artwork.dart';
import 'portrait_surface.dart';

class PortraitSongTile extends StatelessWidget {
  const PortraitSongTile({
    super.key,
    required this.song,
    required this.visual,
    required this.favorite,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onToggleFavorite,
    this.downloaded = false,
    this.onDownload,
    this.onDeleteCache,
  });

  final FreeMusicSong song;
  final DemoTrack visual;
  final bool favorite;
  final VoidCallback onPlay;
  final VoidCallback? onAddToQueue;
  final VoidCallback onToggleFavorite;
  final bool downloaded;
  final VoidCallback? onDownload;
  final VoidCallback? onDeleteCache;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return PortraitSurface(
      onTap: onPlay,
      child: Row(
        children: <Widget>[
          PortraitArtwork(
            visual: visual,
            imageUrl: song.cover,
            size: 56,
            icon: Icons.music_note_rounded,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (downloaded)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: colors.primary,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        song.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  <String>[
                    song.artist,
                    if (song.album.isNotEmpty) song.album,
                    song.source,
                  ].where((String value) => value.isNotEmpty).join(' · '),
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
              favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: favorite ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
          IconButton.filledTonal(
            tooltip: '播放',
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          if (onAddToQueue != null || onDownload != null || onDeleteCache != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (String value) {
                if (value == 'queue') {
                  onAddToQueue?.call();
                } else if (value == 'download') {
                  onDownload?.call();
                } else if (value == 'delete_cache') {
                  onDeleteCache?.call();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (onAddToQueue != null)
                  const PopupMenuItem<String>(
                    value: 'queue',
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.playlist_add_rounded),
                        SizedBox(width: AppSpace.sm),
                        Text('加入队列'),
                      ],
                    ),
                  ),
                if (onDownload != null && !downloaded)
                  const PopupMenuItem<String>(
                    value: 'download',
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.download_rounded),
                        SizedBox(width: AppSpace.sm),
                        Text('下载到本地'),
                      ],
                    ),
                  ),
                if (onDeleteCache != null && downloaded)
                  const PopupMenuItem<String>(
                    value: 'delete_cache',
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.delete_outline_rounded, color: Colors.red),
                        SizedBox(width: AppSpace.sm),
                        Text('删除缓存', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
