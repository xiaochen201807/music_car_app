import 'package:flutter/material.dart';
import '../free_music_api.dart';
import '../models/demo_track.dart';
import '../theme/design_tokens.dart';
import 'portrait_artwork.dart';
import 'portrait_surface.dart';

/// Queue row with a clear "now playing" indicator (Phase 4).
class PortraitQueueTile extends StatelessWidget {
  const PortraitQueueTile({
    super.key,
    required this.song,
    required this.visual,
    required this.selected,
    required this.onTap,
  });

  static const double coverSize = 54;

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
          // Left accent bar for the active track.
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            width: 3,
            height: coverSize,
            margin: const EdgeInsets.only(right: AppSpace.sm),
            decoration: BoxDecoration(
              color: selected ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          PortraitArtwork(
            visual: visual,
            imageUrl: song.cover,
            size: coverSize,
            icon: Icons.music_note_rounded,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: SizedBox(
              height: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    song.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: selected ? colors.primary : colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist.isEmpty ? song.source : song.artist,
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
          if (selected)
            Icon(Icons.graphic_eq_rounded, color: colors.primary, size: 22)
          else
            Icon(
              Icons.drag_handle_rounded,
              color: colors.onSurfaceVariant.withValues(alpha: 0.55),
              size: 22,
            ),
        ],
      ),
    );
  }
}
