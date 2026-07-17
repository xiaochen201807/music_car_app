import 'package:flutter/material.dart';
import '../free_music_api.dart';
import '../models/demo_track.dart';
import '../theme/design_tokens.dart';
import 'portrait_artwork.dart';
import 'portrait_surface.dart';

/// Shared list-row for songs (search / library / batch).
/// Phase 4: fixed cover 54, stable two-line height, semantic action colors.
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

  static const double coverSize = 54;

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
            size: coverSize,
            icon: Icons.music_note_rounded,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: SizedBox(
              // Two fixed text lines — reduces vertical jump when metadata varies.
              height: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (downloaded)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpace.xs),
                          child: Icon(
                            Icons.download_done_rounded,
                            size: 14,
                            // Semantic: offline available = primary success cue.
                            color: colors.primary,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          song.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
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
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onAddToQueue != null)
            IconButton(
              tooltip: '加入队列',
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: onAddToQueue!,
              icon: Icon(
                Icons.playlist_add_rounded,
                color: colors.onSurfaceVariant,
              ),
            ),
          IconButton(
            tooltip: favorite ? '取消收藏' : '收藏',
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: onToggleFavorite,
            icon: Icon(
              favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              // Semantic: favorite = primary accent; idle = muted.
              color: favorite ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
          IconButton.filledTonal(
            tooltip: '播放',
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          if (onAddToQueue != null || onDownload != null || onDeleteCache != null)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: colors.onSurfaceVariant,
              ),
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
                  PopupMenuItem<String>(
                    value: 'queue',
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.playlist_add_rounded,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        const Text('加入队列'),
                      ],
                    ),
                  ),
                if (onDownload != null && !downloaded)
                  PopupMenuItem<String>(
                    value: 'download',
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.download_rounded, color: colors.primary),
                        const SizedBox(width: AppSpace.sm),
                        const Text('下载到本地'),
                      ],
                    ),
                  ),
                if (onDeleteCache != null && downloaded)
                  PopupMenuItem<String>(
                    value: 'delete_cache',
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.delete_outline_rounded,
                          color: colors.error,
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Text(
                          '删除缓存',
                          style: TextStyle(color: colors.error),
                        ),
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
