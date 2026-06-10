import 'package:flutter/material.dart';
import '../free_music_api.dart';
import '../models/demo_track.dart';
import '../theme/design_tokens.dart';
import 'portrait_artwork.dart';
import 'portrait_surface.dart';

class PortraitQueueTile extends StatelessWidget {
  const PortraitQueueTile({
    super.key,
    required this.song,
    required this.visual,
    required this.selected,
    required this.onTap,
  });

  final FreeMusicSong song;
  final DemoTrack visual;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return PortraitSurface(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          PortraitArtwork(
            visual: visual,
            imageUrl: song.cover,
            size: 52,
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  song.artist.isEmpty ? song.source : song.artist,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.graphic_eq_rounded, color: colors.primary)
          else
            const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
