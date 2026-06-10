import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/demo_track.dart';
import '../theme/design_tokens.dart';

class PortraitArtwork extends StatelessWidget {
  const PortraitArtwork({
    super.key,
    required this.visual,
    required this.imageUrl,
    required this.icon,
    this.size,
  });

  final DemoTrack visual;
  final String imageUrl;
  final IconData icon;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Uri? uri = Uri.tryParse(imageUrl);
    final bool canLoad =
        uri != null &&
        uri.hasAbsolutePath &&
        (uri.isScheme('http') || uri.isScheme('https'));
    final Widget placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: visual.color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Center(child: Icon(icon, color: colors.onSurfaceVariant)),
    );
    final Widget image = canLoad
        ? CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: size,
            height: size,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          )
        : placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}
