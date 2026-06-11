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
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: SweepGradient(
          center: Alignment.center,
          colors: <Color>[
            Colors.grey.shade900,
            Colors.grey.shade800,
            Colors.grey.shade700,
            Colors.grey.shade800,
            Colors.grey.shade900,
          ],
          stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
        ),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Opacity(
          opacity: 0.15,
          child: Icon(
            icon,
            size: size != null ? size! * 0.45 : 24.0,
            color: Colors.white,
          ),
        ),
      ),
    );
    final Widget image = canLoad
        ? CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: size ?? double.infinity,
            height: size ?? double.infinity,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          )
        : placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: size != null
          ? SizedBox(width: size, height: size, child: image)
          : image,
    );
  }
}
