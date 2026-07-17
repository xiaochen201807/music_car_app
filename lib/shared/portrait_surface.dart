import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../widgets/glass_card.dart';

class PortraitSurface extends StatelessWidget {
  const PortraitSurface({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    // Roadmap list-row: tile radius + horizontal md / vertical sm.
    final BorderRadius radius = BorderRadius.circular(AppRadius.tile);
    final Widget innerContent = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: selected
            ? isLight
                  ? colors.primaryContainer
                  : colors.primaryContainer.withValues(alpha: 0.24)
            : Colors.transparent,
        borderRadius: radius,
      ),
      child: child,
    );

    return GlassCard(
      radius: AppRadius.tile,
      shadows: const <BoxShadow>[],
      child: onTap == null
          ? innerContent
          : InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: innerContent,
            ),
    );
  }
}
