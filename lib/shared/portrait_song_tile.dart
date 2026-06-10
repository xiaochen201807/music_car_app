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
  });

  final FreeMusicSong song;
  final DemoTrack visual;
  final bool favorite;
  final VoidCallback onPlay;
  final VoidCallback? onAddToQueue;
  final VoidCallback onToggleFavorite;

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
          if (onAddToQueue != null)
            IconButton(
              tooltip: '加入队列',
              onPressed: onAddToQueue,
              icon: const Icon(Icons.playlist_add_rounded),
            ),
          IconButton.filledTonal(
            tooltip: '播放',
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }
}
