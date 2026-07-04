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
    final Widget innerContent = Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: selected
            ? isLight
                  ? colors.primaryContainer
                  : colors.primaryContainer.withValues(alpha: 0.24)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: child,
    );

    return GlassCard(
      radius: AppRadius.card,
      shadows: const <BoxShadow>[],
      child: onTap == null
          ? innerContent
          : InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: onTap,
              child: innerContent,
            ),
    );
  }
}
